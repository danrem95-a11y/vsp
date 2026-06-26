-- =====================================================================
-- FA MENU (SA9-final) — jalankan SAAT PowerBuilder UI FA sudah ter-deploy
-- ke aplikasi produksi (w_fa_category/master/generate, w_rpt_fa_*).
-- Idempotent + reversible. groupid 62 "Aktiva Tetap" (antara GL 60 & Kas 65).
-- Rollback: DELETE FROM sysleftmenu WHERE groupid='62';
--           DELETE FROM sysgroupleftmenu WHERE itemid LIKE '62%'; COMMIT;
-- =====================================================================

-- (1) Struktur menu (boleh dijalankan kapan saja; invisible tanpa grant di bawah)
DELETE FROM sysleftmenu WHERE groupid='62';
INSERT INTO sysleftmenu (groupid,groupdesc,itemid,itemdesc,itemparentid,windowobject,createby,createdate,imageobject) VALUES ('62','Aktiva Tetap','10','Master Kategori Aktiva','62','w_fa_category','dba',CURRENT DATE,'CreateLibrary!');
INSERT INTO sysleftmenu (groupid,groupdesc,itemid,itemdesc,itemparentid,windowobject,createby,createdate,imageobject) VALUES ('62','Aktiva Tetap','20','Master Aktiva Tetap','62','w_fa_master','dba',CURRENT DATE,'Custom076!');
INSERT INTO sysleftmenu (groupid,groupdesc,itemid,itemdesc,itemparentid,windowobject,createby,createdate,imageobject) VALUES ('62','Aktiva Tetap','30','Generate Penyusutan','62','w_fa_generate','dba',CURRENT DATE,'formatdollar!');
INSERT INTO sysleftmenu (groupid,groupdesc,itemid,itemdesc,itemparentid,windowobject,createby,createdate,imageobject) VALUES ('62','Aktiva Tetap','40','Daftar Aktiva Tetap','62','w_rpt_fa_register','dba',CURRENT DATE,'Report!');
INSERT INTO sysleftmenu (groupid,groupdesc,itemid,itemdesc,itemparentid,windowobject,createby,createdate,imageobject) VALUES ('62','Aktiva Tetap','50','Kartu Aktiva','62','w_rpt_fa_card','dba',CURRENT DATE,'Report!');
INSERT INTO sysleftmenu (groupid,groupdesc,itemid,itemdesc,itemparentid,windowobject,createby,createdate,imageobject) VALUES ('62','Aktiva Tetap','60','Rekap Penyusutan','62','w_rpt_fa_rekap','dba',CURRENT DATE,'Report!');

-- (2) AKTIVASI / OTORISASI — JALANKAN HANYA SETELAH UI PB SIAP.
--     Grant 6 item FA ke semua usergroup yang sudah punya akses GL (group 60).
DELETE FROM sysgroupleftmenu WHERE itemid LIKE '62%';
INSERT INTO sysgroupleftmenu (usergroup,itemid,s_view,s_add,s_edit,s_delete,s_cetak,s_alldata,s_koreksi,s_harga,createby,createdate)
SELECT g.usergroup, '62'||m.itemid, 1,1,1,1,1,0,0,0,'dba',CURRENT DATE
FROM (SELECT DISTINCT usergroup FROM sysgroupleftmenu WHERE itemid LIKE '60%') g,
     (SELECT '10' AS itemid UNION ALL SELECT '20' UNION ALL SELECT '30'
      UNION ALL SELECT '40' UNION ALL SELECT '50' UNION ALL SELECT '60') m;
COMMIT;

SELECT 'sysleftmenu(62)='||CAST((SELECT COUNT(*) FROM sysleftmenu WHERE groupid='62') AS varchar(10))||
       '  grant(62)='||CAST((SELECT COUNT(*) FROM sysgroupleftmenu WHERE itemid LIKE '62%') AS varchar(10)) AS result;
