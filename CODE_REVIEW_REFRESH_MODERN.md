# CODE REVIEW — Refresh Modern (production-grade, pendekatan falsification)

Objek: `w_refresh_transaksi_modern.srw` + NVO `n_cst_closing_stock.sru` + `f_transfer_*` + event DB. Metode: berusaha MEMBUKTIKAN desain salah. 2026-07-31. Bukti = source line + SQL + flow.

> **VERDICT: BELUM boleh production.** Dari 10 invariant, **6 TERBUKTI dapat dilanggar**, 3 parsial, 1 aman. Rincian & perbaikan di bawah. Jangan go-live sebelum blocker B1–B6 ditutup.

## 1. Status invariant (ringkas)
| Inv | Isi | Status | Pelanggaran inti |
|---|---|---|---|
| **01** | SINV=ENGINE=GL semua akun | ❌ **DILANGGAR** | Saldo awal tahun tak pernah diregenerasi (al_replace=0) → phantom opening bertahan |
| **02** | Refresh bln M tak ubah bln lain | ❌ **DILANGGAR** | `f_transfer_ap`/`f_transfer_cons`/`dpkomisi` hapus GL **tanpa filter tgl**; oto-minus ubah saldo Januari |
| **03** | Deterministic (1×=100×) | ⚠️ PARSIAL | Engine deterministik pasca-redesign; TAPI isolation-0 (dirty read) + oto-minus non-deterministik |
| **04** | Tak ada phantom qty/hpp/opening | ❌ **DILANGGAR** | Oto-minus (al_minus=1) menol-kan stok minus & menambah abs ke saldo Januari (phantom) |
| **05** | Semua modul = GL | ⚠️ PARSIAL | Refresh parsial (checkbox per-modul) + non-atomic (banyak COMMIT) → snapshot tak konsisten |
| **06** | WIP immutable | ✅ MOSTLY | Pasca-redesign C1 (freeze hpp=0) aman; risiko sisa = event `UPDATE HPP_TSTOK2` & writer eksternal |
| **07** | Refresh hanya baca histori | ❌ **DILANGGAR** | `f_insert_cons_in` **DELETE+INSERT tstok '88' (WIP-In)** → refresh menciptakan/menghapus transaksi |
| **08** | Opening N+1 = Closing N | ❌ **DILANGGAR** | Batas tahun: al_replace=0 → sinv Jan tak ditulis dari closing Des; + oto-minus ubah Jan |
| **09** | Idempotent | ⚠️ PARSIAL | Engine idempoten; TAPI cross-month delete + oto-minus + concurrency merusak |
| **10** | Tak ada hidden write | ❌ **DILANGGAR** | Scheduled **EVENT `UPDATE HPP_TSTOK2`** mengubah tstok2 diam-diam (feed WIP/HPP) |

---

## 2-5. BUKTI (source + SQL + flow) per pelanggaran

### B1 — INVARIANT-02: cross-month GL delete (BLOCKER)
**Source:**
- `f_transfer_ap.srf` L287: `delete from gl_journal where doc_reff = :arg_order_client using sqlca;` — **TANPA `month/year`**. Menghapus GL AP **semua bulan** untuk doc_reff itu.
- `f_transfer_cons.srf` L221: `delete from gl_journal where voucher = :arg_order_client and modul_id in('AS')` — **TANPA tgl**. Konsinyasi semua bulan.
- `f_transfer_dpkomisi.srf` L196/201/212/302/311, `f_transfer_ar.srf` L583 (voucher_manual), `f_transfer_ap.srf` L583 — **TANPA tgl**.
- `w_refresh_transaksi_modern.srw` L369 (`voucher=:ls_reff`), L559 (`voucher=:ls_gl_link`) — **TANPA tgl**.
- Kontras: SO L430, AR L292, PO L290, HPP L160, EKSPEDISI L289, NONITEM L141 **SUDAH** ber-scope `month(tgl)=.. and year(tgl)=..` (fix `.bak_docreffscope` — diterapkan **tak konsisten**, AP/CONS/DPKOMISI terlewat).

**Flow pelanggaran:** doc_reff/voucher yang GL-nya tersebar >1 bulan (faktur+retur beda bulan; WIP-Out dikoreksi lintas-bulan) → refresh bulan M meng-`delete` GL semua bulan → re-`insert` hanya bulan M → **GL bulan lain HILANG** → selisih bulan lain.
**Bukti kejadian nyata (forensik proyek):** "Opname Piutang Feb +35jt saat refresh Mei; 16 doc_reff faktur+retur lintas-bulan" ; "GL orphan consin voucher lintas-bulan (WIP-In dikoreksi Jun→Jul, GL Juni nyangkut)".
**Confidence: TINGGI.**

