-- ============================================================================
-- Bel-Aaktun · Esquema compartido (Flask + app móvil)
-- PostgreSQL 14+
--
-- Un solo backend (Flask + PostgreSQL) para la web y la app. La app consume
-- una API REST; la web puede seguir renderizando con Flask usando las mismas
-- tablas. La autorización se aplica en la capa API (JWT + rol + propiedad),
-- porque los clientes nunca hablan directo con la base de datos.
--
-- Compatibilidad: si más adelante se migra a Supabase, este mismo esquema es
-- la base; solo se añaden políticas RLS y se expone PostgREST.
--
-- Convenciones:
--   * dinero en centavos (integer), nunca float
--   * fechas en timestamptz
--   * ids uuid generados por la base
--   * correo normalizado en minúsculas (índice único)
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. Usuarios y sesiones
-- ---------------------------------------------------------------------------

create table if not exists users (
  id                uuid primary key default gen_random_uuid(),
  email             text not null,
  password_hash     text not null,                 -- argon2id o bcrypt (nunca texto plano)
  full_name         text not null,
  phone             text,
  role              text not null default 'tourist'
                    check (role in ('tourist', 'artisan', 'admin')),
  status            text not null default 'active'
                    check (status in ('active', 'suspended', 'deleted')),
  email_verified_at timestamptz,
  last_login_at     timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create unique index if not exists users_email_lower_key
  on users (lower(email));

-- El rol nunca se cambia desde una petición normal: solo el procedimiento
-- administrativo (`admin_change_role`) o el script de bootstrap lo modifican.

create table if not exists refresh_tokens (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references users(id) on delete cascade,
  token_hash   text not null unique,               -- hash del token, no el token
  user_agent   text,
  ip           inet,
  expires_at   timestamptz not null,
  revoked_at   timestamptz,
  created_at   timestamptz not null default now()
);

create index if not exists refresh_tokens_user_idx
  on refresh_tokens (user_id, expires_at desc);

-- Intentos de acceso para limitar fuerza bruta.
create table if not exists login_attempts (
  id           bigserial primary key,
  email        text,
  ip           inet,
  success      boolean not null,
  attempted_at timestamptz not null default now()
);

create index if not exists login_attempts_email_idx
  on login_attempts (lower(email), attempted_at desc);

-- ---------------------------------------------------------------------------
-- 2. Solicitudes y perfiles de taller
-- ---------------------------------------------------------------------------

-- La solicitud conserva exactamente lo que envió la persona (snapshot).
create table if not exists artisan_applications (
  id               uuid primary key default gen_random_uuid(),
  applicant_id     uuid not null references users(id) on delete cascade,
  workshop_name    text not null,
  description      text,
  location         text,
  address          text,
  latitude         numeric(9, 6),
  longitude        numeric(9, 6),
  contact_phone    text,
  status           text not null default 'pending'
                   check (status in ('pending', 'in_review', 'approved',
                                     'rejected', 'suspended', 'withdrawn')),
  submitted_at     timestamptz not null default now(),
  reviewed_by      uuid references users(id),
  reviewed_at      timestamptz,
  rejection_reason text,
  review_notes     text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),

  -- Toda solicitud revisada debe tener revisor y fecha.
  constraint artisan_applications_reviewed_coherent
    check (status in ('pending', 'in_review', 'withdrawn')
           or (reviewed_by is not null and reviewed_at is not null)),
  -- Rechazo siempre con motivo.
  constraint artisan_applications_rejected_reason
    check (status <> 'rejected' or rejection_reason is not null),
  -- Nadie revisa su propia solicitud.
  constraint artisan_applications_no_self_review
    check (reviewed_by is null or reviewed_by <> applicant_id)
);

-- Una sola solicitud abierta por persona.
create unique index if not exists artisan_applications_one_open
  on artisan_applications (applicant_id)
  where status in ('pending', 'in_review');

create index if not exists artisan_applications_status_idx
  on artisan_applications (status, submitted_at desc);

