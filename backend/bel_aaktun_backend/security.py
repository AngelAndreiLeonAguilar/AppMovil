"""Seguridad: hash de contraseñas, tokens JWT y decoradores de rol.

Sin dependencias nuevas: JWT HS256 con `hmac`/`hashlib` de la biblioteca
estándar y hash de contraseñas con `werkzeug.security` (viene con Flask).

Regla de oro: el rol que trae el token **no** se usa para autorizar. En cada
petición se recarga el usuario desde la base y se comprueban `rol` y `estado`.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import re
import time
import uuid
from functools import wraps
from typing import Any, Callable

from flask import current_app, g, jsonify, request
from werkzeug.security import check_password_hash, generate_password_hash

ISSUER = "bel-aaktun"


class TokenError(Exception):
    """Token inválido, expirado o de tipo incorrecto."""


# ---------------------------------------------------------------------------
# Codificación base64url sin padding
# ---------------------------------------------------------------------------


def _b64(raw: bytes) -> bytes:
    return base64.urlsafe_b64encode(raw).rstrip(b"=")


def _unb64(raw: bytes) -> bytes:
    return base64.urlsafe_b64decode(raw + b"=" * (-len(raw) % 4))


# ---------------------------------------------------------------------------
# Contraseñas
# ---------------------------------------------------------------------------

# Prefijos que usa Werkzeug al guardar hashes. Si el valor guardado no empieza
# con uno de ellos, es una contraseña legada en texto plano.
_HASH_PREFIXES = ("pbkdf2:", "scrypt:", "argon2")


def hash_password(password: str) -> str:
    return generate_password_hash(password)


def is_password_hash(stored: str | None) -> bool:
    return bool(stored) and stored.startswith(_HASH_PREFIXES)


def verify_password(stored: str | None, password: str) -> bool:
    if not stored:
        return False
    if is_password_hash(stored):
        try:
            return check_password_hash(stored, password)
        except ValueError:
            return False
    # Legado en texto plano: se compara y el llamador debe rehashear.
    return hmac.compare_digest(stored, password)


def password_problem(password: str) -> str | None:
    if len(password) < 8:
        return "La contraseña debe tener al menos 8 caracteres."
    if not re.search(r"[A-Za-z]", password) or not re.search(r"\d", password):
        return "La contraseña debe combinar letras y números."
    return None


EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$")


# ---------------------------------------------------------------------------
# JWT (HS256)
# ---------------------------------------------------------------------------


def create_token(
    *,
    subject: str | int,
    role: str,
    kind: str,
    ttl_seconds: int,
    extra: dict[str, Any] | None = None,
) -> str:
    secret = current_app.config["BEL_SECRET_KEY"]
    issued_at = int(time.time())
    payload: dict[str, Any] = {
        "sub": str(subject),
        "rol": role,
        "type": kind,
        "jti": uuid.uuid4().hex,
        "iat": issued_at,
        "exp": issued_at + ttl_seconds,
        "iss": ISSUER,
    }
    if extra:
        payload.update(extra)

    header = {"alg": "HS256", "typ": "JWT"}
    segments = [
        _b64(json.dumps(header, separators=(",", ":")).encode()),
        _b64(json.dumps(payload, separators=(",", ":")).encode()),
    ]
    signing_input = b".".join(segments)
    signature = hmac.new(secret.encode(), signing_input, hashlib.sha256).digest()
    return b".".join([*segments, _b64(signature)]).decode()


def decode_token(token: str, *, kind: str | None = None) -> dict[str, Any]:
    secret = current_app.config["BEL_SECRET_KEY"]
    try:
        header_b64, payload_b64, signature_b64 = token.split(".")
        signing_input = f"{header_b64}.{payload_b64}".encode()
        expected = hmac.new(secret.encode(), signing_input, hashlib.sha256).digest()
        if not hmac.compare_digest(expected, _unb64(signature_b64.encode())):
            raise TokenError("firma inválida")

        header = json.loads(_unb64(header_b64.encode()))
        if header.get("alg") != "HS256":
            raise TokenError("algoritmo no permitido")

        payload = json.loads(_unb64(payload_b64.encode()))
        if payload.get("iss") != ISSUER:
            raise TokenError("emisor inválido")
        if int(payload.get("exp", 0)) < int(time.time()):
            raise TokenError("token expirado")
        if kind is not None and payload.get("type") != kind:
            raise TokenError("tipo de token inválido")
        return payload
    except TokenError:
        raise
    except Exception as exc:  # formato roto, base64 inválido, JSON inválido
        raise TokenError("token inválido") from exc


def issue_session(user: dict[str, Any]) -> dict[str, Any]:
    access_ttl = int(current_app.config["BEL_ACCESS_TTL"])
    refresh_ttl = int(current_app.config["BEL_REFRESH_TTL"])
    access = create_token(
        subject=user["id"],
        role=user["rol"],
        kind="access",
        ttl_seconds=access_ttl,
    )
    refresh = create_token(
        subject=user["id"],
        role=user["rol"],
        kind="refresh",
        ttl_seconds=refresh_ttl,
    )
    return {
        "access_token": access,
        "refresh_token": refresh,
        "token_type": "Bearer",
        "expires_in": access_ttl,
    }


# ---------------------------------------------------------------------------
# Contexto de petición
# ---------------------------------------------------------------------------


def repository():
    return current_app.extensions["bel_repo"]


def bearer_token() -> str | None:
    header = request.headers.get("Authorization", "")
    if header.startswith("Bearer "):
        return header[7:].strip()
    return None


def load_current_user(required: bool = True) -> dict[str, Any] | None:
    """Carga el usuario desde la base, no desde el token."""
    token = bearer_token()
    if not token:
        if required:
            raise TokenError("falta el token")
        return None

    payload = decode_token(token, kind="access")
    user = repository().find_user(int(payload["sub"]))
    if user is None:
        raise TokenError("usuario inexistente")
    if user.get("estado") != "activo":
        raise PermissionError("cuenta suspendida")
    return user


def auth_required(*roles: str) -> Callable:
    """Exige sesión válida y, opcionalmente, uno de los roles indicados."""

    def decorator(view: Callable) -> Callable:
        @wraps(view)
        def wrapper(*args: Any, **kwargs: Any):
            try:
                user = load_current_user()
            except TokenError as exc:
                return jsonify(error="no autorizado", detalle=str(exc)), 401
            except PermissionError as exc:
                return jsonify(error=str(exc)), 403

            if roles and user["rol"] not in roles:
                return jsonify(error="sin permiso para esta operación"), 403

            g.current_user = user
            return view(*args, **kwargs)

        return wrapper

    return decorator


def client_ip() -> str | None:
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.remote_addr


def audit(
    *,
    actor_id: int | None,
    action: str,
    entity: str,
    entity_id: int | None,
    detail: dict[str, Any] | None = None,
) -> None:
    repository().add_audit(
        actor_id=actor_id,
        accion=action,
        entidad=entity,
        entidad_id=entity_id,
        detalle=detail or {},
        ip=client_ip(),
    )
