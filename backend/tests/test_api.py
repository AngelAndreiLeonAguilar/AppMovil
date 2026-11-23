"""Pruebas de la API de autenticación, roles y verificación.

Se ejecutan sin base de datos: la app usa `InMemoryRepository`.

    cd backend
    python -m unittest discover -s tests -v
"""

from __future__ import annotations

import unittest

from bel_aaktun_backend import create_app
from bel_aaktun_backend.config import Settings
from bel_aaktun_backend.repositories import InMemoryRepository
from bel_aaktun_backend.security import hash_password

PASSWORD = "Clave1234"


def settings() -> Settings:
    return Settings(
        secret_key="secreto-de-prueba",
        access_ttl_seconds=900,
        refresh_ttl_seconds=86400,
        db_host="127.0.0.1",
        db_port=3307,
        db_user="test",
        db_password="test",
        db_name="test",
        cors_origins=[],
        login_max_attempts=5,
        login_window_seconds=900,
    )


class ApiTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = InMemoryRepository()
        self.app = create_app(settings(), repository=self.repo)
        self.client = self.app.test_client()

        self.admin_id = self.repo.create_user(
            nombre="Administración",
            email="admin@belaaktun.mx",
            password_hash=hash_password(PASSWORD),
        )
        self.repo.set_user_role(self.admin_id, "admin")

    # Utilidades -----------------------------------------------------------
    def register(self, email="ana@belaaktun.mx", **extra):
        payload = {
            "nombre": "Ana Canul",
            "email": email,
            "password": PASSWORD,
            "telefono": "+52 981 000 0000",
        }
        payload.update(extra)
        return self.client.post("/api/v1/auth/register", json=payload)

    def login(self, email="ana@belaaktun.mx", password=PASSWORD):
        return self.client.post(
            "/api/v1/auth/login", json={"email": email, "password": password}
        )

    @staticmethod
    def bearer(token: str) -> dict:
        return {"Authorization": f"Bearer {token}"}

    def register_and_login(self, email="ana@belaaktun.mx"):
        response = self.register(email=email)
        self.assertEqual(response.status_code, 201, response.get_json())
        return response.get_json()

    def submit_application(self, token):
        return self.client.post(
            "/api/v1/artisan-applications",
            headers=self.bearer(token),
            json={
                "nombre_taller": "Cueva La Esperanza",
                "descripcion": "Taller familiar de tejido de jipi con visitas guiadas.",
                "ubicacion": "Bécal, Campeche",
                "direccion": "Calle 20 x 15, Centro",
                "telefono_contacto": "+52 981 111 1111",
            },
        )

    def admin_login(self):
        response = self.login("admin@belaaktun.mx")
        self.assertEqual(response.status_code, 200, response.get_json())
        return response.get_json()["access_token"]

    # Pruebas --------------------------------------------------------------
    def test_health(self):
        self.assertEqual(self.client.get("/api/v1/health").status_code, 200)

    def test_portada_de_la_api(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["api"], "Bel-Aaktun API")

    def test_register_api_no_pisa_la_raiz_de_la_web(self):
        from flask import Flask

        from bel_aaktun_backend import register_api

        web = Flask(__name__)
        web.add_url_rule("/", "home", lambda: "sitio web")

        register_api(web, settings=settings(), repository=InMemoryRepository())

        client = web.test_client()
        self.assertEqual(client.get("/").data, b"sitio web")
        self.assertEqual(client.get("/api/v1/health").status_code, 200)

    def test_register_api_sobre_una_app_existente_no_duplica_rutas(self):
        from flask import Flask

        from bel_aaktun_backend import register_api

        app = Flask(__name__)
        register_api(app, settings=settings(), repository=InMemoryRepository())
        register_api(app, settings=settings(), repository=InMemoryRepository())

        client = app.test_client()
        self.assertEqual(client.get("/api/v1/health").status_code, 200)
        self.assertEqual(client.get("/api/v1/auth/me").status_code, 401)

    def test_registro_crea_turista_y_ignora_rol_enviado(self):
        response = self.register(rol="admin")
        self.assertEqual(response.status_code, 201)
        body = response.get_json()
        self.assertEqual(body["user"]["rol"], "turista")
        self.assertIn("access_token", body)

    def test_registro_rechaza_contraseña_debil(self):
        response = self.register(password="abc")
        self.assertEqual(response.status_code, 422)

    def test_registro_rechaza_correo_duplicado(self):
        self.assertEqual(self.register().status_code, 201)
        self.assertEqual(self.register().status_code, 409)

    def test_login_y_perfil(self):
        tokens = self.register_and_login()
        response = self.client.get(
            "/api/v1/auth/me", headers=self.bearer(tokens["access_token"])
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["user"]["rol"], "turista")

    def test_login_con_contraseña_incorrecta(self):
        self.register()
        response = self.login(password="OtraClave1")
        self.assertEqual(response.status_code, 401)

    def test_bloqueo_tras_cinco_intentos(self):
        self.register()
        for _ in range(5):
            self.assertEqual(self.login(password="Mala1234").status_code, 401)
        self.assertEqual(self.login(password="Mala1234").status_code, 429)

    def test_migra_contraseña_legada_a_hash(self):
        user_id = self.repo.create_user(
            nombre="Legado",
            email="legado@belaaktun.mx",
            password_hash="Plain1234",  # texto plano como en app.py
        )
        response = self.login("legado@belaaktun.mx", "Plain1234")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(
            self.repo.find_user(user_id)["password_hash"].startswith(
                ("pbkdf2:", "scrypt:", "argon2")
            )
        )

    def test_sin_token_no_hay_perfil(self):
        self.assertEqual(self.client.get("/api/v1/auth/me").status_code, 401)

    def test_turista_no_accede_a_administracion(self):
        tokens = self.register_and_login()
        for path in ("/api/v1/admin/users", "/api/v1/admin/audit"):
            response = self.client.get(
                path, headers=self.bearer(tokens["access_token"])
            )
            self.assertEqual(response.status_code, 403, path)

    def test_solicitud_de_taller_y_aprobacion(self):
        tokens = self.register_and_login()
        created = self.submit_application(tokens["access_token"])
        self.assertEqual(created.status_code, 201)
        application = created.get_json()["solicitud"]
        self.assertEqual(application["estado"], "pendiente")

        admin_token = self.admin_login()
        listing = self.client.get(
            "/api/v1/artisan-applications?estado=pendiente",
            headers=self.bearer(admin_token),
        )
        self.assertEqual(listing.status_code, 200)
        self.assertEqual(len(listing.get_json()["solicitudes"]), 1)

        review = self.client.post(
            f"/api/v1/artisan-applications/{application['id']}/review",
            headers=self.bearer(admin_token),
            json={"decision": "aprobada"},
        )
        self.assertEqual(review.status_code, 200, review.get_json())

        applicant = self.repo.find_user(application["usuario_id"])
        self.assertEqual(applicant["rol"], "artesano")

        audit = self.client.get(
            "/api/v1/admin/audit", headers=self.bearer(admin_token)
        ).get_json()["registro"]
        self.assertTrue(any(item["accion"] == "solicitud_aprobada" for item in audit))

        notifications = [
            item
            for item in self.repo.notifications
            if item["usuario_id"] == applicant["id"]
        ]
        self.assertTrue(
            any(item["tipo"] == "solicitud_aprobada" for item in notifications)
        )

    def test_no_se_puede_repetir_solicitud_abierta(self):
        tokens = self.register_and_login()
        self.assertEqual(self.submit_application(tokens["access_token"]).status_code, 201)
        self.assertEqual(self.submit_application(tokens["access_token"]).status_code, 409)

    def test_admin_no_puede_aprobar_su_propia_solicitud(self):
        application = self.repo.create_application(
            usuario_id=self.admin_id,
            nombre_taller="Taller del admin",
            descripcion="Solicitud creada directamente para probar la regla.",
            ubicacion=None,
            direccion=None,
            latitud=None,
            longitud=None,
            telefono_contacto=None,
        )
        admin_token = self.admin_login()
        response = self.client.post(
            f"/api/v1/artisan-applications/{application['id']}/review",
            headers=self.bearer(admin_token),
            json={"decision": "aprobada"},
        )
        self.assertEqual(response.status_code, 403)

    def test_rechazo_exige_motivo(self):
        tokens = self.register_and_login()
        application = self.submit_application(tokens["access_token"]).get_json()[
            "solicitud"
        ]
        admin_token = self.admin_login()

        without_reason = self.client.post(
            f"/api/v1/artisan-applications/{application['id']}/review",
            headers=self.bearer(admin_token),
            json={"decision": "rechazada"},
        )
        self.assertEqual(without_reason.status_code, 422)

        with_reason = self.client.post(
            f"/api/v1/artisan-applications/{application['id']}/review",
            headers=self.bearer(admin_token),
            json={"decision": "rechazada", "motivo": "No se pudieron verificar los datos."},
        )
        self.assertEqual(with_reason.status_code, 200)
        self.assertEqual(
            with_reason.get_json()["solicitud"]["estado"], "rechazada"
        )

    def test_suspension_invalida_la_sesion_del_artesano(self):
        tokens = self.register_and_login()
        application = self.submit_application(tokens["access_token"]).get_json()[
            "solicitud"
        ]
        admin_token = self.admin_login()
        self.client.post(
            f"/api/v1/artisan-applications/{application['id']}/review",
            headers=self.bearer(admin_token),
            json={"decision": "aprobada"},
        )

        # El token sigue siendo el mismo, pero el rol se relee de la base.
        me = self.client.get("/api/v1/auth/me", headers=self.bearer(tokens["access_token"]))
        self.assertEqual(me.get_json()["user"]["rol"], "artesano")

        suspend = self.client.post(
            f"/api/v1/admin/users/{application['usuario_id']}/suspend",
            headers=self.bearer(admin_token),
            json={"motivo": "Incumplimiento de las políticas del taller."},
        )
        self.assertEqual(suspend.status_code, 200, suspend.get_json())

        blocked = self.client.get(
            "/api/v1/auth/me", headers=self.bearer(tokens["access_token"])
        )
        self.assertEqual(blocked.status_code, 403)

    def test_admin_no_puede_suspenderse(self):
        admin_token = self.admin_login()
        response = self.client.post(
            f"/api/v1/admin/users/{self.admin_id}/suspend",
            headers=self.bearer(admin_token),
            json={"motivo": "Prueba de autosuspensión."},
        )
        self.assertEqual(response.status_code, 409)

    def test_refresh_rota_y_revoca_el_anterior(self):
        tokens = self.register_and_login()
        first = self.client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": tokens["refresh_token"]},
        )
        self.assertEqual(first.status_code, 200)
        self.assertIn("refresh_token", first.get_json())

        reused = self.client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": tokens["refresh_token"]},
        )
        self.assertEqual(reused.status_code, 401)

    def test_logout_revoca_refresh(self):
        tokens = self.register_and_login()
        logout = self.client.post(
            "/api/v1/auth/logout",
            headers=self.bearer(tokens["access_token"]),
            json={"refresh_token": tokens["refresh_token"]},
        )
        self.assertEqual(logout.status_code, 200)
        reused = self.client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": tokens["refresh_token"]},
        )
        self.assertEqual(reused.status_code, 401)


if __name__ == "__main__":
    unittest.main()
