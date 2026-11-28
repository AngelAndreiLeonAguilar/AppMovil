Actúa como experto en producto y desarrollo móvil. Te describo el estado ACTUAL de nuestra app para que trabajes sobre ella sin inventar funciones que no existen.

# Proyecto: Bel·Aaktun

**Qué es.** App móvil de turismo artesanal para Bécal, Calkiní, Campeche (México). Bécal es famoso por los sombreros de palma de jipi japa que se tejen dentro de cuevas húmedas. La app conecta tres partes:
- turistas y compradores, que descubren talleres, reservan visitas y compran piezas;
- artesanos, que administran su taller desde el celular;
- la administración de la plataforma.

El nombre viene del maya: «bel» es camino y «aktun» es cueva.

**Estado.** Prototipo funcional en desarrollo. Ya corre en Android con APK de release, firmada con la clave de depuración. Todavía no tiene usuarios reales, cobro en línea ni servidor en la nube. Equipo 3; presentador: Manuel Daniel Yah Dzul.

## Tecnología
- Flutter 3.47 y Dart 3.13. Android con AGP 9.1.1 y compileSdk 37.
- Estado global: `AppController` (ChangeNotifier) expuesto con `AppScope`.
- Persistencia:
  - Local en el teléfono (shared_preferences) a través de `LocalStore`.
  - Opcional: `SyncStore` contra un servidor de pruebas en Python (`tools/servidor_pruebas/servidor.py`, puerto 8787), para sincronizar dos o más teléfonos en la misma red WiFi.
- Notificaciones reales en la barra del teléfono (flutter_local_notifications), con recordatorios.
- Fotos desde cámara o galería para el perfil, la portada del taller, las piezas y las experiencias.
- Mapa con OpenStreetMap (flutter_map) y paradas georreferenciadas de las cuevas.
- Enlaces a WhatsApp, llamada, correo y mapas (url_launcher).
- Backend de referencia en Python/Flask en `backend/`, con esquemas SQL en `docs/backend/`. Todavía no está conectado en producción.
- Repositorio: https://github.com/AngelAndreiLeonAguilar/AppMovil (rama main).

