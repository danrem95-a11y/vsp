-- =====================================================================
-- KOREKSI selisih AP Juli 2026 = 409.800 (recon 226 Jaya Diesel).
-- Akar: faktur non-item NOITEM260700029 (ap_trans BUKTI_ID 10126079900029,
--       BUKTI_REFF 585016583766771, netto 409.800, vendor 4SL.G009, tgl 14/07)
--       -> ACCOUNT_ID pd dokumen KOSONG -> engine benar pakai default hutang
--          non-item = 227-003 (Cr 409.800).
--       Pembayaran CO voucher 100310126070108 (Dr 226-001) mengurangi 226,
--       BUKAN 227-003. -> 226 kelebihan bayar 409.800 ; 227-003 menggantung.
-- BUKAN bug refresh: engine mem-posting kedua dokumen APA ADANYA (faktur->227
--       default non-item, bayar->226 sesuai voucher CO). Selisih = akun bayar
--       tak cocok dgn akun faktur. Opname Jaya Juli = 0 (subledger seimbang).
-- Catatan: vendor dokumen = 4SL.G009 tapi ket "JAYA DIESEL" -> mohon pastikan
--       ini beneran hutang Jaya Diesel atau G009 (tak mengubah perbaikan akun).
-- =====================================================================
-- CEK SEBELUM (harus: 226 Jaya net -409.800, 227-003 NOITEM..029 Cr 409.800 belum lunas)
select '226 Jaya net (harus -409.800)' info,
  cast(sum(kredit)-sum(debet) as numeric(18,2)) net
from gl_journal where site_id='101' and account_id='226-001' and posting='P'
  and upper(isnull(ket,'')) like '%JAYA DIESEL%' and tgl between '2026-01-01' and '2026-07-31';

-- ================= OPSI A (DISARANKAN): perbaiki di aplikasi =================
-- Buka modul Cash Out, voucher 100310126070108 (manual 26071003P101),
-- ganti akun 226-001 -> 227-003, simpan (GL ter-generate ulang benar).
-- Lebih aman & tahan re-refresh. TIDAK perlu SQL di bawah kalau pakai cara ini.

-- ================= OPSI B: reklas jurnal GJ (bila CO tak bisa diedit) =========
-- Lewat menu Jurnal/Memo aplikasi (disarankan, auto voucher+posting+balance):
--   Tgl 2026-07-31, keterangan "Reklas byr NOITEM260700029 227<->226"
--   Dr 227-003  409.800
--   Cr 226-001  409.800
-- Efek: 226-001 +Cr 409.800 (tak lagi kelebihan bayar) ; 227-003 +Dr 409.800 (lunas).

-- ================= OPSI C (surgical, kalau memang mau langsung di GL) =========
-- HANYA jika refresh TIDAK meng-regenerate voucher CO ini (cek dulu!). Pindahkan
-- sisi debit pembayaran dari 226-001 ke 227-003 pada baris pembayaran itu:
-- update gl_journal set account_id='227-003'
--  where site_id='101' and voucher='100310126070108' and urut=2 and account_id='226-001' and posting='P';
-- commit;

-- CEK SESUDAH (target: 226 Jaya net 0)
-- select cast(sum(kredit)-sum(debet) as numeric(18,2)) net_226_jaya
--   from gl_journal where site_id='101' and account_id='226-001' and posting='P'
--    and upper(isnull(ket,'')) like '%JAYA DIESEL%' and tgl between '2026-01-01' and '2026-07-31';
-- Lalu re-run recon AP Juli -> Check harus ~0 (rounding).
