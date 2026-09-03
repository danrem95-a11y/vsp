-- ============================================================================
-- RUNBOOK: Koreksi Permanen WIP-Out Konsinyasi ber-HPP Beku Stale (39 voucher)
-- Tanggal disiapkan : 2026-08-10
-- Item terdampak    : TR.038A (12 unit), TR.039A (26 unit), TR.910A (1 unit)
-- Voucher terdampak : 39 voucher '88' (WIP-Out), Maret s/d Juni 2026
--
-- ROOT CAUSE
-- ----------
-- FREEZE '88' (WIP-Out) mengunci HPP SEKALI SAJA saat pertama kali <>0
-- (guard: WHERE ISNULL(HPP,0)=0 -- lihat n_cst_closing_stock.sru baris ~150-162,
-- by design supaya tidak flip-flop). Selama masa perbaikan engine, bulan²
-- sebelumnya (Jan/Feb/Mar dst) di-refresh ULANG berkali-kali sehingga rata-rata
-- tier-1 (SINV.HPP_AVG awal bulan) bergeser SETELAH voucher WIP-Out tsb sudah
-- terlanjur beku memakai rata-rata versi lama. Karena FREEZE immutable by
-- design, selisih ini TIDAK PERNAH hilang sendiri walau di-refresh ulang
-- berapa kali pun (sudah dibuktikan: April di-refresh ulang 3x, residu
-- Rp32.953.937,10 tetap sama persis).
--
-- Formula rujukan "benar" (tier1_correct_now) 100% identik dgn source code
-- engine sendiri: SELECT SUM(HPP_AVG) FROM SINV WHERE PERIODE=:ldt_bom
-- (awal bulan transaksi WIP-Out) -- lihat of_get_wip_out_value(), baris 791-833.
--
-- Subset voucher TR.038A tanggal April (6 unit x Rp5.492.322,85 =
-- Rp32.953.937,10) COCOK PERSIS dgn residu Apr->Mei yg sebelumnya sudah
-- dilaporkan ke akunting -- ini BUKAN temuan baru, hanya cakupan yg sekarang
-- lebih lengkap (Maret s/d Juni, 3 item, bukan cuma TR.038A/April).
--
-- SCOPE KOREKSI (4 lapis, 1 root cause yg sama)
-- ----------------------------------------------
--  1. TSALES2.HPP  39 baris '88' (WIP-Out itu sendiri)
--  2. TSALES2.HPP  39 baris '22' (penjualan evap yg sama -- step 4b menyalin
--                  HPP dari '88', jadi ikut stale, harus dikoreksi paralel)
--  3. TSTOK2        39 baris WIP-In auto-generated (field HPP/NETTO/KOTOR/
--                  HRG/NETTO_HPP -- identik dgn field yg di-SET step 4d)
--  4. GL_JOURNAL    78 baris (39 voucher x 2 leg: Dr 102-020 WIP / Cr 102-001
--                  Persediaan TR) -- TIDAK auto-sync oleh refresh manapun,
--                  makanya harus dikoreksi manual (satu-satunya lapis yg
--                  benar2 butuh eksekusi manual; 1-3 sebenarnya akan
--                  auto-sync sendiri pada refresh berikutnya krn step 4b/4d
--                  TIDAK immutable, tapi kita koreksi langsung skrg juga
--                  supaya laporan hari ini langsung benar tanpa nunggu
--                  refresh ulang).
--
-- TOTAL DELTA BERSIH: Rp211.757.528,14 (39 baris)
--
-- SYARAT SEBELUM EKSEKUSI
-- ------------------------
--  - JANGAN refresh ulang Jan-Jun sebelum menjalankan skrip ini (supaya
--    tier1_correct_now di STEP 0 tidak bergeser lagi setelah dihitung).
--  - Jalankan STEP demi STEP, jangan skip STEP 0 (backup) dan STEP 1 (preview).
--  - Setiap UPDATE cek jumlah baris ter-update sesuai catatan di komentar
--    SEBELUM lanjut ke statement berikutnya.
--
-- ROLLBACK: lihat paling bawah file ini.
-- ============================================================================


-- ============================================================================
-- STEP 0: BANGUN PETA KOREKSI (staging table, dihitung SEKALI, dipakai semua
--         langkah berikutnya supaya konsisten) + BACKUP nilai lama.
-- ============================================================================

