-- ============================================================================
-- audit_movement_gap.sql  -- AUDIT MOVEMENT GL vs STOK 2026 (READ-ONLY, forensik)
-- Recovery opening 2026 = CLOSED/TERKUNCI; script ini TIDAK menyentuhnya.
-- ATURAN: TIDAK ADA UPDATE/INSERT/DELETE. Hanya SELECT. Tidak buat jurnal koreksi.
-- Linkage GL<->stok BTB: GL voucher '101BTB'||pppp||sssss  <->  stok BUKTI_ID '101'||pppp||'02'||sssss
--   reverse: voucher = '101BTB'+substring(bukti,4,4)+substring(bukti,10,5)
--   forward: bukti   = '101'+substring(voucher,7,4)+'02'+substring(voucher,11,5)
-- Periode audit: 2026-01-01 .. 2026-02-28 (ubah di WHERE bila perlu).
-- ============================================================================

-- ---------- A. RINGKAS GAP per akun: GL movement vs sinv closing (acuan) ----------
-- gap = sinv_closing - (gl_balance[2026-01-01] + gerakan GL s/d akhir bulan)
SELECT p.acc,
  cast(isnull(sf,0) as numeric(20,2)) sinv_closing_feb,
  cast(isnull(go,0)+isnull(gj,0)+isnull(gf,0) as numeric(20,2)) gl_closing_feb,
  cast(isnull(sf,0)-isnull(go,0)-isnull(gj,0)-isnull(gf,0) as numeric(18,2)) gap_feb
FROM (SELECT DISTINCT persediaan acc FROM im_product_group WHERE persediaan IN ('102-203','102-101','102-010','102-102','102-103','102-110')) p
LEFT JOIN (SELECT gr.persediaan a, sum(isnull(sv.nilai,0)) sf FROM sinv sv JOIN im_produk pr ON pr.produk_id=sv.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE sv.periode='2026-03-01' GROUP BY gr.persediaan) F ON F.a=p.acc
LEFT JOIN (SELECT AccountCode a, sum(isnull(AmountDebet,0)-isnull(AmountCredit,0)) go FROM gl_balance WHERE Period='2026-01-01' GROUP BY AccountCode) GO ON GO.a=p.acc
LEFT JOIN (SELECT account_id a, sum(isnull(debet,0)-isnull(kredit,0)) gj FROM gl_journal WHERE tgl BETWEEN '2026-01-01' AND '2026-01-31' GROUP BY account_id) J ON J.a=p.acc
LEFT JOIN (SELECT account_id a, sum(isnull(debet,0)-isnull(kredit,0)) gf FROM gl_journal WHERE tgl BETWEEN '2026-02-01' AND '2026-02-28' GROUP BY account_id) GF ON GF.a=p.acc
ORDER BY abs(isnull(sf,0)-isnull(go,0)-isnull(gj,0)-isnull(gf,0)) DESC;

-- ---------- A2. GL movement per akun/bulan/modul (pecah sumber) ----------
SELECT account_id, month(tgl) bln, modul_id,
  cast(sum(isnull(debet,0)-isnull(kredit,0)) as numeric(18,2)) net
FROM gl_journal
WHERE account_id IN ('102-203','102-101','102-010','102-102','102-103','102-110')
  AND tgl BETWEEN '2026-01-01' AND '2026-02-28'
GROUP BY account_id, month(tgl), modul_id ORDER BY account_id, bln, modul_id;

-- ============================================================================
-- B. REKONSILIASI PER (AKUN, VOUCHER) BTB -- inti temuan RC-1 (blank produk)
--    gl_net = Dr-Cr GL utk akun; stok_valid = netto stok berproduk-valid utk akun; stok_blank = netto stok tanpa produk (whole BTB)
--    Status: MATCH bila stok_valid ~ gl_net; GL ONLY bila stok_valid=0 (blank/missing).
-- ============================================================================
SELECT g.account_id akun, g.tgl, g.voucher, g.modul_id,
  cast(sum(isnull(g.debet,0)-isnull(g.kredit,0)) as numeric(16,2)) gl_net,
  cast((SELECT isnull(sum(t2.NETTO),0) FROM tstok2 t2 JOIN im_produk pr ON pr.produk_id=t2.produk_id JOIN im_product_group gr ON gr.kode_group=pr.group_product
        WHERE t2.BUKTI_ID='101'+substring(g.voucher,7,4)+'02'+substring(g.voucher,11,5) AND gr.persediaan=g.account_id) as numeric(16,2)) stok_valid_akun,
  cast((SELECT isnull(sum(t2.NETTO),0) FROM tstok2 t2
        WHERE t2.BUKTI_ID='101'+substring(g.voucher,7,4)+'02'+substring(g.voucher,11,5) AND (t2.produk_id IS NULL OR trim(t2.produk_id)='')) as numeric(16,2)) stok_blank
