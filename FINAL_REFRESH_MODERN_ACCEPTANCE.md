# FINAL — Refresh Transaksi Modern: Validation & Hardening (test-based)

Read-only prod (vspnew, 103.233.89.43) 2026-07-31. Pembuktian dengan test, bukan sekadar review source.
Evidence SQL: `evidence_refresh_isolation.sql`, `evidence_month_chain.sql`, `evidence_idempotent.sql`, `evidence_module_balance.sql`.

> **Ringkasan jujur:** MEKANISME refresh sudah aman by-design & terbukti (delete GL ter-scope bulan, tak ada hidden-write, oto-minus mati, loop WIP nyambung ke 102-020). TAPI DATA saat ini masih punya **11 putus month-chain (total Rp276,8 jt)** & **selisih SINV-GL Rp11,38 M** yang berakar pada **unit WIP TR belum dibukukan** + distorsi moving-average lama — ini **belum** boleh disebut production-clean sampai (a) engine hardened di-build, (b) re-refresh, (c) reklas WIP 102-001, lalu harness di bawah menghasilkan 0.

---

## 1. PERIOD ISOLATION — DESIGN PASS, runtime harness siap
**Bukti design (source, jalur aktif modern):** SEMUA `delete from gl_journal` di fungsi yang dipanggil modern ter-scope `month(tgl)=..&year(tgl)=..`:
`f_transfer_so/dpkomisi/po_new/nonitempo/ekspedisi_new/ap/adjustment/cons`. NVO hanya menulis `sinv[bulan+1]` (ldt_next) + `al_minus=0` (Jan tak disentuh) + `al_replace` hanya di batas tahun. Fungsi tak-ter-scope (`f_transfer_ar.srf` L583, `f_transfer_freight`, base `po`/`ekspedisi`) **TIDAK dipanggil modern** (dead untuk jalur ini).
**Runtime:** `evidence_refresh_isolation.sql` — snapshot semua bulan≠Juli (GL) & semua sinv≠Agustus, refresh Juli, bandingkan → **harus 0 baris**. (Dijalankan Bapak di copy-DB.)

## 2. MONTH CHAIN — FAIL (data), test-proven
`opening(m+1) = opening(m) + GL_movement(m)`. Prod 2026: **11 putus > Rp1000, total Rp276.847.305**:

| Bulan | Akun | Break | Akar |
|---|---|---:|---|
| Jul | 102-001 (TR) | +94.641.822 | unit WIP fisik keluar belum di-booking WIP-Out |
| May | 102-001 (TR) | +108.164.307 | idem |
| May | 102-003 (NR) | +38.500.000 | WIP/valuasi |
| Jan | 102-102 (MT) | −11.999.999 | qty error TL.203.0504 (moving-avg) |
| Mar/Apr/May/Jun/Jul | 102-110 | −0,2 s/d −20 jt | distorsi moving-average |
| Jul | 102-102 | +1.232.500 | idem |

→ **Engine-fixable** (102-110 movavg, 102-102 qty, phantom oto-minus): sembuh setelah build engine hardened + re-refresh. **Data-fixable** (102-001/003 WIP): perlu **reklas WIP** (task terpisah, tunggu worksheet fisik).

## 3. IDEMPOTENCY — harness siap (runtime)
`evidence_idempotent.sql` — checksum (GL debet/kredit/voucher/rows Juli, sinv Agustus, HPP Juli) sesudah refresh ke-1 vs ke-2 → **delta 0**, voucher/rows sama = tak ada duplicate journal. (Idempotensi engine sudah didesain: R6/R7 OFF, NVO otoritas HPP tunggal, freeze hpp=0.)

## 4. CROSS-MODULE — sebagian PASS, Inventory FAIL (data)
| Modul | Hasil prod 2026-07-31 | Status |
|---|---|---|
| **WIP-Out = 102-020** | outstanding 2.660.202.269 ≈ GL 2.675.153.958 (Δ~15jt) | ✅ TIES |
| **Inventory SINV=GL** | Σ|break| = **11.380.745.463** | ❌ (akar WIP 102-001 unit belum booking) |
| Konsinyasi out=in | detektor G4 (`evidence_module_balance.sql`) | jalankan |
| AR = GL 103-001 | GL saldo 21.675.493.282 | opname via allrecon |
| AP = GL 226-001 | GL saldo −10.582.607.646 | opname via allrecon |

