-- ============================================================================
-- RUNBOOK: Koreksi WIP-Out NR (102-003) -- 3 baris, root cause BEDA dari TR
-- Tanggal disiapkan : 2026-08-10
--
-- ROOT CAUSE (dikonfirmasi Pak Wira: HPP WIP-Out dihitung sistem dari rata-rata
-- bulan berjalan saat entry, BUKAN input manual):
-- NR.108A dan NR.201A adalah pembelian BARU (PO) yang LANGSUNG di-WIP-Out
-- keesokan harinya (dalam bulan yg sama). Karena SINV belum punya saldo AWAL
-- bulan utk item ini (baru pertama kali ada), rata-rata yg dipakai sistem saat
-- WIP-Out di-entry SEHARUSNYA = rata-rata pembelian BULAN ITU (opening 0 + beli
-- bulan itu), TAPI 3 dari 5 transaksi 05/09/2026 memakai rata-rata yg salah/
-- tidak lengkap (tercampur/prematur) -- 2 transaksi lain (NR.101A) sudah benar.
--
-- BUKTI (rata-rata bulan berjalan YG BENAR = opening SINV + beli TSTOK2 tipe 02
-- bulan itu, dibagi qty):
--   NR.101A Mei : benar 31.500.000 -- frozen SUDAH 31.500.000 (OK, tak disentuh)
--   NR.108A Mei : benar 36.200.000 -- 1 dari 2 unit frozen SALAH pakai 31.500.000
--   NR.108A Jun : benar 31.500.000 -- frozen SUDAH 31.500.000 (OK, tak disentuh)
--   NR.201A Mei : benar 38.500.000 -- KEDUA unit frozen SALAH pakai 19.250.000
--   NR.401A Jan&Jun : benar 48.000.000 -- frozen SUDAH 48.000.000 (OK)
-- Total delta 3 baris = 4.700.000 + 19.250.000 + 19.250.000 = 43.200.000,
-- COCOK PERSIS dgn gap Opname-vs-GL 102-003 yg ditemukan (Rp43.200.000,15).
--
-- SCOPE: HANYA 3 voucher '88' tanggal 05/09/2026:
--   NR.108A/632BFAZI005 (order_client 101260500064): 31.500.000 -> 36.200.000
--   NR.201A/645BDEAC002 (order_client 101260500063): 19.250.000 -> 38.500.000
--   NR.201A/174BCHZA001 (order_client 101260500061): 19.250.000 -> 38.500.000
-- (NR.101A/631BDJBA003 voucher 101260500062 dan NR.108A/632BFAAD005 voucher
--  101260500065 SUDAH BENAR, otomatis tidak ikut ter-update krn deteksi
--  memakai selisih>1 terhadap rata-rata yg benar.)
--
-- Struktur skrip identik RUNBOOK TR (staging map, backup, preview, update 4
-- lapis, verifikasi, rollback) -- HANYA beda formula referensi "hpp_new"
-- (rata-rata bulan berjalan opening+beli, bukan SINV.hpp_avg BOM, krn item
-- baru tanpa saldo awal bulan).
-- ============================================================================

-- ============================================================================
-- STEP 0: PETA + BACKUP
-- ============================================================================
SELECT z.stok_id, z.evap, z.wo_bukti, z.voucher, z.tgl_wo, z.qty,
       z.hpp_old,
       cast( (isnull(sv.nilai,0)+isnull(b.beli_rp,0)) / nullif(isnull(sv.qty,0)+isnull(b.beli_qty,0),0) as numeric(16,2)) as hpp_new,
       z.bukti_id_22,
       ('102'+substr(z.bukti_id_22,4,11)) as wipin_bukti
  INTO ZZ_WIPFIX_NR_MAP_20260810
  FROM (
    select s2.stok_id, s2.evap, s1.bukti_id wo_bukti, s1.order_client voucher,
           s1.tgl tgl_wo, s2.qty, s2.hpp hpp_old,
           dateadd(day,1-day(s1.tgl),s1.tgl) periode_bom,
           (select s1b.bukti_id from tsales1 s1b, tsales2 s2b
              where s1b.bukti_id=s2b.bukti_id and s1b.tipe_trans='22'
                and s2b.stok_id=s2.stok_id and isnull(s2b.evap,'')=isnull(s2.evap,'')) bukti_id_22
      from tsales1 s1, tsales2 s2, im_produk ip, im_product_group ipg
     where s1.bukti_id=s2.bukti_id and s1.tipe_trans='88' and isnull(s2.evap,'')<>''
       and s1.tgl between '2026-01-01' and '2026-06-30'
       and ip.produk_id=s2.stok_id and ipg.kode_group=ip.group_product
       and ipg.persediaan='102-003'
  ) z
  left join sinv sv on sv.stok_id=z.stok_id and sv.periode=z.periode_bom
  left join (
    select t2.stok_id, dateadd(day,1-day(t1.tgl),t1.tgl) periode_bulan, sum(t2.qty) beli_qty, sum(t2.netto) beli_rp
      from tstok1 t1, tstok2 t2
     where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02'
     group by t2.stok_id, dateadd(day,1-day(t1.tgl),t1.tgl)
  ) b on b.stok_id=z.stok_id and b.periode_bulan=z.periode_bom
 WHERE isnull((isnull(sv.nilai,0)+isnull(b.beli_rp,0)) / nullif(isnull(sv.qty,0)+isnull(b.beli_qty,0),0),0) > 0
   AND abs(z.hpp_old - isnull((isnull(sv.nilai,0)+isnull(b.beli_rp,0)) / nullif(isnull(sv.qty,0)+isnull(b.beli_qty,0),0),0)) > 1;

