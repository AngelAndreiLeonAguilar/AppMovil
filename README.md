# Bel-Aaktun

Plataforma de turismo artesanal y gestión de talleres en Bécal, Calkiní,
Campeche: cuevas, talleres de Jipi Japa, artesanas y reservación de visitas.

Flutter 3.47 (Dart 3.13) · Android · iOS · Web.

## Qué incluye

**Turista**

- Inicio, catálogo con búsqueda y filtros, mapa (OpenStreetMap) y fichas de
  talleres y piezas con galería de fotos.
- **Compras con carrito** y **recogida presencial en el taller** (sin envíos):
  un pedido por taller, estados de principio a fin y aviso de cuándo recoger.
- **Reservación de visitas** con disponibilidad real (cupo por horario, días y
  horas del taller) y detalles de cada experiencia.
- **Actividad**: visitas y compras por separado, con estado en vivo e
  historial; avisos en la barra del teléfono y recordatorios.

**Artesano**

- **Panel**: solicitudes, pedidos por aceptar, ingresos del mes, alertas de
  inventario, guía "Completa tu taller" y actividad reciente.
- **Pedidos**: visitas (aceptar, rechazar, completar, no-show, cancelar) y
  compras (aceptar con fecha de recogida, preparar, listo, entregado).
- **Catálogo**: piezas y experiencias con fotos, precios, inventario ajustable
  y plantillas para llenarlo fácil.
- **Ingresos**: vendido, comisión de Bel-Aaktun e ingreso neto por periodo,
  por confirmar, comisión por pagar, gráfica semanal, lo más vendido e
  historial de cada operación.
- **Perfil** del taller: portada, foto, historia, contacto, horario, pagos e
  idiomas.

**Administración**

- Resumen de la plataforma, verificación de talleres, usuarios (turistas,
  artesanos), supervisión de pedidos y reservaciones, moderación del catálogo,
  comisiones configurables con rendimiento por mes y liquidaciones, y bitácora.

**Bel-Aaktun (modelo de negocio)**

- Comisión configurable por venta de piezas (10 %) y por visitas (15 %),
  registrada por operación, con separación clara entre el dinero del taller y
  el ingreso de la plataforma. Ver *Comisiones de Bel-Aaktun* abajo.

## Versión de pruebas sin servidor (modo local)

Mientras no exista el servidor, **la app funciona completa dentro del
teléfono**: cuentas, sesiones, talleres, catálogo, fotos, reservas y avisos se
guardan en el propio dispositivo. Basta con instalar el APK:

```powershell
flutter build apk --release
# El APK queda en build/app/outputs/flutter-apk/app-release.apk
```

Importante para las pruebas con clientes:

- Sin servidor, cada teléfono tiene sus propios datos. Para probar con dos
  teléfonos usa el servidor de pruebas (sección siguiente).
- El registro de taller se **aprueba al instante** (`AppConfig.autoApproveArtisans`)
  para que el artesano pueda subir piezas desde el primer minuto.
- **Versión del piloto: la app arranca vacía.** No trae talleres, piezas,
  experiencias, reservas ni usuarios de ejemplo; los talleres y visitantes
  reales se registran desde la app. Al actualizar sobre una versión anterior,
  los datos de ejemplo se borran solos y lo creado por usuarios reales se
  conserva. Del mapa solo queda la plaza de Bécal como punto de encuentro.
- Única cuenta inicial: `admin@belaaktun.mx` (administración, contraseña
  `Becal2026`), para aprobar talleres y moderar el catálogo. **Cambia la
  contraseña** en `AppConfig.adminAccount` antes de entregar la app.
- Los datos de ejemplo siguen disponibles para las pruebas automáticas
  (`AppConfig.seedSampleData`, que activa `test/flutter_test_config.dart`).
- Las contraseñas se guardan con sal y hash, nunca en texto plano.

### Probar con dos o más teléfonos (servidor de pruebas en la red WiFi)

