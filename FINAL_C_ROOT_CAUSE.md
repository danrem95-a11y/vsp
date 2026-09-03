# BAGIAN C — Audit Gap Rp10,11 M (TR.038A / TR.039A). Evidence-based, prod:2638.
Tanpa konfirmasi fisik. Semua dari database.

## 1. Detail transaksi '02' vs '05' (contoh; lengkap di `audit_c_detail.sql`)
Pola SISTEMATIS: tiap pembelian punya SEPASANG '02'+'05', qty/tanggal/model/user identik.
| tipe | bukti_id | tgl | model | qty | hrg/unit | netto (tstok2) | vendor | ref | user |
|---|---|---|---|---:|---:|---:|---|---|---|
| **02** BTB | 10125120200032 | 09-12-2025 | TR.038A | 12 | 14.593 | 175.116 | 4SL.0301 | 5001779 | super |
| **05** | 10125120500001 | 09-12-2025 | TR.038A | 12 | 243.279.903 | 2.919.358.836 | 4SL.H018 | INJK25… | super |

## 2. Jurnal GL kedua transaksi (KUNCI)
| Transaksi | GL modul | GL | Arti |
|---|---|---|---|
| **'02' BTB** (order_client 101BTB…) | **PO** | **Dr 102-001 4,15 M / Cr 226-001 (AP)** | penerimaan + **jurnal beli penuh** |
| **'05'** (INJK…) | **EX** (Ekspedisi) | Dr 102-001 60 jt (freight) / Cr 226-006 | dokumen **freight/ekspedisi** |

→ **Biaya beli hanya SEKALI di GL (via '02' BTB, modul PO).** GL BENAR.

## 3. Bukti double-count QTY di engine stok
`dw_refresh_stok.srd` menghitung QTY masuk dari **'02' DAN '05'**:
```
CASE WHEN TSTOK1.TIPE_TRANS = '02' THEN TSTOK2.QTY ELSE 0 END      -- BTB
CASE WHEN TSTOK1.TIPE_TRANS = '05' THEN TSTOK2.QTY ELSE 0 END      -- Ekspedisi
```
Skala 2025 (TR 102-001, 24 model): **qty '02' = 1.280  |  qty '05' = 1.280** (identik).
→ Stok menghitung unit **2×**, GL menghitung biaya **1×**.

## 4. Audit table
| Item | Transaksi | Qty 2025 | Netto tstok2 | GL | Status |
|---|---|---:|---:|---|---|
| TR.038A | '02' BTB | 82 | 1,2 jt (token) | **Dr 102-001 penuh (PO)** | **VALID** (penerimaan fisik + jurnal beli) |
| TR.038A | '05' | 82 | 19,8 M (cost) | Dr 102-001 60 jt (EX freight) | **QTY DUPLIKAT** (unit sama, ditambah 2× ke stok) |
| TR.039A | '02' BTB | 38 | ~0,5 jt | Dr 102-001 penuh (PO) | VALID |
| TR.039A | '05' | 38 | ~11 M | Dr freight (EX) | QTY DUPLIKAT |

## 5. ROOT CAUSE
> **Gap Rp10,11 M = QTY impor dihitung dua kali oleh engine stok.** Alur impor memakai 2 dokumen ('02' BTB = penerimaan+beli; '05' = ekspedisi/freight). Engine `dw_refresh_stok` menambahkan QTY dari KEDUANYA → unit phantom menumpuk di model bernilai tinggi & lambat laku (reefer TR.038A/039A). **GL benar (biaya sekali); STOK salah (qty dobel).**

Menjawab kriteria audit:
- ✅ Bukan write-off — unit riil dari '02' BTB tetap ada.
- ✅ Bukan opening manipulation, bukan WIP.
- ✅ Transaksi penyebab teridentifikasi: **'05' (Ekspedisi) tidak boleh menambah unit stok**.
- ✅ Koreksi lewat sumber (bukan adjustment saldo).

## 6. KOREKSI (via sumber, bukan hapus saldo) — WAJIB divalidasi di COPY-DB dulu
**Prinsip:** '05' (Ekspedisi) hanya boleh menyumbang **nilai freight**, **bukan QTY**. Dua jalur setara:
- **Opsi C-1 (engine, permanen):** ubah `dw_refresh_stok` → tipe '05' **QTY = 0** (freight loaded via nilai, bukan unit). Lalu re-close/refresh Jan-Des. Menghentikan phantom **selamanya**.
- **Opsi C-2 (data historis):** set `tstok2.QTY = 0` untuk semua '05' TR/NR/TB (pertahankan netto/biaya_ekspedisi utk costing), lalu re-close. Membersihkan histori.

**Rekomendasi:** C-1 + C-2 bersama (engine berhenti dobel ke depan; historis dibersihkan).

## 7. VALIDASI DEFINITIF (bukti sebelum sentuh prod)
Di COPY-DB: jalankan koreksi → re-close TR/NR/TB Jan-Feb → cek:
- **A.** 102-001/003/006/020: **sinv = ledger** (selisih ≤ Rp1).
- **B.** Mutasi Jan-Feb tetap = ledger (koreksi hanya di qty inbound, bukan gerakan jual).
- **C.** HPP/costing WIP tak berubah (Bagian A/B utuh).
Bila A/B/C lulus di copy-DB → root cause & koreksi TERBUKTI dapat dipertanggungjawabkan → baru prod.

## 8. Catatan kejujuran (agar audit-safe)
Pola double-count '02'+'05' & GL-sekali **terbukti dari data**. Namun sinv qty final dihitung engine closing yang kompleks (WIP by-evap + moving-avg), sehingga **besaran phantom pasti** hanya bisa dikunci dengan **re-close di copy-DB** (langkah 7). **Tidak melakukan koreksi apa pun ke prod sebelum copy-DB membuktikan sinv=ledger.** Ini sesuai instruksi Bapak: buktikan dulu, jangan adjustment saldo langsung.
