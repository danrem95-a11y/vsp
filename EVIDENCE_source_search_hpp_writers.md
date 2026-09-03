# EVIDENCE — Pencarian source: SEMUA penulis `tsales2.hpp` (bukan kesimpulan)

Metode: scan seluruh `C:\BTV\debug\*.srw *.sru *.srf` untuk `UPDATE tsales2` (regex, case-insensitive), lalu telusuri call-graph `w_refresh_transaksi_modern`. Tanggal 2026-07-31. Reproducible (lihat perintah di bawah).

## A. Call-graph refresh modern (apa yang benar-benar dieksekusi saat Refresh)
`w_refresh_transaksi_modern` saat refresh hanya:
- `open(w_wait)` — window tunggu (tak tulis hpp).
- `create n_cst_closing_stock` (L1643, L2071) — NVO closing.
- `f_transfer_so` (L1746/1765), `f_transfer_cons` (L1894/2025) — **TIDAK ada** di daftar penulis `tsales2.hpp` (lihat §B) → hanya posting GL.
- `f_insert_cons_in` (L1749/1947/2000) — overload **1-arg**.

**TIDAK** membuka `w_closing_stok` / `w_posting_hpp` / `w_posting_stok` / `w_refresh_hppstok*` / `w_trace_stok` / `w_closing_harian`. Jadi window-window itu **tak berada di jalur eksekusi refresh**.

## B. Tabel klasifikasi SEMUA hit `UPDATE tsales2` (hasil scan mentah)

| File | Baris | SET | Di jalur refresh modern? | Status penulis `tsales2.hpp` |
|---|---|---|---|---|
| **n_cst_closing_stock.sru** | **98** | `ISNULL(NULLIF(HPP.HRG,0), … MAX '88' WIP-In …)` | **YA (NVO S-B / C1)** | **ACTIVE** — satu-satunya penulis `'88'` WIP-Out (guard `NOT EXISTS ledger`) |
| **n_cst_closing_stock.sru** | **371** | `ABS(ROUND(HPP.HRG,2))` + `WHERE evap=''` | **YA (NVO S-D / C2)** | **ACTIVE** — satu-satunya penulis NON-WIP (average) |
| **n_cst_closing_stock.sru** | **399** | `ABS(ROUND(HPP.HPP,2))` + `WHERE tipe<>'88'` | **YA (NVO S-E / C3)** | **ACTIVE** — satu-satunya penulis WIP-sale (=MAX '88') |
| w_refresh_transaksi_modern.srw | 1658 | `MAX '88' … else moving-avg` (R6) | dibungkus flag | **INACTIVE** — `if not ib_nvo_sole_hpp_authority` = OFF |
| w_refresh_transaksi_modern.srw | 1994 | `MAX '88'` (R7 drift) | dibungkus flag | **INACTIVE** — flag OFF |
| f_insert_cons_in.srf | 366 | `set hpp = :ldec_hpp_cons` (overload **1-arg**) | dipanggil modern | **INERT** — `ls_stok=''` (tak di-assign) → `WHERE stok_id=''` cocok **0 baris** |
| f_insert_cons_in.srf | 183 | `set hpp = :ldec_hpp_cons` (overload **4-arg**) | **tidak dipanggil** modern | **DORMANT** — modern hanya panggil overload 1-arg |
| w_closing_stok.srw | 841, 867 | Stock Opname (BY evap) | TIDAK (menu `b_stokopname`) | **OTHER MENU** — aksi user terpisah; dijaga G6; JANGAN dijalankan atas unit WIP |
| w_posting_hpp.srw | 140 | posting HPP | TIDAK (menu) | **OTHER MENU** |
| w_posting_stok.srw | 267 | posting stok | TIDAK (menu) | **OTHER MENU** |
| w_refresh_hppstok_current.srw | 373 | re-calc HPP | TIDAK (menu) | **OTHER MENU** |
| w_refresh_hppstok.srw | 494 | re-calc HPP (lama) | TIDAK (menu) | **OTHER MENU** |
| w_closing_harian.srw | 386 | closing harian | TIDAK (menu) | **OTHER MENU** |
| w_trace_stok.srw | 457 | trace | TIDAK (tool) | **OTHER MENU** |
| **w_refresh_journal.srw** | **2088 (R6), 2529 (R7)** | R6-setara + drift | refresh LAMA (panggil NVO sama) | **INACTIVE (FASE 1B)** — dibungkus flag `ib_nvo_sole_hpp_authority` OFF; HPP journal kini via NVO (I8) |
| w_refresh_journal - Copy.srw / - Copy (2).srw / _ori / _update | 1998–2021 | — | — | **DEAD COPY** (bukan objek aktif) |
| n_cst_closing_stock_upd.sru | 98,354,381 | — | — | **DEAD COPY** dari NVO |
| f_insert_cons_in_ori.srf / _original.srf | 183,366 | — | — | **DEAD COPY** |
| w_closing_stok_20210603.srw | 817,869 | — | — | **DEAD COPY** bertanggal |

## C. Kesimpulan bukti (untuk klaim "NVO satu-satunya penentu HPP saat refresh")
**Saat menjalankan Refresh via `w_refresh_transaksi_modern`**, penulis `tsales2.hpp` yang benar-benar aktif = **hanya 3 UPDATE di NVO** (L98/L371/L399 = C1/C2/C3), masing-masing untuk kelas berbeda (‘88’ / NON-WIP / WIP-sale) → tak saling menimpa. R6/R7 OFF (flag). `f_insert_cons_in` inert (1-arg). `f_transfer_*` tak menulis hpp. **Klaim terbukti untuk jalur refresh.**

## D. Cakupan I8 (Single HPP Authority se-sistem)
1. **`w_refresh_journal.srw` (refresh LAMA) — DISELESAIKAN di FASE 1B.** Kedua penulis bersaing (L2088 R6-setara, L2529 R7-drift) kini dibungkus flag `ib_nvo_sole_hpp_authority` (default OFF). Journal memanggil **NVO yang sama** (L2079), jadi C1–C4 berlaku dan HPP journal = HPP NVO. Dengan modern **dan** journal sama-sama OFF, **NVO adalah satu-satunya otoritas penulis HPP se-sistem (I8)**. Verifikasi: acceptance `ACCEPTANCE_journal_authority.sql` + G6/G8. Di **FASE 2**, R6/R7 journal + flag dihapus permanen.
2. **OTHER MENU** (Stock Opname `w_closing_stok`, Posting HPP, dll.) dapat menulis `tsales2.hpp` bila **user menjalankannya terpisah** (di luar refresh). Ini **bukan bagian engine refresh** (tak masuk cakupan I8 yang dibatasi "engine refresh"), tetapi bisa merusak nilai beku bila dijalankan atas unit WIP. **Jaring pengaman:** DETEKTOR **G6** (anti-tamper) langsung menangkapnya. Kebijakan operasional: jangan jalankan Stock Opname/Posting atas unit WIP setelah cutover. (Bila diinginkan, penonaktifan menu-menu ini dapat masuk pekerjaan lanjutan terpisah.)

## Perintah reproduksi
```
Get-ChildItem C:\BTV\debug\*.srw,*.sru,*.srf | % {
  $L=[Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($_.FullName)) -split "`r`n"
  for($i=0;$i -lt $L.Count;$i++){ if($L[$i] -match '(?i)update\s+tsales2'){ "$($_.Name):L$($i+1): $($L[$i].Trim())" } } }
```
