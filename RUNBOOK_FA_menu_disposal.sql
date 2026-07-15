-- =====================================================================
-- Menu kiri Disposal Aktiva Tetap -> window w_fa_disposal (group 62 "AKTIVA TETAP (FA)").
-- 2 bagian: (A) daftar menu sysleftmenu, (B) hak-akses per usergroup sysgroupleftmenu.
-- Idempotent (aman dijalankan ulang). Jalankan di dbisql, lalu login ulang aplikasi.
-- =====================================================================

-- (A) Item menu: itemid '35' (di antara Generate '30' & Daftar '40').
IF NOT EXISTS(SELECT 1 FROM sysleftmenu WHERE groupid=62 AND itemid='35') THEN
  INSERT INTO sysleftmenu (groupid, groupdesc, itemid, itemdesc, itemparentid, windowobject, createby, createdate, imageobject)
  SELECT groupid, groupdesc, '35', 'Disposal Aktiva Tetap', itemparentid, 'w_fa_disposal', 'dba', CURRENT TIMESTAMP, 'Delete!'
    FROM sysleftmenu WHERE groupid=62 AND itemid='30';
END IF;
COMMIT;

-- (B) Hak-akses: key = groupid||itemid = '6235'. Disalin dari '6230' (Generate Penyusutan)
--     sehingga usergroup & flag (view/add/edit/delete/cetak) sama persis. INILAH yg bikin menu MUNCUL.
IF NOT EXISTS(SELECT 1 FROM sysgroupleftmenu WHERE itemid='6235') THEN
  INSERT INTO sysgroupleftmenu (usergroup, itemid, s_view, s_add, s_edit, s_delete, createby, createdate, s_cetak, s_alldata, s_koreksi, s_harga)
  SELECT usergroup, '6235', s_view, s_add, s_edit, s_delete, 'dba', CURRENT TIMESTAMP, s_cetak, s_alldata, s_koreksi, s_harga
    FROM sysgroupleftmenu WHERE itemid='6230';
END IF;
COMMIT;

-- Verifikasi:
SELECT groupid, itemid, itemdesc, windowobject FROM sysleftmenu WHERE groupid=62 ORDER BY itemid;
SELECT usergroup, itemid, s_view, s_add, s_edit, s_delete, s_cetak FROM sysgroupleftmenu WHERE itemid='6235' ORDER BY usergroup;

-- Rollback (bila perlu):
-- DELETE FROM sysleftmenu      WHERE groupid=62 AND itemid='35';
-- DELETE FROM sysgroupleftmenu WHERE itemid='6235';
-- COMMIT;
