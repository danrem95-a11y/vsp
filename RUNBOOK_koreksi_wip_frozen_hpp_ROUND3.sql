-- ============================================================================
-- RUNBOOK ROUND 3: Koreksi Cascade WIP-Out (TR.039A Juni, 8 baris)
-- Tanggal disiapkan : 2026-08-10 (setelah refresh April-Juni pasca Round 2)
--
-- Cascade terus mengecil dan menyempit: Round 1 = 39 baris/Rp211,7jt (Mar-Jun),
-- Round 2 = 16 baris/Rp13,5jt (Mei-Jun), Round 3 = 8 baris/Rp7,74jt (Jun saja).
-- Maret-Mei sekarang STABIL permanen (tidak muncul lagi). Struktur & mekanisme
-- skrip identik Round 1/2 (deteksi otomatis, bukan hardcode), suffix _R3.
--
-- SYARAT: JANGAN refresh ulang lagi sebelum menjalankan script ini.
-- SETELAH ini: refresh April-Juni SEKALI LAGI, lalu cek STEP 6a.
-- ============================================================================

SELECT z.stok_id, z.evap, z.wo_bukti, z.voucher, z.tgl_wo, z.qty,
       z.hpp_old, isnull(sv.hpp_avg,0) as hpp_new, z.bukti_id_22,
       ('102'+substr(z.bukti_id_22,4,11)) as wipin_bukti
  INTO ZZ_WIPFIX_MAP_R3_20260810
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

SELECT count(*) n_map,
       sum(case when bukti_id_22 is null then 1 else 0 end) n_22_null,
       cast(sum((hpp_new-hpp_old)*qty) as numeric(20,2)) total_delta
  FROM ZZ_WIPFIX_MAP_R3_20260810;
-- EXPECTED: n_map=8, n_22_null=0

SELECT m.wo_bukti as bukti_id, s2.stok_id, s2.evap, s2.hpp as hpp_old
  INTO ZZ_BAK_WIPFIX_TSALES2_88_R3_20260810
  FROM ZZ_WIPFIX_MAP_R3_20260810 m, tsales2 s2
 WHERE s2.bukti_id=m.wo_bukti AND s2.stok_id=m.stok_id AND isnull(s2.evap,'')=isnull(m.evap,'');

SELECT m.bukti_id_22 as bukti_id, s2.stok_id, s2.evap, s2.hpp as hpp_old
  INTO ZZ_BAK_WIPFIX_TSALES2_22_R3_20260810
  FROM ZZ_WIPFIX_MAP_R3_20260810 m, tsales2 s2
 WHERE s2.bukti_id=m.bukti_id_22 AND s2.stok_id=m.stok_id AND isnull(s2.evap,'')=isnull(m.evap,'');

SELECT m.wipin_bukti as bukti_id, t2.stok_id,
       t2.hpp as hpp_old, t2.netto as netto_old, t2.kotor as kotor_old,
       t2.hrg as hrg_old, t2.netto_hpp as netto_hpp_old
  INTO ZZ_BAK_WIPFIX_TSTOK2_R3_20260810
  FROM ZZ_WIPFIX_MAP_R3_20260810 m, tstok2 t2
 WHERE t2.bukti_id=m.wipin_bukti AND t2.stok_id=m.stok_id;

SELECT g.voucher, g.account_id, g.tgl, g.debet as debet_old, g.kredit as kredit_old, g.ket
  INTO ZZ_BAK_WIPFIX_GL_R3_20260810
  FROM gl_journal g
 WHERE g.voucher IN (SELECT DISTINCT voucher FROM ZZ_WIPFIX_MAP_R3_20260810)
   AND g.modul_id='AS' AND g.account_id IN ('102-020','102-001');

SELECT (SELECT COUNT(*) FROM ZZ_BAK_WIPFIX_TSALES2_88_R3_20260810) n_bak_88,
       (SELECT COUNT(*) FROM ZZ_BAK_WIPFIX_TSALES2_22_R3_20260810) n_bak_22,
       (SELECT COUNT(*) FROM ZZ_BAK_WIPFIX_TSTOK2_R3_20260810)     n_bak_tstok2,
       (SELECT COUNT(*) FROM ZZ_BAK_WIPFIX_GL_R3_20260810)         n_bak_gl;
COMMIT;


SELECT stok_id, evap, wo_bukti, voucher, tgl_wo, qty,
       cast(hpp_old as numeric(16,2)) hpp_lama,
       cast(hpp_new as numeric(16,2)) hpp_baru,
       cast((hpp_new-hpp_old)*qty as numeric(16,2)) delta
  FROM ZZ_WIPFIX_MAP_R3_20260810
 ORDER BY stok_id, tgl_wo;