-- 0b. Verifikasi -- HARUS 3 baris
SELECT count(*) n_map,
       sum(case when bukti_id_22 is null then 1 else 0 end) n_22_null,
       cast(sum((hpp_new-hpp_old)*qty) as numeric(20,2)) total_delta
  FROM ZZ_WIPFIX_NR_MAP_20260810;
-- EXPECTED: n_map=3, n_22_null=0, total_delta=43.200.000,00

-- 0c. Backup
SELECT m.wo_bukti as bukti_id, s2.stok_id, s2.evap, s2.hpp as hpp_old
  INTO ZZ_BAK_WIPFIX_NR_88_20260810
  FROM ZZ_WIPFIX_NR_MAP_20260810 m, tsales2 s2
 WHERE s2.bukti_id=m.wo_bukti AND s2.stok_id=m.stok_id AND isnull(s2.evap,'')=isnull(m.evap,'');

SELECT m.bukti_id_22 as bukti_id, s2.stok_id, s2.evap, s2.hpp as hpp_old
  INTO ZZ_BAK_WIPFIX_NR_22_20260810
  FROM ZZ_WIPFIX_NR_MAP_20260810 m, tsales2 s2
 WHERE s2.bukti_id=m.bukti_id_22 AND s2.stok_id=m.stok_id AND isnull(s2.evap,'')=isnull(m.evap,'');

SELECT m.wipin_bukti as bukti_id, t2.stok_id,
       t2.hpp as hpp_old, t2.netto as netto_old, t2.kotor as kotor_old,
       t2.hrg as hrg_old, t2.netto_hpp as netto_hpp_old
  INTO ZZ_BAK_WIPFIX_NR_TSTOK2_20260810
  FROM ZZ_WIPFIX_NR_MAP_20260810 m, tstok2 t2
 WHERE t2.bukti_id=m.wipin_bukti AND t2.stok_id=m.stok_id;

SELECT g.voucher, g.account_id, g.tgl, g.debet as debet_old, g.kredit as kredit_old, g.ket
  INTO ZZ_BAK_WIPFIX_NR_GL_20260810
  FROM gl_journal g
 WHERE g.voucher IN (SELECT DISTINCT voucher FROM ZZ_WIPFIX_NR_MAP_20260810)
   AND g.modul_id='AS' AND g.account_id IN ('102-020','102-003');

-- 0d. Verifikasi backup -- HARUS 3/3/3/6
SELECT (SELECT COUNT(*) FROM ZZ_BAK_WIPFIX_NR_88_20260810) n_bak_88,
       (SELECT COUNT(*) FROM ZZ_BAK_WIPFIX_NR_22_20260810) n_bak_22,
       (SELECT COUNT(*) FROM ZZ_BAK_WIPFIX_NR_TSTOK2_20260810) n_bak_tstok2,
       (SELECT COUNT(*) FROM ZZ_BAK_WIPFIX_NR_GL_20260810) n_bak_gl;
COMMIT;


-- ============================================================================
-- STEP 1: PREVIEW
-- ============================================================================
SELECT stok_id, evap, wo_bukti, voucher, tgl_wo, qty,
       cast(hpp_old as numeric(16,2)) hpp_lama,
       cast(hpp_new as numeric(16,2)) hpp_baru,
       cast((hpp_new-hpp_old)*qty as numeric(16,2)) delta
  FROM ZZ_WIPFIX_NR_MAP_20260810
 ORDER BY stok_id, tgl_wo;


-- ============================================================================
-- STEP 2: UPDATE TSALES2 -- baris '88'
-- ============================================================================
UPDATE TSALES2
   SET HPP = ROUND(m.hpp_new,2)
  FROM TSALES2, ZZ_WIPFIX_NR_MAP_20260810 m
 WHERE TSALES2.bukti_id = m.wo_bukti
   AND TSALES2.stok_id  = m.stok_id
   AND isnull(TSALES2.evap,'') = isnull(m.evap,'');
-- EXPECTED: 3 rows affected
COMMIT;


