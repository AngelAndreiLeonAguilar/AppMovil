# Plan: autenticación, roles y verificación de artesanos

Proyecto: Bel-Aaktun · Flutter 3.47 / Dart 3.13 · **backend real: Flask + MySQL**
Estado: auditoría del repositorio hecha · migración MySQL escrita · app sin tocar.

---

## 0. Contexto actualizado (auditoría del repositorio, 2026-11-03)

El backend existe: `github.com/ManuelYah/Bel-Aaktun` contiene `becal-backend`
(Flask 3.0 + PyMySQL), `becal-frontend` (TypeScript/Angular) y MySQL 8 en
`docker-compose.yml`. Hallazgos que cambian el plan:

| # | Hallazgo | Consecuencia |
|---|---|---|
| 1 | **MySQL 8**, no PostgreSQL | La migración operativa es [`backend/001_mysql_auth.sql`](backend/001_mysql_auth.sql) |
| 2 | Contraseñas en **texto plano** (`password_hash == password`) | Hay que migrar con hash y rehash al iniciar sesión |
| 3 | **Cero autorización**: `/api/reservas` devuelve todas; productos y apartados se editan sin autenticar | Cualquiera con la URL lee correos y teléfonos |
| 4 | **Contraseña de aplicación de Gmail publicada** en `app.py` + credenciales en `docker-compose.yml` | Rotar de inmediato |
| 5 | `schema.sql` **no coincide** con `app.py` (tablas y columnas distintas) | Falta el esquema vivo antes de migrar |
| 6 | `Flask-JWT-Extended` ya está en `requirements.txt` pero **sin usar** | No hace falta dependencia nueva de auth |
| 7 | Frontend **Angular**, no plantillas Flask | La API `/api/v1` sirve a Angular y a la app |
| 8 | `node_modules/` versionado, `debug=True`, CORS `*` | Limpieza y endurecimiento |

Guía de integración y checklist de seguridad:
[`docs/backend/README.md`](backend/README.md).

---

## 1. Auditoría de la app Flutter

| Elemento | Estado |
|---|---|
| Archivos Dart | 71 en `lib/` |
| Pruebas | 48; 3 capturas doradas fallan por fechas relativas (deuda previa) |
| `flutter analyze` | Limpio |
| Auth actual | **Simulada**: `DemoAccounts` con `demo1234` en el repo |
| Sesión | JSON en `shared_preferences` con el rol dentro → editable |
| Backend en la app | **No existe**: sin cliente HTTP |

### 1.1 Contradicciones con lo solicitado

| Requisito | Estado |
|---|---|
| Registro de turistas | ❌ |
| Solicitud de taller con verificación | ❌ |
| Roles y permisos reales | ❌ (solo UI) |
| Hash de contraseñas | ❌ |
| Tokens / sesión segura | ❌ |
| Auditoría, suspensión, recuperación | ❌ |
| Aislamiento por taller en servidor | ❌ |

### 1.2 Qué se conserva

Tema y componentes, dominio de reservas y dinero con sus pruebas, pantallas del
turista, panel del artesano y catálogo editable. Los datos actuales se migran.

---

## 2. Arquitectura: Flask + MySQL, un backend para dos clientes

```
   Angular (becal-frontend)          App Flutter
              │                          │
              └──────────┬───────────────┘
                         ▼
             API REST /api/v1 (Flask)
             ├── Auth: JWT (Flask-JWT-Extended), Argon2/Werkzeug
             ├── RBAC: rol en base + estado del taller en cada petición
             ├── Servicios: usuarios, talleres, catálogo, reservas,
             │   notificaciones, administración, auditoría
             └── Archivos: fotos de taller y piezas
                         │
                         ▼
                    MySQL 8 (InnoDB, utf8mb4)
```

### 2.1 Seguridad

