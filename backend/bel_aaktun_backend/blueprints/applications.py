"""Solicitudes de taller: envío, consulta de estado y revisión administrativa."""

from __future__ import annotations

from datetime import datetime, timezone

from flask import Blueprint, g, jsonify, request

from ..security import audit, auth_required, repository

applications_bp = Blueprint("bel_applications", __name__)

VALID_DECISIONS = {"aprobada", "rechazada", "en_revision"}
OPEN_STATES = ("pendiente", "en_revision")


def _body() -> dict:
    return request.get_json(silent=True) or {}


@applications_bp.post("")
@auth_required("turista")
def submit_application():
    data = _body()
    user = g.current_user
    repo = repository()

    nombre_taller = (data.get("nombre_taller") or "").strip()
    descripcion = (data.get("descripcion") or "").strip()
    telefono = (data.get("telefono_contacto") or "").strip() or user.get("telefono")

    if len(nombre_taller) < 3:
        return jsonify(error="Escribe el nombre del taller."), 422
    if len(descripcion) < 20:
        return (
            jsonify(error="Describe el taller con al menos 20 caracteres."),
            422,
        )
    if repo.find_open_application(user["id"]):
        return (
            jsonify(error="Ya tienes una solicitud abierta en revisión."),
            409,
        )

    application = repo.create_application(
        usuario_id=user["id"],
        nombre_taller=nombre_taller,
        descripcion=descripcion,
        ubicacion=(data.get("ubicacion") or "").strip() or None,
        direccion=(data.get("direccion") or "").strip() or None,
        latitud=data.get("latitud"),
        longitud=data.get("longitud"),
        telefono_contacto=telefono,
    )

    for admin in repo.find_admins():
        repo.add_notification(
            user_id=admin["id"],
            tipo="solicitud_taller",
            titulo=f"Nueva solicitud de taller: {nombre_taller}",
            cuerpo=f"{user['nombre']} pidió verificar su taller.",
        )

    audit(
        actor_id=user["id"],
        action="solicitud_enviada",
        entity="solicitudes_artesano",
        entity_id=application["id"],
        detail={"nombre_taller": nombre_taller},
    )
    return jsonify(solicitud=application), 201


@applications_bp.get("/me")
@auth_required()
def my_application():
    application = repository().find_latest_application(g.current_user["id"])
    if application is None:
        return jsonify(solicitud=None), 200
    return jsonify(solicitud=application), 200


@applications_bp.get("")
@auth_required("admin")
def list_applications():
    estado = request.args.get("estado")
    if estado is not None and estado not in {
        "pendiente",
        "en_revision",
        "aprobada",
        "rechazada",
        "suspendida",
        "retirada",
    }:
        return jsonify(error="Estado inválido."), 422
    return jsonify(solicitudes=repository().list_applications(estado)), 200


@applications_bp.post("/<int:application_id>/review")
@auth_required("admin")
def review_application(application_id: int):
    data = _body()
    decision = (data.get("decision") or "").strip()
    motivo = (data.get("motivo") or "").strip()
    notas = (data.get("notas") or "").strip() or None

    if decision not in VALID_DECISIONS:
        return (
            jsonify(error="Decisión inválida: usa aprobada, rechazada o en_revision."),
            422,
        )

    repo = repository()
    application = repo.find_application(application_id)
    if application is None:
        return jsonify(error="Solicitud no encontrada."), 404

    if application["usuario_id"] == g.current_user["id"]:
        return jsonify(error="No puedes revisar tu propia solicitud."), 403

    if application["estado"] not in OPEN_STATES:
        return (
            jsonify(error="La solicitud ya fue resuelta o retirada."),
            409,
        )

    if decision == "rechazada" and len(motivo) < 5:
        return jsonify(error="Escribe el motivo del rechazo."), 422

    updates: dict = {
        "estado": decision,
        "notas_revision": notas,
    }
    if decision in ("aprobada", "rechazada"):
        updates.update(
            {
                "revisor_id": g.current_user["id"],
                "revisado_en": datetime.now(timezone.utc).replace(tzinfo=None),
                "motivo_rechazo": motivo or None,
            }
        )
    repo.update_application(application_id, **updates)

    if decision == "aprobada":
        repo.set_user_role(application["usuario_id"], "artesano")
        repo.add_notification(
            user_id=application["usuario_id"],
            tipo="solicitud_aprobada",
            titulo="Tu taller fue aprobado",
            cuerpo=(
                f"Bienvenido, {application['nombre_taller']}. "
                "Ya puedes administrar tu taller desde el panel."
            ),
        )
    elif decision == "rechazada":
        repo.add_notification(
            user_id=application["usuario_id"],
            tipo="solicitud_rechazada",
            titulo="Solicitud de taller rechazada",
            cuerpo=motivo,
        )
    else:
        repo.add_notification(
            user_id=application["usuario_id"],
            tipo="solicitud_en_revision",
            titulo="Tu solicitud está en revisión",
            cuerpo=notas or "La administración está revisando tu información.",
        )

    audit(
        actor_id=g.current_user["id"],
        action=f"solicitud_{decision}",
        entity="solicitudes_artesano",
        entity_id=application_id,
        detail={"motivo": motivo or None, "notas": notas},
    )

    return jsonify(solicitud=repo.find_application(application_id)), 200