UPDATE TSALES2
   SET HPP = ROUND(m.hpp_new,2)
  FROM TSALES2, ZZ_WIPFIX_MAP_R3_20260810 m
 WHERE TSALES2.bukti_id = m.wo_bukti
   AND TSALES2.stok_id  = m.stok_id
   AND isnull(TSALES2.evap,'') = isnull(m.evap,'');
-- EXPECTED: 8 rows affected
COMMIT;


UPDATE TSALES2
   SET HPP = ROUND(m.hpp_new,2)
  FROM TSALES2, ZZ_WIPFIX_MAP_R3_20260810 m
 WHERE TSALES2.bukti_id = m.bukti_id_22
   AND TSALES2.stok_id  = m.stok_id
   AND isnull(TSALES2.evap,'') = isnull(m.evap,'');
-- EXPECTED: 8 rows affected
COMMIT;


UPDATE TSTOK2
   SET HPP        = ROUND(m.hpp_new,0),
       NETTO      = ROUND(m.hpp_new * TSTOK2.qty,2),
       KOTOR      = ROUND(m.hpp_new * TSTOK2.qty,2),
       HRG        = m.hpp_new,
       NETTO_HPP  = ROUND(m.hpp_new * TSTOK2.qty,2)
  FROM TSTOK2, ZZ_WIPFIX_MAP_R3_20260810 m
 WHERE TSTOK2.bukti_id = m.wipin_bukti
   AND TSTOK2.stok_id  = m.stok_id
   AND isnull(TSTOK2.coa_id,'') = m.evap;
-- EXPECTED: 8 rows affected
COMMIT;


UPDATE gl_journal
   SET debet = t.new_total
  FROM gl_journal, ( SELECT voucher, cast(sum(hpp_new*qty) as numeric(16,2)) new_total
                        FROM ZZ_WIPFIX_MAP_R3_20260810 GROUP BY voucher ) t
 WHERE gl_journal.voucher = t.voucher
   AND gl_journal.account_id = '102-020'
   AND gl_journal.modul_id = 'AS';
-- EXPECTED: 8 rows affected

UPDATE gl_journal
   SET kredit = t.new_total
  FROM gl_journal, ( SELECT voucher, cast(sum(hpp_new*qty) as numeric(16,2)) new_total
                        FROM ZZ_WIPFIX_MAP_R3_20260810 GROUP BY voucher ) t
 WHERE gl_journal.voucher = t.voucher
   AND gl_journal.account_id = '102-001'
   AND gl_journal.modul_id = 'AS';
-- EXPECTED: 8 rows affected
COMMIT;


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

SELECT voucher,
       sum(case when account_id='102-020' then debet else 0 end) dr_wip,
       sum(case when account_id='102-001' then kredit else 0 end) cr_persediaan
  FROM gl_journal
 WHERE voucher IN (SELECT DISTINCT voucher FROM ZZ_WIPFIX_MAP_R3_20260810)
   AND modul_id='AS'
 GROUP BY voucher
HAVING sum(case when account_id='102-020' then debet else 0 end) <>
       sum(case when account_id='102-001' then kredit else 0 end);
-- EXPECTED: 0 baris


-- ROLLBACK (jika perlu):
-- UPDATE TSALES2 SET HPP = b.hpp_old FROM TSALES2, ZZ_BAK_WIPFIX_TSALES2_88_R3_20260810 b
--  WHERE TSALES2.bukti_id=b.bukti_id AND TSALES2.stok_id=b.stok_id AND isnull(TSALES2.evap,'')=isnull(b.evap,'');
-- UPDATE TSALES2 SET HPP = b.hpp_old FROM TSALES2, ZZ_BAK_WIPFIX_TSALES2_22_R3_20260810 b
--  WHERE TSALES2.bukti_id=b.bukti_id AND TSALES2.stok_id=b.stok_id AND isnull(TSALES2.evap,'')=isnull(b.evap,'');
-- UPDATE TSTOK2 SET HPP=b.hpp_old, NETTO=b.netto_old, KOTOR=b.kotor_old, HRG=b.hrg_old, NETTO_HPP=b.netto_hpp_old
--  FROM TSTOK2, ZZ_BAK_WIPFIX_TSTOK2_R3_20260810 b WHERE TSTOK2.bukti_id=b.bukti_id AND TSTOK2.stok_id=b.stok_id;
-- UPDATE gl_journal SET debet=b.debet_old, kredit=b.kredit_old
--  FROM gl_journal, ZZ_BAK_WIPFIX_GL_R3_20260810 b
--  WHERE gl_journal.voucher=b.voucher AND gl_journal.account_id=b.account_id AND gl_journal.modul_id='AS';
-- COMMIT;
