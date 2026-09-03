# PRODUCTION HARDENING — Refresh Modern

Tanpa perubahan data prod. Hanya patch source (Bapak build/deploy). 2026-07-31.
Semua source di-backup `.bak_hardening`.

## 1. ROOT CAUSE (mengapa belum production-safe)
| ID | Invariant | Root cause | Status |
|---|---|---|---|
| B1 | INV-01/05 month isolation | `delete from gl_journal` **tanpa filter tgl** di fungsi transfer aktif → hapus GL bulan lain | ✅ **DIPATCH** (7 site) |
| P1 | INV-01 period isolation | Refresh parsial/lintas-bulan/lintas-tahun dari input tanggal bebas | ✅ **DIPATCH** (normalisasi 1 bulan penuh f_bom/f_eom, L3033-3043) |
| B2 | INV-02/04 | Modern panggil NVO `al_minus=1` → oto-minus tambah `abs(sinv_minus)` ke **saldo Januari** (NVO L310-319) | ✅ **DIPATCH** (al_minus=0, L1648+L2075) |
| B3 | INV-02/08 | Modern panggil NVO `al_replace=0` → saldo awal tahun **tak pernah diregenerasi** dari closing engine | ✅ **DIPATCH** (al_replace=1, L1648+L2075; efektif hanya di batas tahun mm='01') |
| B4 | INV-10 | Scheduled EVENT `UPDATE HPP_TSTOK2` — TERNYATA isi COA_ID/PRODUK_ID (serial), bukan HPP; idempoten & dorman | ✅ **DIPUTUSKAN** (keep enabled + monitor `B4_BLANK_COA`) |
| B5 | INV-07 | `f_insert_cons_in` delete+insert tstok '88' (WIP-In turunan) | terima (deterministik pasca-freeze) |
| B6 | INV-03/05/09 | Isolation level 0 (dirty read) + refresh non-atomic (banyak commit) + partial-refresh (checkbox) | ✅ **DIPATCH** (guard antar-sesi + audit ledger); sisa isolation/partial = rekomendasi operasional |

## 2. PATCH YANG SUDAH DITERAPKAN (B1 — 7 site, jalur aktif)
Pola seragam: tambah ` and month(tgl)=month(:ldt_tgl) and year(tgl)=year(:ldt_tgl)` sebelum `using sqlca`. (`ldt_tgl` = tgl transaksi yang di-refresh; `month(:hostvar)` diuji diterima ASA9.)
| File | Baris | Delete (sesudah) |
|---|---|---|
| `f_transfer_cons.srf` | 221 | `... modul_id in('AS') and month(tgl)=month(:ldt_tgl) and year(tgl)=year(:ldt_tgl)` |
| `f_transfer_ap.srf` (f_transfer_ar) | 287 | `where doc_reff=:arg_order_client and month(tgl)=... and year(tgl)=...` |
| `f_transfer_ap.srf` (f_transfer_ap) | 583 | `where voucher_manual=:ls_vouchermanual and month(tgl)=... and year(tgl)=...` |
| `f_transfer_po_new.srf` | 211 | `... modul_id=:ls_coding and month(tgl)=... and year(tgl)=...` |
| `f_transfer_ekspedisi_new.srf` | 237 | idem |
| `f_transfer_dpkomisi.srf` | 197,202,214,303,313 | 5 delete (voucher/voucher_refresh/KS-doc_reff/voucher/TC-doc_reff) di-scope |
| `w_refresh_transaksi_modern.srw` | 370,560 | DP penjualan (f_re_dp) & DP beli (f_re_dp_beli) di-scope |

**Efek:** refresh bulan M kini hanya menghapus GL ber-`tgl` di bulan M untuk voucher/doc_reff itu → GL bulan lain **tak tersentuh**. Menutup risiko "24.794 doc_reff multi-modul" & "604 GL key lintas-bulan" di prod.

### Sisa B1 (cabang else fallback) — ✅ DITUTUP 2026-07-31
Analisis: `ldt_tgl` = `lds_po.object.tgl[i]` di dalam loop → null **hanya bila datastore kosong (tak ada yang di-refresh)**. Jadi else-branch dulu menghapus GL lintas-bulan padahal tak ada yang di-insert ulang = murni merusak.
- `f_transfer_so.srf` L432 & `f_transfer_adjustment.srf` L197 — delete tak ber-scope **diganti no-op guard** (komentar, tidak menghapus). Backup `.bak_b1else`, integritas ok (loneLF=0).
**Hasil:** tak ada lagi jalur delete GL tanpa scope periode di seluruh fungsi transfer.