-- 0a. Peta koreksi utama
SELECT z.stok_id, z.evap, z.wo_bukti, z.voucher, z.tgl_wo, z.qty,
       z.hpp_old, isnull(sv.hpp_avg,0) as hpp_new, z.bukti_id_22,
       ('102'+substr(z.bukti_id_22,4,11)) as wipin_bukti
  INTO ZZ_WIPFIX_MAP_20260810
  FROM (
    select s2.stok_id, s2.evap, s1.bukti_id wo_bukti, s1.order_client voucher,
           s1.tgl tgl_wo, s2.qty, s2.hpp hpp_old,
           dateadd(day, 1-day(s1.tgl), s1.tgl) periode_bom,
           (select s1b.bukti_id from tsales1 s1b, tsales2 s2b
              where s1b.bukti_id=s2b.bukti_id and s1b.tipe_trans='22'
                and s2b.stok_id=s2.stok_id and isnull(s2b.evap,'')=isnull(s2.evap,'')) bukti_id_22
      from tsales1 s1, tsales2 s2
     where s1.bukti_id=s2.bukti_id and s1.tipe_trans='88' and isnull(s2.evap,'')<>''
       and s1.tgl between '2026-01-01' and '2026-06-30'
  ) z
  left join sinv sv on sv.stok_id=z.stok_id and sv.periode=z.periode_bom
 WHERE isnull(sv.hpp_avg,0) > 0
   AND abs(z.hpp_old - isnull(sv.hpp_avg,0)) > 1;

-- 0b. Verifikasi peta -- HARUS 39 baris, bukti_id_22 & wipin_bukti tidak boleh NULL
SELECT count(*) n_map,
       sum(case when bukti_id_22 is null then 1 else 0 end) n_22_null,
       cast(sum((hpp_new-hpp_old)*qty) as numeric(20,2)) total_delta
  FROM ZZ_WIPFIX_MAP_20260810;
-- EXPECTED: n_map=39, n_22_null=0, total_delta=211.757.528,14
-- JANGAN LANJUT jika n_22_null > 0 atau n_map <> 39 -- investigasi dulu.

-- 0c. Backup nilai LAMA (4 tabel, sebelum disentuh sama sekali)
SELECT m.wo_bukti as bukti_id, s2.stok_id, s2.evap, s2.hpp as hpp_old
  INTO ZZ_BAK_WIPFIX_TSALES2_88_20260810
  FROM ZZ_WIPFIX_MAP_20260810 m, tsales2 s2
 WHERE s2.bukti_id=m.wo_bukti AND s2.stok_id=m.stok_id AND isnull(s2.evap,'')=isnull(m.evap,'');

SELECT m.bukti_id_22 as bukti_id, s2.stok_id, s2.evap, s2.hpp as hpp_old
  INTO ZZ_BAK_WIPFIX_TSALES2_22_20260810
  FROM ZZ_WIPFIX_MAP_20260810 m, tsales2 s2
 WHERE s2.bukti_id=m.bukti_id_22 AND s2.stok_id=m.stok_id AND isnull(s2.evap,'')=isnull(m.evap,'');

SELECT m.wipin_bukti as bukti_id, t2.stok_id,
       t2.hpp as hpp_old, t2.netto as netto_old, t2.kotor as kotor_old,
       t2.hrg as hrg_old, t2.netto_hpp as netto_hpp_old
  INTO ZZ_BAK_WIPFIX_TSTOK2_20260810
  FROM ZZ_WIPFIX_MAP_20260810 m, tstok2 t2
 WHERE t2.bukti_id=m.wipin_bukti AND t2.stok_id=m.stok_id;

SELECT g.voucher, g.account_id, g.tgl, g.debet as debet_old, g.kredit as kredit_old, g.ket
  INTO ZZ_BAK_WIPFIX_GL_20260810
  FROM gl_journal g
 WHERE g.voucher IN (SELECT DISTINCT voucher FROM ZZ_WIPFIX_MAP_20260810)
   AND g.modul_id='AS' AND g.account_id IN ('102-020','102-001');

