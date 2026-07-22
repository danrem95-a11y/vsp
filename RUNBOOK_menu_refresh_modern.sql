-- ============================================================================
-- RUNBOOK: Daftarkan window w_refresh_transaksi_modern ke menu + grant akses
-- DB: vspnew (SA9), DSN=vsp dba/jakarta.  Additive & reversible.
-- ----------------------------------------------------------------------------
-- Fakta (hasil probe DB):
--   sysleftmenu group 60 (General Ledger) item: 01,05,06,10(Refresh->w_refresh_journal),20,25
--   Grant table = sysgroupleftmenu ; itemid encoding = groupid||itemid ; Refresh = '6010'
--   Slot baru dipilih: sysleftmenu (60,'13')  ->  grant '6013'  (bebas di menu & grant)
--   Grant '6010' dipegang 6 user: ADMIN,FIYANA,SELLA,SHIANY,SUPER,WIRA (flag di-mirror persis)
-- ============================================================================

-- 1) Item menu baru (sisip setelah 'Refresh Transaksi' 60|10, sebelum 'Reporting' 60|20)
INSERT INTO sysleftmenu
   (groupid,groupdesc,itemid,itemdesc,itemparentid,windowobject,
    createby,createdate,modifyby,modifydate,imageobject)
VALUES
   ('60','General Ledger','13','Refresh Transaksi (Modern)','60','w_refresh_transaksi_modern',
    'ADMIN',CURRENT DATE,'ADMIN',CURRENT DATE,'');

-- 2) Grant: MIRROR persis grant Refresh lama ('6010') ke item baru ('6013')
--    (flag s_view/add/edit/delete/cetak/alldata/koreksi/harga identik per user)
INSERT INTO sysgroupleftmenu
   (usergroup,itemid,s_view,s_add,s_edit,s_delete,
    createby,createdate,modifyby,modifydate,s_cetak,s_alldata,s_koreksi,s_harga)
SELECT
    usergroup,'6013',s_view,s_add,s_edit,s_delete,
    'ADMIN',CURRENT DATE,'ADMIN',CURRENT DATE,s_cetak,s_alldata,s_koreksi,s_harga
FROM sysgroupleftmenu
WHERE itemid = '6010';

COMMIT;

-- 3) Verifikasi
SELECT groupid,itemid,itemdesc,windowobject FROM sysleftmenu WHERE groupid='60' ORDER BY itemid;
SELECT usergroup,itemid,s_view,s_add,s_edit,s_delete,s_cetak
FROM sysgroupleftmenu WHERE itemid IN ('6010','6013') ORDER BY itemid,usergroup;

-- ----------------------------------------------------------------------------
-- ROLLBACK / CLEANUP (kalau perlu batalkan):
--   DELETE FROM sysgroupleftmenu WHERE itemid='6013';
--   DELETE FROM sysleftmenu WHERE groupid='60' AND itemid='13';
--   COMMIT;
-- ============================================================================
