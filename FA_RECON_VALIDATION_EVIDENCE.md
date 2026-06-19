# FA Recon Layer — Bukti Validasi Deploy

**Tanggal:** 2026-06-20 · **DB:** `vspnew` (DSN `vsp`, site `101`) · **State data:** pra-Paket A
**Objek:** [fa_11_recon_view.sql](fa_11_recon_view.sql) · **Kontrak:** [FA_LAYER_GOVERNANCE.md](FA_LAYER_GOVERNANCE.md) · **Arbitrase angka:** [MEMO_REKONSILIASI_FA_FINAL.md](MEMO_REKONSILIASI_FA_FINAL.md)

Tujuan dokumen: memberi reviewer akuntansi bukti bahwa reconciliation layer ter-deploy dan menghasilkan angka benar, **tanpa harus mengulang investigasi**.

---

## 1. Objek ter-create

```
obj                 kind
sp_fa_recon         PROC
v_fa_recon_asset    VIEW
v_fa_recon_gl       VIEW
(3 rows)
```
Katalog: view di `SYS.SYSTABLE (table_type='VIEW')`, proc di `SYS.SYSPROCEDURE`.

## 2. `v_fa_recon_gl` — row count & delta per akun (Output A)

**8 baris** (4 ASSET + 4 ACCUM), semua `account_code` terisi:

| account_code | type | register_amt | gl_amt | delta | post_cutoff_amt | residual_unexpl |
|---|---|---:|---:|---:|---:|---:|
| 158-001 | ACCUM | 1.074.698.389,90 | 1.469.198.392,00 | **−394.500.002,10** | 0 | −394.500.002,10 |
| 158-101 | ACCUM | 845.637.757,39 | 845.637.756,00 | 1,39 | 0 | 1,39 |
| 158-201 | ACCUM | 130.925.056,70 | 130.925.053,00 | 3,70 | 0 | 3,70 |
| 158-301 | ACCUM | 2.731.459.753,34 | 2.638.959.761,00 | **+92.499.992,34** | 0 | +92.499.992,34 |
| 151-100 | ASSET | 3.317.636.932,00 | 3.712.136.932,00 | **−394.500.000,00** | 0 | −394.500.000,00 |
| 153-001 | ASSET | 959.181.516,00 | 950.446.516,00 | +8.735.000,00 | 8.735.000,00 | **0,00** |
| 154-001 | ASSET | 221.324.363,08 | 221.324.363,08 | **0,00** | 0 | 0,00 |
| 155-001 | ASSET | 6.974.040.958,00 | 5.223.064.476,00 | **+1.750.976.482,00** | 0 | +1.750.976.482,00 |

Semua delta cocok [MEMO §4](MEMO_REKONSILIASI_FA_FINAL.md#L47).

## 3. POST_CUTOFF — hanya PKT-0177 & PKT-0178

```
asset_code  asset_name  acquisition_cost
PKT-0177    1           7.950.000,00
PKT-0178    1             785.000,00
(2 rows)
```
Mekanisme `post_cutoff_amt` menetralkan delta 153-001 (+8.735.000) → `residual_unexpl = 0` (timing, bukan selisih riil).

## 4. Distribusi `recon_tag` (Output B, 279 aset)

```
recon_tag           n
ACTIVE              94
FULLY_DEPRECIATED   175
INTERNAL_MISMATCH   3     -> KDR-0002/0003/0004 (Tipe A, memo §5)
POST_CUTOFF         2     -> PKT-0177/0178
ZERO_ACCUM_REVIEW   5     -> 5 aset TA Kendaraan (Tipe B, memo §5)
```

## 5. Temuan kritis saat validasi (root-cause)

Deploy DDL sukses di percobaan pertama, **tetapi data salah total**: semua 279 aset ter-tag `NON_DEPRECIABLE`, `gl_amt=0`, rollup jadi 1 baris `account_code=(null)`.

**Akar:** view membaca akun dari `FA_ASSET.asset_account`/`accum_dep_account` yang **kosong (0/279 terisi)**. Source yang benar = `FA_CATEGORY` (pola sama dengan `sp_fa_build_gl_link` di [fa_09_gl_link.sql](fa_09_gl_link.sql)). Diperbaiki dengan `JOIN FA_CATEGORY`; setelah itu seluruh angka §2 muncul benar.

> Bug ini tidak akan tertangkap code review statis — hanya muncul setelah deploy ke DB nyata + bandingkan ke memo.

## 6. Catatan untuk reviewer (sebelum merge)

- State data = **pra-Paket A**. Residual `< 0` di **151-100 & 158-001** (Bangunan) adalah **expected** sampai [fa_10_koreksi_paket_A.sql](fa_10_koreksi_paket_A.sql) dijalankan (6 aset habis-susut + 11 Tanah belum dimigrasi).
- **155-001 Kendaraan +1.750.976.482** = PAJE pending, keputusan akuntan (memo §7 Paket B) — bukan defect.
- Layer additive & read-only; rollback = `DROP VIEW`×2 + `DROP PROCEDURE` (FA_LAYER_GOVERNANCE.md §8).
