-- =====================================================================
-- FA_GL_LINK : Subledger Accounting link (SAP CO-AA / Oracle SLA style)
-- Binds each asset depreciation -> exact GL journal line (deterministic).
-- Additive only: reads gl_journal, writes new table. Does NOT modify GL.
-- Rollback: DROP TABLE FA_GL_LINK; DROP PROCEDURE sp_fa_build_gl_link;
-- =====================================================================

IF EXISTS (SELECT 1 FROM SYS.SYSTABLE WHERE table_name='FA_GL_LINK') THEN
   DROP TABLE FA_GL_LINK;
END IF;

CREATE TABLE FA_GL_LINK (
    link_id         integer       NOT NULL DEFAULT AUTOINCREMENT,
    site_id         varchar(4)    NOT NULL,
    asset_code      varchar(20)   NOT NULL,
    period          timestamp     NOT NULL,
    voucher         varchar(15)   NOT NULL,
    journal_urut    integer       NOT NULL,        -- line id in gl_journal
    account_code    varchar(15)   NOT NULL,
    amount          decimal(18,2) NOT NULL DEFAULT 0,   -- asset's share of the line
    dk              char(1)       NOT NULL,         -- D = expense, K = accumulation
    allocation_type varchar(10)   NOT NULL DEFAULT 'PRO-RATA',
    created_date    timestamp     NULL DEFAULT CURRENT TIMESTAMP,
    PRIMARY KEY (link_id)
);
CREATE INDEX ix_fa_gl_link_asset ON FA_GL_LINK (site_id, asset_code, voucher);
CREATE INDEX ix_fa_gl_link_vou   ON FA_GL_LINK (site_id, voucher, journal_urut);

-- Deterministic builder for one period (idempotent). Called after FA posting/regenerate.
IF EXISTS (SELECT 1 FROM SYS.SYSPROCEDURE WHERE proc_name='sp_fa_build_gl_link') THEN
   DROP PROCEDURE sp_fa_build_gl_link;
END IF;

CREATE PROCEDURE sp_fa_build_gl_link (IN p_period TIMESTAMP, IN p_site VARCHAR(4))
BEGIN
    DELETE FROM FA_GL_LINK WHERE site_id = p_site AND period = p_period;

    -- Cr : accumulated depreciation line (per category accum account)
    INSERT INTO FA_GL_LINK (site_id,asset_code,period,voucher,journal_urut,account_code,amount,dk,allocation_type)
    SELECT d.site_id, d.asset_code, d.period, d.journal_no, j.urut, c.accum_dep_account,
           d.depreciation_amount, 'K', 'PRO-RATA'
      FROM FA_DEPRECIATION d
      JOIN FA_ASSET    a ON a.site_id = d.site_id  AND a.asset_code = d.asset_code
      JOIN FA_CATEGORY c ON c.site_id = a.site_id  AND c.category_code = a.category_code
      JOIN gl_journal  j ON j.site_id = d.site_id  AND j.voucher = d.journal_no
                        AND j.account_id = c.accum_dep_account
     WHERE d.site_id = p_site AND d.period = p_period
       AND d.journal_no IS NOT NULL AND c.accum_dep_account IS NOT NULL;

    -- Dr : depreciation expense line (shared expense account)
    INSERT INTO FA_GL_LINK (site_id,asset_code,period,voucher,journal_urut,account_code,amount,dk,allocation_type)
    SELECT d.site_id, d.asset_code, d.period, d.journal_no, j.urut, c.dep_expense_account,
           d.depreciation_amount, 'D', 'PRO-RATA'
      FROM FA_DEPRECIATION d
      JOIN FA_ASSET    a ON a.site_id = d.site_id  AND a.asset_code = d.asset_code
      JOIN FA_CATEGORY c ON c.site_id = a.site_id  AND c.category_code = a.category_code
      JOIN gl_journal  j ON j.site_id = d.site_id  AND j.voucher = d.journal_no
                        AND j.account_id = c.dep_expense_account
     WHERE d.site_id = p_site AND d.period = p_period
       AND d.journal_no IS NOT NULL AND c.dep_expense_account IS NOT NULL;
END;

-- Backfill all existing periods (Jan-Jun 2026)
CALL sp_fa_build_gl_link('2026-01-31','101');
CALL sp_fa_build_gl_link('2026-02-28','101');
CALL sp_fa_build_gl_link('2026-03-31','101');
CALL sp_fa_build_gl_link('2026-04-30','101');
CALL sp_fa_build_gl_link('2026-05-31','101');
CALL sp_fa_build_gl_link('2026-06-30','101');
COMMIT;

-- Verify
SELECT 'FA_GL_LINK rows='||CAST(COUNT(*) AS varchar)||
       '  assets='||CAST(COUNT(DISTINCT asset_code) AS varchar)||
       '  vouchers='||CAST(COUNT(DISTINCT voucher) AS varchar) AS result FROM FA_GL_LINK;