## 5. YEAR-END / OPENING CONTROL — DESIGN PASS
`al_minus=0` → refresh bulan mana pun **tak menambah** saldo Januari (oto-minus mati). `al_replace=1` hanya efektif di cabang batas-tahun (mm='01') → opening tahun cuma diregenerasi saat **Desember/tutup-tahun** di-refresh, bukan oleh refresh bulan berjalan. Regenerate opening = jalur khusus (refresh Desember), bukan efek samping.

## 6. HIDDEN-WRITE AUDIT — PASS (tak ada silent saldo-writer di jalur refresh)
Audit seluruh source (di luar file `_ori/_original/_bckp/_lain` = legacy tak ter-build):
| Penulis saldo | Konteks | Verdict |
|---|---|---|
| NVO `n_cst_closing_stock.sru`: UPDATE tsales2.hpp (C1/C2/C3), UPDATE tstok2 (netto/hrg/hpp), delete+insert sinv[ldt_next] ter-scope, update sinv gudang | **pipeline refresh (terlihat)** | OK |
| `f_transfer_*` delete gl_journal | **pipeline, ter-scope bulan** | OK |
| `f_insert_cons_in` update tstok1 (WIP-In) | pipeline | OK |
| NVO oto-minus (update sinv Jan) L312 | **al_minus=0 → OFF** | OK (mati) |
| Event terjadwal `UPDATE HPP_TSTOK2` | isi COA_ID serial (bukan HPP), idempoten, dorman, **di luar refresh** | OK (lihat RUNBOOK_event_hpp_tstok2.md) |
| `w_closing_stok` (Stock Opname), posting | **EXTERNAL, di luar refresh** (I9 boundary), dijaga detektor G3/tamper | di luar scope |
→ **Tidak ada hidden-write yang mengubah saldo diam-diam selama refresh.**

## 7. AUDIT TRAIL — terpasang
`refresh_ledger` (DDL `RUNBOOK_refresh_ledger.sql`): id, user, periode, tgl_mulai/selesai, modul, ts_start/end, rows, delta_gl_debet/kredit, status, error_message. Modern menulis RUNNING di awal + SUCCESS di akhir (guard antar-sesi + degradasi mulus bila tabel belum ada).

---

## 8. FINAL ACCEPTANCE MATRIX

| Kriteria | Status sekarang | Terpenuhi bila |
|---|---|---|
| Refresh Feb hanya ubah Feb | DESIGN ✅ / runtime ⏳ | `evidence_refresh_isolation.sql` = 0 (copy-DB) |
| Refresh Jul hanya ubah Jul | DESIGN ✅ / runtime ⏳ | idem |
| Bulan lain tak berubah | DESIGN ✅ / runtime ⏳ | idem |
| Opening = closing bln lalu | ❌ 11 break (data) | build engine + re-refresh + reklas WIP → `evidence_month_chain.sql` = 0 |
| Refresh 2× identik | design ✅ / runtime ⏳ | `evidence_idempotent.sql` = 0 |
| Tak ada duplicate journal | design ✅ / runtime ⏳ | idem (voucher/rows delta 0) |
| SINV = Engine = GL | ❌ Rp11,38 M (data) | reklas WIP 102-001 → break 0 |
| WIP IN/OUT balance | ✅ (ties Δ15jt) | pantau |
| Konsinyasi IN/OUT | ⏳ | G4 = 0 |
| AR / AP balance | ⏳ | opname allrecon dlm toleransi |
| GL balance | ✅ (D=K per refresh) | pantau |
| Tak ada hidden-write | ✅ | audit §6 |

## VERDICT
**Engine & UI hardening: SELESAI dan mekanismenya terbukti aman** (isolation by-scope, no hidden-write, oto-minus off, WIP loop nyambung, audit trail). **BELUM production-clean** karena data masih punya break month-chain/inventory Rp11,38 M yang berakar pada **unit WIP TR belum dibukukan** + moving-avg lama.

**Jalur ke "aman kapan saja, bulan apa saja":**
1. Build + deploy engine hardened (9 source + DDL refresh_ledger) — lihat `IMPORT_LIST_refresh_modern.md`.
2. Di copy-DB: `evidence_refresh_isolation.sql` & `evidence_idempotent.sql` → **0** (buktikan isolation + idempotency runtime).
3. Reklas WIP 102-001 (unit fisik keluar → 102-020) — tunggu worksheet fisik Bapak (`TELUSUR_WIP_TR_102001.md`).
4. Re-refresh Jan-Jul → `evidence_month_chain.sql` & `evidence_module_balance.sql` → **0**.
5. Baru go-live. Target tercapai: *"Refresh Modern aman dijalankan kapan saja, bulan apa saja, tanpa merusak saldo bulan lain, seluruh subledger = GL."*
