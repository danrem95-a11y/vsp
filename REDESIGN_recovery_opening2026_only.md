# REDESIGN Recovery — HANYA Opening 2026 (Desember 2025 FROZEN)
Constraint final Pak Wira: **Saldo akhir/closing/neraca/laporan 2025 = hasil audit, TIDAK BOLEH berubah satu rupiah.**
Pendekatan lama (re-close Desember → tulis ulang `sinv[2026-01-01]`) **DICABUT** karena `sinv[2026-01-01]` = snapshot yang Bapak anggap saldo akhir 31-12-2025.

## 0. Temuan yang memandu desain (read-only)
- **Neraca 2025 = GL** (`gl_balance`/`gl_journal`). Recovery **tidak menyentuh GL** → neraca 2025 pasti identik.
- **Laporan Mutasi Stok Desember 2025** (`dw_stok_gl_mutasi`, arg=2025-12-01): AWAL=`sinv[2025-12-01]`, **AKHIR dihitung dari transaksi** (bukan baca `sinv[2026-01-01]`). Jadi selama transaksi & `sinv[2025-12-01]` tak diubah → laporan Des-2025 identik.
- `sinv[2026-01-01]` **hanya dibaca sebagai AWAL laporan Januari 2026** (= Saldo Awal 2026). Inilah satu-satunya titik yang perlu dikoreksi.

## 1. Ruang lingkup (dikunci)
| BOLEH berubah | TIDAK BOLEH berubah |
|---|---|
| Saldo Awal 2026 (efektif) | `sinv[2026-01-01]` snapshot (biarkan 23,11 M) |
| Mutasi Jan 2026 | Semua data ≤ 31-12-2025 (tstok/tsales/gl 2025) |
| Mutasi Feb 2026 dst | `sinv[2025-12-01]` & semua sinv 2025 |
| sinv Feb/Mar 2026 | GL / gl_balance / neraca 2025 |
| | Laporan & closing audit 2025 |

## 2. DESAIN: "Koreksi Saldo Awal 2026" (efektif 01-01-2026)
Prinsip: **saldo akhir 2025 dipakai READ-ONLY**; koreksi phantom **dibukukan sebagai entri baru bertanggal 01-01-2026**, sehingga perubahan PERTAMA muncul di Januari 2026, bukan Desember 2025.

**Langkah:**
1. **Hitung target opening 2026 dari engine** (read-only): jalankan `dw_refresh_stok` closing Des-2025 → nilai benar per model (= GL, terbukti 12.999.133.239). *Perhitungan saja, tidak menulis apa pun ke Des-2025.*
2. **Hitung delta phantom per model** = `sinv[2026-01-01]` − engine (mis. TR.038A −30 unit, TR.039A −12 unit). Total per akun (102-001 −10,11 M, dst).
3. **Bukukan "KOREKSI SALDO AWAL 2026"** sebagai penyesuaian **subledger stok** bertanggal **01-01-2026**:
   - Menurunkan qty/nilai phantom per model ke nilai engine.
   - **Stok-subledger saja, TANPA jurnal GL** — karena GL 2026 opening sudah benar (12,99 M). (Ini rekonsiliasi subledger→GL, bukan transaksi baru yang mengubah neraca.)
   - `sinv[2026-01-01]` snapshot **dibiarkan 23,11 M** (saldo akhir 2025 utuh). Koreksi masuk sebagai gerakan Januari.
4. **Re-refresh Januari 2026** (via NVO/aplikasi): AWAL=`sinv[2026-01-01]` (23,11 M) + gerakan Jan (termasuk koreksi −10,11 M) → `sinv[2026-02-01]` = 12,99 M + gerakan riil = **GL closing Jan**.
5. **Re-refresh Februari 2026** → `sinv[2026-03-01]` = **GL closing Feb**.
6. Selesai: opening efektif 2026 & seluruh 2026 = GL; Desember 2025 utuh.

> Alternatif teknis (bila diverifikasi laporan 2025 memang TIDAK membaca `sinv[2026-01-01]`): cukup rebuild `sinv[2026-01-01]`=engine — laporan 2025 tetap identik karena AKHIR-nya dihitung. TAPI karena Bapak minta snapshot itu tidak diubah, desain utama memakai **koreksi efektif Januari** (di atas) yang aman tanpa syarat.

## 3. Kenapa ini audit-safe
- **Tidak ada penulisan apa pun ke periode ≤ 2025-12-31.** Engine hanya DIBACA untuk menghitung target.
- Koreksi = entri **bertanggal 01-01-2026** → perubahan pertama tepat di Opening 2026.
- **Tidak menyentuh GL** → neraca 2025 (dan 2026) tidak berubah dari sisi jurnal.
- **Tidak menyentuh WIP 102-020 & HPP WIP** → costing utuh.

## 4. VALIDASI WAJIB (harus semua lolos)
| # | Validasi | Cara |
|---|---|---|
| A | **Laporan 2025 IDENTIK** (byte-to-byte) | Jalankan `dw_stok_gl_mutasi` Des-2025 sebelum & sesudah → hasil sama; checksum |
| B | **Saldo akhir 31-12-2025 tidak berubah** | `sinv[2026-01-01]` snapshot & closing Des computed tetap; GL 2025 tetap |
| C | **Perubahan pertama di Opening 01-01-2026** | Entri koreksi bertanggal 2026-01-01; tak ada perubahan tgl 2025 |
| D | **Mutasi Jan-Feb konsisten thd opening baru** | sinv[2026-02-01]/[2026-03-01] = GL closing |
| E | **102-020 WIP tetap** | Σ(debet−kredit) 102-020 delta 0 |
| F | **Costing WIP tetap** | HPP jual WIP = HPP WIP-Out; non-WIP = average; Σ hpp×qty '88' delta 0 |
| + | **Idempotent** | Ulangi recovery → hasil identik (delta 0) |

## 5. Catatan eksekusi
- Recovery via **NVO/proses closing resmi** untuk Jan-Feb (hpp presisi), koreksi opening via entri 01-01-2026.
- **Backup** sebelum eksekusi; uji **COPY-DB** dulu.
- **Prevention** (validasi tiap closing: engine vs sinv vs GL, selisih>Rp1 → FAIL) tetap dipasang.
- LOCAL yang sempat saya cascade (menyentuh Des-2025) akan **saya restore** — pendekatan itu dicabut.
