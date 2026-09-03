-- =====================================================================
-- MENU: "Tarik Aktiva dari Pembelian"  (window w_fa_pull_purchase)
-- Tambah item di grup menu 62 = "AKTIVA TETAP (FA)", item 25
--   (urutan pas: 20 Master Aktiva -> 25 Tarik dari Pembelian -> 30 Generate Penyusutan)
-- + GRANT ke SEMUA user-group supaya muncul di semua user.
--
-- Pola terkonfirmasi dari prod:
--   sysleftmenu(groupid,itemid,itemdesc,itemparentid,windowobject,...)  -> definisi item
--   sysgroupleftmenu(usergroup, itemid = groupid||itemid, s_view/add/edit/delete/cetak/... bit) -> hak akses
--   contoh: w_fa_generate = grup 62 item 30 -> sysgroupleftmenu.itemid '6230'
--   -> item baru grup 62 item 25 -> sysgroupleftmenu.itemid '6225'
--   Tidak ada grant level-grup; grup tampil otomatis bila ada item ter-grant.
--
-- URUTAN: jalankan SESUDAH w_fa_pull_purchase di-import & Full Build & deploy EXE.
-- Menu dibaca saat LOGIN -> user harus login ulang untuk melihat menu baru.
-- Idempotent (delete-first). Aditif saja (tak sentuh menu lain). Jalankan di dbisql (dba).
-- =====================================================================

-- (idempotent) hapus bila sudah pernah ditambah
delete from sysgroupleftmenu where itemid = '6225';
delete from sysleftmenu       where groupid = '62' and itemid = '25';
commit;

-- 1) ITEM MENU  (meniru groupdesc + imageobject dari 'Generate Penyusutan' = 62/30)
insert into sysleftmenu(groupid,groupdesc,itemid,itemdesc,itemparentid,windowobject,createby,createdate,imageobject)
select '62', groupdesc, '25', 'Tarik Aktiva dari Pembelian', '62', 'w_fa_pull_purchase', 'SUPER', current date, imageobject
  from sysleftmenu where groupid='62' and itemid='30';
commit;

-- 2) GRANT ke SEMUA user-group (s_view=lihat + aksi add/edit/delete/cetak; alldata/koreksi/harga=0, pola FA)
insert into sysgroupleftmenu(usergroup,itemid,s_view,s_add,s_edit,s_delete,s_cetak,s_alldata,s_koreksi,s_harga,createby,createdate)
select ug, '6225', 1,1,1,1,1,0,0,0, 'SUPER', current date
from ( select distinct usergroup ug from sysgroupleftmenu where usergroup is not null and usergroup <> ''
       union
       select distinct usergroup ug from SYS_USER         where usergroup is not null and usergroup <> '' ) x
where not exists(select 1 from sysgroupleftmenu g where g.usergroup = x.ug and g.itemid = '6225');
commit;

-- =========================== VERIFIKASI ===========================
select 'item menu 62/25 ada?' info, count(*) n from sysleftmenu where groupid='62' and itemid='25'
union all
select 'jml group ter-grant 6225', count(*) from sysgroupleftmenu where itemid='6225';
-- daftar group yg bisa lihat:
select usergroup from sysgroupleftmenu where itemid='6225' order by usergroup;

-- =========================== ROLLBACK =============================
-- delete from sysgroupleftmenu where itemid='6225';
-- delete from sysleftmenu where groupid='62' and itemid='25';
-- commit;
