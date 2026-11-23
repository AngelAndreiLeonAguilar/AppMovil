"""Configuración del backend por variables de entorno.

Nada de secretos en el código: la app toma estos valores de `.env` o del
entorno del servidor.
"""

from __future__ import annotations

import os
from dataclasses import dataclass


def _int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, str(default)))
    except ValueError:
        return default


@dataclass(frozen=True)
class Settings:
    secret_key: str
    access_ttl_seconds: int
    refresh_ttl_seconds: int
    db_host: str
    db_port: int
    db_user: str
    db_password: str
    db_name: str
    cors_origins: list[str]
    login_max_attempts: int
    login_window_seconds: int

    @classmethod
    def from_env(cls) -> "Settings":
        secret = os.getenv("BEL_SECRET_KEY", "")
        if not secret:
            # En desarrollo se permite un secreto efímero; en producción es
            # obligatorio definirlo (falla al primer token).
            secret = "dev-insecure-secret-change-me"
        origins = os.getenv("BEL_CORS_ORIGINS", "")
        return cls(
            secret_key=secret,
            access_ttl_seconds=_int("BEL_ACCESS_TTL", 15 * 60),
            refresh_ttl_seconds=_int("BEL_REFRESH_TTL", 30 * 24 * 60 * 60),
            db_host=os.getenv("DB_HOST", "127.0.0.1"),
            db_port=_int("DB_PORT", 3307),
            db_user=os.getenv("DB_USER", "becal_user"),
            db_password=os.getenv("DB_PASSWORD", ""),
            db_name=os.getenv("DB_NAME", "becal_db"),
            cors_origins=[item.strip() for item in origins.split(",") if item.strip()],
            login_max_attempts=_int("BEL_LOGIN_MAX_ATTEMPTS", 5),
            login_window_seconds=_int("BEL_LOGIN_WINDOW", 15 * 60),
        )