-- ============================================================================
-- STEP 3: UPDATE TSALES2 -- baris '22' (kalau sudah terjual; kalau belum, 0 baris wajar)
-- ============================================================================
UPDATE TSALES2
   SET HPP = ROUND(m.hpp_new,2)
  FROM TSALES2, ZZ_WIPFIX_NR_MAP_20260810 m
 WHERE TSALES2.bukti_id = m.bukti_id_22
   AND TSALES2.stok_id  = m.stok_id
   AND isnull(TSALES2.evap,'') = isnull(m.evap,'');
-- EXPECTED: 0-3 rows affected (tergantung sudah terjual atau belum)
COMMIT;


-- ============================================================================
-- STEP 4: UPDATE TSTOK2 -- WIP-In
-- ============================================================================
UPDATE TSTOK2
   SET HPP        = ROUND(m.hpp_new,0),
       NETTO      = ROUND(m.hpp_new * TSTOK2.qty,2),
       KOTOR      = ROUND(m.hpp_new * TSTOK2.qty,2),
       HRG        = m.hpp_new,
       NETTO_HPP  = ROUND(m.hpp_new * TSTOK2.qty,2)
  FROM TSTOK2, ZZ_WIPFIX_NR_MAP_20260810 m
 WHERE TSTOK2.bukti_id = m.wipin_bukti
   AND TSTOK2.stok_id  = m.stok_id
   AND isnull(TSTOK2.coa_id,'') = m.evap;
-- EXPECTED: 3 rows affected
COMMIT;


-- ============================================================================
-- STEP 5: UPDATE GL_JOURNAL -- Dr 102-020 / Cr 102-003
-- ============================================================================
UPDATE gl_journal
   SET debet = t.new_total
  FROM gl_journal, ( SELECT voucher, cast(sum(hpp_new*qty) as numeric(16,2)) new_total
                        FROM ZZ_WIPFIX_NR_MAP_20260810 GROUP BY voucher ) t
 WHERE gl_journal.voucher = t.voucher
   AND gl_journal.account_id = '102-020'
   AND gl_journal.modul_id = 'AS';
-- EXPECTED: 3 rows affected

UPDATE gl_journal
   SET kredit = t.new_total
  FROM gl_journal, ( SELECT voucher, cast(sum(hpp_new*qty) as numeric(16,2)) new_total
                        FROM ZZ_WIPFIX_NR_MAP_20260810 GROUP BY voucher ) t
 WHERE gl_journal.voucher = t.voucher
   AND gl_journal.account_id = '102-003'
   AND gl_journal.modul_id = 'AS';
-- EXPECTED: 3 rows affected
COMMIT;


-- ============================================================================
-- STEP 6: VERIFIKASI
-- ============================================================================
SELECT voucher,
       sum(case when account_id='102-020' then debet else 0 end) dr_wip,
       sum(case when account_id='102-003' then kredit else 0 end) cr_persediaan
  FROM gl_journal
 WHERE voucher IN (SELECT DISTINCT voucher FROM ZZ_WIPFIX_NR_MAP_20260810)
   AND modul_id='AS'
 GROUP BY voucher
HAVING sum(case when account_id='102-020' then debet else 0 end) <>
       sum(case when account_id='102-003' then kredit else 0 end);
-- EXPECTED: 0 baris

-- 6b. Opname vs GL 102-003 pasca-koreksi (jalankan SETELAH refresh Mei-Juni ulang)
-- selisih harus turun mendekati 0


-- ============================================================================
-- ROLLBACK (jika perlu)
-- ============================================================================
-- UPDATE TSALES2 SET HPP = b.hpp_old FROM TSALES2, ZZ_BAK_WIPFIX_NR_88_20260810 b
--  WHERE TSALES2.bukti_id=b.bukti_id AND TSALES2.stok_id=b.stok_id AND isnull(TSALES2.evap,'')=isnull(b.evap,'');
-- UPDATE TSALES2 SET HPP = b.hpp_old FROM TSALES2, ZZ_BAK_WIPFIX_NR_22_20260810 b
--  WHERE TSALES2.bukti_id=b.bukti_id AND TSALES2.stok_id=b.stok_id AND isnull(TSALES2.evap,'')=isnull(b.evap,'');
-- UPDATE TSTOK2 SET HPP=b.hpp_old, NETTO=b.netto_old, KOTOR=b.kotor_old, HRG=b.hrg_old, NETTO_HPP=b.netto_hpp_old
--  FROM TSTOK2, ZZ_BAK_WIPFIX_NR_TSTOK2_20260810 b WHERE TSTOK2.bukti_id=b.bukti_id AND TSTOK2.stok_id=b.stok_id;
-- UPDATE gl_journal SET debet=b.debet_old, kredit=b.kredit_old
--  FROM gl_journal, ZZ_BAK_WIPFIX_NR_GL_20260810 b
--  WHERE gl_journal.voucher=b.voucher AND gl_journal.account_id=b.account_id AND gl_journal.modul_id='AS';
-- COMMIT;
