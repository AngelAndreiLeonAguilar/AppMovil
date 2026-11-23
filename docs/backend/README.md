# Backend: hallazgos y guía de migración

> **Implementación disponible:** el paquete ejecutable está en
> [`backend/`](../../backend/README.md) con 19 pruebas en verde. Esta guía
> explica los hallazgos del repositorio original y cómo integrarlo.

Auditoría del repositorio `ManuelYah/Bel-Aaktun` (rama `main`, 2026-11-03).
Stack real: **Flask 3.0 + PyMySQL + MySQL 8**, frontend TypeScript aparte
(`becal-frontend`), todo en un `docker-compose.yml`.

---

## 1. Acciones urgentes de seguridad (antes de seguir)

| # | Acción | Por qué |
|---|---|---|
| 1 | **Revocar la contraseña de aplicación de Gmail** que está en `becal-backend/app.py` y cambiarla por variables de entorno | Está publicada en un repositorio público: cualquiera puede enviar correos como la cuenta |
| 2 | Sacar de `docker-compose.yml` y del código las credenciales de BD a un `.env` (y añadir `.env` a `.gitignore`) | Hoy están en el repo; en producción permiten acceso total |
| 3 | Dejar de devolver `str(e)` en las respuestas 500 | Filtra detalles internos de la base y del servidor |
| 4 | Desactivar `debug=True` en producción y restringir CORS a los dominios reales | `app.run(debug=True, host='0.0.0.0')` expone el depurador; CORS `*` permite llamadas desde cualquier sitio |
| 5 | Quitar `node_modules/` del repositorio | Infla el repo (67 MB) y fija dependencias sin control |
| 6 | **No** ejecutar la migración sin respaldo (`mysqldump`) | Cambios de esquema en datos reales |

> Si la contraseña de Gmail ya se usó en producción, revisa la actividad de la
> cuenta y activa verificación en dos pasos.

---

## 2. Hallazgos de la auditoría del backend

### 2.1 Autenticación

| Hallazgo | Evidencia | Riesgo |
|---|---|---|
| Contraseñas en texto plano | `if usuario['password_hash'] == password` en `/api/auth/login` | Cualquiera con acceso a la BD lee todas las contraseñas |
| Sin hash, sin sal, sin verificación | La columna se llama `password_hash` pero guarda texto | Reutilización de contraseñas en otros sitios |
| Sin JWT | `Flask-JWT-Extended` está en `requirements.txt` pero **no se usa** | No hay sesión verificable; la app no puede autenticarse |
| Sin rol en la sesión | `login` devuelve `id, nombre, email, taller_id` | No hay RBAC |
| Sin límite de intentos | Login sin contador ni bloqueo | Fuerza bruta |
| Sin recuperación de contraseña | No hay endpoints | Usuarios bloqueados para siempre |

### 2.2 Endpoints sin autorización

Todos estos endpoints responden **sin comprobar quién llama**:

- `GET /api/reservas` devuelve **todas** las reservas de todos los talleres.
- `PATCH/DELETE /api/reservas/{id}` permite cambiar o borrar cualquier reserva.
- `POST/PUT/DELETE /api/productos` permite crear, editar o borrar productos de
  cualquier taller.
- `GET /api/apartados/taller/{id}` expone datos de clientes de cualquier taller.
- `PATCH/DELETE /api/apartados/{id}` modifica apartados ajenos.

Cualquiera con la URL puede leer nombres, correos y teléfonos de los visitantes.

### 2.3 Desfase entre `schema.sql` y `app.py`

`schema.sql` define `artesanos`, `artesanias`, `reservas` con columnas que
**no coinciden** con las consultas de `app.py`:

| `schema.sql` dice | `app.py` consulta |
|---|---|
| `artesanias` = catálogo (`nombre_es`, `precio_mxn`) | `artesanias` = taller (`nombre_taller`, `artesano_encargado`, `google_maps_url`) |
| `reservas.artesano_id`, `nombre_cliente` | `reservas.taller_id`, `nombre_visitante`, `email_visitante` |
| No existe `usuarios` | `SELECT ... FROM usuarios` |
| No existen `productos` ni `apartados` | Se usan en varios endpoints |

**Conclusión:** el esquema real evolucionó fuera del repositorio. Para migrar sin
romper producción necesito el esquema vivo:

```sql
SHOW TABLES;
SHOW CREATE TABLE usuarios\G
SHOW CREATE TABLE artesanias\G
SHOW CREATE TABLE reservas\G
SHOW CREATE TABLE productos\G
SHOW CREATE TABLE apartados\G
```

### 2.4 Otras observaciones

- `docker-compose.yml` publica MySQL en `3307` con contraseña fija y monta
  `schema.sql` solo al crear el volumen: los cambios posteriores no se aplican.
- No hay migraciones versionadas (Alembic/Flask-Migrate); el esquema depende de
  ejecutar SQL a mano.
- `app.py` es un solo archivo de ~22 KB; conviene separar en blueprints.

---

## 3. Migración SQL incluida

[`001_mysql_auth.sql`](001_mysql_auth.sql) es **aditiva** y defensiva:

- Añade a `usuarios`: `rol`, `estado`, `telefono`, verificación de correo y
  fechas, solo si faltan (usa `information_schema`).
- Crea `solicitudes_artesano`, `medios_solicitud`, `notificaciones`,
  `registro_auditoria`, `intentos_acceso`, `tokens_revocados`.
- Restricciones que evitan errores graves:
  - una sola solicitud abierta por persona (columna generada + índice único);
  - solicitud revisada exige revisor y fecha;
  - rechazo exige motivo;
  - **el revisor no puede ser el solicitante** (auto-aprobación imposible);
  - auditoría con `JSON` y llave foránea al actor.

