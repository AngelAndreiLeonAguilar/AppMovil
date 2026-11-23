"""Servidor de pruebas de Bel-Aaktun para la red local (WiFi).

Permite probar la app en dos o más teléfonos a la vez (por ejemplo, uno como
artesano y otro como turista) sin montar un backend real. Guarda los datos
compartidos de la app y las fotos en esta carpeta.

Uso (en la computadora, conectada al mismo WiFi que los teléfonos):

    python tools/servidor_pruebas/servidor.py

Luego, en cada teléfono: pantalla de inicio de sesión → "Servidor de pruebas"
→ escribe la dirección que muestra este programa (ej. 192.168.1.50).

Solo usa la biblioteca estándar de Python. NO es para producción: no tiene
cifrado (HTTP) y cualquiera en la misma red puede leer los datos.
"""

from __future__ import annotations

import json
import os
import re
import socket
import sys
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PORT = int(os.environ.get("BEL_PORT", "8787"))
BASE = Path(__file__).resolve().parent
DATA_DIR = Path(os.environ.get("BEL_DATA", BASE / "datos"))
STATE_FILE = DATA_DIR / "estado.json"
PHOTOS_DIR = DATA_DIR / "fotos"

# Solo se aceptan las claves que la app comparte entre teléfonos.
ALLOWED_KEYS = {
    "local.auth.v1",
    "bookings.v1",
    "notifications.v1",
    "products.v1",
    "services.v1",
    "artisans.v1",
    "orders.v1",
    "avatars.v1",
    "ledger.v1",
    "finance.settings.v1",
}
MAX_VALUE = 5 * 1024 * 1024  # 5 MB por clave
MAX_PHOTO = 12 * 1024 * 1024  # 12 MB por foto
PHOTO_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/heic": ".heic",
}
SAFE_NAME = re.compile(r"^[A-Za-z0-9_-]+\.(jpg|png|webp|heic)$")

_lock = threading.Lock()
_seen_clients: set[str] = set()
_state: dict[str, str] = {}
_version = 0


def _load() -> None:
    global _state, _version
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    PHOTOS_DIR.mkdir(parents=True, exist_ok=True)
    if STATE_FILE.exists():
        try:
            raw = json.loads(STATE_FILE.read_text(encoding="utf-8"))
            _state = {
                key: value
                for key, value in raw.get("values", {}).items()
                if key in ALLOWED_KEYS and isinstance(value, str)
            }
            _version = int(raw.get("version", 0))
        except (ValueError, OSError) as error:
            print(f"! No se pudo leer {STATE_FILE}: {error}. Se empieza vacío.")


def _save() -> None:
    temp = STATE_FILE.with_suffix(".tmp")
    temp.write_text(
        json.dumps({"version": _version, "values": _state}, ensure_ascii=False),
        encoding="utf-8",
    )
    temp.replace(STATE_FILE)


