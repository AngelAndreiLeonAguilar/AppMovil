"""Administración de usuarios: listado, suspensión, reactivación y auditoría."""

from __future__ import annotations

from flask import Blueprint, g, jsonify, request

from ..security import audit, auth_required, repository

admin_bp = Blueprint("bel_admin", __name__)


def _body() -> dict:
    return request.get_json(silent=True) or {}


@admin_bp.get("/users")
@auth_required("admin")
def list_users():
    rol = request.args.get("rol")
    if rol is not None and rol not in {"turista", "artesano", "admin"}:
        return jsonify(error="Rol inválido."), 422
    users = repository().list_users(rol)
    return jsonify(usuarios=users), 200


@admin_bp.get("/summary")
@auth_required("admin")
def summary():
    repo = repository()
    applications = repo.list_applications()
    pending = [item for item in applications if item["estado"] in ("pendiente", "en_revision")]
    return (
        jsonify(
            usuarios=len(repo.list_users()),
            talleres=len(repo.list_users("artesano")),
            solicitudes_pendientes=len(pending),
            solicitudes_totales=len(applications),
        ),
        200,
    )


@admin_bp.post("/users/<int:user_id>/suspend")
@auth_required("admin")
def suspend_user(user_id: int):
    motivo = (_body().get("motivo") or "").strip()
    if len(motivo) < 5:
        return jsonify(error="Escribe el motivo de la suspensión."), 422
    if user_id == g.current_user["id"]:
        return jsonify(error="No puedes suspender tu propia cuenta."), 409

    repo = repository()
    target = repo.find_user(user_id)
    if target is None:
        return jsonify(error="Usuario no encontrado."), 404
    if target["rol"] == "admin":
        return jsonify(error="No puedes suspender a otro administrador."), 403
    if target["estado"] == "suspendido":
        return jsonify(error="La cuenta ya está suspendida."), 409

    repo.set_user_status(user_id, "suspendido")
    repo.add_notification(
        user_id=user_id,
        tipo="cuenta_suspendida",
        titulo="Tu cuenta fue suspendida",
        cuerpo=motivo,
    )
    audit(
        actor_id=g.current_user["id"],
        action="usuario_suspendido",
        entity="usuarios",
        entity_id=user_id,
        detail={"motivo": motivo},
    )
    return jsonify(usuario=repo.find_user(user_id)), 200


@admin_bp.post("/users/<int:user_id>/reactivate")
@auth_required("admin")
def reactivate_user(user_id: int):
    repo = repository()
    target = repo.find_user(user_id)
    if target is None:
        return jsonify(error="Usuario no encontrado."), 404
    if target["estado"] == "activo":
        return jsonify(error="La cuenta ya está activa."), 409

    repo.set_user_status(user_id, "activo")
    repo.add_notification(
        user_id=user_id,
        tipo="cuenta_reactivada",
        titulo="Tu cuenta fue reactivada",
        cuerpo="Ya puedes volver a iniciar sesión.",
    )
    audit(
        actor_id=g.current_user["id"],
        action="usuario_reactivado",
        entity="usuarios",
        entity_id=user_id,
    )
    return jsonify(usuario=repo.find_user(user_id)), 200


@admin_bp.get("/audit")
@auth_required("admin")
def audit_log():
    limit = request.args.get("limit", default=100, type=int) or 100
    limit = max(1, min(limit, 500))
    return jsonify(registro=repository().list_audit(limit)), 200
