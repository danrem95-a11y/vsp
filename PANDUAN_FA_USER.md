# Panduan Pemakaian Modul Aktiva Tetap (FA) + Closing Bulanan

**Untuk:** user akuntansi & operator closing | **Modul:** menu **"Aktiva Tetap"** (grup 62)
**Berlaku:** produksi vspnew (SA9) site 101 | Penyusutan: garis lurus (straight-line), cut-off saldo awal 31/12/2025

---

## A. Menu & Fungsinya

| Menu | Window | Fungsi |
|---|---|---|
| Ringkasan Aktiva | w_rpt_fa_summary | Dashboard ringkas per kategori (jumlah aset/perolehan/akumulasi/NBV); drill ke Kartu Aktiva. |
| Master Kategori Aktiva | w_fa_category | Lihat/atur 5 kategori (BGN/KDR/PKT/PBK/TNH): akun aset, akun akumulasi, akun beban, umur, metode. **Jarang diubah.** |
| Master Aktiva Tetap | w_fa_master | Input/ubah aset: kode, nama, kategori, tgl perolehan, harga perolehan, saldo awal (akum & sisa umur), status. |
| Generate Penyusutan | w_fa_generate | Hitung & posting penyusutan per bulan ke GL. **Layar utama closing.** |
| Daftar Aktiva Tetap | w_rpt_fa_register | Laporan daftar seluruh aset + nilai buku. |
| Kartu Aktiva | w_rpt_fa_card | Riwayat penyusutan per aset (drill-down ke voucher GL). |
| Rekap Penyusutan | w_rpt_fa_rekap | Rekap penyusutan per kategori (cek sebelum/ sesudah posting). |
| Umur Aktiva | w_rpt_fa_aging | Umur aset + bucket (0-1/2-5/6-10/>10 th) berdasar NBV/sisa umur; drill ke Kartu Aktiva. |

---

## B. Alur Kerja Harian/Bulanan

### 1. Menambah aset baru (saat ada pembelian)
Master Aktiva Tetap → tambah baris:
- **Kode** unik (mis. KDR-0032), **Nama**, **Kategori** (pilih BGN/KDR/PKT/PBK/TNH).
- **Tgl perolehan** & **Harga perolehan**.
- **Saldo awal** — untuk aset BARU: akumulasi awal = 0, sisa umur = umur kategori, nilai buku awal = harga perolehan.
- **Tanah (TNH)**: tidak disusutkan — cukup harga perolehan, akum 0.
- Status **A** (aktif).

> Penting: penyusutan dihitung dari **nilai buku awal ÷ sisa umur**. Pastikan dua kolom ini benar untuk aset baru/penambahan.

### 2. Laporan
Buka Daftar/Kartu/Rekap kapan saja (read-only, aman).

---

## C. Closing Bulanan (langkah baku)

**Prinsip:** boleh generate/regenerate berulang **selama periode belum di-close**. Setelah closing, sistem menolak perubahan periode itu.

### Langkah
1. **Cek master** — pastikan semua aset baru bulan berjalan sudah diinput dengan benar (tgl, cost, kategori, sisa umur).
2. **Generate** — Generate Penyusutan → pilih periode (akhir bulan, mis. 31/07/2026) → **Preview**. Sistem menghitung draft.
3. **Review** — buka Rekap Penyusutan, cek angka per kategori wajar.
4. **Posting** — konfirmasi posting. Jurnal masuk GL: **Dr 412-066 / Cr 158-xxx** per kategori, voucher **FA101YYYYMM** (modul FA).
5. **Cek tie ke GL** — jalankan rekonsiliasi (Bagian D). Delta harus sesuai.
6. **Closing** — setelah yakin, tutup periode (status periode → Closed). Setelah ini generate/posting periode tsb ditolak.

### Bila ada koreksi SEBELUM closing
Regenerate periode (hitung ulang + posting ulang) — voucher FA periode itu ditimpa, tidak dobel.

### Operasi via SQL (operator/DBA, bila tidak lewat UI)
```sql
CALL sp_fa_generate_sl ('2026-07-31','101');   -- hitung draft
CALL sp_fa_post_period ('2026-07-31','101');   -- posting ke GL (modul FA)
CALL sp_fa_build_gl_link('2026-07-31','101');  -- bind aset ↔ baris jurnal (untuk Kartu Aktiva)
-- koreksi sebelum closing:
CALL sp_fa_regenerate_period('2026-07-31','101');
```

---

## D. Rekonsiliasi (cek sub-ledger = GL)

Jalankan kapan saja (read-only):
```sql
SELECT * FROM v_fa_recon_gl WHERE site_id='101' ORDER BY account_type, account_code;
```
Baca kolom **residual_unexpl** (selisih register vs GL setelah memperhitungkan aset perolehan-setelah-cutoff):
- **≈ 0** → cocok (Tanah, Bangunan, P.Bengkel, P.Kantor).
- **> 0 / < 0** → ada item yang perlu ditelaah (aset hilang / beda kebijakan).

> **Catatan Kendaraan:** akun 155-001/158-301 menunjukkan selisih **PAJE audit yang belum dibukukan** (register pakai basis audit-listing, GL pakai book). Ini **terdokumentasi & disengaja**, bukan error — lihat `MEMO_REKONSILIASI_FA_FINAL.md`. Jangan "dipaksa nol".

---

## E. Yang BOLEH & TIDAK

**Boleh:** tambah aset, generate/regenerate sebelum closing, jalankan laporan & rekonsiliasi kapan saja.

**Hati-hati / hindari:**
- Jangan edit voucher **FA101YYYYMM** langsung di jurnal manual — selalu lewat generate/regenerate agar sub-ledger & GL sinkron.
- Jangan hapus aset yang sudah punya penyusutan terposting (gunakan status/disposal, bukan delete).
- Setelah periode **Closed**, jangan paksa ubah — buka periode hanya lewat prosedur regenerate (sebelum closing) atau kebijakan akuntansi.

---

## F. Kontak masalah
- Selisih rekonsiliasi tak wajar → cek `v_fa_recon_gl` + Kartu Aktiva aset terkait.
- Rollback darurat → `fa_99_rollback_PRODUKSI.sql` (DBA).
- Voucher/angka → bandingkan Rekap Penyusutan vs jurnal GL voucher FA101YYYYMM.
