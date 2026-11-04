-- =====================================================================
-- Afordchess Academy: chess coaching business (real organisation, invented data)
-- MIT 8103 Advanced Database Systems - Portfolio 1: Database Design
-- Target: PostgreSQL 15+ (works in Supabase's SQL Editor)
-- =====================================================================

-- Re-runnable: drop in reverse dependency order
DROP TABLE IF EXISTS leads              CASCADE;
DROP TABLE IF EXISTS post_metrics       CASCADE;
DROP TABLE IF EXISTS posts              CASCADE;
DROP TABLE IF EXISTS social_accounts    CASCADE;
DROP TABLE IF EXISTS payments           CASCADE;
DROP TABLE IF EXISTS session_attendance CASCADE;
DROP TABLE IF EXISTS class_sessions     CASCADE;
DROP TABLE IF EXISTS enrolments         CASCADE;
DROP TABLE IF EXISTS course_prices      CASCADE;
DROP TABLE IF EXISTS courses            CASCADE;
DROP TABLE IF EXISTS students           CASCADE;
DROP TABLE IF EXISTS guardians          CASCADE;
DROP TABLE IF EXISTS schools            CASCADE;
DROP TABLE IF EXISTS staff              CASCADE;

-- ---------------------------------------------------------------------
-- 1. staff: the owner, coaches, admin and marketing team
-- ---------------------------------------------------------------------
CREATE TABLE staff (
    staff_id    BIGSERIAL    PRIMARY KEY,
    full_name   VARCHAR(120) NOT NULL,
    email       VARCHAR(255) NOT NULL UNIQUE,
    role        VARCHAR(20)  NOT NULL
                CHECK (role IN ('owner', 'coach', 'admin', 'marketing')),
    country     VARCHAR(60)  NOT NULL,
    status      VARCHAR(20)  NOT NULL DEFAULT 'active'
                CHECK (status IN ('active', 'on_leave', 'left')),
    hired_at    DATE         NOT NULL DEFAULT CURRENT_DATE
);

-- ---------------------------------------------------------------------
-- 2. schools: partner schools where in-person classes are run
-- ---------------------------------------------------------------------
CREATE TABLE schools (
    school_id           BIGSERIAL    PRIMARY KEY,
    school_name         VARCHAR(150) NOT NULL,
    country             VARCHAR(60)  NOT NULL,
    city                VARCHAR(80)  NOT NULL,
    contact_name        VARCHAR(120),
    contact_email       VARCHAR(255),
    partnership_status  VARCHAR(20)  NOT NULL DEFAULT 'active'
                        CHECK (partnership_status IN ('prospect', 'active', 'ended')),
    partner_since       DATE,
    UNIQUE (school_name, city)
);

-- ---------------------------------------------------------------------
-- 3. guardians: parents or guardians who pay for younger students
-- ---------------------------------------------------------------------
CREATE TABLE guardians (
    guardian_id  BIGSERIAL    PRIMARY KEY,
    full_name    VARCHAR(120) NOT NULL,
    email        VARCHAR(255) NOT NULL UNIQUE,
    phone        VARCHAR(30),
    country      VARCHAR(60)  NOT NULL
);

-- ---------------------------------------------------------------------
-- 4. students: guardian and school are optional (adult or online-only students)
-- ---------------------------------------------------------------------
CREATE TABLE students (
    student_id    BIGSERIAL    PRIMARY KEY,
    full_name     VARCHAR(120) NOT NULL,
    email         VARCHAR(255) UNIQUE,
    country       VARCHAR(60)  NOT NULL
                  CHECK (country IN ('Nigeria', 'Canada', 'USA')),
    timezone      VARCHAR(50)  NOT NULL,          -- IANA name, e.g. 'Africa/Lagos'
    skill_level   VARCHAR(20)  NOT NULL DEFAULT 'beginner'
                  CHECK (skill_level IN ('beginner', 'intermediate', 'advanced')),
    status        VARCHAR(20)  NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active', 'paused', 'left')),
    guardian_id   BIGINT       REFERENCES guardians(guardian_id),
    school_id     BIGINT       REFERENCES schools(school_id),
    joined_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 5. courses: what the academy teaches (price lives in course_prices)
-- ---------------------------------------------------------------------
CREATE TABLE courses (
    course_id    BIGSERIAL    PRIMARY KEY,
    course_name  VARCHAR(120) NOT NULL UNIQUE,
    level        VARCHAR(20)  NOT NULL
                 CHECK (level IN ('beginner', 'intermediate', 'advanced')),
    description  TEXT,
    is_active    BOOLEAN      NOT NULL DEFAULT TRUE
);

-- ---------------------------------------------------------------------
-- 6. course_prices: one monthly fee per course per currency
-- ---------------------------------------------------------------------
CREATE TABLE course_prices (
    course_id    BIGINT        NOT NULL REFERENCES courses(course_id) ON DELETE CASCADE,
    currency     CHAR(3)       NOT NULL CHECK (currency IN ('NGN', 'CAD', 'USD')),
    monthly_fee  NUMERIC(12,2) NOT NULL CHECK (monthly_fee > 0),
    PRIMARY KEY (course_id, currency)
);

-- ---------------------------------------------------------------------
-- 7. enrolments: a student's monthly subscription to a course.
--    The agreed currency and fee are a snapshot, because list prices change.
-- ---------------------------------------------------------------------
CREATE TABLE enrolments (
    enrolment_id        BIGSERIAL     PRIMARY KEY,
    student_id          BIGINT        NOT NULL REFERENCES students(student_id),
    course_id           BIGINT        NOT NULL REFERENCES courses(course_id),
    currency            CHAR(3)       NOT NULL,
    agreed_monthly_fee  NUMERIC(12,2) NOT NULL CHECK (agreed_monthly_fee > 0),
    start_date          DATE          NOT NULL DEFAULT CURRENT_DATE,
    end_date            DATE,
    status              VARCHAR(20)   NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'paused', 'cancelled', 'completed')),
    UNIQUE (student_id, course_id, start_date),
    UNIQUE (enrolment_id, currency),              -- lets payments match the enrolment's currency
    CHECK (end_date IS NULL OR end_date >= start_date),
    -- the chosen currency must be one the course is priced in
    FOREIGN KEY (course_id, currency) REFERENCES course_prices(course_id, currency)
);