FROM gl_journal g
WHERE g.account_id IN ('102-203','102-101','102-010','102-102','102-103','102-110')
  AND g.modul_id='PO' AND g.voucher LIKE '101BTB%' AND g.tgl BETWEEN '2026-01-01' AND '2026-02-28'
GROUP BY g.account_id, g.tgl, g.voucher, g.modul_id
ORDER BY g.account_id, g.tgl;

-- ---------- B2. KONTROL: adakah SATU pun BTB Jan-Feb dgn produk valid? (0 = bug sistemik) ----------
SELECT
 (SELECT count(DISTINCT t1.BUKTI_ID) FROM tstok1 t1 JOIN tstok2 t2 ON t2.BUKTI_ID=t1.BUKTI_ID
    WHERE t1.TIPE_TRANS='02' AND t1.TGL BETWEEN '2026-01-01' AND '2026-02-28' AND t2.produk_id IS NOT NULL AND trim(t2.produk_id)<>'') btb_produk_VALID,
 (SELECT count(DISTINCT t1.BUKTI_ID) FROM tstok1 t1 JOIN tstok2 t2 ON t2.BUKTI_ID=t1.BUKTI_ID
    WHERE t1.TIPE_TRANS='02' AND t1.TGL BETWEEN '2026-01-01' AND '2026-02-28' AND (t2.produk_id IS NULL OR trim(t2.produk_id)='')) btb_produk_BLANK,
 (SELECT cast(sum(isnull(t2.NETTO,0)) as numeric(18,2)) FROM tstok1 t1 JOIN tstok2 t2 ON t2.BUKTI_ID=t1.BUKTI_ID
    WHERE t1.TIPE_TRANS='02' AND t1.TGL BETWEEN '2026-01-01' AND '2026-02-28' AND (t2.produk_id IS NULL OR trim(t2.produk_id)='')) netto_blank_total;

-- ============================================================================
-- C. RC-2 SALAH NILAI -- BTB valuta asing: GL(IDR=USD*kurs) vs stok(USD mentah)
-- ============================================================================
SELECT t1.BUKTI_ID, t1.TGL, t1.USER_ID, t1.CURR_ID, cast(t1.KURS as numeric(14,4)) kurs, t1.VENDOR_ID,
  cast(t1.TTL_NETTO as numeric(16,2)) stok_netto_valas,
  cast(t1.TTL_NETTO*t1.KURS as numeric(18,2)) seharusnya_idr,
  cast((SELECT sum(isnull(debet,0)-isnull(kredit,0)) FROM gl_journal g WHERE g.voucher='101BTB'+substring(t1.BUKTI_ID,4,4)+substring(t1.BUKTI_ID,10,5) AND g.account_id LIKE '102%') as numeric(18,2)) gl_idr
FROM tstok1 t1
WHERE t1.TIPE_TRANS='02' AND t1.TGL BETWEEN '2026-01-01' AND '2026-02-28' AND t1.CURR_ID<>'IDR'
ORDER BY t1.TGL;

-- ============================================================================
-- D. RC-3 SALAH QTY -- TL.203.0504: qty sinv naik tanpa pembelian
-- ============================================================================
SELECT periode, cast(qty as numeric(14,2)) qty, cast(nilai as numeric(16,2)) nilai, cast(hpp_avg as numeric(14,4)) hpp_avg
FROM sinv WHERE stok_id='TL.203.0504' AND periode BETWEEN '2026-01-01' AND '2026-03-01' ORDER BY periode;
-- pembelian tstok (harus 0) vs penjualan tsales '22'
SELECT 'tstok_beli' src, count(*) n, cast(sum(isnull(NETTO,0)) as numeric(16,2)) netto FROM tstok2 WHERE produk_id='TL.203.0504'
  AND BUKTI_ID IN (SELECT BUKTI_ID FROM tstok1 WHERE TGL BETWEEN '2026-01-01' AND '2026-02-28')