| Tema | Decisión |
|---|---|
| Contraseñas | `werkzeug.security` (PBKDF2) o `argon2-cffi`; **nunca** texto plano |
| Hash legado | Migración transparente: si el valor no es hash, se valida en claro y se reescribe con hash en esa misma sesión |
| Sesión | Access token 15 min + refresh 30 días; `jti` en tabla `tokens_revocados` para logout |
| Rol | Columna `usuarios.rol`; el token lleva el rol, pero **cada petición relee el usuario** de la base para reflejar suspensiones |
| Admin | Sin registro público; se crea con `UPDATE usuarios SET rol='admin'` (script de una vez) |
| Intentos | `intentos_acceso` + bloqueo temporal por correo/IP |
| Correo | Flask-Mail (ya instalado) para verificación y recuperación; credenciales por `.env` |
| CORS | Lista de orígenes permitidos, no `*` |
| Errores | Nunca devolver `str(e)`; registrar en servidor y responder mensaje genérico |

### 2.2 Autorización por endpoint (reglas mínimas)

| Endpoint | Regla |
|---|---|
| `GET /api/reservas` | Solo admin; artesano usa `/taller/<su id>`; turista solo las suyas |
| `PATCH/DELETE /api/reservas/{id}` | Solo dueño (turista) o taller dueño, según estado |
| `POST/PUT/DELETE /api/productos` | Solo taller dueño y aprobado |
| `GET /api/apartados/taller/{id}` | Solo taller dueño o admin |
| `/api/admin/*` | Solo `rol = 'admin'` y `estado = 'activo'` |

---

## 3. Modelo de datos (MySQL)

[`docs/backend/001_mysql_auth.sql`](backend/001_mysql_auth.sql) crea, de forma
aditiva:

| Tabla | Para qué |
|---|---|
| `usuarios` (columnas nuevas) | `rol`, `estado`, `telefono`, verificación, fechas |
| `solicitudes_artesano` | solicitud con estado, revisor, motivo |
| `medios_solicitud` | fotos del taller y de piezas |
| `notificaciones` | avisos internos |
| `registro_auditoria` | quién aprobó/rechazó/suspendió y cuándo |
| `intentos_acceso` | límite de fuerza bruta |
| `tokens_revocados` | logout y rotación |

Restricciones clave: una solicitud abierta por persona, solicitud revisada exige
revisor y fecha, rechazo exige motivo y **el revisor no puede ser el
solicitante**.

> **Pendiente de validación**: el SQL está escrito para MySQL 8 y revisado a
> mano, pero no se ejecutó: esta sesión no tiene MySQL ni Docker operativo. Se
> valida con tu `mysqldump` y una base de prueba antes de tocar producción.

---

## 4. Flujos

1. **Registro turista** → correo de verificación → rol `turista`.
2. **Solicitud de taller** → `pendiente` + fotos → aviso a administración.
3. **Revisión** → `en_revision` → aprobar o rechazar con motivo → auditoría y
   notificación; al aprobar, `usuarios.rol = 'artesano'`.
4. **Suspensión** → estado del usuario/taller + auditoría; efecto inmediato.
5. **Reservas** → turista crea; taller gestiona; backend revalida las reglas ya
   probadas en Dart.
6. **Sesión** → JWT corto + refresh; logout revoca.

---

## 5. Pantallas de la app

| # | Pantalla | Reutiliza |
|---|---|---|
| 1 | Selector de tipo de cuenta | `PageHeader`, `BelButton` |
| 2 | Registro de turista | `BelTextField` |
| 3 | Solicitud de taller (pasos + fotos) | `BelTextField` |
| 4 | Inicio de sesión | `LoginScreen` (sin cuentas demo en release) |
| 5 | Estado de solicitud | `BelStatTile` |
| 6 | Panel del artesano | ya existe; aviso si está suspendido |
| 7 | Panel administrativo | se amplía |
| 8 | Bandeja de solicitudes | patrón `BookingCard` |
| 9 | Gestión de usuarios | listas existentes |

---

## 6. Fases

