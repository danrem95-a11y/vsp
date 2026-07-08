-- ============================================================================
--  REKON DASHBOARD — FINAL PRODUCTION HARDENING & DEPLOYMENT VALIDATION
--  Target : SQL Anywhere 9 (ASA9) + PowerBuilder 11.5 · DB vspnew
--  Sifat  : VALIDASI (read-only) — tidak mengubah engine/schema/design.
--  Objek diuji (harus SUDAH dideploy):
--    rekon_account_map ; v_gl_mutasi_bulan ; v_gl_opening_tahun ;
--    v_stok_saldo_periode ; v_ap_sisa_vendor ; v_ar_sisa_cust ;
--    v_rekon_stok_final ; v_rekon_ap_final ; v_rekon_ar_final ;
--    v_rekon_gl_bridge ; v_rekon_summary_kpi ; rekon_snapshot_v2 ;
--    sp_rekon_anomali ; sp_rekon_snapshot_build.
--  Konvensi hasil: setiap query "PASS = 0 baris" atau "PASS = status kolom".
--  Akun kontrol TIDAK ditulis literal — selalu dari gl_setup / rekon_account_map.
-- ============================================================================


-- ############################################################################
-- TASK 1 — DEPLOYMENT READINESS VALIDATION (SQL)
-- ############################################################################

-- 1.1  SEMUA OBJEK REKON ADA (view + procedure) — hasil harus 14 baris 'OK'
SELECT 'VIEW' AS obj_type, t.table_name, 'OK' AS status
FROM   SYS.SYSTABLE t
WHERE  t.table_type = 'VIEW'
  AND  t.table_name IN ('v_gl_mutasi_bulan','v_gl_opening_tahun',
        'v_stok_saldo_periode','v_ap_sisa_vendor','v_ar_sisa_cust',
        'v_rekon_stok_final','v_rekon_ap_final','v_rekon_ar_final',
        'v_rekon_gl_bridge','v_rekon_summary_kpi')
UNION ALL
SELECT 'TABLE', t.table_name, 'OK'
FROM   SYS.SYSTABLE t
WHERE  t.table_type = 'BASE'
  AND  t.table_name IN ('rekon_account_map','rekon_snapshot_v2')
UNION ALL
SELECT 'PROC', p.proc_name, 'OK'
FROM   SYS.SYSPROCEDURE p
WHERE  p.proc_name IN ('sp_rekon_anomali','sp_rekon_snapshot_build')
ORDER BY 1,2;
-- >>> Jika < 14 baris: ada objek belum dideploy. STOP, deploy dulu (TASK 6).

-- 1.2  SMOKE TEST — setiap view bisa di-SELECT tanpa error (jalankan 1/1)
SELECT COUNT(*) AS n FROM v_gl_mutasi_bulan;
SELECT COUNT(*) AS n FROM v_gl_opening_tahun;
SELECT COUNT(*) AS n FROM v_stok_saldo_periode;
SELECT COUNT(*) AS n FROM v_ap_sisa_vendor;
SELECT COUNT(*) AS n FROM v_ar_sisa_cust;
SELECT COUNT(*) AS n FROM v_rekon_stok_final;
SELECT COUNT(*) AS n FROM v_rekon_ap_final;
SELECT COUNT(*) AS n FROM v_rekon_ar_final;
SELECT COUNT(*) AS n FROM v_rekon_gl_bridge;
SELECT COUNT(*) AS n FROM v_rekon_summary_kpi;
-- >>> PASS = semua eksekusi sukses (angka apa pun). Error = kolom/skema mismatch.

-- 1.3  DW SOURCE COLUMN MATCH — kolom yang di-bind DW harus ada di view/tabel.
--      PASS = setiap pasangan (objek,kolom) mengembalikan tepat 1 baris.
SELECT o.obj, o.col,
       CASE WHEN EXISTS ( SELECT 1 FROM SYS.SYSCOLUMN c JOIN SYS.SYSTABLE t
                          ON t.table_id = c.table_id
                          WHERE t.table_name = o.obj AND c.column_name = o.col )
            THEN 'OK' ELSE 'MISSING' END AS status