### B2 — INVARIANT-02/04/08: oto-minus mengubah saldo Januari (BLOCKER)
**Source:** modern memanggil `lnv_close.of_run(f_bom(ldt1), false, false, 0, **1**, st_2)` → **al_minus=1**. NVO `n_cst_closing_stock.sru` L310-319:
```
if ll_minus >0 then
  update sinv set sinv.qty = sinv.qty + abs(sinv_minus.qty), sinv.nilai = sinv.hpp_avg*(...)
  where sinv.stok_id=sinv_minus.stok_id and sinv_minus.periode=:ldt_tgl1
    and year(sinv.periode)=year(:ldt_tgl1) and month(sinv.periode)=1
```
**Flow:** refresh bulan APA PUN di tahun Y yang menghasilkan stok minus → menol-kan minus (masking) + **menambah abs ke sinv Januari tahun Y**. Jadi refresh **Feb/Mar/…2026 mengubah saldo awal Januari 2026**. Melanggar INV-02 (ubah bulan lain) + INV-04 (saldo Januari bukan dari transaksi Januari = phantom) + INV-08.
**Confidence: TINGGI.**

### B3 — INVARIANT-01/08: saldo awal tahun tak pernah diregenerasi (BLOCKER)
**Source:** modern kirim **al_replace=0**. NVO cabang tahun (`if string(ldt_next,'mm')='01'`) hanya menulis sinv `ldt_next` bila `lb_replace=true` (al_replace=1). Dengan al_replace=0, **refresh Desember TIDAK menulis/regenerasi sinv 01-Jan** (saldo awal tahun).
**Flow:** closing Des (engine=9) tak pernah di-copy ke opening Jan → opening Jan bertahan pada nilai lama (phantom 45 pada kasus 2026). INV-08 (opening≠closing di batas tahun) + INV-01 (sinv opening ≠ engine=GL). **Ini akar phantom Rp15,25 M di forensik.**
**Confidence: TINGGI.**

### B4 — INVARIANT-10: hidden write via scheduled EVENT (BLOCKER)
**Source (DB catalog):** `SYS.SYSEVENT` → event **`UPDATE HPP_TSTOK2`**: `update TSTOK1 A,TSTOK2 B set B.COA_ID=substring(...), B.PRODUK_ID=substring(...) where A.TIPE_TRANS='88' and isnull(B.COA_ID,'')='' ...`. Berjalan **terjadwal, di luar refresh**, mengubah `tstok2` (coa_id/produk_id) yang **feed WIP-In & pencocokan HPP**. Mutasi tak tertelusur oleh operator. Melanggar INV-10.
(Event lain `auto_backup_log` menghapus `user_log` → merusak audit trail; bukan saldo tapi relevan traceability.)
**Confidence: TINGGI** (definisi event terbaca langsung).

### B5 — INVARIANT-07: refresh menciptakan/menghapus transaksi
**Source:** `f_insert_cons_in.srf` L44/57/65 `delete from tstok2/tstok1`, L83/125 `insert into tstok1/tstok2` (WIP-In '88'). Dipanggil di modern SO L1746 & cons_in. Refresh **membuat & menghapus record tstok '88'** (transaksi turunan), bukan sekadar regenerasi saldo. Melanggar INV-07 (strict).
**Catatan:** ini "regenerasi transaksi turunan", masih deterministik bila '88' beku; tapi secara definisi melanggar "refresh tak menciptakan/menghapus transaksi". **Confidence: TINGGI** (fakta), **dampak: SEDANG** (turunan, bukan transaksi sumber).

### B6 — INVARIANT-03/05/09: concurrency, non-atomic, partial refresh
- **Isolation level 0** (`w_login.srw` L95 `EXECUTE IMMEDIATE \"set transaction isolation level 0\"`): dirty read. Refresh membaca data **belum commit** bila user input bersamaan → hasil **non-deterministik / inconsistent snapshot** (INV-03).
- **Non-atomic:** refresh melakukan banyak `commit` terpisah (tiap transfer). Tak ada transaksi tunggal membungkus seluruh refresh. **Gagal/di tengah → sebagian modul terposting, sebagian tidak** → INV-05 rusak, tak ada rollback menyeluruh.
- **Partial refresh:** modul dipilih via checkbox (`cb_so`..`cb_consin`, dispatch L3066-3074). Jalankan CONSOUT tanpa SO → HPP tak di-refresh dulu → konsinyasi pakai HPP basi → INV-05.
**Confidence: TINGGI** (source + katalog).

---

