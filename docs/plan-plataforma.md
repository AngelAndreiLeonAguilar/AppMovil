# Auditoría y plan: de app turística a plataforma de gestión

Fecha: 2026-11-02 · Estado del código: ~6,000 líneas Dart, 34 archivos, 12 pruebas
en verde, `flutter analyze` limpio.

---

## 0. Estado de avance

| Etapa | Estado | Qué quedó |
|---|---|---|
| 0 · Costuras | ✅ Hecho | `domain/` con entidades y reglas puras; repositorio de reservas; `AppController` + `AppScope`; persistencia con `shared_preferences` y respaldo en memoria |
| 1 · Autenticación | ✅ Hecho | Login con 3 cuentas demo, `AuthGate` por rol, shells separados (turista / artesano / admin) y sesión persistente |
| 2 · Panel del artesano | ✅ Hecho | Dashboard con contadores y dinero, reservaciones con aceptar/rechazar/completar/no-show/cancelar, notificaciones internas con campana y contador, catálogo y perfil del taller |
| 3 · Productos y servicios | ✅ Hecho | Alta, edición, activar/desactivar y eliminar piezas y experiencias; el turista ve los cambios. Falta subir fotos (requiere almacenamiento) |
| 4 · Anticipos | 🟡 Parcial | Precio, porcentaje de anticipo por servicio, cobro simulado marcado como demo, políticas y reembolsos calculados; falta pasarela real |
| 5 · Ganancias | ✅ Básico | Cobrado / por cobrar / pendiente / cancelado, barras de 4 semanas, ranking de servicios y no-shows |
| 6 · Integraciones | ⏳ Pendiente | Supabase, FCM, WhatsApp y Mercado Pago dependen de cuentas y credenciales |
| 7 · Pruebas | ✅ Hecho para lo construido | 36 pruebas: reglas de negocio, dinero, persistencia, aislamiento por taller, flujos y capturas |

Verificado el 2026-11-02: `flutter analyze` sin errores, `flutter test` con 36
pruebas en verde y APK de release compilado.

---

## 1. Auditoría del proyecto actual

### 1.1 Lo que ya funciona (y hay que conservar)

| Área | Estado | Archivos |
|---|---|---|
| Identidad visual | Paleta de 6 colores, modo claro/oscuro, tipografías Playfair/Cormorant/Lato, tokens de espaciado y radios | `core/theme/*` |
| Componentes base | Botones, superficies, píldoras, chips de filtro, campos, encabezados, arte generativo, toggle de tema | `core/widgets/*` |
| Navegación | Shell con 5 pestañas (`PageView` + keep-alive) y `SelectTab` | `features/shell`, `core/navigation` |
| Mapa real | `flutter_map` + OSM, pines por tipo, ruta, encuadre, enlaces a Google Maps | `features/map/*` |
| Catálogo | Búsqueda por texto + filtro por categoría + detalle de pieza | `features/catalog/*` |
| Artesanos | Lista, ficha de perfil, piezas del taller | `features/artisans/*` |
| Reservas (turista) | Formulario: experiencia, día, horario, personas, nombre, teléfono, notas | `features/booking` |
| Contenido | 4 artesanos, 6 productos, 5 paradas con coordenadas, 3 experiencias | `data/demo_content.dart` |
| Modelos de dominio | `Artisan`, `Product`, `CaveLocation`, `Experience`, `BookingRequest` | `data/models.dart` |
| Pruebas | 1 flujo básico, 1 de deslizamiento, 10 capturas doradas | `test/` |
| Documentación | README + estrategia de monetización | `README.md`, `docs/` |

### 1.2 Lo que falta para la plataforma pedida