## 2b. PATCH P1/P2 (period isolation + saldo continuity — SUDAH DITERAPKAN)
### P1 — normalisasi 1 bulan penuh (INV-01)
`w_refresh_transaksi_modern.srw` event "MULAI REFRESH" L3033-3043: bila `cb_all_period` tak dicentang, paksa `ld1=f_bom`, `ld2=f_eom` dari **bulan awal** (leap-safe) + `of_write_log` bila input parsial/lintas-bulan diabaikan. Refresh mustahil lintas-bulan/lintas-tahun.
### P2 — al_minus=0 (matikan oto-minus) & al_replace=1 (year-close via engine)
`w_refresh_transaksi_modern.srw`: L1648 `of_run(f_bom(ldt1), false, false, **1, 0**, st_2)` (of_refresh_so) & L2075 `of_run(f_bom(ldt1), false, true, **1, 0**, st_2)` (sync cons_in).
- **al_minus 1→0:** refresh bulan lain **tak lagi mengubah saldo Januari**. Stok minus jadi **temuan detektor** (`INVARIANT_CHECKER.sql` → STOCK_MINUS_DETECTED), bukan ditambal diam-diam.
- **al_replace 0→1:** efektif hanya saat NVO memasuki cabang batas tahun (mm='01') → sinv 01-Jan diregenerasi = closing Des engine (INV-08). Inert untuk refresh bulan biasa. Menutup phantom opening (kasus 15,25 M) begitu Desember/tutup-tahun di-refresh.
- Risiko: stok minus riil tetap tampak minus sampai diperbaiki di sumber (itu justru benar per INV-04).

## 3. B4 & B6 — DIPUTUSKAN/DITERAPKAN 2026-07-31

### B4 — event `UPDATE HPP_TSTOK2` : ✅ INVESTIGASI SELESAI → **JANGAN dimatikan** (lihat `RUNBOOK_event_hpp_tstok2.md`)
Bukti prod membalik asumsi awal (nama menyesatkan): event **tidak menyentuh HPP**. Isinya mengisi `COA_ID`/`PRODUK_ID` (serial linkage WIP-In) dari `DESCRIPTION` **hanya bila kosong** — monoton/idempoten, tak pernah menimpa. Jadwal 1 jam, tapi **target saat ini = 0** (dorman). Bukan pelanggaran I9 (menulis tstok2.coa_id, bukan tsales2.hpp).
- **Keputusan:** biarkan enabled (jaring self-healing untuk defect lama). **Monitor** via `INVARIANT_CHECKER.sql` blok `B4_BLANK_COA` (harus 0). Bila >0 → perbaiki sumber pembuat WIP-In tanpa serial, **bukan** matikan event.
- Opsi disable-during-refresh tersedia tapi **tidak direkomendasikan** (idempoten & dorman). Detail + rollback di runbook.

### B6 — concurrency & atomicity : ✅ **DIPATCH** (guard antar-sesi + audit ledger)
`w_refresh_transaksi_modern.srw` event MULAI REFRESH (backup `.bak_b6`):
- **Guard antar-sesi (lock DB):** sebelum mulai, `select count(*) from refresh_ledger where status='RUNNING' and datediff(hour,ts_start,current timestamp)<6`. Bila ada → tolak (messagebox StopSign + log) dan `return`. Melengkapi `ib_running` (yang hanya cegah re-entry 1 window). Stale-timeout 6 jam → refresh crash otomatis lepas lock.
- **Audit ledger:** INSERT baris `RUNNING` di awal (user, periode, tgl, ts_start), UPDATE `SUCCESS` + delta GL di akhir. Pakai `@@identity` (SYS.DUMMY) untuk id.
- **Degradasi mulus:** bila tabel `refresh_ledger` belum ada, `sqlca.sqlcode<>0` → guard tak memblokir & insert dilewati (window jalan normal).
- **Sisa (operasional, rekomendasi):** isolation-level 0 (dirty read) — jalankan refresh saat idle; larang partial-refresh untuk periode produksi (bila CONSOUT/CONSIN dipilih paksa SO). Bukan blocker: P1 sudah menjamin isolasi periode; guard sudah menjamin non-concurrent.

### UI periode (P1) — ✅ dropdown Bulan+Tahun DIIMPLEMENTASI di source (backup `.bak_ddlb`)
Ditambahkan 2 DropDownListBox `ddlb_bulan` (Januari..Desember) + `ddlb_tahun` (2024..2030) ke `w_refresh_transaksi_modern.srw`: forward-decl, instance var, create/destroy, Control[] +59/+60, full type block, populate+default **sysdate** di event open, dan `selectionchanged` yang mengisi `dt_from`/`dt_to` = f_bom/f_eom bulan terpilih. Plus default sysdate lama (L2265-2266) + normalisasi P1 tetap sebagai jaring pengaman. Integritas OK (BOM/CR=LF/lone0).

