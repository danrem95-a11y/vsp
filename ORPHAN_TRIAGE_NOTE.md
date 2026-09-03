# ORPHAN TRIAGE NOTE — Patch HPP EVAP (untuk Pak Wira)

## Pernyataan inti
> Patch HPP EVAP telah memperbaiki kasus konsinyasi lintas bulan **yang sumber cost-nya
> tersedia** (cost consout per nomor seri). Sebanyak **29 unit tidak memiliki cost source
> per-serial**, sehingga **secara sengaja TIDAK disentuh otomatis** — untuk menjaga prinsip
> audit dan mencegah rekonstruksi cost yang tidak memiliki bukti.

## Hasil triase (read-only, per periode Jun–Jul 2026)
| Kelas | Jumlah | Arti |
|---|---|---|
| A. RECOVERABLE (bukti langsung) | **0** | tak ada yg tertutup pembelian sebulan / consout serial-nya |
| B. DATA_MISSING (tak ada histori) | **0** | tidak ada yang benar-benar "hilang total" |
| C. DUPLICATE_IDENTITY (serial lintas stok) | **0** | tiap serial unik ke satu stok |
| **D. NEED_ACCOUNTING_DECISION** | **29** | cost MODEL ada, tapi **cost per-serial-nya tidak ber-bukti** |

Seluruhnya unit truk Thermo King (TR.038A, TR.039A, TR.040A, TR.1004A, TR.1006A, TR.1007A, TR.910A), Juli 2026, @1 unit.

## Kenapa 29 unit ini TIDAK diisi otomatis (justifikasi audit)
1. **Ada cost model, bukan cost serial.** Model-nya (mis. TR.1006A) punya banyak penjualan lampau
   ber-HPP, tapi **nomor seri spesifik ini tidak punya consout ber-HPP sendiri**. Mengisi otomatis =
   memakai cost unit LAIN untuk unit ini → estimasi tanpa bukti langsung.
2. **Model-MAX akan OVERSTATE.** Contoh TR.1006A: cost model-tertinggi **56,19 jt**, padahal
   cost aktual serial sejenis **42,44 jt**. Auto-fill dgn model-MAX menaikkan COGS/laba secara salah.
3. **Prinsip audit:** costing hanya boleh dari bukti transaksi unit itu sendiri. Membiarkan 0 lalu
   menyerahkan ke keputusan akuntansi **lebih dapat dipertanggungjawabkan** daripada menebak.

## Materialitas & catatan pengukuran (WAJIB dibaca)
- **Batas atas eksposur** bila 29 unit diberi cost model-MAX ≈ **Rp 3,41 miliar**. Ini **BUKAN**
  angka pasti — hanya upper-bound untuk menunjukkan bahwa residual ini **MATERIAL**, bukan receh.
- Angka 29 diukur pada **produksi saat ini yang Juli-nya belum di-refresh penuh**. Sebagian consout
  unit ini mungkin masih ber-HPP 0 karena belum di-refresh; **setelah refresh penuh di COPY,
  sebagian dapat KELUAR dari daftar orphan** (consout-nya ter-nilai → fallback bekerja).
- **Angka DEFINITIF = jalankan `run_evap_orphan_triage.sql` di DB COPY SETELAH refresh+close
  Juni & Juli** (sesudah patch). Itulah yang dipakai untuk sign-off.

## Rekomendasi tindak lanjut (dipisah dari patch utama)
1. **Patch utama HPP EVAP: tetap GO** setelah Gate 1–6 PASS (residual 29 orphan BUKAN alasan menolak patch).
2. **29 orphan → data remediation / keputusan akuntansi**, per unit:
   - Telusuri apakah consout unit tsb ada tapi ber-HPP 0 (perbaiki di sumber) → masuk otomatis via patch.
   - Bila benar tak ada bukti cost serial → Pak Wira memutuskan: (a) jurnal COGS manual memakai
     cost model **dengan persetujuan tertulis**, atau (b) biarkan 0 & catat sebagai temuan.
3. **Keterbatasan `MAX` fallback = known limitation + monitoring rule:** selama Gate Harden
   *Dup-Cost=0* & *Future-Cost=0*, `MAX` aman. Jadikan kedua gate ini **cek rutin tiap closing**;
   bila salah satu >0, **hentikan** dan perketat fallback (ambil consout TERAKHIR ≤ tgl jual).

## Posisi audit (narasi ke auditor)
Bukan: *"Kami mengubah HPP karena ada bug."*
Melainkan: **"Kami memperbaiki salah saji costing yang terdeteksi, membuktikan tidak ada regresi
(struktural), mengukur dampak laba (±Rp394 jt), dan secara sengaja TIDAK melakukan estimasi cost
pada 29 unit yang tidak memiliki bukti sumber cost per-serial — melainkan menyerahkannya ke
keputusan akuntansi yang terdokumentasi."**

---
*Script bukti: `run_evap_orphan_triage.sql` (READ-ONLY, ASA9). Semua angka dapat direproduksi.*
