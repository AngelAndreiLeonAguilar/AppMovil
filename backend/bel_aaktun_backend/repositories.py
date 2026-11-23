"""Repositorios: una interfaz y dos implementaciones.

- `InMemoryRepository`: pruebas y desarrollo sin base de datos.
- `MySQLRepository`: producción, con PyMySQL (igual que el backend actual).

Los blueprints solo hablan con la interfaz, de modo que las pruebas de
autorización no necesitan MySQL.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any, Protocol


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class Repository(Protocol):
    # Usuarios -------------------------------------------------------------
    def find_user(self, user_id: int) -> dict[str, Any] | None: ...

    def find_user_by_email(self, email: str) -> dict[str, Any] | None: ...

    def create_user(
        self,
        *,
        nombre: str,
        email: str,
        password_hash: str,
        telefono: str | None = None,
    ) -> int: ...

    def update_user_password(self, user_id: int, password_hash: str) -> None: ...

    def set_user_role(self, user_id: int, rol: str) -> None: ...

    def set_user_status(self, user_id: int, estado: str) -> None: ...

    def list_users(self, rol: str | None = None) -> list[dict[str, Any]]: ...

    def find_admins(self) -> list[dict[str, Any]]: ...

    # Intentos -------------------------------------------------------------
    def add_attempt(self, *, email: str, ip: str | None, exito: bool) -> None: ...

    def count_recent_failures(self, email: str, seconds: int) -> int: ...

    # Solicitudes ----------------------------------------------------------
    def create_application(self, **fields: Any) -> dict[str, Any]: ...

    def find_application(self, application_id: int) -> dict[str, Any] | None: ...

    def find_open_application(self, user_id: int) -> dict[str, Any] | None: ...

    def find_latest_application(self, user_id: int) -> dict[str, Any] | None: ...

    def list_applications(self, estado: str | None = None) -> list[dict[str, Any]]: ...

    def update_application(self, application_id: int, **fields: Any) -> None: ...

    # Notificaciones -------------------------------------------------------
    def add_notification(
        self,
        *,
        user_id: int,
        tipo: str,
        titulo: str,
        cuerpo: str | None = None,
    ) -> None: ...

    def list_notifications(self, user_id: int, limit: int = 50) -> list[dict[str, Any]]: ...

    def count_unread(self, user_id: int) -> int: ...

    # Tokens revocados -----------------------------------------------------
    def revoke_token(
        self,
        *,
        jti: str,
        user_id: int,
        expires_at: datetime,
        motivo: str | None = None,
    ) -> None: ...

    def is_token_revoked(self, jti: str) -> bool: ...

    # Auditoría ------------------------------------------------------------
    def add_audit(
        self,
        *,
        actor_id: int | None,
        accion: str,
        entidad: str,
        entidad_id: int | None,
        detalle: dict[str, Any] | None = None,
        ip: str | None = None,
    ) -> None: ...

    def list_audit(self, limit: int = 100) -> list[dict[str, Any]]: ...


class InMemoryRepository:
    """Datos en memoria para pruebas y modo desarrollo."""

    def __init__(self) -> None:
        self.users: dict[int, dict[str, Any]] = {}
        self.applications: dict[int, dict[str, Any]] = {}
        self.notifications: list[dict[str, Any]] = []
        self.audit: list[dict[str, Any]] = []
        self.attempts: list[dict[str, Any]] = []
        self.revoked: dict[str, dict[str, Any]] = {}
        self._ids = {"user": 0, "application": 0, "notification": 0, "audit": 0, "attempt": 0}

    def _next(self, kind: str) -> int:
        self._ids[kind] += 1
        return self._ids[kind]

    # Usuarios -------------------------------------------------------------
    def find_user(self, user_id: int) -> dict[str, Any] | None:
        return self.users.get(int(user_id))

    def find_user_by_email(self, email: str) -> dict[str, Any] | None:
        target = (email or "").strip().lower()
        for user in self.users.values():
            if user["email"].lower() == target:
                return user
        return None

    def create_user(
        self,
        *,
        nombre: str,
        email: str,
        password_hash: str,
        telefono: str | None = None,
    ) -> int:
        user_id = self._next("user")
        self.users[user_id] = {
            "id": user_id,
            "nombre": nombre,
            "email": email.strip().lower(),
            "password_hash": password_hash,
            "telefono": telefono,
            "rol": "turista",
            "estado": "activo",
            "taller_id": None,
            "email_verificado_en": None,
            "creado_en": _now(),
        }
        return user_id

    def update_user_password(self, user_id: int, password_hash: str) -> None:
        self.users[int(user_id)]["password_hash"] = password_hash

    def set_user_role(self, user_id: int, rol: str) -> None:
        self.users[int(user_id)]["rol"] = rol

    def set_user_status(self, user_id: int, estado: str) -> None:
        self.users[int(user_id)]["estado"] = estado

    def list_users(self, rol: str | None = None) -> list[dict[str, Any]]:
        users = list(self.users.values())
        if rol:
            users = [user for user in users if user["rol"] == rol]
        return sorted(users, key=lambda user: user["id"], reverse=True)

    def find_admins(self) -> list[dict[str, Any]]:
        return [user for user in self.users.values() if user["rol"] == "admin"]

    # Intentos -------------------------------------------------------------
    def add_attempt(self, *, email: str, ip: str | None, exito: bool) -> None:
        self.attempts.append(
            {
                "id": self._next("attempt"),
                "email": (email or "").lower(),
                "ip": ip,
                "exito": exito,
                "intentado_en": _now(),
            }
        )

    def count_recent_failures(self, email: str, seconds: int) -> int:
        limit = _now() - timedelta(seconds=seconds)
        target = (email or "").lower()
        return sum(
            1
            for attempt in self.attempts
            if attempt["email"] == target
            and not attempt["exito"]
            and attempt["intentado_en"] >= limit
        )

    # Solicitudes ----------------------------------------------------------
    def create_application(self, **fields: Any) -> dict[str, Any]:
        application_id = self._next("application")
        application = {
            "id": application_id,
            "estado": "pendiente",
            "revisor_id": None,
            "revisado_en": None,
            "motivo_rechazo": None,
            "creado_en": _now(),
            **fields,
        }
        self.applications[application_id] = application
        return application

    def find_application(self, application_id: int) -> dict[str, Any] | None:
        return self.applications.get(int(application_id))

    def find_open_application(self, user_id: int) -> dict[str, Any] | None:
        for application in self.applications.values():
            if application["usuario_id"] == int(user_id) and application[
                "estado"
            ] in ("pendiente", "en_revision"):
                return application
        return None

    def find_latest_application(self, user_id: int) -> dict[str, Any] | None:
        mine = [
            application
            for application in self.applications.values()
            if application["usuario_id"] == int(user_id)
        ]
        return max(mine, key=lambda application: application["id"]) if mine else None

    def list_applications(self, estado: str | None = None) -> list[dict[str, Any]]:
        items = list(self.applications.values())
        if estado:
            items = [application for application in items if application["estado"] == estado]
        return sorted(items, key=lambda application: application["id"], reverse=True)

    def update_application(self, application_id: int, **fields: Any) -> None:
        self.applications[int(application_id)].update(fields)

    # Notificaciones -------------------------------------------------------
    def add_notification(
        self,
        *,
        user_id: int,
        tipo: str,
        titulo: str,
        cuerpo: str | None = None,
    ) -> None:
        self.notifications.append(
            {
                "id": self._next("notification"),
                "usuario_id": int(user_id),
                "tipo": tipo,
                "titulo": titulo,
                "cuerpo": cuerpo,
                "leido_en": None,
                "creado_en": _now(),
            }
        )

    def list_notifications(self, user_id: int, limit: int = 50) -> list[dict[str, Any]]:
        mine = [
            notification
            for notification in self.notifications
            if notification["usuario_id"] == int(user_id)
        ]
        return sorted(mine, key=lambda notification: notification["id"], reverse=True)[:limit]

    def count_unread(self, user_id: int) -> int:
        return sum(
            1
            for notification in self.notifications
            if notification["usuario_id"] == int(user_id) and notification["leido_en"] is None
        )

    # Tokens ---------------------------------------------------------------
    def revoke_token(
        self,
        *,
        jti: str,
        user_id: int,
        expires_at: datetime,
        motivo: str | None = None,
    ) -> None:
        self.revoked[jti] = {
            "jti": jti,
            "usuario_id": int(user_id),
            "expira_en": expires_at,
            "motivo": motivo,
        }

    def is_token_revoked(self, jti: str) -> bool:
        return jti in self.revoked

    # Auditoría ------------------------------------------------------------
    def add_audit(
        self,
        *,
        actor_id: int | None,
        accion: str,
        entidad: str,
        entidad_id: int | None,
        detalle: dict[str, Any] | None = None,
        ip: str | None = None,
    ) -> None:
        self.audit.append(
            {
                "id": self._next("audit"),
                "actor_id": actor_id,
                "accion": accion,
                "entidad": entidad,
                "entidad_id": entidad_id,
                "detalle": detalle or {},
                "ip": ip,
                "creado_en": _now(),
            }
        )

    def list_audit(self, limit: int = 100) -> list[dict[str, Any]]:
        return sorted(self.audit, key=lambda item: item["id"], reverse=True)[:limit]


class MySQLRepository(InMemoryRepository):
    """Producción: PyMySQL contra las tablas de la migración.

    Hereda la interfaz; cada método sobrescribe la consulta. Se importa
    `pymysql` de forma diferida para que las pruebas no lo necesiten.
    """

    def __init__(self, settings) -> None:  # noqa: ANN001 - evita import circular
        self.settings = settings

    def _connect(self):
        import pymysql

        return pymysql.connect(
            host=self.settings.db_host,
            port=self.settings.db_port,
            user=self.settings.db_user,
            password=self.settings.db_password,
            database=self.settings.db_name,
            charset="utf8mb4",
            cursorclass=pymysql.cursors.DictCursor,
            autocommit=False,
        )

    def _run(self, sql: str, params: tuple = (), *, fetch: str | None = None):
        connection = self._connect()
        try:
            with connection.cursor() as cursor:
                cursor.execute(sql, params)
                if fetch == "one":
                    return cursor.fetchone()
                if fetch == "all":
                    return cursor.fetchall()
                connection.commit()
                return cursor.lastrowid
        finally:
            connection.close()

    # Usuarios -------------------------------------------------------------
    def find_user(self, user_id: int):
        return self._run(
            "SELECT * FROM usuarios WHERE id = %s", (int(user_id),), fetch="one"
        )

    def find_user_by_email(self, email: str):
        return self._run(
            "SELECT * FROM usuarios WHERE email = %s",
            ((email or "").strip().lower(),),
            fetch="one",
        )

    def create_user(self, *, nombre: str, email: str, password_hash: str, telefono=None):
        return self._run(
            "INSERT INTO usuarios (nombre, email, password_hash, telefono) "
            "VALUES (%s, %s, %s, %s)",
            (nombre, email.strip().lower(), password_hash, telefono),
        )

    def update_user_password(self, user_id: int, password_hash: str) -> None:
        self._run(
            "UPDATE usuarios SET password_hash = %s WHERE id = %s",
            (password_hash, int(user_id)),
        )

    def set_user_role(self, user_id: int, rol: str) -> None:
        self._run("UPDATE usuarios SET rol = %s WHERE id = %s", (rol, int(user_id)))

    def set_user_status(self, user_id: int, estado: str) -> None:
        self._run("UPDATE usuarios SET estado = %s WHERE id = %s", (estado, int(user_id)))

    def list_users(self, rol=None):
        if rol:
            return self._run(
                "SELECT * FROM usuarios WHERE rol = %s ORDER BY id DESC",
                (rol,),
                fetch="all",
            )
        return self._run("SELECT * FROM usuarios ORDER BY id DESC", fetch="all")

    def find_admins(self):
        return self._run(
            "SELECT * FROM usuarios WHERE rol = 'admin' AND estado = 'activo'",
            fetch="all",
        )

    # Intentos -------------------------------------------------------------
    def add_attempt(self, *, email: str, ip, exito: bool) -> None:
        self._run(
            "INSERT INTO intentos_acceso (email, ip, exito) VALUES (%s, %s, %s)",
            ((email or "").lower(), ip, 1 if exito else 0),
        )

    def count_recent_failures(self, email: str, seconds: int) -> int:
        row = self._run(
            "SELECT COUNT(*) AS total FROM intentos_acceso "
            "WHERE email = %s AND exito = 0 "
            "AND intentado_en >= (NOW() - INTERVAL %s SECOND)",
            ((email or "").lower(), int(seconds)),
            fetch="one",
        )
        return int(row["total"]) if row else 0

    # Solicitudes ----------------------------------------------------------
    def create_application(self, **fields):
        application_id = self._run(
            "INSERT INTO solicitudes_artesano "
            "(usuario_id, nombre_taller, descripcion, ubicacion, direccion, "
            " latitud, longitud, telefono_contacto, estado) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'pendiente')",
            (
                fields["usuario_id"],
                fields["nombre_taller"],
                fields.get("descripcion"),
                fields.get("ubicacion"),
                fields.get("direccion"),
                fields.get("latitud"),
                fields.get("longitud"),
                fields.get("telefono_contacto"),
            ),
        )
        return self.find_application(application_id)

    def find_application(self, application_id: int):
        return self._run(
            "SELECT * FROM solicitudes_artesano WHERE id = %s",
            (int(application_id),),
            fetch="one",
        )

    def find_open_application(self, user_id: int):
        return self._run(
            "SELECT * FROM solicitudes_artesano "
            "WHERE usuario_id = %s AND estado IN ('pendiente','en_revision') "
            "ORDER BY id DESC LIMIT 1",
            (int(user_id),),
            fetch="one",
        )

    def find_latest_application(self, user_id: int):
        return self._run(
            "SELECT * FROM solicitudes_artesano WHERE usuario_id = %s "
            "ORDER BY id DESC LIMIT 1",
            (int(user_id),),
            fetch="one",
        )

    def list_applications(self, estado=None):
        if estado:
            return self._run(
                "SELECT * FROM solicitudes_artesano WHERE estado = %s "
                "ORDER BY id DESC",
                (estado,),
                fetch="all",
            )
        return self._run(
            "SELECT * FROM solicitudes_artesano ORDER BY id DESC", fetch="all"
        )

    def update_application(self, application_id: int, **fields) -> None:
        allowed = {
            "estado",
            "revisor_id",
            "revisado_en",
            "motivo_rechazo",
            "notas_revision",
        }
        updates = {key: value for key, value in fields.items() if key in allowed}
        if not updates:
            return
        assignments = ", ".join(f"{key} = %s" for key in updates)
        self._run(
            f"UPDATE solicitudes_artesano SET {assignments} WHERE id = %s",
            (*updates.values(), int(application_id)),
        )

    # Notificaciones -------------------------------------------------------
    def add_notification(self, *, user_id: int, tipo: str, titulo: str, cuerpo=None) -> None:
        self._run(
            "INSERT INTO notificaciones (usuario_id, tipo, titulo, cuerpo) "
            "VALUES (%s, %s, %s, %s)",
            (int(user_id), tipo, titulo, cuerpo),
        )

    def list_notifications(self, user_id: int, limit: int = 50):
        return self._run(
            "SELECT * FROM notificaciones WHERE usuario_id = %s "
            "ORDER BY id DESC LIMIT %s",
            (int(user_id), int(limit)),
            fetch="all",
        )

    def count_unread(self, user_id: int) -> int:
        row = self._run(
            "SELECT COUNT(*) AS total FROM notificaciones "
            "WHERE usuario_id = %s AND leido_en IS NULL",
            (int(user_id),),
            fetch="one",
        )
        return int(row["total"]) if row else 0

    # Tokens ---------------------------------------------------------------
    def revoke_token(self, *, jti: str, user_id: int, expires_at, motivo=None) -> None:
        self._run(
            "INSERT INTO tokens_revocados (jti, usuario_id, expira_en, motivo) "
            "VALUES (%s, %s, %s, %s)",
            (jti, int(user_id), expires_at, motivo),
        )

    def is_token_revoked(self, jti: str) -> bool:
        row = self._run(
            "SELECT 1 AS presente FROM tokens_revocados WHERE jti = %s",
            (jti,),
            fetch="one",
        )
        return row is not None

    # Auditoría ------------------------------------------------------------
    def add_audit(self, *, actor_id, accion, entidad, entidad_id, detalle=None, ip=None) -> None:
        import json

        self._run(
            "INSERT INTO registro_auditoria "
            "(actor_id, accion, entidad, entidad_id, detalle, ip) "
            "VALUES (%s, %s, %s, %s, %s, %s)",
            (
                actor_id,
                accion,
                entidad,
                entidad_id,
                json.dumps(detalle or {}, ensure_ascii=False),
                ip,
            ),
        )

    def list_audit(self, limit: int = 100):
        return self._run(
            "SELECT * FROM registro_auditoria ORDER BY id DESC LIMIT %s",
            (int(limit),),
            fetch="all",
        )
