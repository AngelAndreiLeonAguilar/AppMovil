# Monetización de Bel-Aaktun

Documento de trabajo: qué puede generar ingresos, cuánto es realista, cómo se
implementa en esta app y qué reglas hay que respetar en México y en las tiendas.

---

## 1. Qué vende realmente la app

Hoy Bel-Aaktun es un **escaparate** de turismo artesanal en Bécal, Calkiní:
5 paradas georreferenciadas, 4 artesanos, 6 piezas y 3 experiencias. La reserva
solo captura datos y promete seguimiento por WhatsApp
([booking_screen.dart](../lib/features/booking/booking_screen.dart)), y las
experiencias ni siquiera tienen precio en el modelo
([models.dart](../lib/data/models.dart)).

Eso significa que **el producto que se monetiza no es la app: es la visita**.
La app aporta tres cosas que el taller solo no tiene:

1. **Descubrimiento**: el turista que ya está en Bécal o planeando Campeche.
2. **Confianza**: ficha del artesano, técnica, fotos, ubicación exacta.
3. **Agenda**: el taller deja de perder mensajes de WhatsApp y ausencias.

Cualquier modelo de ingresos tiene que cobrar por una de esas tres cosas, no por
"usar la app".

---

## 2. Los modelos posibles

| # | Modelo | Cómo cobra | Esfuerzo | Potencial | Riesgo principal |
|---|--------|-----------|----------|-----------|------------------|
| 1 | **Comisión por reserva** | 12–18 % del ticket de la experiencia | Medio | Alto (escala con el turismo) | Desintermediación: el artesano cierra por fuera |
| 2 | **Anticipo/depósito** | 20–30 % al reservar, resto en el taller | Medio | Medio (reduce no-shows y da flujo) | Fricción de pago para el turista |
| 3 | **Suscripción del artesano** | $149–$299 MXN/mes por "taller verificado + destacado" | Medio-alto | Recurrente y predecible | Artesanos con margen ajustado |
| 4 | **Venta de producto con envío** | 15–25 % de comisión o margen propio | Alto (logística, paquetería, devoluciones) | Alto en piezas de $800–$2,500 | Paquetería y mermas |
| 5 | **Contenido premium al visitante** | $49–$99 MXN por audio-guía / ruta / mapa offline | Medio | Bajo-medio (turista de paso) | Poca disposición a pagar en pueblo pequeño |
| 6 | **Patrocinio local** | $5,000–$30,000 MXN por temporada (municipio, hoteles, marcas) | Alto en venta B2B | Alto puntual | Depende de relaciones, no del producto |
| 7 | **Afiliación** (GetYourGuide, Booking, Civitatis) | 3–8 % del tour/hospedaje | Bajo | Bajo-medio | Comisión pequeña y competencia |
| 8 | **Propinas digitales** | 5 % de la propina al artesano | Bajo | Bajo | Volumen |

---

## 3. Recomendación: dos capas, no ocho modelos

**Capa 1 — Cobrar por la visita (mes 0–4).**
Comisión + anticipo en la misma transacción. Es lo que el turista ya entiende:
"reservo y pago mi lugar". El anticipo resuelve el problema real del taller
(ausencias), y la comisión se cobra sobre el total.

**Capa 2 — Cobrar a los artesanos por ser visibles (mes 4–9).**
Suscripción mensual con perfil verificado, prioridad en el mapa y catálogo
ilimitado. Es ingreso recurrente y no depende de la temporada.

**Capa 3 — Contenido y patrocinios (mes 9–18).**
Audio-guía de las cuevas, ruta de un día, paquetes para escuelas y patrocinio
del ayuntamiento o de hoteles de Campeche. Se justifica **después** de tener
usuarios y datos que demuestren audiencia.

> No empieces por la capa 5 (contenido premium). En un pueblo con visitantes
> estacionales la disposición a pagar por una audio-guía es baja y el costo de
> producirla (voz, edición, traducción) es alto.