## 4. REFRESH LEDGER (audit tiap refresh) — DDL
```sql
CREATE TABLE refresh_ledger (
  refresh_id     integer default autoincrement primary key,
  user_id        varchar(30),
  modul          varchar(20),
  periode_awal   date,
  periode_akhir  date,
  ts_start       timestamp,
  ts_end         timestamp,
  rows_deleted   integer,
  rows_inserted  integer,
  delta_gl_debet numeric(20,2),
  delta_gl_kredit numeric(20,2),
  delta_stok_nilai numeric(20,2),
  status         varchar(10),   -- OK / FAIL / ROLLBACK
  error_message  varchar(400)
);
```
Isi di awal & akhir tiap `of_refresh_*` (start → row count sebelum; end → sesudah, status). Dari `f_log` yang sudah ada (USER_LOG_BACKUP) tambahkan angka delta.

## 5. TRANSACTION BOUNDARY + GUARD (desain)
### Guard cross-period (INV-01, defensif)
Fungsi reusable `f_guard_period(as_table, as_where, adt_from, adt_to)`: sebelum delete, cek row target di luar periode:
```
select count(*) into :ll_luar from <as_table> where <as_where> and (tgl < :adt_from or tgl > :adt_to);
if ll_luar > 0 then
   // ROLLBACK + error
   f_log('9999','GL','CROSS PERIOD BLOCK', as_table+' where '+as_where+' : '+string(ll_luar)+' row luar periode', '')
   messagebox('STOP','Cross period modification detected: '+string(ll_luar)+' baris di luar '+string(adt_from)+'..'+string(adt_to)+'. Refresh dibatalkan.')
   return -1
end if
```
Panggil sebelum tiap delete (defense-in-depth di atas scope §2).

### Transaction boundary per periode
```
// di of_run_modul, bungkus 1 periode:
// (isolation snapshot bila mungkin; jika tidak, checkpoint + validate)
BEGIN
  for each modul in [SO,PO,NONITEM,EXP,AR,AP,ADJ,CONSOUT,CONSIN]:
     delete scoped (periode)          // §2
     regenerate scoped (periode)
  validate invariants (INV-01..05)    // §6
  if all pass: COMMIT ; log ledger OK
  else: ROLLBACK ; log ledger ROLLBACK
```
(Catatan ASA9: refresh saat ini per-transfer commit. Untuk atomicity penuh perlu refaktor agar 1 periode = 1 unit. Minimal: **validasi pasca-refresh + rollback manual** bila gagal.)

## 6. VALIDASI INVARIANT (dijalankan setelah refresh, harus semua PASS)
```sql
-- INV-01 SINV=GL per akun persediaan
select gr.persediaan, cast(sum(sv.nilai) as numeric(20,2)) sinv,
  (select cast(sum(debet)-sum(kredit) as numeric(20,2)) from gl_journal g where g.account_id=gr.persediaan and g.tgl<=:eom) gl
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where sv.periode=:periode_next group by gr.persediaan
having abs(sum(sv.nilai) - (select sum(debet)-sum(kredit) from gl_journal g where g.account_id=gr.persediaan and g.tgl<=:eom)) > 1;
-- INV-03 WIP: outstanding WIP-Out = saldo 102-020 (toleransi)
-- INV-04 CONS: consout evap = consin evap (DETEKTOR G4)
-- opening==closing: sinv[periode] = sinv[periode-1] + mutasi (per akun, toleransi)
```
Hasil kosong = lulus. (Gunakan DETEKTOR_residu_hpp_bulanan.sql G1–G5 sebagai pelengkap.)

## 7. REGRESSION TEST (wajib, di copy-DB)
- **RT-01 (isolasi):** snapshot GL semua bulan ≠ M → refresh M (per modul: AP, CONS, DPKOMISI, DP-AR/AP, PO, EXP) → diff bulan lain = **0**.
- **RT-02 (idempoten):** refresh M **2×** → hash(gl_journal,sinv,tstok WIP) identik.
- **RT-03 (SINV=GL):** refresh Jan→Des → `Σ sinv = Σ GL` semua akun (≤ Rp1).
- **RT-04 (collision):** buat 2 transaksi beda bulan doc_reff sama → refresh 1 bulan → GL bulan lain **tetap**.
- **RT-05 (opening=closing):** closing N == opening N+1 semua akun, termasuk batas tahun.
- **RT-06 (guard):** paksa target lintas-periode → guard RAISE ERROR (tak ada delete).