FROM ( SELECT 'rekon_snapshot_v2' AS obj, 'gate1_status' AS col FROM SYS.DUMMY
       UNION ALL SELECT 'rekon_snapshot_v2','gate2_status' FROM SYS.DUMMY
       UNION ALL SELECT 'rekon_snapshot_v2','gate3_status' FROM SYS.DUMMY
       UNION ALL SELECT 'rekon_snapshot_v2','subledger_total' FROM SYS.DUMMY
       UNION ALL SELECT 'rekon_snapshot_v2','ledger_total' FROM SYS.DUMMY
       UNION ALL SELECT 'rekon_snapshot_v2','selisih' FROM SYS.DUMMY
       UNION ALL SELECT 'v_rekon_gl_bridge','voucher' FROM SYS.DUMMY
       UNION ALL SELECT 'v_rekon_gl_bridge','voucher_manual' FROM SYS.DUMMY
       UNION ALL SELECT 'v_rekon_gl_bridge','anchor_type' FROM SYS.DUMMY
       UNION ALL SELECT 'v_rekon_gl_bridge','has_subledger' FROM SYS.DUMMY
       UNION ALL SELECT 'v_rekon_stok_final','subledger_value' FROM SYS.DUMMY
       UNION ALL SELECT 'v_rekon_stok_final','selisih' FROM SYS.DUMMY
       UNION ALL SELECT 'v_ap_sisa_vendor','vendor_id' FROM SYS.DUMMY
       UNION ALL SELECT 'v_ar_sisa_cust','cust_id' FROM SYS.DUMMY ) o
WHERE  NOT EXISTS ( SELECT 1 FROM SYS.SYSCOLUMN c JOIN SYS.SYSTABLE t
                    ON t.table_id = c.table_id
                    WHERE t.table_name = o.obj AND c.column_name = o.col );
-- >>> PASS = 0 baris (semua kolom ada). Baris apa pun = MISSING → perbaiki bind.

-- 1.4  JOIN via rekon_account_map AKTIF — tiap domain punya minimal 1 akun aktif.
--      PASS = 3 baris (STOK/AP/AR) dengan n_akun > 0.
SELECT m.domain, COUNT(*) AS n_akun_aktif
FROM   rekon_account_map m
WHERE  m.is_active = 'Y'
GROUP BY m.domain
HAVING COUNT(*) > 0
ORDER BY m.domain;

