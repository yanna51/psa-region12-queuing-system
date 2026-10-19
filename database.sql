-- =====================================================================
-- PSAQ — Pre-Scheduled Appointment Queuing System
-- database.sql — Phase 2
--
-- Philippine Statistics Authority, PhilSys Registration Center,
-- City of Koronadal, South Cotabato.
-- Academic capstone prototype — demo data only, not connected to any
-- PSA/PhilSys production system.
--
-- HOW TO IMPORT (phpMyAdmin):
--   1. Start Apache + MySQL in the XAMPP Control Panel.
--   2. Open http://localhost/phpmyadmin/
--   3. Click "Import" (do NOT pre-create psaq_db — this file does it).
--   4. Choose this file, format = SQL, click "Go".
--   5. Confirm 20 tables now exist under psaq_db, with demo rows in
--      roles, users, queue_types, service_counters, capacity_settings,
--      queue_settings, and business_schedule.
--
-- ALREADY HAVE A PSAQ DATABASE FROM AN EARLIER VERSION? Do not re-import
-- this whole file (it starts with DROP TABLE on every table — that
-- would wipe your existing clients/appointments/queue data). Instead,
-- run only the "EXISTING-INSTALL MIGRATION" block at the very end of
-- this file (search for that heading) — it adds the HOLD status and
-- the new business_schedule table without touching any data you
-- already have.
--
-- Engine: InnoDB throughout, so foreign keys are actually enforced.
-- Charset: utf8mb4 / utf8mb4_unicode_ci throughout.
-- =====================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- 1. CREATE DATABASE
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS psaq_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE psaq_db;

-- =====================================================================
-- 2–4. CREATE TABLES, RELATIONSHIPS, INDEXES
-- Created in dependency order so every FK reference already exists.
-- =====================================================================