-- 0d. Verifikasi backup lengkap -- HARUS 39/39/39/78
SELECT (SELECT COUNT(*) FROM ZZ_BAK_WIPFIX_TSALES2_88_20260810) n_bak_88,
       (SELECT COUNT(*) FROM ZZ_BAK_WIPFIX_TSALES2_22_20260810) n_bak_22,
       (SELECT COUNT(*) FROM ZZ_BAK_WIPFIX_TSTOK2_20260810)     n_bak_tstok2,
       (SELECT COUNT(*) FROM ZZ_BAK_WIPFIX_GL_20260810)         n_bak_gl;
COMMIT;


-- ============================================================================
-- STEP 1: PREVIEW -- tinjau before/after sebelum eksekusi UPDATE apapun
-- ============================================================================
SELECT stok_id, evap, wo_bukti, voucher, tgl_wo, qty,
       cast(hpp_old as numeric(16,2)) hpp_lama,
       cast(hpp_new as numeric(16,2)) hpp_baru,
       cast((hpp_new-hpp_old)*qty as numeric(16,2)) delta
  FROM ZZ_WIPFIX_MAP_20260810
 ORDER BY stok_id, tgl_wo;
-- Tinjau manual: 39 baris, delta bervariasi (+/-), total = 211.757.528,14


-- ============================================================================
-- STEP 2: UPDATE TSALES2 -- 39 baris '88' (WIP-Out)
-- ============================================================================
UPDATE TSALES2
   SET HPP = ROUND(m.hpp_new,2)
  FROM TSALES2, ZZ_WIPFIX_MAP_20260810 m
 WHERE TSALES2.bukti_id = m.wo_bukti
   AND TSALES2.stok_id  = m.stok_id
   AND isnull(TSALES2.evap,'') = isnull(m.evap,'');
-- EXPECTED: 39 rows affected
COMMIT;


-- ============================================================================
-- STEP 3: UPDATE TSALES2 -- 39 baris '22' (penjualan, evap sama, step 4b logic)
-- ============================================================================
UPDATE TSALES2
   SET HPP = ROUND(m.hpp_new,2)
  FROM TSALES2, ZZ_WIPFIX_MAP_20260810 m
 WHERE TSALES2.bukti_id = m.bukti_id_22
   AND TSALES2.stok_id  = m.stok_id
   AND isnull(TSALES2.evap,'') = isnull(m.evap,'');
-- EXPECTED: 39 rows affected
COMMIT;


-- ============================================================================
-- STEP 4: UPDATE TSTOK2 -- 39 baris WIP-In auto-generated (field identik step 4d)
-- ============================================================================
UPDATE TSTOK2
   SET HPP        = ROUND(m.hpp_new,0),
       NETTO      = ROUND(m.hpp_new * TSTOK2.qty,2),
       KOTOR      = ROUND(m.hpp_new * TSTOK2.qty,2),
       HRG        = m.hpp_new,
       NETTO_HPP  = ROUND(m.hpp_new * TSTOK2.qty,2)
  FROM TSTOK2, ZZ_WIPFIX_MAP_20260810 m
 WHERE TSTOK2.bukti_id = m.wipin_bukti
   AND TSTOK2.stok_id  = m.stok_id
   AND isnull(TSTOK2.coa_id,'') = m.evap;
-- EXPECTED: 39 rows affected  (guard COA_ID=EVAP disamakan dgn matching logic step 4d asli)
COMMIT;


-- ============================================================================
-- STEP 5: UPDATE GL_JOURNAL -- 78 baris (39 voucher x Dr 102-020 / Cr 102-001)
-- ============================================================================
UPDATE gl_journal
   SET debet = t.new_total
  FROM gl_journal, ( SELECT voucher, cast(sum(hpp_new*qty) as numeric(16,2)) new_total
                        FROM ZZ_WIPFIX_MAP_20260810 GROUP BY voucher ) t
 WHERE gl_journal.voucher = t.voucher
   AND gl_journal.account_id = '102-020'
   AND gl_journal.modul_id = 'AS';
-- EXPECTED: 39 rows affected

UPDATE gl_journal
   SET kredit = t.new_total
  FROM gl_journal, ( SELECT voucher, cast(sum(hpp_new*qty) as numeric(16,2)) new_total
                        FROM ZZ_WIPFIX_MAP_20260810 GROUP BY voucher ) t
 WHERE gl_journal.voucher = t.voucher
   AND gl_journal.account_id = '102-001'
   AND gl_journal.modul_id = 'AS';
