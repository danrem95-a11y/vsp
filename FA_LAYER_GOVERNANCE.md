# FA Layer Governance — Accounting Control Layer Modul Fixed Asset

**DB:** `vspnew` (DSN `vsp`, site `101`) · **Status:** aktif (di-deploy & tervalidasi 2026-06-20)
**Objek:** `v_fa_recon_asset`, `v_fa_recon_gl`, `sp_fa_recon` — lihat [fa_11_recon_view.sql](fa_11_recon_view.sql)
**Memo arbitrase angka:** [MEMO_REKONSILIASI_FA_FINAL.md](MEMO_REKONSILIASI_FA_FINAL.md)

Dokumen ini adalah **kontrak (the "harusnya")**; view/procedure di `fa_11_recon_view.sql` adalah **enforcement-nya (the "kenyataannya")**. Keduanya saling mengunci: doc tanpa view = filosofi; view tanpa doc = tooling tanpa guardrail.

---

## 1. Tujuan Layer

Mengikat tiga layer Fixed Asset menjadi satu kontrol rekonsiliasi permanen, sehingga selisih register-vs-GL ketahuan **saat closing** (real-time lewat view), bukan **saat audit**. Setiap kasus seperti Kendaraan (basis audit-listing vs book) terklasifikasi otomatis, bukan jadi debat berulang.

| Layer | Objek DB | Peran | Sumber kebenaran |
|---|---|---|---|
| **L1 — Asset Register** | `FA_ASSET` + `FA_CATEGORY` | daftar aset & pemetaan akun GL | kelengkapan migrasi |
| **L2 — Engine** | `FA_DEPRECIATION`, `FA_PERIOD` | perhitungan penyusutan per periode | terkunci per periode |
| **L3 — General Ledger** | `gl_balance`, `gl_journal` | saldo & jurnal resmi | **source of truth saldo** |
| **Bridge** | `FA_GL_LINK` | mengikat tiap penyusutan → baris jurnal GL | deterministik (PRO-RATA) |

---

## 2. Source of Truth

1. **Saldo (opening balance) = `gl_balance`.** Register tidak pernah meng-override GL. Bila register ≠ GL, yang dipertanyakan adalah kelengkapan/kebijakan register, bukan GL.
2. **Pemetaan akun GL = `FA_CATEGORY`**, BUKAN `FA_ASSET`. Kolom `FA_ASSET.asset_account`/`accum_dep_account` kosong (0/279 terisi) — terverifikasi 2026-06-20. Semua view & `FA_GL_LINK` mengambil akun via `JOIN FA_CATEGORY`. Mapping aktif:

   | Kategori | asset_account | accum_dep_account | dep_expense_account |
   |---|---|---|---|
   | BGN Bangunan | 151-100 | 158-001 | 412-066 |
   | KDR Kendaraan | 155-001 | 158-301 | 412-066 |
   | PBK P.Bengkel | 154-001 | 158-201 | 412-066 |
   | PKT P.Kantor | 153-001 | 158-101 | 412-066 |
   | TNH Tanah | 151-001 | *(null — non-depresiasi)* | *(null)* |

3. **Pergerakan (penyusutan 2026) = valid & terposting.** Jurnal FA Jan–Jun 2026 sudah cocok GL (memo §3). Recon layer hanya menilai **saldo register vs GL**, tidak membongkar pergerakan.

---

## 3. Cutoff Policy *(§cutoff)*

- **Cutoff resmi = `gl_balance` Period `2026-01-01`** = opening FY2026 = saldo 31/12/2025.
- Cutoff **DIKUNCI eksplisit** sebagai konstanta `'2026-01-01'` di kedua view, dan sebagai parameter `p_cutoff` (default `'2026-01-01'`) di `sp_fa_recon`.
- **DILARANG memakai `MAX(Period)`** sebagai cutoff. `gl_balance` menyimpan satu snapshot opening per tahun (1-Jan tiap tahun, 2009→2026). `MAX(Period)` kebetulan = `2026-01-01` hari ini, tapi akan bergeser ke `2027-01-01` begitu closing FY2026 → seluruh rekonsiliasi diam-diam membandingkan register ke opening tahun berikutnya. Ini design flaw yang sudah diperbaiki; jangan dikembalikan.
- **Pindah FY:** ganti satu konstanta `'2026-01-01'` di kedua view (re-deploy view) **dan/atau** panggil `sp_fa_recon('2027-01-01','101')` tanpa ubah kode.

---

## 4. Treatment `recon_tag` (per aset — `v_fa_recon_asset`, Output B)

Urutan evaluasi (prioritas atas-ke-bawah):