## 6. EDGE CASES yang memicu selisih
1. Faktur + retur **beda bulan**, doc_reff/voucher sama (AP/CONS) → B1.
2. WIP-Out dikoreksi/dipindah bulan (CIM lintas-bulan) → B1.
3. Stok reguler **minus sesaat** di bulan mana pun + al_minus=1 → saldo Januari berubah (B2).
4. Refresh **Desember** (batas tahun) → opening tahun berikut tak diregenerasi (B3).
5. Refresh **hanya sebagian modul** (mis. CONSOUT saja) → HPP basi (B6).
6. Input user **bersamaan** dengan refresh (isolation 0) → snapshot kotor (B6).
7. Refresh **gagal/mati listrik** di tengah → sebagian modul terposting (B6, non-atomic).
8. Event `UPDATE HPP_TSTOK2` berjalan **saat/selepas** refresh → tstok2 berubah, WIP tak sinkron (B4).
9. Serial WIP hpp=0 (zero-opening) → tak ada posting GL → outstanding tanpa jurnal (minor).
10. Voucher_manual dipakai ulang lintas-bulan → B1 (L583).

## 7. RACE CONDITIONS
- R1: user commit faktur baru **selama** loop refresh (isolation 0) → refresh sebagian menghitung dengan/tanpa faktur itu antar-statement → hasil tak reprodusibel.
- R2: dua sesi refresh periode berbeda **bersamaan** → keduanya `delete gl_journal by voucher` (tanpa tgl) bisa menghapus hasil satu sama lain.
- R3: event scheduler `UPDATE HPP_TSTOK2` menembak `tstok2` di tengah refresh cons_in → WIP-In dibangun dari data setengah-berubah.

## 8. FAILURE SCENARIOS
- F1: refresh mati setelah SO commit, sebelum CONSOUT → stok ter-close, GL konsinyasi belum → selisih WIP/konsinyasi sampai refresh ulang penuh.
- F2: `delete gl_journal` sukses, `lds_update.update()` gagal (lock/isolation) → GL terhapus, tak ter-insert → posting HILANG (missing posting) sampai retry.
- F3: refresh Feb memicu oto-minus → saldo Jan berubah → laporan Jan yang sudah "final" berubah diam-diam.

## 9. ROOT CAUSE (bila invariant dilanggar)
- B1: fix scope tgl diterapkan **tak konsisten** (AP/CONS/DPKOMISI/voucher_manual/modern-DP terlewat).
- B2/B3: parameter `al_minus=1` & `al_replace=0` pada pemanggilan NVO — kebijakan tahun/minus warisan, tak sesuai invariant isolasi/idempoten.
- B4: mekanisme perbaikan data lewat **event terjadwal**, bukan bagian pipeline yang tertelusur.
- B5: WIP-In sebagai transaksi turunan dibangun on-the-fly saat refresh.
- B6: model konkuren isolation-0 + refresh non-atomik + modul opsional.

## 10. PERBAIKAN PERMANEN (fix, urut prioritas)
- **P1 (B1):** samakan SEMUA delete GL ke pola ber-scope periode. Ganti `delete from gl_journal where doc_reff=:x` → tambah `and tgl between :ldt1 and :ldt2` (atau `month/year` seperti SO/AR). Berlaku: f_transfer_ap L287+L583, f_transfer_cons L221, f_transfer_dpkomisi(5 titik), f_transfer_ar L583, modern L369/L559, f_transfer_so L432(else). **Prinsip: refresh periode M hanya boleh delete GL ber-tgl di M.**
- **P2 (B3):** regenerasi saldo awal tahun secara terkontrol: sediakan mode "tutup-tahun" yang memanggil NVO dengan al_replace=1 untuk menimpa sinv 01-Jan = closing Des (engine). Refresh rutin tetap al_replace=0 (tak sentuh saldo awal), TETAPI opening awal harus di-seed sekali dari engine (bukan angka lama).
- **P3 (B2):** nonaktifkan/oto-minus dari refresh rutin (al_minus=0) ATAU pindahkan penanganan stok-minus ke proses terkontrol yang TIDAK menulis ke saldo Januari saat refresh bulan lain. Stok minus riil harus jadi TEMUAN (detektor), bukan ditambal ke opening.
- **P4 (B4):** pensiunkan event `UPDATE HPP_TSTOK2`; jadikan langkah eksplisit di pipeline cons_in (tertelusur), atau perbaiki di sumber input.
- **P5 (B6):** (a) refresh dijalankan saat **tak ada user input** (window maintenance) atau naikkan isolation ke snapshot; (b) bungkus 1 periode dalam **satu transaksi** (all-or-nothing) atau checkpoint + verifikasi; (c) **paksa urutan modul penuh** (SO→…→CONSIN) — larang partial-refresh untuk periode produksi, atau auto-ikutkan SO bila CONSOUT/CONSIN dipilih.
- **P6 (B5):** terima WIP-In sebagai turunan deterministik (sudah aman pasca-freeze), tapi dokumentasikan & pastikan idempoten (delete+insert nilai identik) — tambahkan detektor drift WIP-In.