Para que un teléfono sea el **artesano** y otro el **turista** y se vean entre
sí, la computadora hace de servidor provisional:

1. Conecta la computadora y los teléfonos al **mismo WiFi**.
2. En la computadora, doble clic en
   `tools/servidor_pruebas/iniciar_servidor.bat` (o
   `python tools/servidor_pruebas/servidor.py`). Muestra una dirección como
   `192.168.1.50:8787`.
   - Si Windows pregunta por el firewall, elige **Permitir** en redes
     privadas. Si tu WiFi está marcado como *red pública*, cámbialo a
     *privada* en Configuración → Red e Internet.
3. En cada teléfono, en la pantalla de inicio de sesión toca **Servidor de
   pruebas → Conectar**, escribe la dirección, **Probar** y **Conectar**. La app
   se reinicia ya conectada (también está en *Mi cuenta / Perfil*).
4. Teléfono 1: crea una cuenta con **Tengo un taller**. Teléfono 2: crea una
   cuenta de visitante.

Qué se comparte: cuentas, talleres, catálogo, fotos, reservas, compras y
avisos. Cada teléfono revisa cambios cada 4 segundos y muestra el aviso en la
barra de notificaciones mientras la app esté abierta o en segundo plano (si
el sistema la cierra por completo, el aviso llega al volver a abrirla).

Los datos y las fotos quedan en `tools/servidor_pruebas/datos/`. Para empezar
de cero, cierra el servidor y borra esa carpeta. **Es solo para pruebas**: usa
HTTP sin cifrar y cualquiera en la misma red podría leer los datos.

### Compras de piezas con recogida en el taller

Comprar una pieza **no** es reservar una visita, y Bel-Aaktun **no hace
envíos**: el turista compra en la app y recoge en el taller.

