-- ============================================================
-- FA engine patch: bulan penyusutan TERAKHIR menyerap seluruh sisa
-- nilai buku sehingga Nilai Buku = 0 pas (tidak ada residu sen-an
-- yang tumpah ke bulan ke-(life+1)). Permintaan Pak Wira 2026-07.
-- Perubahan vs fa_07_procs.sql: LATERAL prior + COUNT(*) cnt, dan
-- cabang CASE baru "WHEN (prior.cnt+1) >= remaining_life_begin".
-- ============================================================
IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE p JOIN SYS.SYSUSERPERM u ON p.creator=u.user_id WHERE u.user_name='DBA' AND p.proc_name='sp_fa_generate_sl')
   THEN DROP PROCEDURE sp_fa_generate_sl END IF;
CREATE PROCEDURE sp_fa_generate_sl(IN p_period timestamp, IN p_site varchar(4))
BEGIN
   IF EXISTS(SELECT 1 FROM FA_PERIOD WHERE site_id=p_site AND period=p_period AND status IN ('P','C')) THEN
      RAISERROR 17001 'Periode sudah diposting/closed - pakai regenerate';
   END IF;
   DELETE FROM FA_DEPRECIATION WHERE site_id=p_site AND period=p_period AND posting_status='D';
   INSERT INTO FA_DEPRECIATION (site_id,asset_code,period,depreciation_amount,accum_depreciation,book_value,posting_status)
   SELECT a.site_id, a.asset_code, p_period,
          dep.amt,
          a.accum_dep_beginning + prior.acc + dep.amt,
          a.acquisition_cost - (a.accum_dep_beginning + prior.acc + dep.amt),
          'D'
   FROM FA_ASSET a
   JOIN FA_CATEGORY c ON c.site_id=a.site_id AND c.category_code=a.category_code
   , LATERAL (SELECT COALESCE(SUM(d.depreciation_amount),0) AS acc, COUNT(*) AS cnt
                FROM FA_DEPRECIATION d
               WHERE d.site_id=a.site_id AND d.asset_code=a.asset_code AND d.period<p_period) prior
   , LATERAL (SELECT CASE
                        -- Bulan terakhir umur: serap SELURUH sisa nilai buku -> NBV = 0
                        WHEN (prior.cnt + 1) >= a.remaining_life_begin
                             THEN (a.book_value_beginning - prior.acc)
                        -- Bulan normal: straight-line dibulatkan, dibatasi sisa
                        WHEN ROUND(a.book_value_beginning/NULLIF(a.remaining_life_begin,0),2)
                             < (a.book_value_beginning - prior.acc)
                             THEN ROUND(a.book_value_beginning/NULLIF(a.remaining_life_begin,0),2)
                        ELSE (a.book_value_beginning - prior.acc) END AS amt) dep
   WHERE a.site_id=p_site AND a.status='A' AND c.depreciable_yn='Y'
     AND a.remaining_life_begin>0
     AND (a.book_value_beginning - prior.acc) > 0
     AND dep.amt > 0;
END;

SELECT 'sp_fa_generate_sl (residual-absorbing) updated' AS status;
