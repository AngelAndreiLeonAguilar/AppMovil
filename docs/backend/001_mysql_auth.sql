-- ============================================================================
-- Bel-Aaktun · Migración de autenticación y roles
-- Motor real del proyecto: MySQL 8 (docker-compose usa mysql:8.0)
-- Archivo: docs/backend/001_mysql_auth.sql
--
-- Es una migración ADITIVA: no borra tablas ni columnas existentes.
-- Crea las estructuras de autenticación, verificación de talleres y auditoría.
--
-- ANTES DE EJECUTAR:
--   1. Respaldo:  mysqldump -u becal_user -p becal_db > respaldo.sql
--   2. Revisa el tipo de `usuarios.id` (se asume INT). Si es BIGINT,
--      cambia INT por BIGINT en las claves foráneas de este archivo.
--   3. Ejecuta:  mysql -u becal_user -p becal_db < 001_mysql_auth.sql
--
-- Nota: `schema.sql` del repositorio está desactualizado respecto a `app.py`
-- (app.py consulta columnas que no existen en schema.sql). Por eso esta
-- migración usa información_schema para añadir columnas solo si faltan, y no
-- asume la forma exacta de `usuarios`.
-- ============================================================================

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
-- 0. Utilidades: añadir columnas/índices solo si no existen
-- ---------------------------------------------------------------------------

DROP PROCEDURE IF EXISTS bel_add_column;

DELIMITER $$
CREATE PROCEDURE bel_add_column(
  IN p_table VARCHAR(64),
  IN p_column VARCHAR(64),
  IN p_definition TEXT
)
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = p_table
      AND column_name = p_column
  ) THEN
    SET @ddl = CONCAT('ALTER TABLE `', p_table, '` ADD COLUMN ', p_definition);
    PREPARE stmt FROM @ddl;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END IF;
END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS bel_add_index;

DELIMITER $$
CREATE PROCEDURE bel_add_index(
  IN p_table VARCHAR(64),
  IN p_index VARCHAR(64),
  IN p_definition TEXT
)
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.statistics
    WHERE table_schema = DATABASE()
      AND table_name = p_table
      AND index_name = p_index
  ) THEN
    SET @ddl = CONCAT('ALTER TABLE `', p_table, '` ADD ', p_definition);
    PREPARE stmt FROM @ddl;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------------
-- 1. Tabla de usuarios (si no existe) y columnas nuevas
-- ---------------------------------------------------------------------------
-- Se asume que ya existe `usuarios` (app.py hace SELECT ... FROM usuarios).
-- Si no existe, se crea con la estructura mínima compatible.