| Fase | Alcance | Días | Estado |
|---|---|---|---|
| F0 | Migración MySQL (auth, solicitudes, auditoría) | 1 | ✅ escrita, falta ejecutarla |
| F1 | Backend Flask: `blueprints/auth.py`, JWT, Argon2/PBKDF2, límite de intentos, `/me` | 2–3 | ✅ implementado en `backend/` con 21 pruebas y flujo HTTP verificado |
| F2 | Backend: solicitudes de taller + fotos + estados | 2 | 🟡 solicitudes y estados hechos; fotos pendientes |
| F3 | Backend: administración (aprobar/rechazar/suspender/auditoría) | 2 | ✅ endpoints y pruebas |
| F4 | App: cliente HTTP, `AuthRepository`, registro/login/estado, `AuthGate` real | 2 | ✅ app conectada a `/api/v1`; 56 pruebas en verde |
| F5 | App: solicitud de taller y estado; bloqueo de funciones | 2 | tras F2/F4 |
| F6 | Migrar catálogo y reservas de la app a la API | 2–3 | tras F1 |
| F7 | Pruebas: pytest de endpoints + widget tests + 10 escenarios | 2 | cierre |

**Total ≈ 14–18 días.** La app no puede conectarse antes de F1.

---

## 7. Los 10 escenarios de prueba

| # | Escenario | Verificación |
|---|---|---|
| 1 | Turista se registra e inicia sesión | pytest + widget test |
| 2 | Turista no entra al panel de artesanos | 403 + guarda en `AuthGate` |
| 3 | Usuario solicita ser artesano | fila `pendiente` + auditoría |
| 4 | Pendiente no administra ni recibe reservas | 403/409 + panel bloqueado |
| 5 | Admin aprueba | estado, rol, auditoría |
| 6 | Aprobado accede a su panel | pytest + widget |
| 7 | Artesano no toca otro taller | 403 con dos talleres |
| 8 | Turista no cambia su rol | campo ignorado |
| 9 | Usuario no accede a admin | 403 en cada endpoint |
| 10 | Admin suspende un taller | estado + sesión invalidada |

Infraestructura: `pytest` con base de prueba MySQL (o SQLite para lógica pura),
`flutter test` con cliente HTTP falso y reloj fijo en las doradas.

---

## 8. Lo que necesito de ti

1. **Esquema vivo** de MySQL: `SHOW TABLES;` y `SHOW CREATE TABLE` de
   `usuarios`, `artesanias`, `reservas`, `productos`, `apartados` (o un dump sin
   datos). Sin esto, la migración puede chocar con columnas reales.
2. **Rotar ya** la contraseña de aplicación de Gmail expuesta y las credenciales
   de base del `docker-compose.yml`; moverlas a `.env`.
3. Confirmar **MySQL** como motor definitivo (recomendado: no migrar de motor).
4. **Dónde corre** el backend (hoy compose local) para probar desde el teléfono.
5. **Fotos**: disco del servidor o S3/R2. **Correo**: confirmar que Flask-Mail
   sigue siendo la vía.
6. ¿Inicializo `git` en el proyecto Flutter para tener historial?

---

## 9. Riesgos

| Riesgo | Mitigación |
|---|---|
| Migrar sin conocer el esquema real | Esperar `SHOW CREATE TABLE`; probar en base de prueba |
| Endpoints abiertos mientras se migra | Cerrar primero los que exponen datos personales |
| Sesiones que sobreviven a suspensión | Releer usuario en cada petición |
| Fotos pesadas o inapropiadas | Límite de tamaño/tipo + revisión en la aprobación |
| Tests de UI frágiles | Reloj fijo en la semilla |

---

## 10. Lo que no haré

- No guardar contraseñas en texto plano ni credenciales en el repositorio.
- No confiar en el rol que envía el cliente.
- No permitir auto-aprobación ni cambio de rol desde el perfil.
- No borrar pantallas, datos ni pruebas existentes.
- No publicar un release con cuentas demo.
