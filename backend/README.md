# Backend de autenticación y verificación (Flask)

Paquete **independiente** que implementa autenticación, roles, solicitudes de
taller y administración sobre el `becal-backend` existente. No modifica las
rutas actuales: añade `/api/v1/*`.

## Qué incluye

| Método | Ruta | Acceso | Qué hace |
|---|---|---|---|
| POST | `/api/v1/auth/register` | público | Registro de **turista** (ignora `rol` del cuerpo) |
| POST | `/api/v1/auth/login` | público | Login con hash, migra contraseñas legadas y limita intentos |
| POST | `/api/v1/auth/refresh` | público | Rota el refresh token |
| POST | `/api/v1/auth/logout` | autenticado | Revoca el refresh |
| GET | `/api/v1/auth/me` | autenticado | Perfil + solicitud + notificaciones sin leer |
| POST | `/api/v1/artisan-applications` | turista | Envía solicitud de taller (queda `pendiente`) |
| GET | `/api/v1/artisan-applications/me` | autenticado | Estado de mi solicitud |
| GET | `/api/v1/artisan-applications` | admin | Bandeja, filtro `?estado=` |
| POST | `/api/v1/artisan-applications/{id}/review` | admin | `aprobada` / `rechazada` / `en_revision` con auditoría |
| GET | `/api/v1/admin/users` | admin | Usuarios, filtro `?rol=` |
| GET | `/api/v1/admin/summary` | admin | Contadores para el panel |
| POST | `/api/v1/admin/users/{id}/suspend` | admin | Suspensión con motivo |
| POST | `/api/v1/admin/users/{id}/reactivate` | admin | Reactivación |
| GET | `/api/v1/admin/audit` | admin | Bitácora de acciones |
| GET | `/api/v1/health` | público | Estado del servicio |

Reglas aplicadas en el servidor:

- El rol **se relee de la base** en cada petición: una suspensión corta la sesión
  de inmediato, aunque el token siga vigente.
- Registrar con `rol: "admin"` no sirve: el endpoint fuerza `turista`.
- Los endpoints de administración exigen `rol = admin` y cuenta activa.
- Aprobar exige que el revisor no sea el solicitante; rechazar exige motivo.
- Cada aprobación, rechazo o suspensión escribe en `registro_auditoria`.
- Contraseñas con PBKDF2 (Werkzeug); las legadas en texto plano se rehashean en
  el primer login.
- Límite de 5 intentos fallidos por correo en 15 minutos.

## Integración en el backend actual (3 pasos)

### 1. Copiar el paquete

Copia `bel_aaktun_backend/`, `main.py` y `tests/` dentro de `becal-backend/`.

### 2. Aplicar la migración

```bash
mysqldump -u becal_user -p becal_db > respaldo.sql
mysql -u becal_user -p becal_db < ../docs/backend/001_mysql_auth.sql
```

Crea el administrador inicial (una sola vez):

```sql
UPDATE usuarios SET rol = 'admin' WHERE email = 'correo-del-responsable@dominio.mx';
```

### 3. Registrar la API en `app.py`

Al final de `becal-backend/app.py`, antes de `if __name__ == '__main__'`:

```python
from bel_aaktun_backend import register_api

register_api(app)
```

No se duplican rutas: la API vive en `/api/v1` y la app actual sigue igual.

## Variables de entorno

Crea `.env` junto a `app.py` (nunca lo subas al repositorio):

```env
BEL_SECRET_KEY=cadena-larga-aleatoria-de-64-caracteres
BEL_ACCESS_TTL=900
BEL_REFRESH_TTL=2592000
BEL_LOGIN_MAX_ATTEMPTS=5
BEL_LOGIN_WINDOW=900
BEL_CORS_ORIGINS=http://localhost:4200,https://tu-dominio.mx

DB_HOST=127.0.0.1
DB_PORT=3307
DB_USER=becal_user
DB_PASSWORD=tu-password-real
DB_NAME=becal_db
```

> La contraseña de aplicación de Gmail que está en `app.py` debe rotarse y
> moverse a `.env`. No la reutilices.

## Pruebas

```bash
cd backend
python -m unittest discover -s tests -v
```

19 pruebas cubren: registro de turista, intento de registro como admin, límite
de intentos, migración de contraseñas en texto plano, sesión y perfil, turista
sin acceso a administración, solicitud de taller, duplicados, aprobación con
auditoría, auto-aprobación bloqueada, rechazo con motivo obligatorio,
suspensión que invalida la sesión, auto-suspensión bloqueada, rotación de
refresh y logout, además de montar la API sobre una app existente sin duplicar
rutas.

Se ejecutan con un repositorio en memoria: **no requieren MySQL**.

## Probar la API sin MySQL (modo desarrollo)

```bash
cd backend
set BEL_REPO=memory          # PowerShell: $env:BEL_REPO='memory'
python main.py               # http://127.0.0.1:5001

# en otra terminal
python scripts/smoke_test.py
```

Crea un administrador de desarrollo (`admin@belaaktun.mx` / `Admin1234`) y
recorre por HTTP: registro de turista, login, solicitud de taller, bandeja del
admin, aprobación, cambio de rol y auditoría. Este modo **se niega a arrancar**
si `BEL_ENV=production`.

## Prueba de integración con MySQL

La implementación `MySQLRepository` usa las tablas de la migración. Para
validarla en tu entorno:

```bash
# base de prueba, nunca producción
mysql -u root -p -e "CREATE DATABASE becal_test;"
mysql -u root -p becal_test < ../docs/backend/001_mysql_auth.sql

export DB_NAME=becal_test DB_PASSWORD=...
python - <<'PY'
from bel_aaktun_backend import create_app
app = create_app()
with app.test_client() as client:
    print(client.get('/api/v1/health').get_json())
PY
```

Aún no se ejecutó contra un MySQL real en esta sesión (no había servidor
disponible); es el paso pendiente antes de producción.

## Lo que falta

1. Subida de fotos del taller (`medios_solicitud`) y validación de tipo/tamaño.
2. Verificación de correo y recuperación de contraseña con Flask-Mail.
3. Migrar a esta API los endpoints actuales de reservas/productos/apartados,
   cerrando los que hoy están abiertos.
4. Cliente HTTP en la app Flutter y retiro de las cuentas demo del release.
