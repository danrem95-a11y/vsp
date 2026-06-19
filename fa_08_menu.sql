-- Add Fixed Asset navigation menu (data-driven left menu).
-- Idempotent + reversible (rollback: DELETE FROM sysleftmenu WHERE groupid='62';
--                                   DELETE FROM sysgroupleftmenu WHERE itemid LIKE '62%';)
-- groupid 62 = "Aktiva Tetap", placed between General Ledger (60) and Kas & Bank (65).

DELETE FROM sysleftmenu WHERE groupid = '62';
INSERT INTO sysleftmenu (groupid,groupdesc,itemid,itemdesc,itemparentid,windowobject,createby,createdate,imageobject) VALUES
 ('62','Aktiva Tetap','10','Master Kategori Aktiva','62','w_fa_category','dba',today(),'CreateLibrary!');
INSERT INTO sysleftmenu (groupid,groupdesc,itemid,itemdesc,itemparentid,windowobject,createby,createdate,imageobject) VALUES
 ('62','Aktiva Tetap','20','Master Aktiva Tetap','62','w_fa_master','dba',today(),'Custom076!');
INSERT INTO sysleftmenu (groupid,groupdesc,itemid,itemdesc,itemparentid,windowobject,createby,createdate,imageobject) VALUES
 ('62','Aktiva Tetap','30','Generate Penyusutan','62','w_fa_generate','dba',today(),'formatdollar!');
INSERT INTO sysleftmenu (groupid,groupdesc,itemid,itemdesc,itemparentid,windowobject,createby,createdate,imageobject) VALUES
 ('62','Aktiva Tetap','40','Daftar Aktiva Tetap','62','w_rpt_fa_register','dba',today(),'Report!');
INSERT INTO sysleftmenu (groupid,groupdesc,itemid,itemdesc,itemparentid,windowobject,createby,createdate,imageobject) VALUES
 ('62','Aktiva Tetap','50','Kartu Aktiva','62','w_rpt_fa_card','dba',today(),'Report!');
INSERT INTO sysleftmenu (groupid,groupdesc,itemid,itemdesc,itemparentid,windowobject,createby,createdate,imageobject) VALUES
 ('62','Aktiva Tetap','60','Rekap Penyusutan','62','w_rpt_fa_rekap','dba',today(),'Report!');

-- Authorization: grant the 6 FA items to every usergroup that can already see General Ledger (group 60).
DELETE FROM sysgroupleftmenu WHERE itemid LIKE '62%';
INSERT INTO sysgroupleftmenu
 (usergroup,itemid,s_view,s_add,s_edit,s_delete,s_cetak,s_alldata,s_koreksi,s_harga,createby,createdate)
SELECT g.usergroup, '62'||m.itemid, 1,1,1,1,1,0,0,0,'dba',today()
FROM (SELECT DISTINCT usergroup FROM sysgroupleftmenu WHERE itemid LIKE '60%') g,
     (SELECT '10' AS itemid UNION ALL SELECT '20' UNION ALL SELECT '30'
      UNION ALL SELECT '40' UNION ALL SELECT '50' UNION ALL SELECT '60') m;

COMMIT;
SELECT 'sysleftmenu(62)='||CAST((SELECT COUNT(*) FROM sysleftmenu WHERE groupid='62') AS varchar)||
       '  sysgroupleftmenu(62%)='||CAST((SELECT COUNT(*) FROM sysgroupleftmenu WHERE itemid LIKE '62%') AS varchar) AS result;