---

## 4. Números honestos

Supuestos de temporada alta (diciembre–abril), 4 talleres activos:

| Concepto | Valor |
|---|---|
| Ticket promedio por persona | $350 MXN |
| Personas por reserva | 2.4 |
| Ticket por reserva | $840 MXN |
| Comisión 15 % | $126 MXN |
| Reservas por semana | 10 |
| **Ingreso por comisión** | **$5,040 MXN/mes** |
| Artesanos suscritos (8 × $199) | $1,592 MXN/mes |
| **Total temporada (6 meses)** | **≈ $39,800 MXN** |

Con eso queda claro el tamaño: **no es un negocio que reemplace un sueldo**; es
un complemento que crece si se suman talleres, productos con envío y patrocinio.
El valor estratégico es otro: **ser el canal** por el que Bécal recibe turistas.

### Costos fijos mínimos

| Concepto | Aproximado |
|---|---|
| Google Play (una vez) | $25 USD ≈ $500 MXN |
| Dominio .mx | $300–$600 MXN/año |
| Backend (Supabase/Firebase) | $0 → $400 MXN/mes |
| Pasarela de pago | 3.5 % + $4 MXN por transacción |
| Contador / CFDI | $800–$1,500 MXN/mes |

**Punto de equilibrio**: ~12 reservas al mes cubren costos variables; el hosting
gratuito cubre el resto mientras el volumen sea bajo.

---

## 5. Cómo se implementa en esta app

### Fase 0 — Poner precio a lo que ya existe (1–2 días)

`Experience` no tiene precio ni cupo. Agregar al modelo:

```dart
final int price;              // MXN por persona
final int depositPercent;     // 0-100, anticipo
final int maxParticipants;
```

Y en la pantalla de reserva mostrar el total en vivo:

```dart
final total = experience.price * people;
final deposit = (total * experience.depositPercent / 100).round();
```

### Fase 1 — Cobrar sin backend (1 semana)

La vía más rápida y sin comisiones de tienda:

1. Crear en Mercado Pago (o Stripe) un **link de pago por experiencia**.
2. Al confirmar la reserva, abrir el link con `url_launcher`
   (ya está en el proyecto, ver `lib/core/utils/maps_links.dart` como ejemplo).
3. El webhook de la pasarela manda la confirmación por correo/WhatsApp.
4. Conciliación manual al principio: perfectamente válido con 10 reservas/semana.

Esto monetiza **esta temporada** sin escribir backend.

### Fase 2 — Backend ligero (3–6 semanas)

Supabase (Postgres + Auth + Edge Functions) o Firebase:

- Tablas: `artisans`, `experiences`, `bookings`, `payments`, `subscriptions`.
- Roles: visitante, artesano, administrador.
- Confirmación automática de anticipo por webhook y correo.
- Panel del artesano: agenda, cancelaciones, no-shows.

### Fase 3 — Suscripción del artesano (2–3 semanas)

- Precio: $199 MXN/mes, $1,990/año (2 meses gratis).
- Beneficios: perfil verificado, prioridad en el mapa, catálogo ilimitado,
  estadísticas de visitas.
- Cobro: suscripciones de Mercado Pago o Stripe Billing.
- En la app: un widget `BelPaywall` reutilizable y banderas en `AppConfig`
  para activar/desactivar funciones.

### Fase 4 — Contenido premium (cuando haya demanda)

- **Audio-guía** de la Cueva La Esperanza: 6 pistas de 2 minutos, español e
  inglés, $79 MXN. Se reproduce con `just_audio` y se protege con un flag de
  compra en el backend.
- **Mapa offline**: `flutter_map_tile_caching` para guardar las teselas de Bécal.
  Funciona sin señal dentro de las cuevas; es un argumento de venta real.

### Eventos que hay que medir desde el día uno