## 8. RUNBOOK DEPLOYMENT
1. **Backup** library PB + DB prod (titik pulih).
2. Jalankan DDL `refresh_ledger` (§4) di prod (objek baru, aman).
3. **Import** 7 file source ter-patch: f_transfer_cons, f_transfer_ap, f_transfer_po_new, f_transfer_ekspedisi_new, f_transfer_dpkomisi, w_refresh_transaksi_modern (+ f_transfer_so/adjustment bila else-branch difix).
4. P1/P2 sudah di source (normalisasi bulan penuh, al_minus=0, al_replace=1). (Keputusan tambahan) B4 (disable event) bila disetujui.
5. **Full Build** PB.
6. **RT-01..06 di copy-DB** (bukan prod) → semua lulus.
7. **Seed opening 2026** via engine (year-close) — menutup phantom 15,25 M.
8. Refresh Jan→Des prod → jalankan §6 validasi + DETEKTOR G1–G5 = 0.
9. Go-live. Pantau refresh_ledger + validasi tiap refresh.

## 9. ROLLBACK PLAN
- **Source:** restore `*.bak_hardening` → build library lama. (7 file.)
- **DDL:** `DROP TABLE refresh_ledger;` (objek baru, tak ada data operasional).
- **Data:** bila refresh sudah dijalankan pasca-patch & perlu revert → restore DB dari backup runbook step 1.
- **P2/B4:** parameter/event — kembalikan `of_run(...,0,1,...)` (al_replace=0, al_minus=1) & `ALTER EVENT ... ENABLE`. **P1:** hapus blok normalisasi L3033-3043.
- Semua reversibel; simpan backup sampai observasi selesai.

## 10. ACCEPTANCE (go/no-go)
> "Setelah refresh modern berjalan: tidak ada selisih Konsinyasi IN/OUT, WIP IN/OUT, AR, AP, Stok vs GL, Opening vs Closing; dan refresh 1 bulan tak pernah mengubah bulan lain."
- Terpenuhi bila: **RT-01..06 lulus** + **§6 validasi = 0** + B1 patch terpasang + P1/P2 terpasang (opening/minus).
- **Belum boleh go-live** bila salah satu RT gagal atau `INVARIANT_CHECKER.sql`/`ACCEPTANCE_hardening.sql` belum semua lulus di copy-DB.

## STATUS (2026-07-31 — hardening SELESAI di source; siap build/test copy-DB)
✅ **B1 (cross-month delete) DIPATCH** — 7 site + 2 else-branch (so/adj) ditutup → **tak ada delete GL tanpa scope periode**.
✅ **P1 (normalisasi 1 bulan penuh + dropdown Bulan/Tahun) DIPATCH** — refresh tak bisa parsial/lintas-bulan; dropdown default sysdate, ganti bulan → tanggal ikut (`.bak_ddlb`).
✅ **P2 (al_minus=0, al_replace=1) DIPATCH** — Jan tak berubah oleh refresh bulan lain; opening tahun = closing engine.
✅ **B6 (concurrency) DIPATCH** — guard lock antar-sesi (stale-timeout 6 jam) + audit ledger RUNNING/SUCCESS, degradasi mulus.
✅ **B4 (event HPP_TSTOK2) DIPUTUSKAN** — evidence prod: idempoten/dorman/serial-only → keep enabled + monitor (bukan matikan).
✅ **P3 artefak** — `RUNBOOK_refresh_ledger.sql`, `INVARIANT_CHECKER.sql` (INV-01/STOCK_MINUS/B4/INV-03, SQL divalidasi prod), `ACCEPTANCE_hardening.sql` (Test1-4), `RUNBOOK_event_hpp_tstok2.md`, `UI_SPEC_month_year_dropdown.md`.
⏳ **Rekomendasi operasional tersisa (bukan blocker):** isolation-level 0 saat idle; larang partial-refresh periode produksi.
⏳ **Langkah Bapak (agent tak sentuh data prod):** backup lib+DB → jalankan `RUNBOOK_refresh_ledger.sql` → import 8 source → Full Build → uji `ACCEPTANCE_hardening.sql`+`INVARIANT_CHECKER.sql` di copy-DB → seed-opening 2026 (year-close) → go-live + pantau `refresh_ledger`.

### Daftar file source ter-patch (backup di samping):
`f_transfer_cons.srf`, `f_transfer_ap.srf`, `f_transfer_po_new.srf`, `f_transfer_ekspedisi_new.srf`, `f_transfer_dpkomisi.srf` (`.bak_hardening`); `f_transfer_so.srf`, `f_transfer_adjustment.srf` (`.bak_b1else`); `w_refresh_transaksi_modern.srw` (`.bak_hardening` P1/P2 + `.bak_b6` guard/ledger).
