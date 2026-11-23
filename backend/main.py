"""Arranque del backend de Bel-Aaktun (API v1).

Modos:
  * Producción (por defecto): MySQL.
        python main.py
  * Desarrollo sin base de datos:
        set BEL_REPO=memory
        python main.py
    Crea un administrador de desarrollo (no usar en producción).

Escucha en 5001 para no chocar con el `app.py` actual (5000).
"""

from __future__ import annotations

import os

from bel_aaktun_backend import create_app
from bel_aaktun_backend.repositories import InMemoryRepository
from bel_aaktun_backend.security import hash_password


def build_app():
    modo = os.getenv("BEL_REPO", "mysql").lower()
    entorno = os.getenv("BEL_ENV", "development").lower()

    if modo == "memory":
        if entorno == "production":
            raise SystemExit(
                "BEL_REPO=memory no está permitido en producción: usa MySQL."
            )
        repo = InMemoryRepository()
        email = os.getenv("BEL_ADMIN_EMAIL", "admin@belaaktun.mx")
        password = os.getenv("BEL_ADMIN_PASSWORD", "Admin1234")
        user_id = repo.create_user(
            nombre="Administración (desarrollo)",
            email=email,
            password_hash=hash_password(password),
        )
        repo.set_user_role(user_id, "admin")
        print(f"[dev] repositorio en memoria · admin: {email} / {password}")
        return create_app(repository=repo)

    return create_app()


app = build_app()

if __name__ == "__main__":
    host = os.getenv("BEL_HOST", "127.0.0.1")
    port = int(os.getenv("BEL_PORT", "5001"))
    if host == "0.0.0.0":
        print("[dev] escuchando en toda la red local (usa HTTPS en producción)")
        print("[dev] desde un teléfono usa la IP de esta computadora, por ejemplo:")
        print("[dev]   http://192.168.1.50:5001/api/v1")
    app.run(host=host, port=port, debug=False)
