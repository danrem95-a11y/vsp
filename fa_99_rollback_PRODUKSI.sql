-- =====================================================================
-- ROLLBACK PENUH deploy FA di PRODUKSI (vspnew @103.233.89.43, SA9)
-- Urutan: keuangan dulu (pulihkan GL), lalu objek modul (additive).
-- Jalankan via dbisql SA9. Review sebelum eksekusi.
-- =====================================================================

-- (1) KEUANGAN — batalkan rebase: hapus 6 voucher FA, pulihkan 4 MEMO Jan-Apr
DELETE FROM gl_journal WHERE site_id='101' AND voucher LIKE 'FA101%';
INSERT INTO gl_journal SELECT * FROM gl_journal_fa_rebase_backup;
-- (catatan: Mei-Jun yang baru di-book ikut terhapus -> kembali ke kondisi awal)

-- (2) MENU (bila sempat di-deploy)
DELETE FROM sysgroupleftmenu WHERE itemid LIKE '62%';
DELETE FROM sysleftmenu WHERE groupid='62';

-- (3) OBJEK MODUL FA (additive — aman di-drop)
IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='v_fa_recon_gl')    THEN DROP VIEW v_fa_recon_gl END IF;
IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='v_fa_recon_asset') THEN DROP VIEW v_fa_recon_asset END IF;
IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE WHERE proc_name='sp_fa_build_gl_link')     THEN DROP PROCEDURE sp_fa_build_gl_link END IF;
IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE WHERE proc_name='sp_fa_rebase_jan_jun')    THEN DROP PROCEDURE sp_fa_rebase_jan_jun END IF;
IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE WHERE proc_name='sp_fa_regenerate_period') THEN DROP PROCEDURE sp_fa_regenerate_period END IF;
IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE WHERE proc_name='sp_fa_post_period')       THEN DROP PROCEDURE sp_fa_post_period END IF;
IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE WHERE proc_name='sp_fa_generate_sl')       THEN DROP PROCEDURE sp_fa_generate_sl END IF;
IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='FA_GL_LINK')      THEN DROP TABLE FA_GL_LINK END IF;
IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='FA_ASSET_AUDIT')  THEN DROP TABLE FA_ASSET_AUDIT END IF;
IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='FA_DEPRECIATION') THEN DROP TABLE FA_DEPRECIATION END IF;
IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='FA_PERIOD')       THEN DROP TABLE FA_PERIOD END IF;
IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='FA_ASSET')        THEN DROP TABLE FA_ASSET END IF;
IF EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='FA_CATEGORY')     THEN DROP TABLE FA_CATEGORY END IF;
COMMIT;
SELECT 'rollback selesai' AS status;