-- Taller ya aprobado y editable. Nace al aprobar una solicitud.
create table if not exists artisan_profiles (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null unique references users(id) on delete cascade,
  application_id  uuid references artisan_applications(id),
  workshop_name   text not null,
  description     text,
  location        text,
  address         text,
  latitude        numeric(9, 6),
  longitude       numeric(9, 6),
  contact_phone   text,
  status          text not null default 'active'
                  check (status in ('active', 'suspended')),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Fotos del taller y de sus piezas (archivos en disco/S3/Storage).
create table if not exists artisan_media (
  id             uuid primary key default gen_random_uuid(),
  artisan_id     uuid references artisan_profiles(id) on delete cascade,
  application_id uuid references artisan_applications(id) on delete cascade,
  kind           text not null check (kind in ('workshop', 'product')),
  storage_key    text not null,
  mime_type      text,
  size_bytes     integer check (size_bytes is null or size_bytes > 0),
  created_at     timestamptz not null default now(),

  -- La foto pertenece a un taller aprobado o a una solicitud en trámite.
  constraint artisan_media_one_parent
    check ((artisan_id is null) <> (application_id is null))
);

create index if not exists artisan_media_artisan_idx
  on artisan_media (artisan_id);

create index if not exists artisan_media_application_idx
  on artisan_media (application_id);

-- ---------------------------------------------------------------------------
-- 3. Catálogo
-- ---------------------------------------------------------------------------

create table if not exists products (
  id           uuid primary key default gen_random_uuid(),
  artisan_id   uuid not null references artisan_profiles(id) on delete cascade,
  name         text not null,
  category     text not null,
  description  text,
  technique    text,
  price_cents  integer check (price_cents is null or price_cents >= 0),
  image_key    text,
  made_to_order boolean not null default false,
  active       boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists products_artisan_idx
  on products (artisan_id, active);

create table if not exists services (
  id               uuid primary key default gen_random_uuid(),
  artisan_id       uuid not null references artisan_profiles(id) on delete cascade,
  title            text not null,
  description      text,
  duration_minutes integer not null check (duration_minutes between 15 and 720),
  price_cents      integer not null check (price_cents >= 0),
  deposit_percent  integer not null default 30
                   check (deposit_percent between 0 and 100),
  capacity         integer not null default 12 check (capacity >= 1),
  active           boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index if not exists services_artisan_idx
  on services (artisan_id, active);

-- ---------------------------------------------------------------------------
-- 4. Reservaciones
-- ---------------------------------------------------------------------------

create table if not exists bookings (
  id             uuid primary key default gen_random_uuid(),
  folio          text not null unique,
  tourist_id     uuid not null references users(id),
  artisan_id     uuid not null references artisan_profiles(id),
  service_id     uuid not null references services(id),
  visit_date     date not null,
  time_slot      time not null,
  people         integer not null check (people between 1 and 50),
  status         text not null default 'requested'
                 check (status in ('requested', 'accepted', 'rejected',
                                   'completed', 'cancelled_by_tourist',
                                   'cancelled_by_artisan', 'no_show')),
  total_cents    integer not null check (total_cents >= 0),
  deposit_cents  integer not null default 0 check (deposit_cents >= 0),
  deposit_status text not null default 'none'
                 check (deposit_status in ('none', 'pending', 'paid',
                                           'refunded', 'partially_refunded',
                                           'forfeited')),
  refund_cents   integer not null default 0 check (refund_cents >= 0),
  notes          text,
  confirmed_at   timestamptz,
  completed_at   timestamptz,
  cancelled_at   timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  constraint bookings_deposit_not_greater_total
    check (deposit_cents <= total_cents),
  constraint bookings_refund_not_greater_deposit
    check (refund_cents <= deposit_cents)
);

create index if not exists bookings_tourist_idx
  on bookings (tourist_id, visit_date desc);

create index if not exists bookings_artisan_idx
  on bookings (artisan_id, visit_date desc);

create index if not exists bookings_pending_idx
  on bookings (artisan_id, status) where status = 'requested';

-- Historial inmutable de cada cambio de estado.
create table if not exists booking_events (
  id         bigserial primary key,
  booking_id uuid not null references bookings(id) on delete cascade,
  status     text not null,
  actor_id   uuid references users(id),
  note       text,
  created_at timestamptz not null default now()
);

create index if not exists booking_events_booking_idx
  on booking_events (booking_id, created_at);

-- ---------------------------------------------------------------------------
-- 5. Notificaciones y auditoría
-- ---------------------------------------------------------------------------

create table if not exists notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users(id) on delete cascade,
  type       text not null,
  title      text not null,
  body       text,
  booking_id uuid references bookings(id) on delete set null,
  read_at    timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_idx
  on notifications (user_id, created_at desc);

-- Bitácora de acciones administrativas y cambios sensibles.
create table if not exists audit_logs (
  id         bigserial primary key,
  actor_id   uuid references users(id),
  action     text not null,                 -- artisan_approved, user_suspended, ...
  entity     text not null,                 -- artisan_applications, users, ...
  entity_id  uuid,
  metadata   jsonb not null default '{}'::jsonb,
  ip         inet,
  created_at timestamptz not null default now()
);

create index if not exists audit_logs_entity_idx
  on audit_logs (entity, entity_id, created_at desc);

create index if not exists audit_logs_actor_idx
  on audit_logs (actor_id, created_at desc);

-- ---------------------------------------------------------------------------
-- 6. Utilidades
-- ---------------------------------------------------------------------------

create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

do $$
declare
  t text;
begin
  foreach t in array array['users', 'artisan_applications', 'artisan_profiles',
                           'products', 'services', 'bookings']
  loop
    execute format(
      'drop trigger if exists %I on %I; create trigger %I before update on %I
       for each row execute function set_updated_at();',
      t || '_updated_at', t, t || '_updated_at', t
    );
  end loop;
end $$;

-- Registro de auditoría desde la API (misma transacción).
create or replace function log_audit(
  p_actor uuid,
  p_action text,
  p_entity text,
  p_entity_id uuid,
  p_metadata jsonb default '{}'::jsonb,
  p_ip inet default null
) returns void
language sql as $$
  insert into audit_logs (actor_id, action, entity, entity_id, metadata, ip)
  values (p_actor, p_action, p_entity, p_entity_id, coalesce(p_metadata, '{}'::jsonb), p_ip);
$$;

commit;

-- ============================================================================
-- Notas de integración
-- ============================================================================
-- 1. Flask: mapear estas tablas con SQLAlchemy o usar SQL directo. El esquema
--    es compatible con Flask-Migrate/Alembic como migración inicial.
-- 2. Cada endpoint debe verificar: sesión válida, rol en la base (no en el
--    token si hay cambios de rol), estado del taller y propiedad del recurso.
-- 3. Cambios de rol y aprobaciones pasan por funciones de servicio en Flask
--    que escriben audit_logs en la misma transacción.
-- 4. Fotos: la API guarda el archivo (disco/S3) y registra storage_key; nunca
--    se expone el sistema de archivos directamente.
-- 5. Si más adelante se usa Supabase: habilitar RLS en todas las tablas y
--    escribir políticas equivalentes a las reglas descritas en
--    docs/plan-autenticacion.md.
-- ============================================================================