class Handler(BaseHTTPRequestHandler):
    server_version = "BelAaktunPruebas/1.0"

    def log_message(self, fmt: str, *args) -> None:  # noqa: D401
        client = self.client_address[0]
        if client not in _seen_clients:
            _seen_clients.add(client)
            print(f"{time.strftime('%H:%M:%S')} >>> Nuevo teléfono conectado: {client}")
        # Registro breve: método y ruta.
        if self.command != "GET" or "/fotos/" in self.path:
            sys.stdout.write(
                f"{time.strftime('%H:%M:%S')} {self.client_address[0]} "
                f"{self.command} {self.path.split('?')[0]}\n"
            )

    # -- utilidades ---------------------------------------------------------

    def _json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _body(self, limit: int) -> bytes | None:
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0 or length > limit:
            self._json(413 if length > limit else 400, {"error": "Tamaño inválido."})
            return None
        return self.rfile.read(length)

    # -- rutas --------------------------------------------------------------

    def do_GET(self) -> None:  # noqa: N802
        path = self.path.split("?")[0]
        if path in ("/", "/index.html"):
            # Página para comprobar la conexión desde el navegador del teléfono.
            body = (
                "<!doctype html><meta charset='utf-8'>"
                "<meta name='viewport' content='width=device-width'>"
                "<body style='font-family:sans-serif;padding:24px;"
                "background:#f4efe6;color:#2a1d16'>"
                "<h1>&#9989; Bel-Aaktun</h1>"
                "<p>El servidor de pruebas funciona y este teléfono "
                "<b>sí llega</b> a la computadora.</p>"
                f"<p>Dirección para la app: <b>{self.headers.get('Host')}</b></p>"
                "</body>"
            ).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            self.log_message("%s", "pagina")
            return
        if path == "/health":
            self._json(200, {"status": "ok", "app": "bel-aaktun", "version": _version})
            return
        if path == "/state":
            with _lock:
                self._json(200, {"version": _version, "values": dict(_state)})
            return
        if path.startswith("/fotos/"):
            name = path[len("/fotos/"):]
            file = PHOTOS_DIR / name
            if not SAFE_NAME.match(name) or not file.exists():
                self._json(404, {"error": "Foto no encontrada."})
                return
            data = file.read_bytes()
            ext = file.suffix.lower()
            content_type = next(
                (ctype for ctype, suffix in PHOTO_TYPES.items() if suffix == ext),
                "application/octet-stream",
            )
            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "public, max-age=86400")
            self.end_headers()
            self.wfile.write(data)
            return
        self._json(404, {"error": "Ruta no encontrada."})

    def do_PUT(self) -> None:  # noqa: N802
        global _version
        path = self.path.split("?")[0]
        if not path.startswith("/state/"):
            self._json(404, {"error": "Ruta no encontrada."})
            return
        key = path[len("/state/"):]
        if key not in ALLOWED_KEYS:
            self._json(400, {"error": f"Clave no permitida: {key}"})
            return
        body = self._body(MAX_VALUE)
        if body is None:
            return
        try:
            value = body.decode("utf-8")
            json.loads(value)  # Debe ser JSON válido.
        except (UnicodeDecodeError, ValueError):
            self._json(400, {"error": "El valor debe ser JSON."})
            return
        with _lock:
            _state[key] = value
            _version += 1
            _save()
            self._json(200, {"version": _version})

    def do_DELETE(self) -> None:  # noqa: N802
        global _version
        path = self.path.split("?")[0]
        key = path[len("/state/"):] if path.startswith("/state/") else ""
        if key not in ALLOWED_KEYS:
            self._json(400, {"error": "Clave no permitida."})
            return
        with _lock:
            _state.pop(key, None)
            _version += 1
            _save()
            self._json(200, {"version": _version})

    def do_POST(self) -> None:  # noqa: N802
        path = self.path.split("?")[0]
        if path != "/fotos":
            self._json(404, {"error": "Ruta no encontrada."})
            return
        content_type = (self.headers.get("Content-Type") or "").split(";")[0]
        ext = PHOTO_TYPES.get(content_type.strip().lower())
        if ext is None:
            self._json(415, {"error": "Solo se aceptan fotos JPG, PNG, WEBP o HEIC."})
            return
        body = self._body(MAX_PHOTO)
        if body is None:
            return
        name = f"{uuid.uuid4().hex}{ext}"
        (PHOTOS_DIR / name).write_bytes(body)
        self._json(200, {"path": f"/fotos/{name}"})


def _local_ips() -> list[str]:
    ips: set[str] = set()
    try:
        # Truco común: la IP con la que saldría a internet.
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            probe.connect(("8.8.8.8", 80))
            ips.add(probe.getsockname()[0])
    except OSError:
        pass
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            ips.add(info[4][0])
    except OSError:
        pass
    return sorted(ip for ip in ips if not ip.startswith("127."))


def main() -> None:
    sys.stdout.reconfigure(line_buffering=True)
    _load()
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print("=" * 62)
    print(" Servidor de pruebas de Bel-Aaktun")
    print("=" * 62)
    print(f" Datos y fotos en: {DATA_DIR}")
    print(" En cada teléfono escribe una de estas direcciones:")
    for ip in _local_ips() or ["(no se detectó la IP; revisa tu WiFi)"]:
        print(f"     {ip}:{PORT}")
    print()
    print(" Para comprobar desde un teléfono, abre en Chrome:")
    for ip in _local_ips()[:1]:
        print(f"     http://{ip}:{PORT}")
    print(" Los teléfonos deben estar en el MISMO WiFi que esta computadora.")
    print(" Si Windows pregunta por el firewall, elige 'Permitir' en redes")
    print(" privadas. Para detener el servidor: Ctrl + C")
    print("=" * 62)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServidor detenido.")


if __name__ == "__main__":
    main()