## 11. REGRESSION TEST (wajib)
- RT-01 (INV-02): snapshot GL bln M−1 & M+1 → refresh bln M → **diff=0** utk bln lain. Ulang per modul (AP, CONS, DPKOMISI, DP-AR/AP).
- RT-02 (INV-08): closing bln N (semua akun) == opening bln N+1, **termasuk batas tahun Des→Jan**.
- RT-03 (INV-01): pasca-refresh, `Σ sinv = Σ GL` per akun persediaan (≤ toleransi pembulatan).
- RT-04 (INV-02/oto-minus): buat stok minus di Mar → refresh Mar → **sinv Jan tak berubah**.
- RT-05 (INV-10): jalankan refresh; pastikan `tstok2` tak berubah oleh event di window uji (event dimatikan saat uji, lalu dibuktikan tak diperlukan).

## 12. PROPERTY TEST
- PT-01 idempoten: refresh Jan→Des **N kali** → hash(`sinv`,`gl_journal`,`tstok2` WIP) identik antar-run.
- PT-02 isolasi: untuk periode acak M, `∀ P≠M: state(P) invariant` setelah refresh M.
- PT-03 konservasi: `Σ debet = Σ kredit` per voucher & per periode; `Σ mutasi GL = Σ mutasi sinv` (nilai) per akun.
- PT-04 immutability WIP: `hash(tsales2.hpp WHERE tipe='88')` tak berubah lintas refresh.

## 13. MUTATION TEST (sengaja rusakkan, harus tertangkap)
- MT-01: hapus filter `and month(tgl)=` di satu transfer → RT-01 harus GAGAL (membuktikan RT-01 sensitif).
- MT-02: set al_replace=1 pada refresh rutin → RT-02 batas tahun berubah → tertangkap.
- MT-03: set al_minus=1 + stok minus → RT-04 harus GAGAL.
- MT-04: aktifkan event UPDATE HPP_TSTOK2 saat refresh → RT-05 GAGAL.

## 14. ACCEPTANCE TEST (go/no-go)
- AT-01: refresh **Jan→Des 2× berturut** → diff DB = 0 (idempoten global).
- AT-02: refresh tiap bulan sendiri-sendiri → tak ada bulan lain berubah (isolasi).
- AT-03: `SINV=ENGINE=GL` semua akun, semua bulan (≤ pembulatan).
- AT-04: Stock/AR/AP/ConsIn/ConsOut/WIPIn/WIPOut/HPP vs GL = 0 selisih.
- AT-05: opening==closing tiap batas bulan & batas tahun.

## 15. PRODUCTION CHECKLIST
- [ ] P1 (scope tgl semua delete GL) terpasang + RT-01/MT-01 lulus.
- [ ] P2 (seed/tutup-tahun opening via engine) + RT-02 batas tahun lulus.
- [ ] P3 (al_minus dari refresh rutin dimatikan; detektor stok-minus) + RT-04 lulus.
- [ ] P4 (event UPDATE HPP_TSTOK2 dipensiun/dipindah) + RT-05 lulus.
- [ ] P5 (refresh atomik per-periode / window maintenance / larang partial) diverifikasi.
- [ ] AT-01..05 lulus di lingkungan non-prod (copy DB).
- [ ] Seed opening 2026 = engine (regenerasi 1×) — menutup phantom 15,25 M.
- [ ] DETEKTOR pasca-refresh (G1–G8) = 0 anomaly.
- [ ] Backup DB sebelum go-live; rollback teruji.

## 16. SEMUA KONDISI YANG MASIH DAPAT MENIMBULKAN SELISIH (saat ini)
1. Refresh AP/CONS/DPKOMISI atas voucher/doc_reff lintas-bulan → GL bulan lain terhapus. **(B1, aktif)**
2. Refresh bulan mana pun saat ada stok minus (al_minus=1) → saldo Januari berubah. **(B2, aktif)**
3. Saldo awal tahun tak pernah diregenerasi → phantom opening bertahan (kasus 2026 = 15,25 M). **(B3, aktif)**
4. Event `UPDATE HPP_TSTOK2` mengubah tstok2 di luar refresh → WIP/HPP tak sinkron. **(B4, aktif)**
5. Refresh parsial (modul tak lengkap) → HPP/konsinyasi basi. **(B6, aktif)**
6. Input user bersamaan refresh (isolation 0) → snapshot kotor. **(B6, aktif)**
7. Refresh gagal di tengah (non-atomic) → posting sebagian. **(B6, aktif)**
8. Dua refresh bersamaan → saling menghapus GL. **(R2, aktif)**

**Selama 8 kondisi di atas masih mungkin, sistem BELUM memenuhi target "tidak ada selisih setelah Refresh Modern".** Tutup B1–B4 + B6 (P1–P5) lalu jalankan AT-01..05 sebelum go-live.