-- 1.5  NO HARDCODE COA di query layer — view_def TIDAK boleh memuat akun kontrol
--      literal (harus lewat map). PASS = 0 baris.
SELECT t.table_name AS view_with_hardcoded_coa
FROM   SYS.SYSTABLE t
WHERE  t.table_type = 'VIEW'
  AND  t.table_name LIKE 'v_rekon%'
  AND  ( t.view_def LIKE '%'''||(SELECT MAX(acc_ap) FROM gl_setup)||'''%'
      OR t.view_def LIKE '%'''||(SELECT MAX(acc_ar) FROM gl_setup)||'''%'
      OR t.view_def LIKE '%'''||(SELECT MAX(acc_biaya_ekpedisi) FROM gl_setup)||'''%' );
-- >>> PASS = 0. Jika ada: view memuat akun literal → refactor ke map.

-- 1.6  SEMUA VOUCHER (baris GL ber-akun-map, posting='P') RESOLVE ke gl_bridge.
--      PASS = 0 baris.
SELECT j.account_id, j.voucher, j.tgl
FROM   gl_journal j
JOIN   rekon_account_map m
       ON  m.account_id = j.account_id AND m.is_active = 'Y'
       AND (m.site_id = '*' OR m.site_id = j.site_id)
       AND j.tgl >= m.effective_from
       AND (m.effective_to IS NULL OR j.tgl <= m.effective_to)
WHERE  j.posting = 'P'
  AND  NOT EXISTS ( SELECT 1 FROM v_rekon_gl_bridge b
                    WHERE b.account_id = j.account_id
                      AND b.voucher = j.voucher AND b.tgl = j.tgl );
-- >>> PASS = 0 (bridge meng-cover semua baris GL ber-map).


-- ############################################################################
-- TASK 2 — WINDOW DEPLOYMENT SPEC FINAL CHECK  (checklist + SQL pendukung)
-- ############################################################################
-- Struktur window (7) — validasi manual saat import PB, dibantu SQL 2.x.
--
-- | window                 | DataWindow(s)                    | source objek        | :arg_* binding                          | calc di PB? | filter config-driven |
-- |------------------------|----------------------------------|---------------------|-----------------------------------------|-------------|----------------------|
-- | w_rekon_dashboard      | dw_rekon_summary,(snapshot_v2)   | rekon_snapshot_v2   | :arg_periode                            | TIDAK       | ddw_domain/site/period (map/snapshot) |
-- | w_rekon_ap             | dw_rekon_ap_final                | v_ap_sisa_vendor    | :arg_thn,:arg_bln                       | TIDAK       | via view (map)       |
-- | w_rekon_ar             | dw_rekon_ar_final                | v_ar_sisa_cust      | :arg_thn,:arg_bln                       | TIDAK       | via view (map)       |
-- | w_rekon_stok           | dw_rekon_stok_final              | v_rekon_stok_final  | :arg_thn,:arg_bln                       | TIDAK       | via view (map)       |
-- | w_rekon_voucher_detail | dw_rekon_detail_voucher,gl_bridge| opname + v_rekon_gl_bridge | :arg_domain,:arg_entity,:arg_thn,:arg_bln | TIDAK  | via view/opname      |
-- | w_rekon_anomali        | dw_rekon_anomali (Stored Proc)   | sp_rekon_anomali    | :arg_domain,:arg_thn,:arg_bln           | TIDAK       | param domain (map)   |
-- | w_rekon_snapshot       | dw_rekon_snapshot_v2             | rekon_snapshot_v2   | :arg_domain,:arg_per1,:arg_per2         | TIDAK       | param periode        |
--
-- Aturan lulus per window:
--   (a) DataWindow.Object.DataWindow source = view/proc/tabel di TASK1.1 (bukan tabel transaksi mentah).
--   (b) Semua Retrieve() membawa argumen :arg_* (tak ada retrieve tanpa filter periode).
--   (c) Tidak ada Compute/Expression yang MENGHITUNG ulang subledger/ledger/selisih
--       (format & pewarnaan boleh; agregasi/aritmatika saldo TIDAK).
--   (d) Semua dropdown filter dari DDDW config (ddw_domain/site/period), bukan enum statik.

-- 2.1  DDDW config source valid (dropdown filter) — PASS = 3 baris > 0.
SELECT 'ddw_domain' AS ddw, COUNT(*) AS n FROM (SELECT DISTINCT domain FROM rekon_account_map WHERE is_active='Y') d
UNION ALL
SELECT 'ddw_site',   COUNT(*) FROM (SELECT DISTINCT site_id FROM rekon_account_map WHERE is_active='Y') s
UNION ALL
SELECT 'ddw_period', COUNT(*) FROM (SELECT DISTINCT periode FROM rekon_snapshot_v2) p;
-- >>> ddw_period=0 berarti snapshot belum dibangun (jalankan sp_rekon_snapshot_build).

-- 2.2  Entity key untuk drill tersedia (vendor/cust/account) — PASS = tidak error.
SELECT 'AP_ENTITY' AS k, COUNT(DISTINCT vendor_id) AS n FROM v_ap_sisa_vendor
UNION ALL SELECT 'AR_ENTITY', COUNT(DISTINCT cust_id) FROM v_ar_sisa_cust
UNION ALL SELECT 'STOK_ENTITY', COUNT(DISTINCT account_id) FROM v_rekon_stok_final;


-- ############################################################################
-- TASK 3 — DATA INTEGRITY FINAL GATE (PRE-PROD)  — GATE A / B / C
--   Parameter periode: ganti :arg_thn / :arg_bln saat eksekusi (host var PB).
-- ############################################################################

-- ---------------------------------------------------------------------------
-- GATE A — ENGINE vs SNAPSHOT : v_rekon_summary_kpi == rekon_snapshot_v2
--   PASS = 0 baris (tak ada domain dg selisih engine-vs-snapshot > 10).
-- ---------------------------------------------------------------------------
SELECT k.domain,
       k.subledger_total AS kpi_sub, s.subledger_total AS snap_sub,
       k.ledger_total    AS kpi_led, s.ledger_total    AS snap_led,
       k.selisih         AS kpi_sel, s.selisih         AS snap_sel
FROM   v_rekon_summary_kpi k
JOIN   rekon_snapshot_v2 s
       ON  s.domain  = k.domain
       AND s.periode = CAST(STRING(k.thn,'-',RIGHT('0'||STRING(k.bln),2),'-01') AS DATE)
WHERE  k.thn = :arg_thn AND k.bln = :arg_bln
  AND  ( ABS(ISNULL(k.subledger_total,0) - ISNULL(s.subledger_total,0)) > 10
      OR ABS(ISNULL(k.ledger_total,0)    - ISNULL(s.ledger_total,0))    > 10
      OR ABS(ISNULL(k.selisih,0)         - ISNULL(s.selisih,0))         > 10 );

-- ---------------------------------------------------------------------------
-- GATE B — SUBLEDGER vs GL TRACE : setiap voucher subledger resolve ke gl_bridge.
--   Sisa yang TIDAK resolve WAJIB terjelaskan sp_rekon_anomali (R9/R11), else FAIL.
--   PASS = 0 baris.
-- ---------------------------------------------------------------------------
-- B-AR : pembayaran (voucher_manual) ter-anchor AR tapi tak ada di bridge & bukan anomali
SELECT 'B_AR' AS gate, t1.voucher_manual
FROM   tbyr1 t1 JOIN tbyr2 t2 ON t2.voucher = t1.voucher
WHERE  t1.flag_bayar IN (1,2)
  AND  YEAR(t1.tgl) = :arg_thn AND MONTH(t1.tgl) <= :arg_bln
  AND  EXISTS ( SELECT 1 FROM ar_trans a WHERE a.order_client = t2.bukti_id )
  AND  NOT EXISTS ( SELECT 1 FROM v_rekon_gl_bridge b
                    WHERE b.voucher_manual = t1.voucher_manual )
  AND  NOT EXISTS ( SELECT 1 FROM gl_journal gj
                    WHERE gj.voucher_manual = t1.voucher_manual AND gj.modul_id = 'CI'
                      AND gj.account_id IN ( SELECT m.account_id FROM rekon_account_map m
                                             WHERE m.domain='AR' AND m.is_active='Y' ) )
GROUP BY t1.voucher_manual
UNION ALL
-- B-AP : simetris (modul CO)
SELECT 'B_AP', t1.voucher_manual
FROM   tbyr1 t1 JOIN tbyr2 t2 ON t2.voucher = t1.voucher
WHERE  t1.flag_bayar IN (1,2)
  AND  YEAR(t1.tgl) = :arg_thn AND MONTH(t1.tgl) <= :arg_bln
  AND  EXISTS ( SELECT 1 FROM ap_trans p WHERE p.order_client = t2.bukti_id )
  AND  NOT EXISTS ( SELECT 1 FROM v_rekon_gl_bridge b
                    WHERE b.voucher_manual = t1.voucher_manual )
  AND  NOT EXISTS ( SELECT 1 FROM gl_journal gj
                    WHERE gj.voucher_manual = t1.voucher_manual AND gj.modul_id = 'CO'
                      AND gj.account_id IN ( SELECT m.account_id FROM rekon_account_map m
                                             WHERE m.domain='AP' AND m.is_active='Y' ) );
-- >>> Catatan: voucher DP (R11) tetap MUNCUL sbg anomali di sp_rekon_anomali; GATE B
--     hanya FAIL bila ada voucher yg TIDAK di bridge DAN TIDAK terjelaskan (di luar R11/R9).

-- B-INVOICE : faktur AR/AP (anchor) tanpa baris GL di bridge → wajib 0.
SELECT 'B_INV_AR' AS gate, a.order_client AS voucher
FROM   ar_trans a
WHERE  a.order_oke = 'Y' AND a.tipe_trans IN ('22','32','33','26','36')
  AND  YEAR(a.tgl) = :arg_thn AND MONTH(a.tgl) <= :arg_bln
  AND  NOT EXISTS ( SELECT 1 FROM v_rekon_gl_bridge b WHERE b.voucher = a.order_client )
GROUP BY a.order_client
UNION ALL
SELECT 'B_INV_AP', p.order_client
FROM   ap_trans p
WHERE  p.order_oke = 'Y' AND p.tipe_trans IN ('02','05','12','06','16')
  AND  YEAR(p.tgl) = :arg_thn AND MONTH(p.tgl) <= :arg_bln
  AND  NOT EXISTS ( SELECT 1 FROM v_rekon_gl_bridge b WHERE b.voucher = p.order_client )
GROUP BY p.order_client;
-- >>> PASS = 0 (semua faktur ber-anchor GL).

-- ---------------------------------------------------------------------------
-- GATE C — CONFIG CONSISTENCY : GL account aktif harus ter-map; no orphan map.
-- ---------------------------------------------------------------------------
-- C1 : akun GL ber-aktivitas AP/AR-anchored TAPI belum ter-map. PASS = 0.
SELECT 'C1_UNMAPPED' AS gate, j.account_id, COUNT(*) AS n_baris
FROM   gl_journal j
WHERE  j.posting = 'P'
  AND  ( EXISTS ( SELECT 1 FROM ap_trans p WHERE p.order_client = j.voucher AND j.kredit > 0 )
      OR EXISTS ( SELECT 1 FROM ar_trans a WHERE a.order_client = j.voucher AND j.debet  > 0 ) )
  AND  NOT EXISTS ( SELECT 1 FROM rekon_account_map m
                    WHERE m.account_id = j.account_id AND m.is_active = 'Y' )
GROUP BY j.account_id
HAVING COUNT(*) >= 5;
-- C2 : akun persediaan (im_product_group) belum ter-map. PASS = 0.
SELECT 'C2_STOK_UNMAPPED' AS gate, g.persediaan AS account_id
FROM   im_product_group g
WHERE  ISNULL(g.persediaan,'') <> ''
  AND  NOT EXISTS ( SELECT 1 FROM rekon_account_map m
                    WHERE m.domain='STOK' AND m.account_id = g.persediaan AND m.is_active='Y' )
GROUP BY g.persediaan;
-- C3 : ORPHAN MAP — map aktif tapi tak pernah muncul di GL. PASS = 0.
SELECT 'C3_ORPHAN_MAP' AS gate, m.domain, m.account_id
FROM   rekon_account_map m
WHERE  m.is_active = 'Y'
  AND  NOT EXISTS ( SELECT 1 FROM gl_journal j WHERE j.account_id = m.account_id )
  AND  NOT EXISTS ( SELECT 1 FROM gl_balance b WHERE b.AccountCode = m.account_id );
-- C4 : OVERLAP effective-date (duplikasi mapping tumpang-tindih). PASS = 0.
SELECT 'C4_OVERLAP' AS gate, a.domain, a.account_id, a.site_id
FROM   rekon_account_map a
JOIN   rekon_account_map b
       ON  b.domain=a.domain AND b.account_type=a.account_type
       AND b.account_id=a.account_id AND b.site_id=a.site_id
       AND b.effective_from > a.effective_from
WHERE  a.is_active='Y' AND b.is_active='Y'
  AND  (a.effective_to IS NULL OR b.effective_from <= a.effective_to);


-- ############################################################################
-- TASK 4 — PERFORMANCE FINAL HARDENING
-- ############################################################################

-- 4.1  INDEX VALIDATION CHECKLIST — index wajib harus ADA. PASS = 0 baris.
SELECT req.idx AS index_hilang
FROM ( SELECT 'idx_gljrn_acc_tgl_post' AS idx FROM SYS.DUMMY
       UNION ALL SELECT 'idx_gljrn_voucher'   FROM SYS.DUMMY
       UNION ALL SELECT 'idx_gljrn_vmanual'   FROM SYS.DUMMY
       UNION ALL SELECT 'idx_sinv_per_stok'   FROM SYS.DUMMY
       UNION ALL SELECT 'idx_saf_bukti'       FROM SYS.DUMMY
       UNION ALL SELECT 'idx_aptrans_order'   FROM SYS.DUMMY
       UNION ALL SELECT 'idx_artrans_order'   FROM SYS.DUMMY
       UNION ALL SELECT 'idx_tbyr2_bukti'     FROM SYS.DUMMY
       UNION ALL SELECT 'idx_tbyr1_voucher'   FROM SYS.DUMMY
       UNION ALL SELECT 'idx_tbyr1_vmanual'   FROM SYS.DUMMY
       UNION ALL SELECT 'idx_ram_acc_site'    FROM SYS.DUMMY
       UNION ALL SELECT 'idx_ram_domain'      FROM SYS.DUMMY ) req
WHERE  NOT EXISTS ( SELECT 1 FROM SYS.SYSINDEX i WHERE i.index_name = req.idx );
-- >>> Setiap index hilang → buat saat idle (aplikasi memegang SHARE lock luas).

-- 4.2  QUERY EXECUTION RISK POINTS (dokumentatif — cek plan bila retrieve lambat):
--   R1  v_ap_sisa_vendor / v_ar_sisa_cust : 4 UNION + anchor EXISTS gl_journal.
--       Risk = scan gl_journal bila idx_gljrn_voucher hilang. Mitigasi: 4.1.
--   R2  v_rekon_*_final : scalar-subquery kumulatif ke view bulanan (kecil) → aman.
--   R3  v_rekon_gl_bridge : EXISTS ganda (ap_trans/ar_trans/saf/tbyr1) per baris GL.
--       Risk = tanpa idx_aptrans_order/idx_artrans_order/idx_saf_bukti/idx_tbyr1_vmanual.
--   R4  sp_rekon_anomali R11 : join tbyr1+tbyr2 + NOT EXISTS gl_journal by voucher_manual.
--       Wajib idx_gljrn_vmanual + idx_tbyr1_vmanual.

-- 4.3  FULL-SCAN RISK ELIMINATION (aturan):
--   - gl_journal SELALU difilter (account_id, tgl, posting) rentang tgl BETWEEN,
--     JANGAN YEAR(tgl)= pada tabel besar (mematikan index).
--   - Filter akun via subselect map (idx_ram_*), map kecil → nested-loop murah.
--   - Dashboard TIDAK menyentuh view berat → baca snapshot (4.4).
--   - UPDATE STATISTICS gl_journal, sinv, tbyr1, tbyr2, ap_trans, ar_trans setelah index.

-- 4.4  SNAPSHOT-FIRST ENFORCEMENT (NO LIVE CALC di PB):
--   - w_rekon_dashboard & w_rekon_snapshot HANYA membaca rekon_snapshot_v2.
--   - v_rekon_*_final HANYA dijalankan saat build snapshot / drill manual, bukan open.
--   - Build: sp_rekon_snapshot_build(:thn,:bln) pasca closing/refresh (idempotent).

-- 4.5  Verifikasi snapshot terisi untuk periode target (PASS = 3 baris domain).
SELECT s.domain, s.gate1_status, s.gate2_status, s.gate3_status
FROM   rekon_snapshot_v2 s
WHERE  s.periode = CAST(STRING(:arg_thn,'-',RIGHT('0'||STRING(:arg_bln),2),'-01') AS DATE)
ORDER BY s.domain;


-- ############################################################################
-- TASK 5 — POWERBUILDER FINALIZATION RULES (developer — enforce di code review)
-- ############################################################################
-- R-PB-1  DILARANG SELECT langsung ke gl_journal / ap_trans / ar_trans / sinv /
--         tbyr* dari objek window. Semua data via v_rekon_* / snapshot / SP.
-- R-PB-2  Angka saldo/ledger/selisih HANYA dari view/snapshot/SP — TIDAK dihitung
--         ulang di script/Compute Field (format & warna boleh).
-- R-PB-3  Drill-down transaksi HANYA lewat voucher -> v_rekon_gl_bridge
--         (:arg_account,:arg_thn,:arg_bln,:arg_voucher).
-- R-PB-4  Anomali HANYA read sp_rekon_anomali (DataWindow tipe Stored Procedure).
-- R-PB-5  Semua filter parameterized (:arg_* host var); DILARANG literal COA/
--         periode/domain di SQL DataWindow. Dropdown dari DDDW config.
-- R-PB-6  Setiap Retrieve() membawa filter periode (+domain/account/entity).
-- R-PB-7  SetTransObject(SQLCA) sekali; Retrieve ulang saat filter berubah.
--
-- 5.1  AUDIT DEV (jalankan setelah export objek PB ke teks; bukan SQL DB):
--      grep -i "FROM gl_journal|FROM ap_trans|FROM ar_trans|FROM sinv|FROM tbyr"
--           pada *.srw/*.srd window layer  -> HARUS kosong (kecuali dw_rekon_gl_bridge
--           yang sumbernya view, bukan tabel). Referensi tabel mentah = pelanggaran R-PB-1.


-- ############################################################################
-- TASK 6 — DEPLOYMENT ORDER (CRITICAL) + DEPENDENCY
-- ############################################################################
-- Urutan WAJIB (tiap langkah bergantung penuh pada langkah sebelumnya):
--
--  1) rekon_account_map (+idx_ram_*)         [config COA — akar semua view]
--        └─ diisi dari gl_setup + im_product_group (migration idempotent)
--  2) base views:
--        v_gl_mutasi_bulan, v_gl_opening_tahun   (butuh: map, gl_journal, gl_balance)
--        v_stok_saldo_periode                    (butuh: map, sinv, im_produk/group)
--        v_ap_sisa_vendor, v_ar_sisa_cust        (butuh: map, ap/ar_trans, tbyr*, saf, gl_journal)
--  3) v_rekon_stok_final / _ap_final / _ar_final (butuh: base views #2)
--        v_rekon_gl_bridge                       (butuh: map, gl_journal + anchor tabel)
--        v_rekon_summary_kpi                     (butuh: v_rekon_*_final)
--  4) sp_rekon_anomali                           (butuh: map, view, gl_journal, tbyr*)
--  5) rekon_snapshot_v2 (+idx) + sp_rekon_snapshot_build
--                                                (butuh: v_rekon_*_final, kpi)
--  6) index performa TASK4.1 (saat idle) + UPDATE STATISTICS
--  7) DW binding (rekon_dashboard_pb_spec.md §2) -> PB window import (7 window)
--
--  DEPENDENCY GRAPH (teks):
--    gl_setup, im_product_group ─┐
--                                ├─> rekon_account_map ─┬─> v_gl_* ┐
--    gl_journal, gl_balance ─────┘                      ├─> v_stok_saldo_periode
--    ap_trans/ar_trans/tbyr*/saf ───────────────────────┴─> v_ap_sisa/v_ar_sisa
--         └─> v_rekon_stok/ap/ar_final ─> v_rekon_summary_kpi ─> rekon_snapshot_v2
--         └─> v_rekon_gl_bridge ─> (drill)
--         └─> sp_rekon_anomali ─> dw_rekon_anomali
--    rekon_snapshot_v2 ─> dw_rekon_summary / dw_rekon_snapshot_v2 ─> w_rekon_* (PB)
--
--  Validasi tiap langkah: jalankan TASK1.1 (objek ada) + TASK1.2 (smoke) sebelum lanjut.


-- ############################################################################
-- TASK 7 — FINAL SIGN-OFF (PRODUCTION READY CERTIFICATION)
-- ############################################################################
-- Sistem = "AUDIT-CERTIFIED PRODUCTION" bila SEMUA benar (set :arg_thn,:arg_bln):
--
--   [ ] TASK1.1  = 14 objek OK
--   [ ] TASK1.3  = 0 kolom MISSING
--   [ ] TASK1.5  = 0 view hardcode COA
--   [ ] TASK1.6  = 0 voucher unresolved
--   [ ] GATE A   = 0 baris (engine == snapshot)
--   [ ] GATE B   = 0 baris (semua voucher tertrace / terjelaskan)
--   [ ] GATE C1..C4 = 0 baris (config konsisten, no orphan)
--   [ ] TASK4.1  = 0 index hilang
--   [ ] TASK4.5  = 3 baris snapshot (gate2/gate3 = PASS)
--   [ ] Anomali sisa (GATE B non-zero) 100% terklasifikasi R1..R11 (sp_rekon_anomali)
--
-- 7.1  CERTIFICATION AGGREGATOR — satu angka. PASS bila total_violation = 0.
--   Menggabungkan cek non-periodik (objek, voucher resolve, config C2/C3).
--   GATE A & GATE B (butuh :arg_thn/:arg_bln) dijalankan terpisah; hasil 0-baris
--   dimasukkan ke checklist §7 (governance) untuk verdict final.
SELECT v.total_violation,
       CASE WHEN v.total_violation = 0 THEN 'CERTIFIED' ELSE 'NOT_READY' END AS verdict
FROM ( SELECT
         ( CASE WHEN ( SELECT COUNT(*) FROM SYS.SYSTABLE t
                       WHERE t.table_type='VIEW' AND t.table_name IN
                        ('v_gl_mutasi_bulan','v_gl_opening_tahun','v_stok_saldo_periode',
                         'v_ap_sisa_vendor','v_ar_sisa_cust','v_rekon_stok_final',
                         'v_rekon_ap_final','v_rekon_ar_final','v_rekon_gl_bridge',
                         'v_rekon_summary_kpi') ) < 10 THEN 1 ELSE 0 END )
       + ( SELECT COUNT(*) FROM gl_journal j          -- unresolved voucher (TASK1.6)
           JOIN rekon_account_map m ON m.account_id=j.account_id AND m.is_active='Y'
             AND (m.site_id='*' OR m.site_id=j.site_id)
             AND j.tgl>=m.effective_from AND (m.effective_to IS NULL OR j.tgl<=m.effective_to)
           WHERE j.posting='P'
             AND NOT EXISTS (SELECT 1 FROM v_rekon_gl_bridge b
                             WHERE b.account_id=j.account_id AND b.voucher=j.voucher AND b.tgl=j.tgl) )
       + ( SELECT COUNT(*) FROM im_product_group g     -- stok unmapped (GATE C2)
           WHERE ISNULL(g.persediaan,'')<>''
             AND NOT EXISTS (SELECT 1 FROM rekon_account_map m
                             WHERE m.domain='STOK' AND m.account_id=g.persediaan AND m.is_active='Y') )
       + ( SELECT COUNT(*) FROM rekon_account_map m     -- orphan map (GATE C3)
           WHERE m.is_active='Y'
             AND NOT EXISTS (SELECT 1 FROM gl_journal j WHERE j.account_id=m.account_id)
             AND NOT EXISTS (SELECT 1 FROM gl_balance b WHERE b.AccountCode=m.account_id) )
         AS total_violation
       FROM SYS.DUMMY ) v;
--
-- 7.2  VERDICT AKHIR (governance):
--   CERTIFIED  = TASK7.1 total_violation=0  DAN  GATE A=0  DAN  GATE B tersisa hanya
--                anomali terklasifikasi (R1..R11)  DAN  GATE C1..C4=0.
--   Ditandatangani: (1) Finance (angka & definisi), (2) DBA (index/plan),
--   (3) App Owner (window/DW binding). Simpan hasil query sebagai kertas kerja.
-- ============================================================================
