CALL sp_fa_generate_sl('2026-07-31','101');
SELECT CAST(SUM(depreciation_amount) AS numeric(18,2)) jul_total, COUNT(*) baris FROM FA_DEPRECIATION WHERE site_id='101' AND period='2026-07-31' AND posting_status='D';
DELETE FROM FA_DEPRECIATION WHERE site_id='101' AND period='2026-07-31' AND posting_status='D';
COMMIT;
SELECT COUNT(*) jul_after_cleanup FROM FA_DEPRECIATION WHERE site_id='101' AND period='2026-07-31';