-- ---------------------------------------------------------------------
-- roles
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS roles;
CREATE TABLE roles (
    role_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    role_name   VARCHAR(30)  NOT NULL,
    description VARCHAR(120) DEFAULT NULL,
    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_roles_role_name (role_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- users  (admin + staff accounts only — clients never log in, §9)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS users;
CREATE TABLE users (
    user_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    role_id        INT UNSIGNED NOT NULL,
    full_name      VARCHAR(120) NOT NULL,
    email          VARCHAR(120) NOT NULL,
    password_hash  VARCHAR(255) NOT NULL,
    status         ENUM('ACTIVE','INACTIVE') NOT NULL DEFAULT 'ACTIVE',
    -- Phase 20 (security pass): brute-force lockout on admin/staff login.
    -- See includes/auth.php's check_login_lockout()/record_login_failure()/
    -- record_login_success() — nothing before Phase 20 read or wrote these.
    failed_login_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
    locked_until        DATETIME DEFAULT NULL,
    last_login_at  DATETIME     DEFAULT NULL,
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_users_email (email),
    KEY idx_users_role_id (role_id),
    CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES roles (role_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- clients  (no account — identified per booking by info + email, §9)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS clients;
CREATE TABLE clients (
    client_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    first_name     VARCHAR(60)  NOT NULL,
    middle_name    VARCHAR(60)  DEFAULT NULL,
    last_name      VARCHAR(60)  NOT NULL,
    suffix         VARCHAR(10)  DEFAULT NULL,
    date_of_birth  DATE         NOT NULL,
    sex            ENUM('MALE','FEMALE') NOT NULL,
    mobile_number  VARCHAR(15)  NOT NULL,
    email          VARCHAR(120) NOT NULL,
    address        VARCHAR(255) NOT NULL,
    created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- Indexed for the §29 duplicate check (name + DOB + mobile).
    KEY idx_clients_name_dob (last_name, first_name, date_of_birth),
    KEY idx_clients_mobile (mobile_number),
    KEY idx_clients_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- queue_types  (R / P / U / C, §10)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS queue_types;
CREATE TABLE queue_types (
    queue_type_id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code                      CHAR(1)      NOT NULL,
    name                      VARCHAR(60)  NOT NULL,
    default_duration_minutes  SMALLINT UNSIGNED NOT NULL DEFAULT 15,
    is_active                 TINYINT(1)   NOT NULL DEFAULT 1,
    UNIQUE KEY uq_queue_types_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- service_counters  (§21)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS service_counters;
CREATE TABLE service_counters (
    counter_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    counter_name  VARCHAR(40) NOT NULL,
    status        ENUM('ACTIVE','INACTIVE') NOT NULL DEFAULT 'ACTIVE',
    created_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_counters_name (counter_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- time_slots  (§22–23 — one row per bookable date/time/queue-type slot)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS time_slots;
CREATE TABLE time_slots (
    time_slot_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    slot_date      DATE   NOT NULL,
    start_time     TIME   NOT NULL,
    end_time       TIME   NOT NULL,
    queue_type_id  INT UNSIGNED DEFAULT NULL, -- NULL = shared across all types
    max_capacity   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    booked_count   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_time_slots_slot (slot_date, start_time, queue_type_id),
    KEY idx_time_slots_date (slot_date),
    CONSTRAINT fk_time_slots_queue_type FOREIGN KEY (queue_type_id)
        REFERENCES queue_types (queue_type_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- capacity_settings  (§22 — admin-configurable daily/hourly caps)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS capacity_settings;
CREATE TABLE capacity_settings (
    capacity_setting_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    queue_type_id        INT UNSIGNED DEFAULT NULL,
    setting_type         ENUM('DAILY','HOURLY') NOT NULL,
    start_time            TIME DEFAULT NULL, -- NULL when setting_type = DAILY
    end_time               TIME DEFAULT NULL,
    max_capacity           SMALLINT UNSIGNED NOT NULL,
    is_active               TINYINT(1) NOT NULL DEFAULT 1,
    created_at              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY idx_capacity_queue_type (queue_type_id),
    CONSTRAINT fk_capacity_queue_type FOREIGN KEY (queue_type_id)
        REFERENCES queue_types (queue_type_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- appointments
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS appointments;
CREATE TABLE appointments (
    appointment_id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    appointment_code        VARCHAR(20)  NOT NULL, -- e.g. PSAQ-2026-000001
    client_id               INT UNSIGNED NOT NULL,
    queue_type_id            INT UNSIGNED NOT NULL,
    time_slot_id              INT UNSIGNED DEFAULT NULL,
    appointment_date          DATE NOT NULL,
    appointment_time          TIME NOT NULL,
    status                     ENUM('PENDING_OTP','CONFIRMED','CANCELLED','NO_SHOW','COMPLETED')
                                 NOT NULL DEFAULT 'PENDING_OTP',
    is_possible_duplicate      TINYINT(1) NOT NULL DEFAULT 0,       -- §29
    duplicate_reviewed_by      INT UNSIGNED DEFAULT NULL,
    duplicate_remarks          VARCHAR(255) DEFAULT NULL,
    created_at                 TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                 TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_appointments_code (appointment_code),
    KEY idx_appointments_client (client_id),
    KEY idx_appointments_queue_type (queue_type_id),
    KEY idx_appointments_time_slot (time_slot_id),
    KEY idx_appointments_date_status (appointment_date, status),
    CONSTRAINT fk_appointments_client FOREIGN KEY (client_id)
        REFERENCES clients (client_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_appointments_queue_type FOREIGN KEY (queue_type_id)
        REFERENCES queue_types (queue_type_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_appointments_time_slot FOREIGN KEY (time_slot_id)
        REFERENCES time_slots (time_slot_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_appointments_reviewer FOREIGN KEY (duplicate_reviewed_by)
        REFERENCES users (user_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- otp_verifications  (§12 — otp_hash is a password_hash() of the code,
-- the plaintext OTP is never written to the database)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS otp_verifications;
CREATE TABLE otp_verifications (
    otp_id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    appointment_id  INT UNSIGNED NOT NULL,
    otp_hash        VARCHAR(255) NOT NULL,
    attempts        TINYINT UNSIGNED NOT NULL DEFAULT 0,
    max_attempts    TINYINT UNSIGNED NOT NULL DEFAULT 5,
    expires_at      DATETIME NOT NULL,
    is_used         TINYINT(1) NOT NULL DEFAULT 0,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_otp_appointment (appointment_id),
    CONSTRAINT fk_otp_appointment FOREIGN KEY (appointment_id)
        REFERENCES appointments (appointment_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- qr_tokens  (§13 — token_hash only; the raw token lives in the QR
-- image and briefly in memory, never in the database)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS qr_tokens;
CREATE TABLE qr_tokens (
    qr_token_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    appointment_id  INT UNSIGNED NOT NULL,
    token_hash      CHAR(64) NOT NULL, -- sha256() hex digest
    issued_at       DATETIME NOT NULL,
    checked_in_at   DATETIME DEFAULT NULL,
    UNIQUE KEY uq_qr_appointment (appointment_id),
    CONSTRAINT fk_qr_appointment FOREIGN KEY (appointment_id)
        REFERENCES appointments (appointment_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- priority_requests  (§15)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS priority_requests;
CREATE TABLE priority_requests (
    priority_request_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    appointment_id        INT UNSIGNED NOT NULL,
    category               ENUM('SENIOR','PWD','PREGNANT') NOT NULL,
    status                  ENUM('PENDING','VERIFIED','REJECTED') NOT NULL DEFAULT 'PENDING',
    reviewed_by             INT UNSIGNED DEFAULT NULL,
    reviewed_at             DATETIME DEFAULT NULL,
    remarks                 VARCHAR(255) DEFAULT NULL,
    created_at              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_priority_appointment (appointment_id),
    KEY idx_priority_status (status),
    CONSTRAINT fk_priority_appointment FOREIGN KEY (appointment_id)
        REFERENCES appointments (appointment_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_priority_reviewer FOREIGN KEY (reviewed_by)
        REFERENCES users (user_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- priority_documents  (§34 — stored_filename is random, never the
-- client's original filename; served only through an authenticated
-- script, never linked to directly — see uploads/priority/.htaccess)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS priority_documents;
CREATE TABLE priority_documents (
    priority_document_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    priority_request_id    INT UNSIGNED NOT NULL,
    stored_filename          VARCHAR(255) NOT NULL,
    original_filename        VARCHAR(255) NOT NULL,
    mime_type                 VARCHAR(100) NOT NULL,
    file_size                  INT UNSIGNED NOT NULL,
    uploaded_at                 TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_priority_docs_request (priority_request_id),
    CONSTRAINT fk_priority_docs_request FOREIGN KEY (priority_request_id)
        REFERENCES priority_requests (priority_request_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- counter_assignments  (§21 — Counter × Queue Type × Staff, per day)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS counter_assignments;
CREATE TABLE counter_assignments (
    counter_assignment_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    counter_id               INT UNSIGNED NOT NULL,
    queue_type_id              INT UNSIGNED NOT NULL,
    staff_user_id                INT UNSIGNED NOT NULL,
    assigned_date                 DATE NOT NULL,
    is_active                      TINYINT(1) NOT NULL DEFAULT 1,
    created_at                      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_counter_assign_counter (counter_id),
    KEY idx_counter_assign_queue_type (queue_type_id),
    KEY idx_counter_assign_staff (staff_user_id),
    KEY idx_counter_assign_date (assigned_date),
    CONSTRAINT fk_counter_assign_counter FOREIGN KEY (counter_id)
        REFERENCES service_counters (counter_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_counter_assign_queue_type FOREIGN KEY (queue_type_id)
        REFERENCES queue_types (queue_type_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_counter_assign_staff FOREIGN KEY (staff_user_id)
        REFERENCES users (user_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- queue_entries  (§17–19 — the live queue; queue_number is the one
-- deliberate denormalization, stored for fast display)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS queue_entries;
CREATE TABLE queue_entries (
    queue_entry_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    appointment_id        INT UNSIGNED NOT NULL,
    queue_number            VARCHAR(6) NOT NULL, -- e.g. "P003"
    counter_id                INT UNSIGNED DEFAULT NULL,
    status                     ENUM('WAITING','CALLED','SERVING','COMPLETED','NO_SHOW','CANCELLED','SKIPPED','HOLD')
                                 NOT NULL DEFAULT 'WAITING',
    check_in_time              DATETIME DEFAULT NULL,
    called_time                 DATETIME DEFAULT NULL,
    service_start_time           DATETIME DEFAULT NULL,
    service_end_time              DATETIME DEFAULT NULL,
    priority_score                 DECIMAL(10,2) NOT NULL DEFAULT 0.00, -- see §11 formula
    -- "You're almost up" email notification: set the first (and only)
    -- time includes/queue-functions.php's notify_upcoming_clients()
    -- sends this client the heads-up email, so a client is never
    -- emailed twice for the same appointment no matter how many times
    -- the queue reorders around them afterward. NULL = not sent yet.
    next_notified_at               DATETIME DEFAULT NULL,
    created_at                      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_queue_entries_appointment (appointment_id),
    KEY idx_queue_entries_status (status),
    KEY idx_queue_entries_counter (counter_id),
    KEY idx_queue_entries_number (queue_number),
    CONSTRAINT fk_queue_entries_appointment FOREIGN KEY (appointment_id)
        REFERENCES appointments (appointment_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_queue_entries_counter FOREIGN KEY (counter_id)
        REFERENCES service_counters (counter_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- service_transactions  (feeds staff/queue-type reports, §30)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS service_transactions;
CREATE TABLE service_transactions (
    service_transaction_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    queue_entry_id            INT UNSIGNED NOT NULL,
    staff_user_id                INT UNSIGNED NOT NULL,
    counter_id                     INT UNSIGNED NOT NULL,
    start_time                      DATETIME NOT NULL,
    end_time                         DATETIME DEFAULT NULL,
    notes                              VARCHAR(255) DEFAULT NULL,
    UNIQUE KEY uq_service_tx_queue_entry (queue_entry_id),
    KEY idx_service_tx_staff (staff_user_id),
    KEY idx_service_tx_counter (counter_id),
    CONSTRAINT fk_service_tx_queue_entry FOREIGN KEY (queue_entry_id)
        REFERENCES queue_entries (queue_entry_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_service_tx_staff FOREIGN KEY (staff_user_id)
        REFERENCES users (user_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_service_tx_counter FOREIGN KEY (counter_id)
        REFERENCES service_counters (counter_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- queue_status_history  — approved Phase-0 addition (§18: every queue
-- status change recorded). activity_logs stays a general prose log;
-- this is the queryable table the Queue Report reads from.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS queue_status_history;
CREATE TABLE queue_status_history (
    history_id       BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    queue_entry_id     INT UNSIGNED NOT NULL,
    from_status           ENUM('WAITING','CALLED','SERVING','COMPLETED','NO_SHOW','CANCELLED','SKIPPED','HOLD') DEFAULT NULL,
    to_status               ENUM('WAITING','CALLED','SERVING','COMPLETED','NO_SHOW','CANCELLED','SKIPPED','HOLD') NOT NULL,
    changed_by                INT UNSIGNED DEFAULT NULL,
    changed_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_qsh_queue_entry (queue_entry_id),
    KEY idx_qsh_changed_at (changed_at),
    CONSTRAINT fk_qsh_queue_entry FOREIGN KEY (queue_entry_id)
        REFERENCES queue_entries (queue_entry_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_qsh_changed_by FOREIGN KEY (changed_by)
        REFERENCES users (user_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- queue_settings  (§19–20, §25–26 — admin-configurable key/value store)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS queue_settings;
CREATE TABLE queue_settings (
    setting_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    setting_key     VARCHAR(60)  NOT NULL,
    setting_value   VARCHAR(255) NOT NULL,
    description     VARCHAR(255) DEFAULT NULL,
    updated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_queue_settings_key (setting_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- business_schedule  (Sunday–Saturday operating-hours configuration).
-- day_of_week uses PHP's date('w') numbering: 0=Sunday .. 6=Saturday.
-- One row per day, always all 7 present (enforced app-side, not by a
-- CHECK constraint, for XAMPP/MariaDB-version compatibility).
--
-- This is a per-day GATE + bounds check layered on top of the existing
-- capacity_settings HOURLY slot list (§22) — it does NOT replace it.
-- is_open decides whether booking/check-in is allowed AT ALL that day;
-- opening_time/closing_time/break_start/break_end bound which of the
-- existing shared HOURLY slots are actually offered that day; and
-- max_appointments (nullable) is an optional extra per-day cap on top
-- of whatever capacity_settings already allows — NULL means "no extra
-- cap, defer entirely to capacity_settings" so a fresh install behaves
-- exactly like before this table existed. See
-- includes/schedule-functions.php for the read-side logic.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS business_schedule;
CREATE TABLE business_schedule (
    schedule_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    day_of_week          TINYINT UNSIGNED NOT NULL, -- 0=Sunday .. 6=Saturday
    day_name                VARCHAR(10) NOT NULL,
    is_open                    TINYINT(1) NOT NULL DEFAULT 1,
    opening_time                 TIME DEFAULT NULL,
    closing_time                    TIME DEFAULT NULL,
    break_start                        TIME DEFAULT NULL,
    break_end                             TIME DEFAULT NULL,
    max_appointments                        INT UNSIGNED DEFAULT NULL,
    updated_at                                 TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_business_schedule_day (day_of_week)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- notifications  (§6 diagram, §26 — SMS reserved but NOT IMPLEMENTED
-- YET per §15; only EMAIL/SYSTEM currently ship)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS notifications;
CREATE TABLE notifications (
    notification_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    appointment_id    INT UNSIGNED DEFAULT NULL,
    channel             ENUM('EMAIL','SYSTEM','SMS') NOT NULL DEFAULT 'EMAIL',
    message               TEXT NOT NULL,
    status                  ENUM('PENDING','SENT','FAILED') NOT NULL DEFAULT 'PENDING',
    sent_at                   DATETIME DEFAULT NULL,
    created_at                  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_notifications_appointment (appointment_id),
    KEY idx_notifications_status (status),
    CONSTRAINT fk_notifications_appointment FOREIGN KEY (appointment_id)
        REFERENCES appointments (appointment_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- activity_logs  (§28 — append-only digital logbook)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS activity_logs;
CREATE TABLE activity_logs (
    activity_log_id  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id             INT UNSIGNED DEFAULT NULL, -- NULL for client-side actions
    action                 VARCHAR(60) NOT NULL,
    description               VARCHAR(255) DEFAULT NULL,
    ip_address                  VARCHAR(45) DEFAULT NULL,
    created_at                    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_activity_user (user_id),
    KEY idx_activity_action (action),
    KEY idx_activity_created (created_at),
    CONSTRAINT fk_activity_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- 5. DEMO ROLES
-- =====================================================================
INSERT INTO roles (role_name, description) VALUES
    ('admin',  'Full system control.'),
    ('staff',  'Handles queue and client transactions.'),
    ('client', 'Books appointments and monitors their appointment (no login account).');

-- =====================================================================
-- 6. DEMO ADMIN
-- Login: admin@psaq.local / Admin@123
-- Hash generated with PHP's own password_hash(PASSWORD_DEFAULT) —
-- change this password before any real defense/demo.
-- =====================================================================
INSERT INTO users (role_id, full_name, email, password_hash, status) VALUES
    (
        (SELECT role_id FROM roles WHERE role_name = 'admin'),
        'PSAQ System Administrator',
        'admin@psaq.local',
        '$2y$12$jeR3j7hSKeaQ4HX/qIKkmuTfsP0JkyEcVkjyMxkgEIPp/KD8Sa6QW',
        'ACTIVE'
    );

-- =====================================================================
-- 7. DEMO STAFF
-- Login: staff@psaq.local / Staff@123
-- =====================================================================
INSERT INTO users (role_id, full_name, email, password_hash, status) VALUES
    (
        (SELECT role_id FROM roles WHERE role_name = 'staff'),
        'Juan Dela Cruz',
        'staff@psaq.local',
        '$2y$12$0ldCD.IWYTl2mvEbGEwzC.TmywsQU8iEVivC3ZKeOuwQT4ERSyhDa',
        'ACTIVE'
    );

-- =====================================================================
-- 8. QUEUE TYPES  (§10)
-- ---------------------------------------------------------------------
-- code | name                  | default_duration_minutes
-- R    | Regular Registration  | 20
-- P    | Priority              | 20
-- U    | Update                | 15
-- C    | Claim                 | 10
-- =====================================================================
INSERT INTO queue_types (code, name, default_duration_minutes, is_active) VALUES
    ('R', 'Regular Registration', 20, 1),
    ('P', 'Priority',             20, 1),
    ('U', 'Update',                15, 1),
    ('C', 'Claim',                  10, 1);

-- =====================================================================
-- 9. SAMPLE COUNTERS  (§21)
-- =====================================================================
INSERT INTO service_counters (counter_name, status) VALUES
    ('Counter 1', 'ACTIVE'),
    ('Counter 2', 'ACTIVE'),
    ('Counter 3', 'ACTIVE'),
    ('Counter 4', 'ACTIVE');

-- =====================================================================
-- 10. DEFAULT CAPACITY SETTINGS  (§22)
-- Daily caps per queue type, matching your example figures.
-- =====================================================================
INSERT INTO capacity_settings (queue_type_id, setting_type, start_time, end_time, max_capacity, is_active) VALUES
    ((SELECT queue_type_id FROM queue_types WHERE code = 'R'), 'DAILY', NULL, NULL, 50, 1),
    ((SELECT queue_type_id FROM queue_types WHERE code = 'P'), 'DAILY', NULL, NULL, 20, 1),
    ((SELECT queue_type_id FROM queue_types WHERE code = 'U'), 'DAILY', NULL, NULL, 30, 1),
    ((SELECT queue_type_id FROM queue_types WHERE code = 'C'), 'DAILY', NULL, NULL, 20, 1);

-- Hourly caps shared across all queue types (queue_type_id = NULL),
-- office hours 8:00–17:00 with a 12:00–13:00 lunch break excluded,
-- matching your example figures.
INSERT INTO capacity_settings (queue_type_id, setting_type, start_time, end_time, max_capacity, is_active) VALUES
    (NULL, 'HOURLY', '08:00:00', '09:00:00', 15, 1),
    (NULL, 'HOURLY', '09:00:00', '10:00:00', 15, 1),
    (NULL, 'HOURLY', '10:00:00', '11:00:00', 15, 1),
    (NULL, 'HOURLY', '11:00:00', '12:00:00', 15, 1),
    (NULL, 'HOURLY', '13:00:00', '14:00:00', 15, 1),
    (NULL, 'HOURLY', '14:00:00', '15:00:00', 15, 1),
    (NULL, 'HOURLY', '15:00:00', '16:00:00', 15, 1),
    (NULL, 'HOURLY', '16:00:00', '17:00:00', 15, 1);

-- =====================================================================
-- 11. DEFAULT QUEUE SETTINGS  (§19–20, §25–26)
-- =====================================================================
INSERT INTO queue_settings (setting_key, setting_value, description) VALUES
    ('active_algorithm',        'FCFS', 'Active queue-calling algorithm: FCFS or SPT (§19). Switch built in Phase 17.'),
    -- Seconds-scale counterpart to grace_period_minutes below — see
    -- includes/queue-functions.php's auto_advance_stale_called_entries().
    -- When set, fires first (seconds beat minutes) and also auto-calls
    -- the next WAITING client into the same counter; grace_period_minutes
    -- is kept as a slow backstop for whatever this misses. Blank ('') by
    -- default = no limit — this fast timer is off out of the box, so a
    -- CALLED client is never auto-marked NO_SHOW just for taking a while
    -- to reach the counter; admin can set a value here anytime to turn
    -- it back on.
    ('call_timeout_seconds',    '',     'Seconds a CALLED client has to reach the counter before they are auto-marked NO_SHOW and the next client is automatically called. Blank = no limit.'),
    ('grace_period_minutes',    '15',   'Minutes after being called before a no-show is recorded (§25).'),
    ('otp_expiry_minutes',      '5',    'Minutes before an issued OTP expires (§12).'),
    ('otp_max_attempts',        '5',    'Maximum wrong-OTP attempts before the code is invalidated (§12).'),
    ('voice_language',          'en',   'Default SpeechSynthesis language: en or fil (§26).'),
    ('voice_speed',             '1.0',  'Default SpeechSynthesis rate, 0.5–2.0 (§26).'),
    ('voice_volume',            '1.0',  'Default SpeechSynthesis volume, 0.0–1.0 (§26).'),
    -- Phase 10 priority-scoring formula (§11) tunables — see
    -- includes/queue-functions.php's compute_priority_score() for the
    -- exact formula. Admin-editable UI for these is also Phase 17.
    -- (priority_weight / "Priority Lane Bonus" removed by request —
    -- Priority-transaction entries no longer get a flat score bonus.)
    ('aging_points_per_minute', '0.5',  'Points added per minute waited — the fairness/aging factor that prevents starvation and also drives FCFS ordering (§11).'),
    ('spt_weight_per_minute',   '1.0',  'SPT mode only: points subtracted per minute of a transaction type''s default duration, favoring shorter jobs (§11, §19).'),
    -- "You're almost up" email notification tunable — see
    -- includes/queue-functions.php's notify_upcoming_clients().
    ('queue_notify_threshold',  '2',    'A WAITING client is emailed once they have this many people or fewer ahead of them in their transaction type''s queue.');

-- =====================================================================
-- 12. DEFAULT BUSINESS SCHEDULE (Sunday–Saturday)
-- Seeded open every day, 8:00–17:00 with a 12:00–13:00 break, matching
-- the office hours capacity_settings already assumed (§22) — so a
-- fresh install behaves exactly as it did before this table existed.
-- Nothing is silently closed by default; admin can close any day (e.g.
-- Sunday) from admin/schedule.php.
-- =====================================================================
-- Saturday and Sunday closed by default (is_open = 0, hours NULL — the
-- same "closed day" shape validate_business_schedule() itself writes,
-- see includes/schedule-functions.php) — a PSA registration center
-- office is not open weekends. Admin can still flip either back open
-- any time from Admin -> Business Schedule; nothing else in the app
-- hardcodes the 5-day week, it all reads this table.
INSERT INTO business_schedule (day_of_week, day_name, is_open, opening_time, closing_time, break_start, break_end, max_appointments) VALUES
    (0, 'Sunday',    0, NULL, NULL, NULL, NULL, NULL),
    (1, 'Monday',    1, '08:00:00', '17:00:00', '12:00:00', '13:00:00', NULL),
    (2, 'Tuesday',   1, '08:00:00', '17:00:00', '12:00:00', '13:00:00', NULL),
    (3, 'Wednesday', 1, '08:00:00', '17:00:00', '12:00:00', '13:00:00', NULL),
    (4, 'Thursday',  1, '08:00:00', '17:00:00', '12:00:00', '13:00:00', NULL),
    (5, 'Friday',    1, '08:00:00', '17:00:00', '12:00:00', '13:00:00', NULL),
    (6, 'Saturday',  0, NULL, NULL, NULL, NULL, NULL);

-- =====================================================================
-- EXISTING-INSTALL MIGRATION
-- Run ONLY this block (from here to the end of the file) if you already
-- have a working PSAQ database from before the HOLD status / business
-- schedule / contact-email features. It is safe to re-run: every
-- statement below is idempotent (IF NOT EXISTS / INSERT IGNORE /
-- ON DUPLICATE KEY), and none of it touches an existing row in
-- clients, appointments, or queue_entries. Select the psaq_db database
-- in phpMyAdmin, open the "SQL" tab, paste this block, and click "Go".
-- =====================================================================
USE psaq_db;

-- 1) Add the HOLD status to queue_entries and queue_status_history.
--    MODIFY COLUMN on an ENUM is safe here — it only widens the set of
--    allowed values; no existing row's status changes, since none of
--    them were ever 'HOLD' before this column allowed it.
ALTER TABLE queue_entries
    MODIFY COLUMN status ENUM('WAITING','CALLED','SERVING','COMPLETED','NO_SHOW','CANCELLED','SKIPPED','HOLD')
        NOT NULL DEFAULT 'WAITING';

ALTER TABLE queue_status_history
    MODIFY COLUMN from_status ENUM('WAITING','CALLED','SERVING','COMPLETED','NO_SHOW','CANCELLED','SKIPPED','HOLD') DEFAULT NULL,
    MODIFY COLUMN to_status   ENUM('WAITING','CALLED','SERVING','COMPLETED','NO_SHOW','CANCELLED','SKIPPED','HOLD') NOT NULL;

-- 2) Create business_schedule if it doesn't already exist (idempotent —
--    unlike the DROP TABLE + CREATE TABLE used earlier in this file for
--    a fresh install, this must NOT drop an existing table).
CREATE TABLE IF NOT EXISTS business_schedule (
    schedule_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    day_of_week          TINYINT UNSIGNED NOT NULL,
    day_name                VARCHAR(10) NOT NULL,
    is_open                    TINYINT(1) NOT NULL DEFAULT 1,
    opening_time                 TIME DEFAULT NULL,
    closing_time                    TIME DEFAULT NULL,
    break_start                        TIME DEFAULT NULL,
    break_end                             TIME DEFAULT NULL,
    max_appointments                        INT UNSIGNED DEFAULT NULL,
    updated_at                                 TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_business_schedule_day (day_of_week)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3) Seed all 7 days only if they're missing (INSERT IGNORE skips any
--    day_of_week that's already there, e.g. if this migration is
--    re-run, or a day was already added by hand).
-- Same weekend-closed default as the fresh-install seed above; INSERT
-- IGNORE means this only fills in a day_of_week row that isn't already
-- there, so it never overwrites an admin's existing Saturday/Sunday
-- setting on an upgraded install.
INSERT IGNORE INTO business_schedule (day_of_week, day_name, is_open, opening_time, closing_time, break_start, break_end, max_appointments) VALUES
    (0, 'Sunday',    0, NULL, NULL, NULL, NULL, NULL),
    (1, 'Monday',    1, '08:00:00', '17:00:00', '12:00:00', '13:00:00', NULL),
    (2, 'Tuesday',   1, '08:00:00', '17:00:00', '12:00:00', '13:00:00', NULL),
    (3, 'Wednesday', 1, '08:00:00', '17:00:00', '12:00:00', '13:00:00', NULL),
    (4, 'Thursday',  1, '08:00:00', '17:00:00', '12:00:00', '13:00:00', NULL),
    (5, 'Friday',    1, '08:00:00', '17:00:00', '12:00:00', '13:00:00', NULL),
    (6, 'Saturday',  0, NULL, NULL, NULL, NULL, NULL);

-- 4) Seed the contact_email setting (see includes/settings-functions.php)
--    if it isn't already there — a fresh install's INSERT (section 11
--    above) doesn't cover an existing database, and update_queue_settings()
--    reads get_current_settings()'s PHP-side default until a row exists,
--    so this step is optional but keeps admin/settings.php's saved value
--    in the database explicitly from the start.
INSERT IGNORE INTO queue_settings (setting_key, setting_value, description) VALUES
    ('contact_email', 'psaqhelpdesk@gmail.com', 'Public contact email shown on the client homepage''s "Email Us" button and QR code. Never used to send mail server-side.');
