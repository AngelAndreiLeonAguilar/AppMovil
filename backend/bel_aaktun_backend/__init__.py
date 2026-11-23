"""Fábrica de la aplicación Flask del backend de Bel-Aaktun.

Dos formas de uso:

1. App independiente (desarrollo):

       from bel_aaktun_backend import create_app
       app = create_app()

2. Montar la API sobre el `app.py` que ya existe (recomendado en producción):

       from bel_aaktun_backend import register_api
       register_api(app)   # solo añade /api/v1/*, no toca las rutas actuales
"""

from __future__ import annotations

from flask import Flask, jsonify

from .blueprints.admin import admin_bp
from .blueprints.applications import applications_bp
from .blueprints.auth import auth_bp
from .config import Settings
from .repositories import MySQLRepository


def register_api(app: Flask, settings: Settings | None = None, repository=None) -> Flask:
    """Registra configuración, repositorio y blueprints en una app existente."""
    settings = settings or Settings.from_env()

    app.config.update(
        BEL_SECRET_KEY=settings.secret_key,
        BEL_ACCESS_TTL=settings.access_ttl_seconds,
        BEL_REFRESH_TTL=settings.refresh_ttl_seconds,
        BEL_LOGIN_MAX_ATTEMPTS=settings.login_max_attempts,
        BEL_LOGIN_WINDOW=settings.login_window_seconds,
    )
    app.extensions["bel_repo"] = repository or MySQLRepository(settings)

    # No se registran dos veces si la app ya montó la API.
    if "bel_auth" not in app.blueprints:
        app.register_blueprint(auth_bp, url_prefix="/api/v1/auth")
    if "bel_applications" not in app.blueprints:
        app.register_blueprint(
            applications_bp, url_prefix="/api/v1/artisan-applications"
        )
    if "bel_admin" not in app.blueprints:
        app.register_blueprint(admin_bp, url_prefix="/api/v1/admin")

    if "api_health" not in app.view_functions:
        app.add_url_rule(
            "/api/v1/health",
            endpoint="api_health",
            view_func=lambda: jsonify(status="ok"),
        )

    return app


def create_app(settings: Settings | None = None, repository=None) -> Flask:
    settings = settings or Settings.from_env()
    app = Flask(__name__)
    app.config["JSON_SORT_KEYS"] = False

    if settings.cors_origins:
        try:
            from flask_cors import CORS

            CORS(app, resources={r"/api/*": {"origins": settings.cors_origins}})
        except ImportError:  # flask-cors no instalado en pruebas
            pass
    else:
        # Desarrollo: permite Flutter web (puerto variable) y emuladores.
        import os

        if os.getenv("BEL_ENV", "development").lower() != "production":
            try:
                from flask_cors import CORS

                CORS(app, resources={r"/api/*": {"origins": "*"}})
            except ImportError:
                pass

    register_api(app, settings=settings, repository=repository)

    @app.get("/")
    def api_index():
        """Portada informativa del servidor de API (solo app independiente)."""
        return jsonify(
            api="Bel-Aaktun API",
            version="v1",
            health="/api/v1/health",
            endpoints=[
                "POST /api/v1/auth/register",
                "POST /api/v1/auth/login",
                "POST /api/v1/auth/refresh",
                "POST /api/v1/auth/logout",
                "GET  /api/v1/auth/me",
                "POST /api/v1/artisan-applications",
                "GET  /api/v1/artisan-applications/me",
                "GET  /api/v1/artisan-applications (admin)",
                "POST /api/v1/artisan-applications/{id}/review (admin)",
                "GET  /api/v1/admin/users (admin)",
                "GET  /api/v1/admin/summary (admin)",
                "POST /api/v1/admin/users/{id}/suspend (admin)",
                "POST /api/v1/admin/users/{id}/reactivate (admin)",
                "GET  /api/v1/admin/audit (admin)",
            ],
        )

    @app.errorhandler(404)
    def not_found(_error):
        return jsonify(error="recurso no encontrado"), 404

    @app.errorhandler(405)
    def not_allowed(_error):
        return jsonify(error="método no permitido"), 405

    @app.errorhandler(500)
    def server_error(_error):
        # Nunca exponer detalles internos.
        return jsonify(error="error interno del servidor"), 500

    return app