UNION ALL
SELECT 'tsales_jual22', count(*), cast(sum(isnull(HPP,0)*isnull(QTY,0)) as numeric(16,2)) FROM tsales2 s2 JOIN tsales1 s1 ON s1.BUKTI_ID=s2.BUKTI_ID
  WHERE s2.STOK_ID='TL.203.0504' AND s1.TIPE_TRANS='22' AND s1.TGL BETWEEN '2026-01-01' AND '2026-02-28';

-- ============================================================================
-- E. Detail 1 BTB (contoh 102-203) -- Dr/Cr + user + stok (produk kosong)
-- ============================================================================
SELECT g.voucher, g.account_id, cast(isnull(g.debet,0) as numeric(16,2)) debet, cast(isnull(g.kredit,0) as numeric(16,2)) kredit, g.modul_id, g.doc_reff, left(g.ket,45) ket
FROM gl_journal g WHERE g.voucher IN ('101BTB260200022','101BTB260400004') ORDER BY g.voucher, g.account_id;
SELECT t1.BUKTI_ID, t1.USER_ID, t2.produk_id, cast(t2.QTY as numeric(12,2)) qty, cast(t2.NETTO as numeric(16,2)) netto
FROM tstok1 t1 JOIN tstok2 t2 ON t2.BUKTI_ID=t1.BUKTI_ID WHERE t1.BUKTI_ID IN ('10126020200022','10126040200004');

-- ============================================================================
-- F. METODOLOGI A -- PECAH MOVEMENT GL per VOUCHER (voucher/tgl/account/debet/kredit/modul/ref/USER/ket)
--    user diambil dari tstok1.USER_ID via konversi voucher BTB->BUKTI_ID (gl_journal tak simpan user).
--    Kolom "ada_pasangan_stok": netto stok BERPRODUK-VALID utk akun ini (0 = GL tanpa pasangan stok).
-- ============================================================================
SELECT g.tgl, g.account_id, g.voucher, g.modul_id,
  cast(sum(isnull(g.debet,0)) as numeric(16,2)) debet, cast(sum(isnull(g.kredit,0)) as numeric(16,2)) kredit,
  max(g.doc_reff) ref_dok,
  (SELECT max(t1.USER_ID) FROM tstok1 t1 WHERE t1.BUKTI_ID='101'+substring(g.voucher,7,4)+'02'+substring(g.voucher,11,5)) usr,
  max(left(g.ket,40)) keterangan,
  cast((SELECT isnull(sum(t2.NETTO),0) FROM tstok2 t2 JOIN im_produk pr ON pr.produk_id=t2.produk_id JOIN im_product_group gr ON gr.kode_group=pr.group_product
        WHERE t2.BUKTI_ID='101'+substring(g.voucher,7,4)+'02'+substring(g.voucher,11,5) AND gr.persediaan=g.account_id) as numeric(16,2)) ada_pasangan_stok
FROM gl_journal g
WHERE g.account_id IN ('102-203','102-101','102-010','102-102','102-103','102-110')
  AND g.tgl BETWEEN '2026-01-01' AND '2026-02-28'
GROUP BY g.tgl, g.account_id, g.voucher, g.modul_id
ORDER BY g.account_id, g.tgl;

-- ============================================================================
-- G. METODOLOGI B -- PECAH MOVEMENT STOK dari sumber asli (cari stok TANPA pasangan GL)
--    G1 = tstok (BTB'02'/mutasi'09''19'/retur'12'); G2 = tsales (jual'22'/consin-WIP'88')
-- ============================================================================
-- G1. tstok per akun (produk valid) + status produk
SELECT gr.persediaan akun, t1.TIPE_TRANS, t1.TGL, t1.BUKTI_ID, t1.USER_ID,
  cast(sum(isnull(t2.NETTO,0)) as numeric(16,2)) netto,
  sum(case when t2.produk_id is null or trim(t2.produk_id)='' then 1 else 0 end) baris_produk_kosong
FROM tstok1 t1 JOIN tstok2 t2 ON t2.BUKTI_ID=t1.BUKTI_ID
  LEFT JOIN im_produk pr ON pr.produk_id=t2.produk_id LEFT JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE t1.TGL BETWEEN '2026-01-01' AND '2026-02-28'
  AND (gr.persediaan IN ('102-203','102-101','102-010','102-102','102-103','102-110')
       OR t2.produk_id IS NULL OR trim(t2.produk_id)='')