-- ---------------------------------------------------------------------
-- 8. class_sessions: online sessions have no school; in-person sessions
--    are held at a partner school
-- ---------------------------------------------------------------------
CREATE TABLE class_sessions (
    session_id        BIGSERIAL   PRIMARY KEY,
    course_id         BIGINT      NOT NULL REFERENCES courses(course_id),
    coach_id          BIGINT      NOT NULL REFERENCES staff(staff_id),
    school_id         BIGINT      REFERENCES schools(school_id),
    delivery_mode     VARCHAR(20) NOT NULL CHECK (delivery_mode IN ('online', 'in_person')),
    meeting_link      VARCHAR(300),
    scheduled_start   TIMESTAMPTZ NOT NULL,
    duration_minutes  INT         NOT NULL DEFAULT 60 CHECK (duration_minutes BETWEEN 15 AND 240),
    capacity          INT         NOT NULL CHECK (capacity > 0),
    status            VARCHAR(20) NOT NULL DEFAULT 'scheduled'
                      CHECK (status IN ('scheduled', 'completed', 'cancelled')),
    CHECK (
        (delivery_mode = 'online'    AND school_id IS NULL) OR
        (delivery_mode = 'in_person' AND school_id IS NOT NULL)
    )
);

-- ---------------------------------------------------------------------
-- 9. session_attendance: a seat booking and, later, the attendance outcome
--    (resolves the many-to-many between students and sessions)
-- ---------------------------------------------------------------------
CREATE TABLE session_attendance (
    session_id  BIGINT      NOT NULL REFERENCES class_sessions(session_id) ON DELETE CASCADE,
    student_id  BIGINT      NOT NULL REFERENCES students(student_id),
    status      VARCHAR(20) NOT NULL DEFAULT 'booked'
                CHECK (status IN ('booked', 'present', 'late', 'absent', 'excused', 'cancelled')),
    booked_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (session_id, student_id)
);