| # | Requisito | Estado | Brecha |
|---|---|---|---|
| 1 | Roles (turista / artesano / admin) | ❌ Nada | No hay `User`, ni sesión, ni login, ni guardas de ruta |
| 2 | Persistencia | ❌ Nada | Todo es `static const`; al cerrar la app se pierden reservas. No hay repositorios ni capa de datos |
| 3 | Reserva con estado | ❌ Nada | `BookingRequest` no tiene id, estado, precio, anticipo, historial ni fechas de creación |
| 4 | Aceptar / rechazar / completar / no-show | ❌ Nada | El flujo termina en un modal de "solicitud registrada" |
| 5 | Precio de experiencias | ❌ Nada | `Experience` no tiene precio, cupo, anticipo ni dueño |
| 6 | Asignación al taller | ❌ Nada | `Experience` no referencia a un artesano; una reserva no sabe a quién pertenece |
| 7 | Notificaciones | ❌ Nada | Sin centro de notificaciones, sin push, sin registro |
| 8 | Disponibilidad real | ❌ Nada | Horarios globales en `AppConfig`; sin bloqueos ni cupo por turno |
| 9 | Panel del artesano | ❌ Nada | No existe |
| 10 | Panel de administración | ❌ Nada | No existe |
| 11 | Productos/servicios editables | ❌ Nada | Catálogo de solo lectura |
| 12 | Ingresos y estadísticas | ❌ Nada | Sin registro de pagos ni cálculos |
| 13 | Anticipos | ❌ Nada | Sin pasarela, sin política, sin simulación marcada |
| 14 | Mensajería | ⚠️ Parcial | Contacto solo copia el número al portapapeles; no abre WhatsApp con mensaje |
| 15 | Datos reales | ⚠️ Demo | Todo el contenido es ficticio y está etiquetado como demo |
| 16 | Pruebas de dominio | ❌ Nada | No hay pruebas de reglas (estados, dinero, anticipos) |

### 1.3 Deuda técnica detectada

1. **Acoplamiento a `DemoContent`**: las pantallas leen datos estáticos directamente. Cambiar a repositorios tocará todas las vistas, pero es mecánico.
2. **Sin capa de estado compartido**: solo `setState` por pantalla. El estado de sesión, reservas y notificaciones debe vivir en un ámbito común.
3. **`BookingRequest` es un DTO del formulario**, no una entidad: no sirve como base para el panel del artesano.
4. **`Experience` sin dueño ni precio**: impide enrutar reservas y calcular dinero.
5. **Navegación plana**: 5 pestañas fijas, sin concepto de rol ni rutas con nombre.
6. **Sin serialización**: no hay `fromJson`/`toJson`; integrar backend implicará añadirlos.
7. **Sin manejo de errores/estados de carga**: todo es síncrono; con red aparecerán estados vacíos, errores y reintentos.
8. **Pruebas solo de UI**: no hay pruebas de las reglas que más dinero tocan.

---

## 2. Arquitectura propuesta

Separación por capas dentro del mismo proyecto, sin reescribir la UI existente:

```
lib/
  core/            tema, widgets base, utils, config, routing
  domain/          entidades + reglas puras (estados, anticipos, dinero)
  data/
    models/        DTO con fromJson/toJson
    repositories/  interfaces + implementación demo (memoria) y remota
    services/      auth, pagos, notificaciones, analítica
  features/
    auth/          login, registro, selector de rol
    tourist/       todo lo actual (home, catalog, map, artisans, booking, perfil, mis reservas)
    artisan/       dashboard, reservations, products, services, earnings, profile
    admin/         usuarios, artesanos, talleres
```

**Reglas de convivencia:**

- Nada de lo actual se elimina: las pantallas del turista se mueven a `features/tourist/` conservando widgets y capturas.
- Los componentes de `core/widgets` se reutilizan tal cual (botones, superficies, píldoras, campos).
- Las reglas de negocio van a `domain/` como funciones puras, fáciles de probar sin interfaz.

### 2.1 Estado y sesión

Se reutiliza el patrón que ya existe (`ThemeScope` con `InheritedNotifier`) para un
`AppScope` con:

```dart
class AppState extends ChangeNotifier {
  Session? session;          // usuario y rol
  List<Booking> bookings;
  List<AppNotification> notifications;
  List<Product> products;
  List<Service> services;
}
```

Sin dependencias nuevas de gestión de estado: el patrón ya está probado en el
proyecto y mantiene el proyecto ligero.

### 2.2 Repositorios

Interfaz primero, implementación intercambiable:

```dart
abstract interface class BookingRepository {
  Future<List<Booking>> byArtisan(String artisanId);
  Future<List<Booking>> byTourist(String userId);
  Future<Booking> create(Booking draft);
  Future<Booking> updateStatus(String id, BookingStatus status);
}
```

- `InMemoryBookingRepository` + `DemoContent`: permite entregar el módulo completo
  sin backend y con la etiqueta "demo" ya existente.
- `SupabaseBookingRepository`: se añade cuando exista el proyecto y las políticas
  RLS por artesano.