**Antes de ejecutarla**: respaldo y revisión de `SHOW CREATE TABLE usuarios`.
Si `usuarios.id` es `BIGINT`, cambia `INT` por `BIGINT` en las FK.

```bash
mysqldump -u becal_user -p becal_db > respaldo_$(date +%F).sql
mysql -u becal_user -p becal_db < docs/backend/001_mysql_auth.sql
```

---

## 4. Integración en Flask (siguiente fase)

### 4.1 Dependencias

```txt
Flask==3.0.2
Flask-Cors==4.0.0
PyMySQL==1.1.0
Cryptography==42.0.5
Flask-JWT-Extended==4.6.0   # ya está instalado
argon2-cffi==23.1.0         # hash de contraseñas (o usa werkzeug.security)
python-dotenv==1.0.1        # variables de entorno
```

### 4.2 Estructura propuesta (sin romper lo actual)

```
becal-backend/
  app.py                 # solo crea la app y registra blueprints
  config.py              # lee .env (secretos fuera del código)
  db.py                  # get_db_connection()
  security.py            # hash de contraseñas, decoradores de rol, auditoría
  blueprints/
    auth.py              # registro, login, refresh, logout, recuperar
    solicitudes.py       # solicitud de taller + fotos + estado
    admin.py             # bandeja, aprobar/rechazar, suspender, auditoría
    reservas.py          # (mover lo actual y proteger)
    productos.py         # (mover lo actual y proteger)
  tests/
```

`app.py` actual se conserva; solo se le añade al final:

```python
from blueprints.auth import auth_bp
from blueprints.admin import admin_bp
app.register_blueprint(auth_bp, url_prefix='/api/v1/auth')
app.register_blueprint(admin_bp, url_prefix='/api/v1/admin')
```

### 4.3 Contraseñas: migración sin pedir cambio a los usuarios

1. En el login, detectar si el valor guardado ya es un hash:

```python
from werkzeug.security import check_password_hash, generate_password_hash

stored = usuario['password_hash']
if stored.startswith(('pbkdf2:', 'scrypt:', 'argon2')):
    ok = check_password_hash(stored, password)
else:
    ok = stored == password          # legado en texto plano
    if ok:                            # se actualiza en el acto
        cursor.execute(
            'UPDATE usuarios SET password_hash = %s WHERE id = %s',
            (generate_password_hash(password), usuario['id'])
        )
        conn.commit()
```

2. A partir de ahí, toda contraseña nueva se guarda con hash y las viejas se
   migran en su siguiente inicio de sesión.
3. Forzar cambio de contraseña a las cuentas administrativas.

### 4.4 Reglas que cada endpoint debe cumplir

| Endpoint | Regla |
|---|---|
| `GET /api/reservas` | Solo admin; el artesano usa `/taller/<su id>`; el turista solo las suyas |
| `PATCH /api/reservas/{id}` | Solo el taller dueño o el turista dueño, según el estado |
| `POST/PUT/DELETE /api/productos` | Solo el taller dueño y aprobado |
| `GET /api/apartados/taller/{id}` | Solo el taller dueño o admin |
| Endpoints admin | Solo `rol = 'admin'` y `estado = 'activo'` |

Decoradores sugeridos:

```python
@jwt_required()
def requiere_rol(*roles):
    def wrapper(fn):
        @wraps(fn)
        def inner(*args, **kwargs):
            identidad = get_jwt_identity()
            usuario = cargar_usuario(identidad)          # de la BD, no del token
            if not usuario or usuario['estado'] != 'activo':
                return jsonify(error='cuenta inactiva'), 403
            if usuario['rol'] not in roles:
                return jsonify(error='sin permiso'), 403
            return fn(*args, **kwargs)
        return inner
    return wrapper
```

La suspensión se aplica al releer el usuario en cada petición (no basta el rol
del token).

### 4.5 Flujo de verificación de talleres

1. `POST /api/v1/artisan-applications` (turista autenticado) → estado
   `pendiente`, notificación a administradores.
2. `POST .../{id}/media` → sube fotos (validar tipo y tamaño).
3. Admin: `GET /api/v1/admin/artisan-applications?estado=pendiente`.
4. Admin: `POST .../{id}/review` con `{decision: 'aprobada'|'rechazada', motivo}`:
   - valida rol admin y que no sea el solicitante;
   - actualiza estado, revisor y fecha;
   - escribe `registro_auditoria`;
   - notifica al solicitante;
   - si se aprueba: `UPDATE usuarios SET rol='artesano' WHERE id=...`.
5. Suspensión: `POST /api/v1/admin/artisans/{id}/suspend` con motivo → estado del
   usuario/taller y auditoría.

---

## 5. Qué falta de tu lado para implementarlo

1. **Esquema vivo** (`SHOW CREATE TABLE` de las 5 tablas principales) o un dump
   sin datos. Sin eso, la migración puede chocar con columnas reales.
2. Confirmar **MySQL** como motor definitivo (recomendado: no migrar de motor
   ahora; el esquema y la app no dependen de Postgres).
3. Rotar las credenciales filtradas antes de conectar la app.
4. Decidir **dónde corre** el backend (hoy `docker-compose` local) para probar
   los endpoints desde el teléfono.
5. Aprobar la estructura de blueprints propuesta.

Con el esquema vivo, el siguiente paso es implementar `blueprints/auth.py` y
`blueprints/admin.py` con pruebas `pytest` de los 10 escenarios, y después
conectar la app Flutter a `/api/v1`.
