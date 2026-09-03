-- ============================================================
-- TAHAP 2 — PREVENTION: validasi otomatis SETIAP selesai closing/refresh.
-- Aturan: gap = SINV − LEDGER per akun persediaan. gap ≤ Rp1 = PASS; gap > Rp1 = FAIL.
-- Dipasang di akhir proses closing (of_run_modul terakhir / setelah refresh) → bila FAIL,
-- tampilkan warning & JANGAN finalisasi closing (atau tandai perlu review).
-- ============================================================

-- ---- Query validasi (SINV closing = engine = GL) ----
-- Ganti periode: @sinv_next = awal bulan berikut (closing bln ybs) ; @thn_open ; @eom
SELECT g.acc AS akun,
  CAST(isnull(sv.sinv,0) AS numeric(20,2)) AS sinv,
  CAST(isnull(op.opn,0)+isnull(mv.mov,0) AS numeric(20,2)) AS ledger,
  CAST(isnull(sv.sinv,0)-(isnull(op.opn,0)+isnull(mv.mov,0)) AS numeric(20,2)) AS gap,
  CASE WHEN abs(isnull(sv.sinv,0)-(isnull(op.opn,0)+isnull(mv.mov,0))) <= 1
       THEN 'PASS' ELSE 'FAIL' END AS status
FROM (SELECT DISTINCT persediaan acc FROM im_product_group WHERE isnull(persediaan,'')<>'') g
LEFT JOIN (SELECT gr.persediaan acc,sum(s.nilai) sinv FROM sinv s JOIN im_produk pr ON pr.produk_id=s.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE s.periode='2026-08-01' /*@sinv_next*/ GROUP BY gr.persediaan) sv ON sv.acc=g.acc
LEFT JOIN (SELECT AccountCode acc,sum(AmountDebet-AmountCredit) opn FROM gl_balance WHERE Period='2026-01-01' /*@thn_open*/ GROUP BY AccountCode) op ON op.acc=g.acc
LEFT JOIN (SELECT account_id acc,sum(debet-kredit) mov FROM gl_journal WHERE tgl BETWEEN '2026-01-01' AND '2026-07-31' /*@thn_open..@eom*/ GROUP BY account_id) mv ON mv.acc=g.acc
ORDER BY abs(isnull(sv.sinv,0)-(isnull(op.opn,0)+isnull(mv.mov,0))) DESC;

-- ---- Ringkas: berapa akun FAIL (untuk logic PB) ----
SELECT count(*) AS n_fail FROM (
  SELECT g.acc, isnull(sv.sinv,0)-(isnull(op.opn,0)+isnull(mv.mov,0)) gap
  FROM (SELECT DISTINCT persediaan acc FROM im_product_group WHERE isnull(persediaan,'')<>'') g
  LEFT JOIN (SELECT gr.persediaan acc,sum(s.nilai) sinv FROM sinv s JOIN im_produk pr ON pr.produk_id=s.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE s.periode='2026-08-01' GROUP BY gr.persediaan) sv ON sv.acc=g.acc
  LEFT JOIN (SELECT AccountCode acc,sum(AmountDebet-AmountCredit) opn FROM gl_balance WHERE Period='2026-01-01' GROUP BY AccountCode) op ON op.acc=g.acc
  LEFT JOIN (SELECT account_id acc,sum(debet-kredit) mov FROM gl_journal WHERE tgl BETWEEN '2026-01-01' AND '2026-07-31' GROUP BY account_id) mv ON mv.acc=g.acc
) x WHERE abs(gap) > 1;
-- n_fail = 0 → closing SEHAT. n_fail > 0 → ada akun tak match, tampilkan warning, tandai review.

-- ============================================================
-- DESAIN PEMASANGAN di PowerBuilder (w_refresh_transaksi_modern, akhir event MULAI REFRESH):
--   long ll_fail
--   select count(*) into :ll_fail from (<query n_fail>) using sqlca;
--   if ll_fail > 0 then
--       of_write_log('PERINGATAN: ' + string(ll_fail) + ' akun Stok<>Ledger > Rp1. Closing perlu review.')
--       st_status.text = 'Status : WARNING (Stok<>Ledger)'
--   else
--       of_write_log('VALIDASI OK: semua akun Stok = Ledger (<= Rp1).')
--   end if
-- (Simpan juga ke refresh_ledger.status = 'WARNING'/'SUCCESS' agar teraudit.)
-- ============================================================