| Tag | Kondisi | Arti & tindakan |
|---|---|---|
| `NON_DEPRECIABLE` | `accum_dep_account IS NULL` (kategori TNH) | Tanah; tidak disusutkan; akum=0 wajar. |
| `INTERNAL_MISMATCH` | `\|cost − (akum+NBV)\| > 1` | Inkonsistensi internal register (cost≠akum+NBV). **Wajib koreksi** (cth KDR-0002/0003/0004). |
| `POST_CUTOFF` | `acquisition_date >= cutoff` | Perolehan setelah cutoff; **benar belum ada di GL opening**. Bukan selisih riil — dinetralkan via `post_cutoff_amt`. |
| `FULLY_DEPRECIATED` | `akum >= cost − 1` | Habis-susut; NBV≈0 wajar. |
| `ZERO_ACCUM_REVIEW` | `akum = 0 AND cost > 0` | Akum nol tapi berbiaya → **review** (cth 5 aset TA Kendaraan). |
| `ACTIVE` | selain di atas | Normal. |

**Klasifikasi residual GL (`v_fa_recon_gl`, Output A):** `residual_unexpl = delta − post_cutoff_amt`.
- `≈ 0` → cocok / hanya timing (cth 153-001: delta +8.735.000 tapi residual 0).
- `< 0` → register **kurang** vs GL = **missing asset** (cth 151-100/158-001: −394,5 jt = 6 aset Bangunan belum dimigrasi).
- `> 0` → register **lebih** vs GL = **policy/PAJE** (cth 155-001: +1.750.976.482 = basis audit-listing vs book, PAJE pending).

---

## 5. Mapping Output

### Output A — Finance (ringkas, per akun) → `v_fa_recon_gl` / `sp_fa_recon`
Kolom: `account_code, account_type, register_amt, gl_amt, delta, post_cutoff_amt, residual_unexpl, gl_period`.
Untuk closing & neraca: satu baris per akun, langsung tie ke GL.

### Output B — Audit (detail, per aset) → `v_fa_recon_asset`
Kolom: identitas aset + `acquisition_cost, accum_dep_beginning, book_value_beginning, internal_diff, recon_tag`.
Untuk investigasi level-aset (cth penelusuran Kendaraan di memo §5).

---

## 6. Aturan Pokok (no-override policy)

1. **GL tidak di-override oleh register.** Selisih = reconciling item, diselesaikan lewat data (Paket A) atau kebijakan (PAJE), bukan dengan memaksa GL.
2. **Engine terkunci per periode.** `FA_DEPRECIATION`/jurnal Jan–Jun 2026 yang sudah tervalidasi tidak dibongkar untuk "membenarkan" angka. Menurunkan basis Kendaraan = membatalkan jurnal tervalidasi → dilarang (memo §5.1).
3. **PAJE = bridge, bukan rewrite history.** Selisih kebijakan (cth Kendaraan +1,751 M) dicatat sebagai PAJE pending yang dieskalasi ke akuntan, bukan dengan menghapus aset riil atau mengedit saldo historis.
4. **Akun selalu dari `FA_CATEGORY`** (lihat §2).

---

## 7. Deployment Procedure

```
# 32-bit ODBC (DSN vsp arsitektur 32-bit). Jalankan fa_11_recon_view.sql statement-by-statement
# via ODBC, atau lewat Interactive SQL Anywhere (dbisql) terhadap DSN vsp.
# Idempotent: tiap objek drop-if-exists (SYS.SYSTABLE table_type='VIEW' / SYS.SYSPROCEDURE) lalu create.
```

**Validasi wajib pasca-deploy** (semua harus pass):
- 3 objek ada: `v_fa_recon_asset`, `v_fa_recon_gl` (SYS.SYSTABLE, VIEW), `sp_fa_recon` (SYS.SYSPROCEDURE).
- `v_fa_recon_gl` mengembalikan **8 baris** (4 ASSET + 4 ACCUM), `account_code` terisi (bukan null).
- Angka `delta` cocok memo §4 (151-100 −394.500.000; 155-001 +1.750.976.482; 158-301 +92.499.992; 154-001 = 0).
- `POST_CUTOFF` = PKT-0177 & PKT-0178 saja.

> **Catatan katalog:** JANGAN gunakan `sys.sysview`/`sys.sysprocedure` (tidak ada di SQL Anywhere ini → skrip gagal senyap dan objek tak pernah tercipta). Gunakan `SYS.SYSTABLE` (view) & `SYS.SYSPROCEDURE` (proc).

---

## 8. Rollback Procedure

Layer 100% additive & read-only terhadap data (tak ada INSERT/UPDATE/DELETE; tak menyentuh FA_ASSET/FA_DEPRECIATION/gl_balance/jurnal). Rollback penuh:

```sql
DROP VIEW v_fa_recon_asset;
DROP VIEW v_fa_recon_gl;
DROP PROCEDURE sp_fa_recon;
```

Tidak ada efek samping pada data; aman dijalankan kapan saja.

---

## 9. Catatan State Saat Ini (2026-06-20)

- Data masih **pra-Paket A**: kategori TNH belum ada aset (11 master Tanah belum dimigrasi); 6 aset Bangunan habis-susut belum dimuat → residual `< 0` di 151-100/158-001 adalah **expected** sampai [fa_10_koreksi_paket_A.sql](fa_10_koreksi_paket_A.sql) dijalankan.
- Setelah Paket A: residual Bangunan & Tanah seharusnya → 0; Kendaraan (+1,751 M) tetap sebagai PAJE pending (keputusan akuntan, memo §7 Paket B).