## Diseño
- Modo claro por defecto; también tiene modo oscuro.
- Paleta inspirada en la cueva y la palma:
  - café oscuro (#1F1410);
  - arena (#F5EFE4);
  - papel (#FFF8EE);
  - terracota (#D65F38 / #B4452A);
  - dorado (#E0B054).
- Tipografías: Playfair Display (títulos), Cormorant Garamond (acentos en itálica) y Lato (texto).

## Cuentas de demostración (contraseña: Becal2026)
- admin@belaaktun.mx: administración
- elena@belaaktun.mx: artesana, «Doña Elena Chan», Cueva La Esperanza
- turista@belaaktun.mx: visitante

Los datos de ejemplo son 4 talleres, piezas como el «Sombrero Brisa de Bécal» ($4,200 MXN) y experiencias de visita. Los talleres de muestra llevan la etiqueta «Ejemplo».

## Funciones por rol

### Visitante (turista)
- **Inicio** con portada, historia de Bécal y accesos a Explorar y Reservar.
- **Catálogo** de piezas con búsqueda y filtros.
- **Ficha de cada pieza:** galería, precio, artesano y botón «Agregar al carrito».
- **Mapa** de las cuevas y talleres.
- **Artesanos:** directorio y ficha de cada taller con historia, fotos, horario, contacto y experiencias.
- **Carrito de compras:**
  - Las piezas se agrupan por taller y se crea un pedido por taller.
  - Pide nombre, teléfono o WhatsApp e indicaciones.
  - **Sin envíos:** la pieza se recoge en el taller y se paga al recogerla.
- **Reservación de visitas:**
  - Horarios con cupo real por horario.
  - Días y horas en que el taller abre; los días cerrados aparecen deshabilitados.
  - Detalles de la experiencia y precio claro.
  - Validaciones: solo los visitantes reservan, y no se aceptan horarios llenos ni días cerrados.
- **Actividad:** «Visitas» y «Compras» por separado, con estado en vivo, historial y detalle de cada uno.
- **Centro de notificaciones** y avisos en la barra del teléfono, como «pedido aceptado», «listo para recoger» y recordatorios de recogida y de visita.
- **Contacto:** abre WhatsApp con un mensaje listo, llamada, correo y mapa.
- **Cuenta:** preferencias y tarjeta para conectarse al servidor de pruebas.

### Artesano (taller)
- **Panel:**
  - solicitudes por responder, confirmadas, próximas 7 días y completadas;
  - pedidos por aceptar e ingresos del mes;
  - alertas de inventario bajo;
  - guía «Completa tu taller» (pasos con progreso);
  - actividad reciente.
- **Pedidos de visitas:** aceptar, rechazar, marcar completada, marcar que no llegó (no-show) o cancelar.
- **Pedidos de piezas:** aceptar con fecha y hora de recogida, rechazar, pasar a en preparación, listo para recoger y entregado.
- **Catálogo:**
  - piezas y experiencias con fotos, precios y plantillas para llenarlo fácil;
  - inventario ajustable con aviso de existencias.
- **Ingresos** («Ventas e ingresos»):
  - lo vendido, la comisión de Bel·Aaktun y el ingreso neto por periodo;
  - lo que falta por confirmar y la comisión por pagar;
  - gráfica semanal, lo más vendido e historial de cada operación.
- **Perfil del taller:** portada, foto, historia, contacto, horario, formas de pago e idiomas.
- **Registro de nuevos talleres** con solicitud y pantalla de estado: pendiente, aprobado o rechazado.

### Administración
- **Resumen de la plataforma:**
  - solicitudes pendientes, talleres aprobados, usuarios y turistas;
  - ingreso de Bel·Aaktun del mes y comisión por confirmar.
- **Solicitudes:** verificar, aprobar o rechazar talleres.
- **Usuarios:** lista con filtro por rol.
- **Supervisión** de todos los pedidos y reservaciones.
- **Moderación del catálogo:** activar o desactivar piezas y experiencias, con aviso al taller.
- **Comisiones:**
  - tasas configurables (venta 10 %, visita 15 % por defecto, guardadas en puntos base);
  - resumen por periodo y rendimiento por mes;
  - detalle de cada operación;
  - registro de liquidaciones con referencia manual.
- **Bitácora / auditoría.**

## Reglas de negocio implementadas
- **Pedido de piezas**, con sus estados:
  - Pendiente de aceptación → Aceptado → En preparación → Listo para recoger → Entregado.
  - También puede terminar en Rechazado o Cancelado.
  - No se puede marcar «listo» sin fecha de recogida.
  - Las existencias se apartan al aceptar y se devuelven si se cancela.
- **Comisiones** (un registro por operación en el libro `ledger`):
  - Al aceptar queda **pendiente**. Al entregar la pieza o realizar la visita queda **ganada**. Si se rechaza, se cancela o no llega el visitante, queda **anulada**.
  - Nunca se cuenta como ingreso una comisión pendiente, rechazada o cancelada.
  - El visitante no paga comisión: paga el precio del taller. Del total, el taller se queda con 85–90 %.
- **Visitas:** la comisión se crea al aceptar y se gana al completar. Las reservas de ejemplo no generan comisión.
- **Pagos:**
  - La app **no cobra en línea**: todo se paga en el taller.
  - Los anticipos de visita son simulados y se indican como tales.
  - Nunca se muestra dinero como cobrado o transferido.
- **Permisos:** cada acción revisa rol y propiedad.
  - El taller solo mueve sus pedidos y reservaciones.
  - El turista solo ve los suyos.
  - Solo la administración modera, configura comisiones y registra liquidaciones.

## Calidad
- 104 pruebas automáticas que pasan. Cubren:
  - dominio, compras, comisiones, disponibilidad y administración;
  - modo local y dos teléfonos sincronizados;
  - pantallas, y 17 capturas de referencia (goldens).

## Modelo de negocio (Canvas)
- **Ingresos:**
  - 15 % por visita y 10 % por pieza;
  - «Taller destacado» a $199 MXN al mes;
  - patrocinios locales (desde el mes 9);
  - audioguías y paquetes (a futuro).
- **Plan financiero por fases.** Regla: nunca se gasta lo que no se ha ganado.
  - **Fase 1, piloto (meses 1–6): ≈ $222 al mes.**
    - Servidor: $0 con la capa gratuita de Supabase.
    - Dominio: $42. Traslados: $180 (3 integrantes, 2 visitas al mes, Bécal queda cerca).
    - Google Play: $25 USD (≈ $450), un solo pago.
    - El equipo participa como residencia profesional o servicio social, sin sueldo fijo.
    - Equilibrio: 4 sombreros finos de $800 o 2 mensualidades de taller al mes (sin IVA, antes de ISR).
  - **Fase 2, lanzamiento: ≈ $3,172 al mes.**
    - Supabase Pro: $25 USD ≈ $450.
    - Dominio $42, contador $1,000, marketing $1,500, traslados $180.
    - El equipo cobra un sueldo variable: el 70 % de la utilidad.
    - Equilibrio: 46 sombreros finos de $800 al mes.
  - **Fase 3, operación estable: ≈ $18,322 al mes.**
    - Fase 2, más un sueldo fijo de 3 × $5,000 (≈ 20 h/semana, por arriba de la parte proporcional del salario mínimo de 2026, $315.04 al día) y Apple $99 USD/año ≈ $150 al mes.
    - Solo se activa cuando el ingreso cubra este costo 3 meses seguidos.
    - Requiere sumar otras comunidades y alianzas; Bécal sola no alcanza.
  - Tipo de cambio supuesto: $18 por USD.
- **Lo que sabemos hoy:** en Bécal identificamos 9 artesanías y 5 paradores turísticos.
- **Demanda no medida:** no se ha hecho muestreo ni pruebas con clientes ni talleres. NO se deben usar proyecciones de volumen ni de ingresos mensuales.
- **Impuestos:** las comisiones (10 % y 15 %) ya incluyen IVA 16 %; se planea iniciar en RESICO (ISR 1–2.5 %), validado con contador. Constitución prevista: S.A.S. en línea ante la Secretaría de Economía.
- **Por qué 10 % y 15 %:** por debajo del 20 % que cobra Airbnb Experiencias a sus anfitriones; configurables.
- **Comisión por operación:**
  - sombrero intermedio: $40–$80;
  - sombrero fino: $80–$350;
  - experiencia completa propuesta: $27–$37.50 por persona.
  - Ejemplo: en un sombrero de $1,000, el artesano recibe $900 y Bel·Aaktun $100.
- **Cobro de la comisión hoy:** la app genera el estado de cuenta y registra cada liquidación; el taller liquida cada mes. Con pagos en línea se descontará automáticamente.
- **Beneficio para el artesano:** $0 de entrada; paga solo si vende; conserva el 90 % de cada pieza y el 85 % de cada visita; usa gratis la agenda, el inventario y el control de ingresos.
- **Segmentos:** turistas de la ruta Mérida–Campeche, compradores de jipi japa, talleres de Bécal, y escuelas, agencias y grupos.

## Mensualidad de los talleres (implementada)
- Cada taller paga $199 al mes (IVA incluido). Con la mensualidad al día aparece «Activo» y recibe pedidos y reservas; sin ella aparece «Fuera de servicio»: se ve, pero no vende ni recibe reservas.
- El taller registra la referencia de su pago desde su panel (Mensualidad). La administración lo confirma en «Mensualidades» y el taller queda activo 30 días; también puede rechazar el pago o ponerlo fuera de servicio. El taller recibe un aviso en cada caso.
- La app no cobra en línea: el pago es por transferencia o en efectivo.
- Hay dos talleres de muestra, marcados «Ejemplo»: uno activo y otro fuera de servicio. No reciben pedidos reales.

## Pendiente para producción (NO existe todavía)
1. Pagos en línea (Mercado Pago o Stripe).
2. Servidor en la nube para sincronizar datos y fotos fuera de la red local.
3. Notificaciones push entre teléfonos (Firebase Cloud Messaging).
4. Reemplazar los datos de ejemplo por talleres reales.
5. Recuperación de contraseña por correo.
6. Firma de release propia y publicación en Play Store; versión iOS.

---
**Instrucciones para ti:**
- Usa esta descripción como fuente de verdad.
- Si algo no aparece aquí, trátalo como no implementado y dilo.
- No presentes funciones simuladas (pagos, anticipos) como reales.
- Mi petición es: [ESCRIBE AQUÍ LO QUE NECESITAS]
