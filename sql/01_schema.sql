-- =====================================================================
-- AML / KYC Analytics: schema
-- All data is synthetic. Target: PostgreSQL 18
-- =====================================================================

DROP SCHEMA IF EXISTS aml CASCADE;
CREATE SCHEMA aml;
SET search_path TO aml;

-- ---------- Reference tables ----------

CREATE TABLE analysts (
    analyst_id      SERIAL PRIMARY KEY,
    full_name       VARCHAR(100) NOT NULL,
    team            VARCHAR(50)  NOT NULL CHECK (team IN ('Onboarding', 'Remediation', 'EDD')),
    grade           VARCHAR(30)  NOT NULL CHECK (grade IN ('Operational Analyst', 'Senior Operational Analyst', 'Team Lead')),
    join_date       DATE         NOT NULL
);

CREATE TABLE high_risk_countries (
    country_code    CHAR(2) PRIMARY KEY,
    country_name    VARCHAR(100) NOT NULL,
    risk_category   VARCHAR(30)  NOT NULL CHECK (risk_category IN ('Sanctioned', 'High Risk', 'Elevated')),
    source_list     VARCHAR(100)  -- e.g. FATF grey/black list, synthetic
);

-- ---------- Core customer tables ----------

CREATE TABLE customers (
    customer_id         SERIAL PRIMARY KEY,
    customer_name       VARCHAR(200) NOT NULL,
    entity_type         VARCHAR(30)  NOT NULL
                        CHECK (entity_type IN ('Ltd', 'LLP', 'LP', 'Partnership', 'Sole Trader', 'Public Sector')),
    sic_code            VARCHAR(5)   NOT NULL,
    nature_of_business  VARCHAR(200),
    country_of_incorp   CHAR(2)      NOT NULL,
    onboarding_date     DATE         NOT NULL,
    expected_monthly_turnover NUMERIC(14,2) NOT NULL CHECK (expected_monthly_turnover >= 0),
    risk_rating         VARCHAR(10)  NOT NULL CHECK (risk_rating IN ('Low', 'Medium', 'High')),
    customer_status     VARCHAR(15)  NOT NULL DEFAULT 'Active'
                        CHECK (customer_status IN ('Active', 'Under Review', 'Exited')),
    next_review_due     DATE         NOT NULL
);

CREATE TABLE associated_parties (
    party_id            SERIAL PRIMARY KEY,
    customer_id         INT NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    party_name          VARCHAR(150) NOT NULL,
    role                VARCHAR(30)  NOT NULL
                        CHECK (role IN ('Director', 'UBO', 'Partner', 'Controller', 'Signatory')),
    ownership_pct       NUMERIC(5,2) CHECK (ownership_pct BETWEEN 0 AND 100),
    nationality         CHAR(2),
    date_of_birth       DATE,
    is_pep              BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE accounts (
    account_id          SERIAL PRIMARY KEY,
    customer_id         INT NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    account_type        VARCHAR(30) NOT NULL
                        CHECK (account_type IN ('Business Current', 'Business Reserve', 'Liquidity Manager')),
    opened_date         DATE NOT NULL,
    account_status      VARCHAR(10) NOT NULL DEFAULT 'Open' CHECK (account_status IN ('Open', 'Closed', 'Frozen'))
);

-- ---------- Activity and monitoring ----------

CREATE TABLE transactions (
    txn_id              BIGSERIAL PRIMARY KEY,
    account_id          INT NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
    txn_date            DATE NOT NULL,
    direction           VARCHAR(6) NOT NULL CHECK (direction IN ('Credit', 'Debit')),
    amount              NUMERIC(14,2) NOT NULL CHECK (amount > 0),
    currency            CHAR(3) NOT NULL DEFAULT 'GBP',
    counterparty_name   VARCHAR(150),
    counterparty_country CHAR(2) NOT NULL,
    payment_method      VARCHAR(20) CHECK (payment_method IN ('Faster Payment', 'CHAPS', 'BACS', 'SWIFT', 'Cash', 'Card'))
);

CREATE TABLE screening_alerts (
    alert_id            SERIAL PRIMARY KEY,
    customer_id         INT NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    party_id            INT REFERENCES associated_parties(party_id) ON DELETE SET NULL,
    alert_type          VARCHAR(20) NOT NULL CHECK (alert_type IN ('Sanctions', 'PEP', 'Adverse Media')),
    match_score         NUMERIC(5,2) CHECK (match_score BETWEEN 0 AND 100),
    raised_date         DATE NOT NULL,
    status              VARCHAR(15) NOT NULL DEFAULT 'Open'
                        CHECK (status IN ('Open', 'Closed - False Positive', 'Closed - True Match', 'Escalated')),
    closed_date         DATE,
    analyst_id          INT REFERENCES analysts(analyst_id)
);

CREATE TABLE kyc_reviews (
    review_id           SERIAL PRIMARY KEY,
    customer_id         INT NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    review_type         VARCHAR(20) NOT NULL CHECK (review_type IN ('Onboarding', 'Periodic', 'Event-Driven', 'Remediation')),
    due_date            DATE NOT NULL,
    completed_date      DATE,
    review_status       VARCHAR(15) NOT NULL DEFAULT 'Pending'
                        CHECK (review_status IN ('Pending', 'In Progress', 'Completed', 'Overdue')),
    outcome             VARCHAR(20) CHECK (outcome IN ('Maintain', 'Maintain - Rerate', 'Exit')),
    analyst_id          INT REFERENCES analysts(analyst_id),
    qa_result           VARCHAR(10) CHECK (qa_result IN ('Pass', 'Fail'))
);

-- ---------- Indexes for the queries we'll write later ----------

CREATE INDEX idx_txn_account_date   ON transactions(account_id, txn_date);
CREATE INDEX idx_txn_country        ON transactions(counterparty_country);
CREATE INDEX idx_accounts_customer  ON accounts(customer_id);
CREATE INDEX idx_alerts_customer    ON screening_alerts(customer_id);
CREATE INDEX idx_reviews_due        ON kyc_reviews(due_date, review_status);
CREATE INDEX idx_parties_customer   ON associated_parties(customer_id);

-- ---------- Table comments (shows up in pgAdmin and your docs) ----------

COMMENT ON TABLE customers          IS 'Synthetic business customers with declared expected turnover and risk rating';
COMMENT ON TABLE transactions       IS 'Synthetic account transactions used for monitoring rules';
COMMENT ON TABLE screening_alerts   IS 'Sanctions, PEP and adverse media alerts with disposition';
COMMENT ON TABLE kyc_reviews        IS 'Periodic, event-driven and remediation reviews with QA outcome';