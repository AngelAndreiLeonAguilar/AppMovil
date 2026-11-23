"""Prueba de humo de la API por HTTP (sin MySQL).

Uso:
    set BEL_REPO=memory
    python main.py

    # en otra terminal
    python scripts/smoke_test.py
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request

BASE = os.getenv("BEL_API", "http://127.0.0.1:5001")
ADMIN_EMAIL = os.getenv("BEL_ADMIN_EMAIL", "admin@belaaktun.mx")
ADMIN_PASSWORD = os.getenv("BEL_ADMIN_PASSWORD", "Admin1234")
PASSWORD = "Clave1234"


def call(method: str, path: str, payload: dict | None = None, token: str | None = None):
    data = json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(BASE + path, data=data, method=method)
    request.add_header("Content-Type", "application/json")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            body = response.read().decode() or "{}"
            return response.status, json.loads(body)
    except urllib.error.HTTPError as error:
        body = error.read().decode() or "{}"
        try:
            return error.code, json.loads(body)
        except json.JSONDecodeError:
            return error.code, {"raw": body}


def check(label: str, condition: bool, detail: str = "") -> None:
    mark = "OK  " if condition else "FALLA"
    print(f"[{mark}] {label}" + (f" · {detail}" if detail else ""))
    if not condition:
        sys.exit(1)


def main() -> None:
    status, health = call("GET", "/api/v1/health")
    check("servicio arriba", status == 200 and health.get("status") == "ok", str(status))

    email = "humo@belaaktun.mx"
    status, body = call(
        "POST",
        "/api/v1/auth/register",
        {"nombre": "Prueba Humo", "email": email, "password": PASSWORD},
    )
    if status == 409:  # ya existía de una corrida anterior
        status, body = call(
            "POST", "/api/v1/auth/login", {"email": email, "password": PASSWORD}
        )
    check("registro turista", status in (200, 201), str(status))
    token = body["access_token"]
    check("rol forzado a turista", body["user"]["rol"] == "turista", body["user"]["rol"])

    status, body = call("GET", "/api/v1/auth/me", token=token)
    check("perfil autenticado", status == 200, str(status))

    status, body = call(
        "POST",
        "/api/v1/artisan-applications",
        {
            "nombre_taller": "Cueva de prueba",
            "descripcion": "Taller de prueba para validar el flujo completo.",
            "ubicacion": "Bécal, Campeche",
        },
        token=token,
    )
    check("solicitud de taller", status == 201, str(status))
    application_id = body["solicitud"]["id"]

    status, body = call(
        "POST",
        "/api/v1/auth/login",
        {"email": ADMIN_EMAIL, "password": ADMIN_PASSWORD},
    )
    check("login admin", status == 200, str(status))
    admin_token = body["access_token"]

    status, body = call(
        "GET", "/api/v1/artisan-applications?estado=pendiente", token=admin_token
    )
    check("bandeja admin", status == 200 and len(body["solicitudes"]) >= 1, str(status))

    status, body = call(
        "POST",
        f"/api/v1/artisan-applications/{application_id}/review",
        {"decision": "aprobada"},
        token=admin_token,
    )
    check("aprobación", status == 200, str(status))

    status, body = call("GET", "/api/v1/auth/me", token=token)
    check("turista ahora es artesano", body["user"]["rol"] == "artesano", body["user"]["rol"])

    status, body = call("GET", "/api/v1/admin/audit", token=admin_token)
    actions = [item["accion"] for item in body.get("registro", [])]
    check("auditoría registrada", "solicitud_aprobada" in actions, ", ".join(actions[:4]))

    status, body = call(
        "POST",
        "/api/v1/admin/users/99999/suspend",
        {"motivo": "Usuario inexistente para la prueba."},
        token=admin_token,
    )
    check("id inexistente responde 404", status == 404, str(status))

    print("\nFlujo completo verificado por HTTP.")


if __name__ == "__main__":
    main()