GROUP BY gr.persediaan, t1.TIPE_TRANS, t1.TGL, t1.BUKTI_ID, t1.USER_ID
ORDER BY t1.TGL;
-- G2. tsales (jual '22' = COGS Cr persediaan; '88' = WIP/consin) per akun
SELECT gr.persediaan akun, s1.TIPE_TRANS, count(*) n,
  cast(sum(isnull(s2.HPP,0)*isnull(s2.QTY,0)) as numeric(18,2)) nilai_hpp
FROM tsales2 s2 JOIN tsales1 s1 ON s1.BUKTI_ID=s2.BUKTI_ID
  JOIN im_produk pr ON pr.produk_id=s2.STOK_ID JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE gr.persediaan IN ('102-203','102-101','102-010','102-102','102-103','102-110')
  AND s1.TIPE_TRANS IN ('22','88') AND s1.TGL BETWEEN '2026-01-01' AND '2026-02-28'
GROUP BY gr.persediaan, s1.TIPE_TRANS ORDER BY gr.persediaan, s1.TIPE_TRANS;

-- CATATAN WIP: modul WIP (tsales '88' / tstok '88') TIDAK muncul sebagai penyebab gap ke-6 akun ini
--   (tak ada baris '88' material pada akun target). WIP 102-020 & HPP-WIP tidak disentuh & bukan penyebab.

-- ============================================================================
-- H. TABEL MOVEMENT 9 AKUN (headline metodologi A) -- GL_mov vs Stock_mov(Δsinv) vs Selisih
--    Stock Movement = sinv nilai closing(2026-03-01) - opening(2026-01-01); GL = Σ(debet-kredit) Jan-Feb.
-- ============================================================================
SELECT p.acc,
  cast(isnull(gj.v,0) as numeric(18,2)) gl_movement,
  cast(isnull(sc.v,0)-isnull(so.v,0) as numeric(18,2)) stock_movement,
  cast((isnull(sc.v,0)-isnull(so.v,0))-isnull(gj.v,0) as numeric(18,2)) selisih
FROM (SELECT DISTINCT persediaan acc FROM im_product_group WHERE persediaan IN ('102-001','102-006','102-010','102-101','102-102','102-103','102-110','102-201','102-203')) p
LEFT JOIN (SELECT account_id a, sum(isnull(debet,0)-isnull(kredit,0)) v FROM gl_journal WHERE tgl BETWEEN '2026-01-01' AND '2026-02-28' GROUP BY account_id) gj ON gj.a=p.acc
LEFT JOIN (SELECT gr.persediaan a, sum(isnull(sv.nilai,0)) v FROM sinv sv JOIN im_produk pr ON pr.produk_id=sv.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE sv.periode='2026-01-01' GROUP BY gr.persediaan) so ON so.a=p.acc
LEFT JOIN (SELECT gr.persediaan a, sum(isnull(sv.nilai,0)) v FROM sinv sv JOIN im_produk pr ON pr.produk_id=sv.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product WHERE sv.periode='2026-03-01' GROUP BY gr.persediaan) sc ON sc.a=p.acc
ORDER BY abs((isnull(sc.v,0)-isnull(so.v,0))-isnull(gj.v,0)) DESC;

-- ============================================================================
-- I. RC-3 REKON ENGINE TL.203.0504 (bukti SALAH QTY: closing != opening - jual + beli)
-- ============================================================================
SELECT
  (SELECT cast(qty as numeric(14,2)) FROM sinv WHERE stok_id='TL.203.0504' AND periode='2026-01-01') opening_jan,
  (SELECT isnull(sum(s2.QTY),0) FROM tsales2 s2 JOIN tsales1 s1 ON s1.BUKTI_ID=s2.BUKTI_ID WHERE s2.STOK_ID='TL.203.0504' AND s1.TIPE_TRANS='22' AND s1.TGL BETWEEN '2026-01-01' AND '2026-01-31') jual_jan,
  (SELECT isnull(sum(t2.QTY),0) FROM tstok1 t1 JOIN tstok2 t2 ON t2.BUKTI_ID=t1.BUKTI_ID WHERE t2.produk_id='TL.203.0504' AND t1.TGL BETWEEN '2026-01-01' AND '2026-01-31') beli_jan,
  (SELECT cast(qty as numeric(14,2)) FROM sinv WHERE stok_id='TL.203.0504' AND periode='2026-02-01') sinv_closing_jan;
-- seharusnya_closing = opening - jual + beli ; selisih vs sinv_closing_jan = qty tak bersumber (RC-3).

