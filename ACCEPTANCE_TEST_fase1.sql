-- ============================================================
-- ACCEPTANCE_TEST_fase1.sql — bukti Exit Criteria EC1-EC7 (FASE 1 redesign)
-- Semua read-only. Ganti '2026-07-01'/'2026-07-31' ke periode uji bila perlu.
-- Cara pakai ringkas:
--   EC5 idempotent : jalankan SIGNATURE sesudah pass-1 (SNAP_A) & sesudah pass-2 (SNAP_B) -> harus identik.
--   EC4 scope bulan: SIGNATURE utk ym < M sebelum & sesudah refresh M -> identik.
--   EC6 parallel   : SIGNATURE tsales2 mode-lama (SEBELUM build baru) vs mode-baru -> NON-WIP identik, WIP hanya geser.
-- ============================================================

-- ========== A) SIGNATURE (checksum agregat per bulan) ==========
-- A1 tsales2 — dipecah WIP vs NON-WIP agar EC6 mudah dinilai
SELECT 'tsales2' tbl, (CASE WHEN ISNULL(s2.evap,'')<>'' THEN 'WIP' ELSE 'NONWIP' END) kelas,
       year(s1.tgl)*100+month(s1.tgl) ym, count(*) c,
       cast(sum(cast(s2.hpp as numeric(30,4))) as numeric(30,2)) sig_hpp,
       cast(sum(cast(s2.hpp as numeric(30,4))*cast(s2.qty as numeric(30,4))) as numeric(30,2)) sig_hppqty
FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
GROUP BY (CASE WHEN ISNULL(s2.evap,'')<>'' THEN 'WIP' ELSE 'NONWIP' END), year(s1.tgl)*100+month(s1.tgl)
ORDER BY kelas, ym;

-- A2 tstok2 (termasuk WIP-In '88')
SELECT 'tstok2' tbl, year(t1.tgl)*100+month(t1.tgl) ym, count(*) c,
       cast(sum(cast(t2.hpp as numeric(30,4))) as numeric(30,2)) sig_hpp,
       cast(sum(cast(t2.netto as numeric(30,4))) as numeric(30,2)) sig_netto
FROM tstok1 t1 JOIN tstok2 t2 ON t1.bukti_id=t2.bukti_id
GROUP BY year(t1.tgl)*100+month(t1.tgl) ORDER BY ym;

-- A3 sinv (saldo)
SELECT 'sinv' tbl, year(periode)*100+month(periode) ym, count(*) c,
       cast(sum(cast(nilai as numeric(30,4))) as numeric(30,2)) sig_nilai,
       cast(sum(cast(hpp_avg as numeric(30,4))) as numeric(30,2)) sig_hppavg
FROM sinv GROUP BY year(periode)*100+month(periode) ORDER BY ym;

-- A4 gl_journal
SELECT 'gl_journal' tbl, year(tgl)*100+month(tgl) ym, count(*) c,
       cast(sum(debet) as numeric(30,2)) sig_debet,
       cast(sum(kredit) as numeric(30,2)) sig_kredit
FROM gl_journal GROUP BY year(tgl)*100+month(tgl) ORDER BY ym;

-- ========== B) UJI ATURAN BISNIS (semua HARUS kosong = lulus) ==========

-- T4 (=G5) WIP sale = WIP-Out : lihat DETEKTOR G5 (harus kosong).

-- T5 (EC3/B4) NON-WIP ('22' evap='') hpp HARUS = SINV avg akhir bulan (periode bln+1).
--   baris muncul = MELANGGAR (NON-WIP tak sama moving-average).
SELECT 'T5 NONWIP<>avg' t, s2.stok_id, s1.bukti_id,
       cast(s2.hpp as numeric(18,2)) hpp_sale,
       cast((select sum(hpp_avg) from sinv where stok_id=s2.stok_id and periode=dateadd(month,1,cast('2026-07-01' as date))) as numeric(18,2)) sinv_avg_akhir
FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
WHERE s1.tipe_trans='22' AND ISNULL(s2.evap,'')='' AND s1.tgl BETWEEN '2026-07-01' AND '2026-07-31'
  AND ISNULL(s2.qty,0)<>0
  AND ABS(ISNULL(s2.hpp,0) - ISNULL((select sum(hpp_avg) from sinv where stok_id=s2.stok_id and periode=dateadd(month,1,cast('2026-07-01' as date))),0)) > 1
ORDER BY s2.stok_id;

-- T6 (EC/B3) CONSOUT: GL 102-020 (modul AS) per voucher = qty * HPP WIP-Out beku.
--   baris muncul = GL WIP-Out <> nilai beku (selisih > Rp1).
SELECT 'T6 CONSOUT GL<>beku' t, g.voucher,
       cast(g.gl_debet as numeric(18,2)) gl_102020,
       cast(w.hpp_beku as numeric(18,2)) hpp_beku
FROM ( SELECT voucher, sum(debet) gl_debet FROM gl_journal
       WHERE modul_id='AS' AND account_id='102-020' AND tgl BETWEEN '2026-07-01' AND '2026-07-31'
       GROUP BY voucher ) g
JOIN ( SELECT s1.order_client voucher, sum(cast(s2.hpp as numeric(30,4))*cast(s2.qty as numeric(30,4))) hpp_beku
       FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
       WHERE s1.tipe_trans='88' AND ISNULL(s2.evap,'')<>'' AND s1.tgl BETWEEN '2026-07-01' AND '2026-07-31'
       GROUP BY s1.order_client ) w  ON w.voucher=g.voucher
WHERE ABS(ISNULL(g.gl_debet,0)-ISNULL(w.hpp_beku,0)) > 1
ORDER BY g.voucher;

-- T7 (=G4) CONSIN WIP-In = WIP-Out : lihat DETEKTOR G4 (harus kosong).

-- ========== C) FREEZE / IMMUTABILITAS '88' (tanpa tabel) ==========
-- C-a berapa '88' WIP-Out yg sudah beku (hpp>0) vs belum (hpp=0). Yg hpp=0 akan dibekukan refresh berikut.
SELECT (SELECT count(*) FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
        WHERE s1.tipe_trans='88' AND ISNULL(s2.evap,'')<>'' AND ISNULL(s2.hpp,0)>0) AS jml_88_beku,
       (SELECT count(*) FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
        WHERE s1.tipe_trans='88' AND ISNULL(s2.evap,'')<>'' AND ISNULL(s2.hpp,0)=0) AS jml_88_belum_beku;
-- C-b integritas '88': lihat DETEKTOR G3 (WIP-Out vs basis SINV-awal) — harus kosong.
-- EC2 freeze-once (immutabilitas): dibuktikan IDEMPOTENCY_metric.sql LAPORAN B (pass#2: WIP_OUT=0).