-- EXPECTED: 39 rows affected  (2 desimal, samakan presisi dgn nilai lama; TIDAK dibulatkan ke 0 desimal)
COMMIT;


-- ============================================================================
-- STEP 6: VERIFIKASI PASCA-KOREKSI (semua HARUS 0 baris / net 0)
-- ============================================================================

-- 6a. Deteksi ulang stale-freeze -- HARUS 0 baris sekarang
SELECT count(*) sisa_stale
  FROM (
    select s2.stok_id, s2.hpp, dateadd(day, 1-day(s1.tgl), s1.tgl) periode_bom
      from tsales1 s1, tsales2 s2
     where s1.bukti_id=s2.bukti_id and s1.tipe_trans='88' and isnull(s2.evap,'')<>''
       and s1.tgl between '2026-01-01' and '2026-06-30'
  ) z
  LEFT JOIN sinv sv ON sv.stok_id=z.stok_id AND sv.periode=z.periode_bom
 WHERE isnull(sv.hpp_avg,0) > 0
   AND abs(z.hpp - isnull(sv.hpp_avg,0)) > 1;
-- EXPECTED: 0

-- 6b. GL 102-020 vs 102-001 utk 39 voucher -- Dr harus = Cr per voucher (tetap balance)
SELECT voucher,
       sum(case when account_id='102-020' then debet else 0 end) dr_wip,
       sum(case when account_id='102-001' then kredit else 0 end) cr_persediaan
  FROM gl_journal
 WHERE voucher IN (SELECT DISTINCT voucher FROM ZZ_WIPFIX_MAP_20260810)
   AND modul_id='AS'
 GROUP BY voucher
HAVING sum(case when account_id='102-020' then debet else 0 end) <>
       sum(case when account_id='102-001' then kredit else 0 end);
-- EXPECTED: 0 baris (semua voucher tetap balance Dr=Cr setelah koreksi)

-- 6c. Opname (SINV) vs Ledger (GL) 102-001 -- selisih harus turun ke ~0
--     (jalankan query yg sama dgn evidence sebelumnya utk konfirmasi akhir)


-- ============================================================================
-- ROLLBACK (jika STEP 6 gagal / ada yang tidak sesuai harapan)
-- ============================================================================
-- UPDATE TSALES2 SET HPP = b.hpp_old FROM TSALES2, ZZ_BAK_WIPFIX_TSALES2_88_20260810 b
--  WHERE TSALES2.bukti_id=b.bukti_id AND TSALES2.stok_id=b.stok_id AND isnull(TSALES2.evap,'')=isnull(b.evap,'');
-- UPDATE TSALES2 SET HPP = b.hpp_old FROM TSALES2, ZZ_BAK_WIPFIX_TSALES2_22_20260810 b
--  WHERE TSALES2.bukti_id=b.bukti_id AND TSALES2.stok_id=b.stok_id AND isnull(TSALES2.evap,'')=isnull(b.evap,'');
-- UPDATE TSTOK2 SET HPP=b.hpp_old, NETTO=b.netto_old, KOTOR=b.kotor_old, HRG=b.hrg_old, NETTO_HPP=b.netto_hpp_old
--  FROM TSTOK2, ZZ_BAK_WIPFIX_TSTOK2_20260810 b WHERE TSTOK2.bukti_id=b.bukti_id AND TSTOK2.stok_id=b.stok_id;
-- UPDATE gl_journal SET debet=b.debet_old, kredit=b.kredit_old
--  FROM gl_journal, ZZ_BAK_WIPFIX_GL_20260810 b
--  WHERE gl_journal.voucher=b.voucher AND gl_journal.account_id=b.account_id AND gl_journal.modul_id='AS';
-- COMMIT;
--
-- Setelah rollback selesai & terverifikasi, baru DROP TABLE ZZ_WIPFIX_MAP_20260810,
-- ZZ_BAK_WIPFIX_TSALES2_88_20260810, ZZ_BAK_WIPFIX_TSALES2_22_20260810,
-- ZZ_BAK_WIPFIX_TSTOK2_20260810, ZZ_BAK_WIPFIX_GL_20260810;
-- (tabel ZZ_BAK_* JANGAN dihapus dulu selama beberapa hari setelah koreksi
--  berhasil -- simpan sbg audit trail, baru hapus setelah akunting konfirmasi final.)
