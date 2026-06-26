-- =====================================================================
-- Tambah 2 menu FA yang belum ter-script: 05 Ringkasan Aktiva, 70 Umur Aktiva
-- Prasyarat: window PB w_rpt_fa_summary & w_rpt_fa_aging SUDAH ada di aplikasi
--            produksi (library fa_reports). Bila belum, JANGAN jalankan (klik = error).
-- Idempotent + reversible:
--   DELETE FROM sysgroupleftmenu WHERE itemid IN ('6205','6270');
--   DELETE FROM sysleftmenu WHERE groupid='62' AND itemid IN ('05','70'); COMMIT;
-- =====================================================================

-- Struktur menu (05 muncul paling atas, 70 paling bawah)
DELETE FROM sysleftmenu WHERE groupid='62' AND itemid IN ('05','70');
INSERT INTO sysleftmenu (groupid,groupdesc,itemid,itemdesc,itemparentid,windowobject,createby,createdate,imageobject) VALUES ('62','Aktiva Tetap','05','Ringkasan Aktiva','62','w_rpt_fa_summary','dba',CURRENT DATE,'Report!');
INSERT INTO sysleftmenu (groupid,groupdesc,itemid,itemdesc,itemparentid,windowobject,createby,createdate,imageobject) VALUES ('62','Aktiva Tetap','70','Umur Aktiva','62','w_rpt_fa_aging','dba',CURRENT DATE,'Report!');

-- Otorisasi: laporan -> cukup view + cetak, ke semua usergroup yang punya akses GL (60)
DELETE FROM sysgroupleftmenu WHERE itemid IN ('6205','6270');
INSERT INTO sysgroupleftmenu (usergroup,itemid,s_view,s_add,s_edit,s_delete,s_cetak,s_alldata,s_koreksi,s_harga,createby,createdate)
SELECT g.usergroup, '62'||m.itemid, 1,0,0,0,1,0,0,0,'dba',CURRENT DATE
FROM (SELECT DISTINCT usergroup FROM sysgroupleftmenu WHERE itemid LIKE '60%') g,
     (SELECT '05' AS itemid UNION ALL SELECT '70') m;
COMMIT;

SELECT 'menu62 items='||CAST((SELECT COUNT(*) FROM sysleftmenu WHERE groupid='62') AS varchar(10))||
       '  grant(6205/6270)='||CAST((SELECT COUNT(*) FROM sysgroupleftmenu WHERE itemid IN ('6205','6270')) AS varchar(10)) AS result;