`view_experience`, `start_booking`, `begin_checkout`, `purchase`,
`subscription_started`, `directions_opened`. Firebase Analytics o PostHog.

---

## 6. Reglas de las tiendas (esto evita un rechazo)

- **Servicios del mundo real** (tours, talleres, hospedaje) **pueden** cobrarse
  con pasarela externa (Mercado Pago/Stripe) tanto en Google Play como en
  App Store; no es obligatorio usar la facturación de la tienda.
- **Bienes digitales consumidos dentro de la app** (audio-guía, mapa offline,
  suscripción al contenido digital) **sí** deben usar Google Play Billing /
  In-App Purchase de Apple (15–30 % de comisión).
- Si vendes productos físicos (sombreros), es comercio normal: pasarela externa
  y envío; la tienda no cobra comisión.
- La suscripción al **artesano** es un servicio profesional B2B que normalmente
  se cobra por web; aun así, revisar la política vigente antes de publicar.

---

## 7. Legal y fiscal en México

- **CFDI por la comisión**: la app factura su comisión al artesano, no el total
  de la visita (salvo que actúes como agencia de viajes, que cambia el régimen).
- **Aviso de privacidad** (LFPDPPP) para nombre, teléfono y datos de pago;
  consentimiento explícito al reservar.
- **Términos y condiciones**: política de cancelación, no-show, reembolsos,
  responsabilidad del taller y del visitante, límite de participantes.
- **IVA**: los servicios turísticos causan 16 %; confirma con tu contador si la
  comisión va con IVA y si aplica retención a personas físicas.
- **Contrato de intermediación** con cada taller: quién cobra, cuándo se le
  paga, qué pasa si cancela y cómo se maneja la comisión.

---

## 8. Métricas y experimentos

| Métrica | Meta inicial |
|---|---|
| Visitas a ficha de experiencia → reserva | 3–8 % |
| No-show | < 10 % |
| Take rate (comisión real) | 12–18 % |
| Artesanos activos con reservas/mes | 4 de 8 |
| MRR de suscripciones | $1,500 MXN al mes 9 |
| NPS del visitante | > 50 |

Experimentos baratos, en orden:

1. Anticipo del 30 % vs pago completo anticipado.
2. Precio $250 vs $350 por persona (elasticidad real).
3. Reserva por WhatsApp con link de pago vs formulario dentro de la app.
4. Perfil "verificado" pagado vs gratuito: ¿sube el número de reservas del taller?

---

## 9. Plan de 90 días

| Semanas | Entregable | Ingreso que habilita |
|---|---|---|
| 1–2 | Precios y cupos reales; anticipo con link de pago; medición básica | Comisión + anticipo |
| 3–6 | Backend de reservas, confirmaciones automáticas, panel del artesano | Comisión escalable |
| 7–10 | Perfil verificado y cobro de suscripción | MRR |
| 11–13 | Piloto de audio-guía en una cueva y medición de disposición a pagar | Contenido premium |

---

## 10. Riesgos y cómo mitigarlos

| Riesgo | Mitigación |
|---|---|
| El artesano cierra por fuera y no paga comisión | Darle agenda, recordatorios, reputación y difusión; cobrar el anticipo en la app |
| Temporada baja (mayo–noviembre) | Paquetes escolares, suscripción anual con descuento, patrocinio municipal |
| Cobranza a artesanos | Suscripción con cobro automático y periodo de gracia de 7 días |
| Turista desconfía de pagar en línea | Anticipo pequeño (30 %), sello de taller verificado, política clara de reembolso |
| Contenido premium sin demanda | Probarlo con una sola cueva y 20 usuarios antes de producir más |

---

## 11. Lo primero que yo implementaría (si tienes que elegir uno)

**Anticipo del 30 % con link de pago por experiencia.** Cambia tres archivos,
no requiere backend, y resuelve el problema que más dinero cuesta hoy: las
reservas que nunca llegan. La comisión llega sola cuando el flujo ya cobra.