-- ---------------------------------------------------------------------
-- 10. payments: one row per enrolment per billing month (monthly schedule)
-- ---------------------------------------------------------------------
CREATE TABLE payments (
    payment_id     BIGSERIAL     PRIMARY KEY,
    enrolment_id   BIGINT        NOT NULL,
    billing_month  DATE          NOT NULL CHECK (EXTRACT(DAY FROM billing_month) = 1),
    amount         NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    currency       CHAR(3)       NOT NULL,
    method         VARCHAR(20)   NOT NULL DEFAULT 'card'
                   CHECK (method IN ('card', 'bank_transfer', 'cash', 'other')),
    status         VARCHAR(20)   NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending', 'paid', 'failed', 'refunded')),
    due_date       DATE          NOT NULL,
    paid_at        TIMESTAMPTZ,
    UNIQUE (enrolment_id, billing_month),         -- one bill per month per enrolment
    CHECK (status <> 'paid' OR paid_at IS NOT NULL),
    -- the payment currency must equal the enrolment's currency
    FOREIGN KEY (enrolment_id, currency) REFERENCES enrolments(enrolment_id, currency)
);

-- ---------------------------------------------------------------------
-- 11. social_accounts: the academy's Instagram, TikTok and YouTube channels
-- ---------------------------------------------------------------------
CREATE TABLE social_accounts (
    account_id  BIGSERIAL    PRIMARY KEY,
    platform    VARCHAR(20)  NOT NULL CHECK (platform IN ('instagram', 'tiktok', 'youtube')),
    handle      VARCHAR(80)  NOT NULL,
    managed_by  BIGINT       REFERENCES staff(staff_id),
    created_at  DATE         NOT NULL DEFAULT CURRENT_DATE,
    UNIQUE (platform, handle)
);

-- ---------------------------------------------------------------------
-- 12. posts: a piece of content published on one account
-- ---------------------------------------------------------------------
CREATE TABLE posts (
    post_id       BIGSERIAL    PRIMARY KEY,
    account_id    BIGINT       NOT NULL REFERENCES social_accounts(account_id),
    title         VARCHAR(200),
    caption       TEXT,
    content_type  VARCHAR(20)  NOT NULL
                  CHECK (content_type IN ('reel', 'short', 'video', 'story', 'image')),
    posted_at     TIMESTAMPTZ  NOT NULL,
    external_url  VARCHAR(300)
);

-- ---------------------------------------------------------------------
-- 13. post_metrics: daily engagement snapshot per post (time-series)
-- ---------------------------------------------------------------------
CREATE TABLE post_metrics (
    post_id        BIGINT NOT NULL REFERENCES posts(post_id) ON DELETE CASCADE,
    snapshot_date  DATE   NOT NULL,
    views          INT    NOT NULL DEFAULT 0 CHECK (views >= 0),
    likes          INT    NOT NULL DEFAULT 0 CHECK (likes >= 0),
    comments       INT    NOT NULL DEFAULT 0 CHECK (comments >= 0),
    shares         INT    NOT NULL DEFAULT 0 CHECK (shares >= 0),
    PRIMARY KEY (post_id, snapshot_date)
);

-- ---------------------------------------------------------------------
-- 14. leads: a prospective student, and where they came from. A converted
--     lead points to the student record it became.
-- ---------------------------------------------------------------------
CREATE TABLE leads (
    lead_id               BIGSERIAL    PRIMARY KEY,
    full_name             VARCHAR(120) NOT NULL,
    email                 VARCHAR(255),
    country               VARCHAR(60)  NOT NULL,
    source_type           VARCHAR(25)  NOT NULL
                          CHECK (source_type IN ('social_post', 'school_partnership', 'referral', 'other')),
    post_id               BIGINT       REFERENCES posts(post_id),
    status                VARCHAR(20)  NOT NULL DEFAULT 'new'
                          CHECK (status IN ('new', 'contacted', 'converted', 'lost')),
    converted_student_id  BIGINT       UNIQUE REFERENCES students(student_id),
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    -- a post is recorded only for leads that came from a social post
    CHECK (
        (source_type = 'social_post' AND post_id IS NOT NULL) OR
        (source_type <> 'social_post' AND post_id IS NULL)
    ),
    CHECK ((status = 'converted') = (converted_student_id IS NOT NULL))
);

-- NOTE: No extra indexes are created here on purpose. Portfolio 2 measures
-- query performance before and after adding indexes, so the baseline stays
-- unindexed (apart from the automatic indexes on primary keys and UNIQUE).
