-- ============================================================
-- Fixed Asset Module - Schema (SQL Anywhere)
-- Idempotent: drop-if-exists then create. Additive (no existing tables touched).
-- ============================================================
IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='FA_ASSET_AUDIT') THEN DROP TABLE FA_ASSET_AUDIT END IF;
IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='FA_DEPRECIATION') THEN DROP TABLE FA_DEPRECIATION END IF;
IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='FA_PERIOD') THEN DROP TABLE FA_PERIOD END IF;
IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='FA_ASSET') THEN DROP TABLE FA_ASSET END IF;
IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='FA_CATEGORY') THEN DROP TABLE FA_CATEGORY END IF;

CREATE TABLE FA_CATEGORY (
    site_id              varchar(4)    NOT NULL DEFAULT '101',
    category_code        varchar(10)   NOT NULL,
    category_name        varchar(50)   NOT NULL,
    asset_account        varchar(15)   NOT NULL,
    accum_dep_account    varchar(15)   NULL,
    dep_expense_account  varchar(15)   NULL,
    useful_life_month    integer       NOT NULL DEFAULT 0,
    residual_percent     decimal(5,2)  NOT NULL DEFAULT 0,
    depreciable_yn       char(1)       NOT NULL DEFAULT 'Y',
    active_yn            char(1)       NOT NULL DEFAULT 'Y',
    created_by           varchar(15)   NULL DEFAULT CURRENT USER,
    created_date         timestamp     NULL DEFAULT CURRENT TIMESTAMP,
    PRIMARY KEY (site_id, category_code)
);

CREATE TABLE FA_ASSET (
    site_id              varchar(4)    NOT NULL DEFAULT '101',
    asset_code           varchar(20)   NOT NULL,
    asset_name           varchar(100)  NOT NULL,
    category_code        varchar(10)   NOT NULL,
    acquisition_date     timestamp     NULL,
    acquisition_cost     decimal(18,2) NOT NULL DEFAULT 0,
    residual_value       decimal(18,2) NOT NULL DEFAULT 0,
    useful_life_month    integer       NOT NULL DEFAULT 0,
    accum_dep_beginning  decimal(18,2) NOT NULL DEFAULT 0,
    book_value_beginning decimal(18,2) NOT NULL DEFAULT 0,
    remaining_life_begin integer       NOT NULL DEFAULT 0,
    beginning_period     timestamp     NULL,
    asset_account        varchar(15)   NULL,
    accum_dep_account    varchar(15)   NULL,
    dep_expense_account  varchar(15)   NULL,
    department           varchar(10)   NULL,
    project              varchar(10)   NULL,
    location             varchar(50)   NULL,
    status               char(1)       NOT NULL DEFAULT 'A',
    disposal_date        timestamp     NULL,
    remarks              varchar(250)  NULL,
    created_by           varchar(15)   NULL DEFAULT CURRENT USER,
    created_date         timestamp     NULL DEFAULT CURRENT TIMESTAMP,
    updated_by           varchar(15)   NULL,
    updated_date         timestamp     NULL,
    PRIMARY KEY (site_id, asset_code),
    FOREIGN KEY (site_id, category_code) REFERENCES FA_CATEGORY (site_id, category_code)
);
CREATE INDEX ix_fa_asset_cat ON FA_ASSET (site_id, category_code, status);

CREATE TABLE FA_DEPRECIATION (
    site_id             varchar(4)    NOT NULL DEFAULT '101',
    asset_code          varchar(20)   NOT NULL,
    period              timestamp     NOT NULL,
    depreciation_amount decimal(18,2) NOT NULL DEFAULT 0,
    accum_depreciation  decimal(18,2) NOT NULL DEFAULT 0,
    book_value          decimal(18,2) NOT NULL DEFAULT 0,
    journal_no          varchar(15)   NULL,
    posting_status      char(1)       NOT NULL DEFAULT 'D',
    created_by          varchar(15)   NULL DEFAULT CURRENT USER,
    created_date        timestamp     NULL DEFAULT CURRENT TIMESTAMP,
    PRIMARY KEY (site_id, asset_code, period),
    FOREIGN KEY (site_id, asset_code) REFERENCES FA_ASSET (site_id, asset_code)
);
CREATE INDEX ix_fa_depr_period ON FA_DEPRECIATION (site_id, period, posting_status);

CREATE TABLE FA_PERIOD (
    site_id        varchar(4)    NOT NULL DEFAULT '101',
    period         timestamp     NOT NULL,
    status         char(1)       NOT NULL DEFAULT 'O',
    journal_no     varchar(15)   NULL,
    total_depr     decimal(18,2) NOT NULL DEFAULT 0,
    generate_date  timestamp     NULL,
    generate_by    varchar(15)   NULL,
    post_date      timestamp     NULL,
    post_by        varchar(15)   NULL,
    PRIMARY KEY (site_id, period)
);

CREATE TABLE FA_ASSET_AUDIT (
    audit_id     integer       NOT NULL DEFAULT AUTOINCREMENT,
    site_id      varchar(4)    NOT NULL,
    asset_code   varchar(20)   NOT NULL,
    field_name   varchar(30)   NOT NULL,
    old_value    varchar(100)  NULL,
    new_value    varchar(100)  NULL,
    action       varchar(10)   NOT NULL,
    log_user     varchar(15)   NULL DEFAULT CURRENT USER,
    log_date     timestamp     NULL DEFAULT CURRENT TIMESTAMP,
    PRIMARY KEY (audit_id)
);
CREATE INDEX ix_fa_audit_asset ON FA_ASSET_AUDIT (site_id, asset_code, log_date);

COMMIT;
SELECT 'FA schema created' AS status;
