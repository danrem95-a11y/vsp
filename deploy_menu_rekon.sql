-- ============================================================================
--  MENU ENTRY — Dashboard Rekonsiliasi  (tabel: sysleftmenu)
--  Kolom: groupid(char20,key) groupdesc(char50) itemid(char20,key)
--         itemdesc(char50) itemparentid(char10) windowobject(char225)
--         createby(char10) createdate(date) modifyby(char10) modifydate(date)
--         imageobject(char100)
--  Jalankan LANGKAH 1 dulu untuk melihat pola group/parent existing,
--  lalu sesuaikan nilai di LANGKAH 2 sebelum commit.
-- ============================================================================

-- LANGKAH 1 — inspeksi menu existing (pilih groupid & itemparentid yang tepat)
SELECT groupid, groupdesc, itemid, itemparentid, itemdesc, windowobject
FROM   sysleftmenu
ORDER BY groupid, itemparentid, itemid;

-- LANGKAH 2 — tambah entri Dashboard Rekonsiliasi
--   Ganti <GROUPID>, <GROUPDESC>, <PARENTID> sesuai hasil LANGKAH 1.
--   Jika menu dua level: buat 1 header (itemparentid='') + 1 anak (window).
--   windowobject WAJIB = 'w_rekon_dashboard'.

-- (2a) opsional: header group "Rekonsiliasi" (lewati bila sudah ada group cocok)
INSERT INTO sysleftmenu
  (groupid, groupdesc, itemid, itemdesc, itemparentid, windowobject, imageobject, createby, createdate)
SELECT '<GROUPID>', '<GROUPDESC>', 'REKON_HDR', 'Rekonsiliasi', '', '', '', 'ADMIN', CURRENT DATE
FROM   dummy
WHERE  NOT EXISTS (SELECT 1 FROM sysleftmenu WHERE itemid = 'REKON_HDR');

-- (2b) item dashboard (membuka w_rekon_dashboard)
INSERT INTO sysleftmenu
  (groupid, groupdesc, itemid, itemdesc, itemparentid, windowobject, imageobject, createby, createdate)
SELECT '<GROUPID>', '<GROUPDESC>', 'REKON_DASH', 'Dashboard Rekonsiliasi', 'REKON_HDR',
       'w_rekon_dashboard', '', 'ADMIN', CURRENT DATE
FROM   dummy
WHERE  NOT EXISTS (SELECT 1 FROM sysleftmenu WHERE itemid = 'REKON_DASH');

-- LANGKAH 3 — HAK AKSES (WAJIB, kalau tidak menu TAK TAMPIL walau ada di sysleftmenu)
--   Menu runtime difilter tabel sysgroupleftmenu(usergroup, itemid, s_view,...).
--   PENTING: itemid di sysgroupleftmenu = GABUNGAN groupid || itemid
--            (mis. group '61' + item '10' => '6110').  usergroup = USERID.
--   Grant 3 item rekon ke semua usergroup (read-only + cetak). Idempotent.
INSERT INTO sysgroupleftmenu
  (usergroup, itemid, s_view, s_add, s_edit, s_delete, s_cetak, s_alldata, s_koreksi, s_harga, createby, createdate)
SELECT u.usergroup, i.itemid, 1,0,0,0,1,1,0,0, 'dba', CURRENT DATE
FROM   ( SELECT DISTINCT usergroup FROM sysgroupleftmenu ) u,
       ( SELECT '6110' AS itemid FROM dummy
         UNION ALL SELECT '6120' FROM dummy
         UNION ALL SELECT '6130' FROM dummy ) i
WHERE  NOT EXISTS ( SELECT 1 FROM sysgroupleftmenu g
                    WHERE g.usergroup = u.usergroup AND g.itemid = i.itemid );
-- (PROD: bila ingin dibatasi, ganti daftar usergroup dg grup finance/admin saja.)

-- verifikasi lalu COMMIT
SELECT groupid, itemid, itemparentid, itemdesc, windowobject
FROM   sysleftmenu WHERE groupid='61';
SELECT usergroup, itemid, s_view FROM sysgroupleftmenu WHERE itemid IN ('6110','6120','6130');
-- COMMIT;
-- >>> Setelah commit: user LOGOUT/LOGIN ulang agar menu ter-refresh.
