"""Autenticación: registro de turistas, login, refresh, logout y perfil."""

from __future__ import annotations

from datetime import datetime, timezone

from flask import Blueprint, current_app, g, jsonify, request

from ..security import (
    EMAIL_RE,
    TokenError,
    audit,
    auth_required,
    bearer_token,
    client_ip,
    create_token,
    decode_token,
    hash_password,
    is_password_hash,
    issue_session,
    password_problem,
    repository,
    verify_password,
)

auth_bp = Blueprint("bel_auth", __name__)


def _body() -> dict:
    return request.get_json(silent=True) or {}


def public_user(user: dict) -> dict:
    return {
        "id": user["id"],
        "nombre": user["nombre"],
        "email": user["email"],
        "telefono": user.get("telefono"),
        "rol": user["rol"],
        "estado": user["estado"],
        "email_verificado": bool(user.get("email_verificado_en")),
        "taller_id": user.get("taller_id"),
    }


@auth_bp.post("/register")
def register():
    """Registro público: **siempre** crea turistas.

    El campo `rol` del cuerpo se ignora a propósito: un cliente no puede
    registrarse como artesano ni administrador.
    """
    data = _body()
    nombre = (data.get("nombre") or "").strip()
    email = (data.get("email") or "").strip().lower()
    password = data.get("password") or ""
    telefono = (data.get("telefono") or "").strip() or None

    if len(nombre) < 3:
        return jsonify(error="Escribe tu nombre completo."), 422
    if not EMAIL_RE.match(email):
        return jsonify(error="Correo electrónico inválido."), 422
    problem = password_problem(password)
    if problem:
        return jsonify(error=problem), 422

    repo = repository()
    if repo.find_user_by_email(email):
        return jsonify(error="Ese correo ya está registrado."), 409

    user_id = repo.create_user(
        nombre=nombre,
        email=email,
        password_hash=hash_password(password),
        telefono=telefono,
    )
    user = repo.find_user(user_id)
    audit(
        actor_id=user_id,
        action="usuario_registrado",
        entity="usuarios",
        entity_id=user_id,
        detail={"rol": "turista"},
    )
    return jsonify(user=public_user(user), **issue_session(user)), 201


@auth_bp.post("/login")
def login():
    data = _body()
    email = (data.get("email") or "").strip().lower()
    password = data.get("password") or ""
    if not email or not password:
        return jsonify(error="Correo y contraseña requeridos."), 400

    repo = repository()
    max_attempts = int(current_app.config["BEL_LOGIN_MAX_ATTEMPTS"])
    window = int(current_app.config["BEL_LOGIN_WINDOW"])
    if repo.count_recent_failures(email, window) >= max_attempts:
        return (
            jsonify(
                error="Demasiados intentos. Espera unos minutos antes de reintentar."
            ),
            429,
        )

    user = repo.find_user_by_email(email)
    if not user or not verify_password(user.get("password_hash"), password):
        repo.add_attempt(email=email, ip=client_ip(), exito=False)
        # Mismo mensaje para no revelar si el correo existe.
        return jsonify(error="Correo o contraseña incorrectos."), 401

    if user.get("estado") != "activo":
        repo.add_attempt(email=email, ip=client_ip(), exito=False)
        return jsonify(error="La cuenta está suspendida."), 403

    # Migración transparente de contraseñas legadas en texto plano.
    if not is_password_hash(user.get("password_hash")):
        repo.update_user_password(user["id"], hash_password(password))

    repo.add_attempt(email=email, ip=client_ip(), exito=True)
    return jsonify(user=public_user(user), **issue_session(user)), 200


@auth_bp.post("/refresh")
def refresh():
    data = _body()
    token = data.get("refresh_token") or ""
    if not token:
        return jsonify(error="Falta el token de refresco."), 400

    try:
        payload = decode_token(token, kind="refresh")
    except TokenError:
        return jsonify(error="Sesión inválida o expirada."), 401

    repo = repository()
    if repo.is_token_revoked(payload["jti"]):
        return jsonify(error="Sesión revocada."), 401

    user = repo.find_user(int(payload["sub"]))
    if user is None or user.get("estado") != "activo":
        return jsonify(error="Cuenta no disponible."), 403

    # Rotación: el refresh usado deja de servir.
    expires_at = datetime.fromtimestamp(
        int(payload["exp"]), tz=timezone.utc
    ).replace(tzinfo=None)
    repo.revoke_token(
        jti=payload["jti"],
        user_id=user["id"],
        expires_at=expires_at,
        motivo="rotado",
    )
    return jsonify(user=public_user(user), **issue_session(user)), 200


@auth_bp.post("/logout")
@auth_required()
def logout():
    token = _body().get("refresh_token") or ""
    if not token:
        return jsonify(error="Falta el token de refresco."), 400
    try:
        payload = decode_token(token, kind="refresh")
    except TokenError:
        return jsonify(error="Token inválido."), 400

    if payload["sub"] != str(g.current_user["id"]):
        return jsonify(error="El token no pertenece a esta sesión."), 403

    expires_at = datetime.fromtimestamp(
        int(payload["exp"]), tz=timezone.utc
    ).replace(tzinfo=None)
    repository().revoke_token(
        jti=payload["jti"],
        user_id=g.current_user["id"],
        expires_at=expires_at,
        motivo="logout",
    )
    return jsonify(message="Sesión cerrada."), 200


@auth_bp.get("/me")
@auth_required()
def me():
    user = g.current_user
    repo = repository()
    application = repo.find_latest_application(user["id"])
    return (
        jsonify(
            user=public_user(user),
            solicitud=application,
            notificaciones_no_leidas=repo.count_unread(user["id"]),
        ),
        200,
    )