- En la ficha de la pieza: **Agregar al carrito** (las piezas de "precio a
  consultar" abren WhatsApp con el taller en lugar del carrito).
- **Carrito** (bolsa en Catálogo, ficha de pieza y Actividad → Compras):
  cantidades, resumen y **Confirmar pedido**. Si hay piezas de varios talleres
  se genera **un pedido por taller**.
- Estados: Pendiente de aceptación → Aceptado → En preparación → Listo para
  recoger → Entregado; también Rechazado y Cancelado.
- El taller, en **Pedidos → Compras**, acepta o rechaza y define **fecha y hora
  de recogida** (con indicaciones). El turista recibe el aviso y un
  recordatorio 2 horas antes.
- Al aceptar se apartan las existencias; si se cancela, se devuelven.
- Pago: en el taller al recoger. La app todavía no procesa pagos en línea y no
  simula cobros.

### Comisiones de Bel-Aaktun

- Tasas configurables por la administración (**Plataforma → Comisiones**):
  venta de piezas (10 % por defecto) y visitas (15 %). Un cambio solo aplica
  a operaciones que se acepten después; cada movimiento conserva su tasa.
- Cada pedido aceptado crea **un único** movimiento con total, comisión e
  ingreso del taller. Estados: *Por confirmar* (aceptado, no es ingreso),
  *Devengada* (entregado) y *Anulada* (cancelado). Un pedido rechazado nunca
  genera comisión. Cada movimiento guarda su historial para auditoría.
- Como el cliente paga en el taller, la comisión devengada queda **por
  liquidar** hasta que la administración registra su pago con una referencia.
  La app no simula cobros ni transferencias.
- Las **visitas** siguen la misma regla: al confirmar una reservación se crea
  su movimiento (sobre el precio total de la experiencia), se devenga al
  marcarla como completada y se anula si se cancela, se rechaza o el turista
  no llega. Las reservaciones de ejemplo (`bk-seed-*`) no generan comisión.
- El taller ve en cada pedido y en cada reservación el desglose: total,
  comisión y su ingreso neto.

### Ventas e ingresos del taller

La pestaña **Ingresos** del artesano sale del registro financiero real:

- Ingreso neto, vendido y comisión de Bel-Aaktun por periodo (este mes, 30
  días, todo); *por confirmar* y *comisión por pagar*.
- Desglose por piezas y por visitas, barras de ingreso neto de 4 semanas, lo
  más vendido e historial de cada venta y visita con su desglose.
- El panel muestra los ingresos del mes y avisa de piezas con 2 o menos en
  existencia; en el catálogo cada pieza muestra sus existencias y se ajustan
  con un toque.
- Los anticipos simulados ya no aparecen como dinero cobrado.

### Panel de administración

Pestañas: **Resumen** (ingreso del mes, turistas, talleres, piezas,
experiencias, pedidos y reservaciones), **Solicitudes** (verificación de
talleres), **Usuarios** (filtro por turistas, artesanos y administración;
suspender y reactivar), **Pedidos** y **Reservas** (supervisión de toda la
plataforma), **Catálogo** (ocultar o volver a publicar piezas y experiencias;
el taller recibe un aviso con el motivo), **Comisiones** (tasas, totales por
periodo, rendimiento de los últimos 6 meses, movimientos y liquidaciones) y
**Auditoría**. Las funciones de supervisión solo responden a cuentas de
administración.

### Reservaciones con disponibilidad real

- Cada horario muestra los **lugares libres** (cupo de la experiencia menos las
  solicitudes y visitas confirmadas) y se marca "Lleno" cuando no hay.
- Solo se ofrecen los **días y horas en que abre el taller** (si definió su
  horario) y la visita debe terminar antes de cerrar; el mismo día se pide al
  menos 1 hora de anticipación.
- La app vuelve a validar todo al enviar la solicitud, por si otro turista
  reservó al mismo tiempo.
- Se muestran los detalles de la experiencia (qué incluye, idiomas, qué traer,
  punto de encuentro) y el anticipo se presenta tal cual: la app todavía no
  cobra en línea; se acuerda y paga en el taller.

### Fotos

Artesanos y turistas pueden tomar o elegir fotos (cámara o galería): foto de
perfil, portada del taller y hasta 6 fotos por pieza o experiencia. Se
comprimen y se copian a la carpeta privada de la app.

### Notificaciones

Los avisos llegan a la **barra de notificaciones** del teléfono (Android 13+
pide permiso la primera vez que se inicia sesión):

- Solicitud enviada, nueva solicitud, confirmación, rechazo, cancelación.
- Recordatorios programados 24 h y 2 h antes de cada visita confirmada.
- Desde *Mi cuenta / Perfil* se pueden apagar y enviar un aviso de prueba.

Sin servidor, los avisos solo pueden generarse por acciones hechas en el mismo
teléfono. Para que un taller reciba el aviso cuando un turista reserva desde
**otro** teléfono hace falta el backend + Firebase Cloud Messaging (pendiente).

### Modo oscuro

La app abre siempre en modo claro. El usuario puede cambiarlo con el botón de
luna o en *Mi cuenta / Perfil → Modo oscuro*; la elección se recuerda.

## Con servidor (más adelante)

La app ya sabe hablar con la API del backend (`/api/v1`) descrito en
[`backend/`](backend/README.md). Para usarla, compila indicando la URL:

```powershell
cd backend
$env:BEL_REPO='memory'
python main.py            # http://127.0.0.1:5001

cd ..
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:5001/api/v1
```

Con `API_BASE_URL` definido, el login, el registro y la verificación de
talleres pasan por el servidor (JWT, refresh rotativo, suspensiones) y en la
pantalla de inicio de sesión aparece el apartado **SERVIDOR** para cambiar la
URL. Si la app dice «No se pudo conectar con…», revisa
`http://IP:5001/api/v1/health`, que el teléfono y la PC estén en la misma red
y que el firewall permita el puerto 5001.

## Arquitectura

```
lib/
  core/        tema, widgets base, estado global (AppScope), config
  domain/      entidades y reglas puras: reservas, pedidos, comisiones
  data/        modelos, repositorios, servicios (cuentas locales, fotos,
               notificaciones, servidor de pruebas), datos de ejemplo
  features/
    auth/          inicio de sesión, registro y AuthGate por rol
    home/ catalog/ map/ artisans/ contact/   experiencia del turista
    booking/       reservación de visitas y Actividad del turista
    orders/        carrito, pedidos y detalle con recogida
    artisan/       panel, pedidos, catálogo, ingresos y perfil del taller
    admin/         resumen, supervisión, catálogo y comisiones
    account/       cuenta, preferencias y servidor de pruebas
    notifications/ centro de avisos
tools/servidor_pruebas/  servidor para probar con varios teléfonos en WiFi
```

- **Estado**: `AppController` (ChangeNotifier) expuesto con `AppScope`.
- **Reglas puras y probadas**: `domain/booking_rules.dart` (visitas),
  `domain/order.dart` (pedidos y recogida), `domain/finance.dart`
  (comisiones, registro y resúmenes).
- **Permisos**: cada acción revisa el rol y la propiedad (el taller solo
  mueve sus pedidos y reservaciones, el turista los suyos y solo la
  administración modera, configura comisiones y registra liquidaciones).
- **Persistencia**: almacenamiento local en el teléfono o compartido con el
  servidor de pruebas; la misma interfaz permite migrar a un backend real.

## Reglas de negocio implementadas

- `requested → accepted → completed | noShow`, más `rejected` y cancelaciones
  por turista o taller. El resto de transiciones se rechaza.
- Anticipo configurable por experiencia (`depositPercent`).
- Reembolsos: 100 % con más de 48 h, 50 % entre 24 y 48 h, 0 % con menos de
  24 h, 100 % si el taller rechaza o cancela, retenido en no-show.
- Pedidos: pendiente de aceptación → aceptado → en preparación → listo para
  recoger → entregado; rechazado o cancelado. No se marca listo sin fecha de
  recogida; las existencias se apartan al aceptar y se devuelven si se cancela.
- Dinero: solo lo entregado o realizado cuenta como ingreso; lo aceptado es
  "por confirmar" y lo cancelado se anula. Los anticipos siguen simulados y no
  se presentan como dinero cobrado.

## Mapa

Por defecto usa OpenStreetMap: gratis, sin API key. Si la app crece, cambia dos
constantes en [`lib/core/config/app_config.dart`](lib/core/config/app_config.dart):

```dart
static const String mapTileUrl =
    'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=TU_KEY';
static const String mapAttribution = '© OpenStreetMap © MapTiler';
```

> **Android**: el permiso `INTERNET` está declarado en el manifest principal;
> sin él el mapa se ve vacío en el APK de release.

## Compilar y probar

```powershell
flutter pub get
flutter run
flutter analyze
flutter test                    # dominio, compras, comisiones, disponibilidad, admin y capturas
flutter test --update-goldens   # solo si cambias la interfaz a propósito
flutter build apk --release
```

La firma de release usa la clave de depuración: sirve para instalar y probar,
no para publicar en Play Store.

## Pendientes para producción

1. **Pagos en línea** (Mercado Pago o Stripe) para cobrar anticipos y piezas;
   hoy se paga en el taller y las comisiones se liquidan con referencia manual.
2. **Servidor en la nube** (Firebase o el backend en Python) para sincronizar
   datos y fotos entre teléfonos fuera de la red local.
3. **Notificaciones push** entre teléfonos (Firebase Cloud Messaging).
4. **Datos reales**: los talleres ya se registran desde la app; faltan las
   paradas reales del mapa y los datos de contacto de la plataforma.
5. Recuperación de contraseña por correo y firma de release propia para
   publicar en Play Store.