CREATE TABLE IF NOT EXISTS usuarios (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  nombre            VARCHAR(150) NOT NULL,
  email             VARCHAR(190) NOT NULL,
  password_hash     VARCHAR(255) NOT NULL,
  taller_id         INT NULL,
  creado_en         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_usuarios_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CALL bel_add_column('usuarios', 'telefono',
  'telefono VARCHAR(30) NULL');
CALL bel_add_column('usuarios', 'rol',
  "rol ENUM('turista','artesano','admin') NOT NULL DEFAULT 'turista'");
CALL bel_add_column('usuarios', 'estado',
  "estado ENUM('activo','suspendido','eliminado') NOT NULL DEFAULT 'activo'");
CALL bel_add_column('usuarios', 'email_verificado_en',
  'email_verificado_en DATETIME NULL');
CALL bel_add_column('usuarios', 'ultimo_acceso_en',
  'ultimo_acceso_en DATETIME NULL');
CALL bel_add_column('usuarios', 'creado_en',
  'creado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP');
CALL bel_add_column('usuarios', 'actualizado_en',
  'actualizado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');

CALL bel_add_index('usuarios', 'uq_usuarios_email',
  'UNIQUE KEY uq_usuarios_email (email)');
CALL bel_add_index('usuarios', 'idx_usuarios_rol_estado',
  'INDEX idx_usuarios_rol_estado (rol, estado)');

-- Los administradores no se crean desde la app: este UPDATE se ejecuta a mano
-- una sola vez, con el correo del responsable.
-- UPDATE usuarios SET rol = 'admin' WHERE email = 'ADMIN@EJEMPLO.MX';

-- ---------------------------------------------------------------------------
-- 2. Intentos de acceso (límite de fuerza bruta)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS intentos_acceso (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  email         VARCHAR(190) NULL,
  ip            VARCHAR(45) NULL,
  exito         TINYINT(1) NOT NULL DEFAULT 0,
  intentado_en  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_intentos_email (email, intentado_en),
  INDEX idx_intentos_ip (ip, intentado_en)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 3. Tokens revocados (logout y rotación de refresh)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS tokens_revocados (
  jti           VARCHAR(64) PRIMARY KEY,
  usuario_id    INT NOT NULL,
  expira_en     DATETIME NOT NULL,
  revocado_en   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  motivo        VARCHAR(120) NULL,
  CONSTRAINT fk_tokens_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios(id) ON DELETE CASCADE,
  INDEX idx_tokens_expira (expira_en)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 4. Solicitudes de taller y verificación
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS solicitudes_artesano (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id        INT NOT NULL,
  nombre_taller     VARCHAR(150) NOT NULL,
  descripcion       TEXT NULL,
  ubicacion         VARCHAR(150) NULL,
  direccion         VARCHAR(255) NULL,
  latitud           DECIMAL(10, 8) NULL,
  longitud          DECIMAL(11, 8) NULL,
  telefono_contacto VARCHAR(30) NULL,
  estado            ENUM('pendiente','en_revision','aprobada','rechazada',
                         'suspendida','retirada')
                    NOT NULL DEFAULT 'pendiente',
  revisor_id        INT NULL,
  revisado_en       DATETIME NULL,
  motivo_rechazo    VARCHAR(500) NULL,
  notas_revision    TEXT NULL,
  creado_en         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                    ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_solicitud_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios(id) ON DELETE CASCADE,
  CONSTRAINT fk_solicitud_revisor FOREIGN KEY (revisor_id)
    REFERENCES usuarios(id) ON DELETE SET NULL,

  -- Toda solicitud revisada exige revisor y fecha
  CONSTRAINT chk_solicitud_revisada CHECK (
    estado IN ('pendiente','en_revision','retirada')
    OR (revisor_id IS NOT NULL AND revisado_en IS NOT NULL)
  ),
  -- Rechazo siempre con motivo
  CONSTRAINT chk_solicitud_rechazo CHECK (
    estado <> 'rechazada' OR motivo_rechazo IS NOT NULL
  ),
  -- Nadie revisa su propia solicitud
  CONSTRAINT chk_solicitud_sin_autoaprobacion CHECK (
    revisor_id IS NULL OR revisor_id <> usuario_id
  ),

  INDEX idx_solicitudes_estado (estado, creado_en),
  INDEX idx_solicitudes_usuario (usuario_id, creado_en)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Una sola solicitud abierta por persona.
-- MySQL no tiene índices parciales: se usa una columna generada.
CALL bel_add_column('solicitudes_artesano', 'solicitud_abierta',
  "solicitud_abierta TINYINT
   GENERATED ALWAYS AS (
     CASE WHEN estado IN ('pendiente','en_revision') THEN 1 ELSE NULL END
   ) STORED");
CALL bel_add_index('solicitudes_artesano', 'uq_solicitud_abierta',
  'UNIQUE KEY uq_solicitud_abierta (usuario_id, solicitud_abierta)');

-- ---------------------------------------------------------------------------
-- 5. Fotos de la solicitud (taller y piezas)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS medios_solicitud (
  id             INT AUTO_INCREMENT PRIMARY KEY,
  solicitud_id   INT NOT NULL,
  tipo           ENUM('taller','producto') NOT NULL DEFAULT 'taller',
  ruta_archivo   VARCHAR(255) NOT NULL,
  mime_type      VARCHAR(100) NULL,
  tamano_bytes   INT NULL,
  creado_en      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_medio_solicitud FOREIGN KEY (solicitud_id)
    REFERENCES solicitudes_artesano(id) ON DELETE CASCADE,
  INDEX idx_medios_solicitud (solicitud_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 6. Notificaciones internas
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS notificaciones (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  usuario_id  INT NOT NULL,
  tipo        VARCHAR(40) NOT NULL,
  titulo      VARCHAR(150) NOT NULL,
  cuerpo      TEXT NULL,
  reserva_id  INT NULL,
  leido_en    DATETIME NULL,
  creado_en   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_notificacion_usuario FOREIGN KEY (usuario_id)
    REFERENCES usuarios(id) ON DELETE CASCADE,
  INDEX idx_notificaciones_usuario (usuario_id, creado_en),
  INDEX idx_notificaciones_no_leidas (usuario_id, leido_en)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 7. Auditoría administrativa
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS registro_auditoria (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  actor_id    INT NULL,
  accion      VARCHAR(80) NOT NULL,      -- solicitud_aprobada, usuario_suspendido...
  entidad     VARCHAR(80) NOT NULL,      -- solicitudes_artesano, usuarios...
  entidad_id  INT NULL,
  detalle     JSON NULL,
  ip          VARCHAR(45) NULL,
  creado_en   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_auditoria_actor FOREIGN KEY (actor_id)
    REFERENCES usuarios(id) ON DELETE SET NULL,
  INDEX idx_auditoria_entidad (entidad, entidad_id, creado_en),
  INDEX idx_auditoria_actor (actor_id, creado_en)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- 8. Limpieza de utilidades
-- ---------------------------------------------------------------------------

DROP PROCEDURE IF EXISTS bel_add_column;
DROP PROCEDURE IF EXISTS bel_add_index;

-- ============================================================================
-- Verificación rápida (ejecutar después)
-- ============================================================================
-- SHOW TABLES LIKE '%usuarios%';
-- DESCRIBE usuarios;
-- DESCRIBE solicitudes_artesano;
-- SELECT COUNT(*) FROM registro_auditoria;
--
-- Rollback (solo si algo salió mal en un entorno de prueba):
-- DROP TABLE IF EXISTS registro_auditoria;
-- DROP TABLE IF EXISTS notificaciones;
-- DROP TABLE IF EXISTS medios_solicitud;
-- DROP TABLE IF EXISTS solicitudes_artesano;
-- DROP TABLE IF EXISTS tokens_revocados;
-- DROP TABLE IF EXISTS intentos_acceso;
-- ALTER TABLE usuarios
--   DROP COLUMN rol, DROP COLUMN estado, DROP COLUMN telefono,
--   DROP COLUMN email_verificado_en, DROP COLUMN ultimo_acceso_en;
-- ============================================================================