**Por qué Supabase y no Firebase para esta app:** base de datos relacional con
políticas por fila (un artesano solo ve lo suyo, garantizado en servidor), Auth,
Storage para fotos y Realtime para notificaciones internas, con plan gratuito.
FCM se sigue necesitando solo para push real en dispositivos.

---

## 3. Modelo de datos propuesto

### 3.1 Entidades nuevas

```dart
enum UserRole { tourist, artisan, admin }

class User { id, role, name, phone, email, createdAt }

class ArtisanProfile {
  id, userId, displayName, craft, caveId, bio, phone, address,
  photoUrl, policies, defaultDepositPercent, isVerified, isActive
}

class Service {                    // la actual Experience, ampliada
  id, artisanId, caveId, title, description, durationMinutes,
  pricePerPerson, maxParticipants, depositPercent, schedule, isActive
}

enum BookingStatus {
  requested, accepted, rejected,
  completed, cancelledByTourist, cancelledByArtisan, noShow
}

class Booking {
  id, folio, serviceId, artisanId, touristId, touristName, touristPhone,
  date, timeSlot, people, status, totalAmount, depositAmount,
  depositStatus, paymentId, notes, createdAt, updatedAt, history
}

class Payment { id, bookingId, amount, kind (deposit|balance|refund),
                provider, status, reference, paidAt }

class AppNotification {
  id, userId, type, title, body, bookingId, read, createdAt
}
```

### 3.2 Reglas de negocio (funciones puras, con pruebas)

**Máquina de estados**

| Desde | Acción | Hacia | Quién |
|---|---|---|---|
| `requested` | aceptar | `accepted` | artesano |
| `requested` | rechazar | `rejected` | artesano |
| `requested` | cancelar | `cancelledByTourist` | turista |
| `accepted` | completar | `completed` | artesano |
| `accepted` | no-show | `noShow` | artesano |
| `accepted` | cancelar | `cancelledByTourist` / `…ByArtisan` | turista / artesano |

Cualquier otra transición se rechaza y se registra en `history`.

**Anticipos (configurables por servicio, nunca globales)**

| Situación | Política propuesta |
|---|---|
| Cancelación con más de 48 h | Reembolso del 100 % del anticipo |
| Cancelación entre 24 y 48 h | Reembolso del 50 % |
| Cancelación con menos de 24 h | Sin reembolso |
| Rechazo del artesano | Reembolso del 100 % |
| No-show | Anticipo retenido por el taller |
| Cambio de fecha | Permitido una vez, sin costo, con más de 48 h |

**Dinero** (lo más delicado, y lo que piden no confundir):

- `ingresos cobrados` = anticipos y saldos con pago `paid` de reservas `completed`.
- `por cobrar` = reservas `accepted` con anticipo pagado pero visita futura.
- `pendientes` = solicitudes `requested`.
- `perdido` = `noShow` y cancelaciones sin reembolso.
- Una reserva **nunca** suma a ingresos solo por estar agendada.

### 3.3 Persistencia

| Fase | Implementación | Qué gana |
|---|---|---|
| Demo | Repositorios en memoria sembrados con `DemoContent` | Módulo completo funcional sin backend, todo etiquetado demo |
| Local | `shared_preferences` para sesión y borradores | La sesión sobrevive al reinicio |
| Remota | Supabase (Postgres + RLS + Storage + Realtime) | Multiusuario real, datos separados por taller |

---

## 4. Navegación por roles

```
main
 └── AuthGate (decide según Session)
      ├── LoginScreen / Registro (rol turista o artesano)
      ├── TouristShell      (pestañas actuales + "Mis reservas")
      ├── ArtisanShell      (Panel · Reservas · Productos · Ganancias · Perfil)
      └── AdminShell        (Usuarios · Artesanos · Talleres)
```

- **Turista**: conserva sus 5 pestañas. La pestaña "Reservas" pasa a ser
  "Mis reservas" con historial y estado en vivo; el formulario de reserva se
  abre como ruta desde cada taller/experiencia.
- **Artesano**: barra inferior nueva con 5 secciones; "Servicios" se agrupa con
  "Productos" en una pantalla con dos segmentos (menos pestañas = menos ruido).
- **Admin**: lista simple y directa, sin dashboard pesado en la primera versión.

---

## 5. Plan de implementación

