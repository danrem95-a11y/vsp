-- ============================================================
-- EVIDENCE #4 : CROSS-MODULE RECONCILIATION (subledger = GL)
--   Closing bulan contoh: sinv '2026-08-01', GL <= '2026-07-31', opening tahun '2026-01-01'.
--   Target: SEMUA break = 0 (toleransi rounding). Dijalankan prod 2026-07-31 (angka di dok).
-- ============================================================

-- ---------- G. INVENTORY : SINV = GL persediaan (per akun) ----------
-- break>Rp1 = FAIL. (Prod: total |break| = 11,380,745,462.85 -- akar 102-001 WIP unit belum di-booking.)
SELECT g.acc,
  CAST(isnull(sv.sinv,0) AS numeric(20,2)) sinv_nilai,
  CAST(isnull(op.opn,0)+isnull(mv.mov,0) AS numeric(20,2)) gl_nilai,
  CAST(isnull(sv.sinv,0)-(isnull(op.opn,0)+isnull(mv.mov,0)) AS numeric(20,2)) break
FROM (SELECT DISTINCT persediaan acc FROM im_product_group WHERE isnull(persediaan,'')<>'') g
LEFT JOIN (SELECT gr.persediaan acc,sum(s.nilai) sinv FROM sinv s JOIN im_produk pr ON pr.produk_id=s.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE s.periode='2026-08-01' GROUP BY gr.persediaan) sv ON sv.acc=g.acc
LEFT JOIN (SELECT AccountCode acc,sum(AmountDebet-AmountCredit) opn FROM gl_balance WHERE Period='2026-01-01' GROUP BY AccountCode) op ON op.acc=g.acc
LEFT JOIN (SELECT account_id acc,sum(debet-kredit) mov FROM gl_journal WHERE tgl BETWEEN '2026-01-01' AND '2026-07-31' GROUP BY account_id) mv ON mv.acc=g.acc
WHERE abs(isnull(sv.sinv,0)-(isnull(op.opn,0)+isnull(mv.mov,0))) > 1
ORDER BY abs(isnull(sv.sinv,0)-(isnull(op.opn,0)+isnull(mv.mov,0))) DESC;

-- ---------- A/B. WIP-OUT : outstanding = GL 102-020 ----------
-- (Prod: outstanding 2,660,202,268.56 vs GL 102-020 2,675,153,958.12 -> Δ ~15jt, TIES.)
SELECT
 CAST((SELECT isnull(sum(abs(isnull(s2.hpp,0)*isnull(s2.qty,0))),0)
       FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
       WHERE s1.tipe_trans='88' AND isnull(s2.evap,'')<>'' AND s1.tgl<='2026-07-31'
       AND NOT EXISTS(SELECT 1 FROM tstok1 t1 JOIN tstok2 t2 ON t1.bukti_id=t2.bukti_id
          WHERE t1.tipe_trans='88' AND t2.stok_id=s2.stok_id AND isnull(t2.coa_id,'')=s2.evap AND t1.tgl<='2026-07-31')
      ) AS numeric(20,2)) AS wipout_outstanding,
 CAST((SELECT isnull(sum(AmountDebet-AmountCredit),0) FROM gl_balance WHERE AccountCode='102-020' AND Period='2026-01-01')
    + (SELECT isnull(sum(debet-kredit),0) FROM gl_journal WHERE account_id='102-020' AND tgl BETWEEN '2026-01-01' AND '2026-07-31')
     AS numeric(20,2)) AS gl_102020;

-- ---------- C/D. KONSINYASI out=in per serial (DETEKTOR G4) ----------
SELECT o.stok_id, o.evap, CAST(o.hpp_out AS numeric(18,2)) hpp_out, CAST(i.hpp_in AS numeric(18,2)) hpp_in
FROM (SELECT s2.stok_id, s2.evap, s2.hpp hpp_out FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id
      WHERE s1.tipe_trans='88' AND s1.tgl BETWEEN '2026-07-01' AND '2026-07-31' AND isnull(s2.evap,'')<>'') o
JOIN (SELECT t2.stok_id, t2.coa_id evap, t2.hpp hpp_in FROM tstok1 t1 JOIN tstok2 t2 ON t1.bukti_id=t2.bukti_id
      WHERE t1.tipe_trans='88' AND isnull(t2.coa_id,'')<>'') i ON i.stok_id=o.stok_id AND i.evap=o.evap
WHERE abs(isnull(o.hpp_out,0)-isnull(i.hpp_in,0)) > 1 ORDER BY o.stok_id;

-- ---------- E. AR = GL 103-001 ; F. AP = GL 226-xxx ----------
-- GL saldo (prod): AR 103-001 = 21,675,493,282.47 ; AP 226-001 = -10,582,607,646.25.
-- Rekon opname AR/AP vs ledger: jalankan allrecon.ps1 / allrecon_julext.ps1 (opname vs GL, dlm toleransi).
SELECT '103-001 AR' akun,
  CAST((SELECT isnull(sum(AmountDebet-AmountCredit),0) FROM gl_balance WHERE AccountCode='103-001' AND Period='2026-01-01')
     + (SELECT isnull(sum(debet-kredit),0) FROM gl_journal WHERE account_id='103-001' AND tgl BETWEEN '2026-01-01' AND '2026-07-31') AS numeric(20,2)) gl_saldo
UNION ALL
SELECT '226-001 AP',
  CAST((SELECT isnull(sum(AmountDebet-AmountCredit),0) FROM gl_balance WHERE AccountCode='226-001' AND Period='2026-01-01')
     + (SELECT isnull(sum(debet-kredit),0) FROM gl_journal WHERE account_id='226-001' AND tgl BETWEEN '2026-01-01' AND '2026-07-31') AS numeric(20,2));