| Etapa | Alcance | Días | Archivos principales |
|---|---|---|---|
| 0 | Costuras: repositorios, `AppScope`, entidades y estados, sin cambiar la UI | 2 | `domain/*`, `data/repositories/*`, `core/state/*` |
| 1 | Autenticación con roles y `AuthGate`; login demo con 3 perfiles | 2–3 | `features/auth/*`, `app.dart` |
| 2 | Panel del artesano: dashboard con contadores, lista de solicitudes, aceptar/rechazar, notificaciones internas | 4–6 | `features/artisan/*`, `data/services/notifications.dart` |
| 3 | Gestión de productos y servicios con formularios y activar/desactivar | 3–4 | `features/artisan/products*`, `services*` |
| 4 | Anticipos: precio y % por servicio, pago **simulado** marcado como demo, políticas, `Payment` | 3–4 | `domain/deposit_policy.dart`, `features/booking/*` |
| 5 | Ganancias: reportes día/semana/mes, ranking de servicios, gráficas propias | 3 | `features/artisan/earnings*` |
| 6 | Integraciones reales: Supabase, FCM, WhatsApp (`wa.me`), Mercado Pago | 5–10 | `data/services/*`, `android/`, plataformas |
| 7 | Pruebas: unitarias de reglas, widget del flujo artesano, capturas actualizadas | 2–3 | `test/*` |

**Ruta corta recomendada:** etapas 0→5 (~3 semanas de trabajo efectivo) dan un
producto demostrable y usable por un taller con datos locales y anticipos
simulados claramente marcados. Las integraciones externas (etapa 6) dependen de
cuentas, credenciales y trámites que no puedo crear por ti.

### Qué se reutiliza en el módulo del artesano

| Necesidad | Componente existente |
|---|---|
| Tarjetas y contenedores | `BelSurface` |
| Botones de acción | `BelButton`, `BelIconButton` |
| Estados y etiquetas | `BelPill` (ampliar con color semántico) |
| Campos de formulario | `BelTextField` |
| Encabezados | `PageHeader`, `SectionHeader` |
| Listas de taller | `ArtisanCard`, `ProductCard` |
| Gráficas | `CustomPaint` con la paleta actual (sin dependencia nueva) |
| Tema | `AppColors`, `BelPalette`, `context.colors/palette/texts` |

---

## 6. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Sobrecargar al artesano con pantallas | 5 secciones máximo, acciones grandes, dashboard con 4 números |
| Datos demo confundidos con reales | Mantener `showDemoBadges`, insignia "Demo" en pagos simulados y aviso en el dashboard |
| Pérdida de datos al no haber backend | Aviso explícito en modo demo; fase 0 con repositorios para migrar sin tocar UI |
| Complejidad de roles mal resuelta | Reglas de visibilidad en el `AuthGate` y pruebas de aislamiento por taller |
| "Ingresos" inflados | Cálculo separado de cobrado / por cobrar / pendiente, con pruebas unitarias |
| Dependencias de FCM/Mercado Pago | Aisladas en servicios; la app sigue funcionando sin ellas |

---

## 7. Decisiones que necesito antes de tocar código

1. **Backend**: ¿Supabase (recomendado) o Firebase? ¿O seguimos en modo local/demo
   hasta validar el módulo con artesanos reales?
2. **Pagos**: ¿Mercado Pago (recomendado para México) o Stripe? Mientras no exista
   cuenta, el anticipo se simula y se marca como demo.
3. **Login**: ¿correo y contraseña, o teléfono con código SMS? (Los artesanos suelen
   preferir teléfono/WhatsApp; SMS tiene costo por mensaje.)
4. **Fotos de productos**: ¿cámara/galería con `image_picker` y almacenamiento en la
   nube, o solo URL/ruta por ahora?
5. **Administrador general**: ¿lo construimos en la primera entrega o lo dejamos
   para después de validar el módulo del artesano?
6. **Datos reales**: nombres, teléfonos, precios y políticas de los talleres. Sin
   ellos, todo queda como demo etiquetada.

## 8. Orden de arranque propuesto

Si apruebas el plan, empiezo por las etapas 0 y 1 en una sola entrega:

1. Entidades y reglas de reservas/anticipos con pruebas unitarias.
2. Repositorios en memoria y `AppScope` (la UI actual sigue funcionando igual).
3. Login con selector de rol demo y `AuthGate`; el turista entra a la app actual
   sin cambios visuales.
4. Panel vacío del artesano con dashboard conectado a los datos demo, para revisar
   la navegación antes de construir cada sección.

Con eso podrás abrir la app, elegir "soy artesano" y ver el cascarón del panel con
datos reales del repositorio, sin haber roto nada de lo que ya existe.
