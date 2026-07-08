# SPEC — REFAKTOR UI DRILLDOWN POPUP (PB 11.5, UI-LAYER ONLY)
**Ruang lingkup:** HANYA presentation layer. TIDAK mengubah view/SP/snapshot/tabel. Traceability voucher→GL→subledger dipertahankan.
**Objek baru (UI):** `w_rekon_drill` (response window), `str_rekon_ctx` (structure). **Diperbarui (UI props saja):** `dw_rekon_gl_bridge`, `dw_rekon_detail_voucher` (label ramah + warna + tooltip). **Dipakai apa adanya:** semua view/SP.

---

## 1. WINDOW LAYOUT IMPROVEMENT SPEC
`w_rekon_drill` = **RESPONSE WINDOW, modal, resizable, center** (pola legacy `w_fa_journal_popup`). Tata letak atas→bawah:

```
┌───────────────────────────────────────────────────────────────┐
│ [HEADER PANEL]  Domain | Entitas | Identitas | Dokumen | Status│  ← statictext read-only
├───────────────────────────────────────────────────────────────┤
│ [SYSTEM INSIGHT]  kalimat otomatis dari data yang dibuka       │  ← multilineedit read-only
├───────────────────────────────────────────────────────────────┤
│ Dokumen / Transaksi                                            │  ← st divider
│ [dw_txn = dw_rekon_detail_voucher]  (klik = trace GL)          │
├───────────────────────────────────────────────────────────────┤
│ Jejak Buku Besar (GL)                                          │  ← st divider
│ [dw_gl = dw_rekon_gl_bridge]                                   │
├───────────────────────────────────────────────────────────────┤
│ [Kembali]   [Ke Dashboard]   [Lihat Anomali]                   │  ← command buttons
└───────────────────────────────────────────────────────────────┘
```
- **HEADER PANEL** (§4) = konteks bisnis; label besar, bold, warna status.
- **SYSTEM INSIGHT** (§5) = 1–3 kalimat ringkas, diisi dari data DW yang sudah di-retrieve (tanpa query/logic baru).
- **Dua section** dipisah `statictext` judul (grouping visual: header vs detail tak tercampur).
- **Button bar** (§6): Kembali / Ke Dashboard / Lihat Anomali.

---

## 2. STRUKTUR POPUP (SECTION-BASED)
| Section | Kontrol | Sumber (tak berubah) | Isi |
|---|---|---|---|
| A. Konteks (Summary) | `st_*` header panel | dari `str_rekon_ctx` + baris terpilih | Domain, Entitas, Identitas, Dokumen, Status |
| B. Insight | `mle_insight` (read-only) | dihitung dari `dw_gl`/`dw_txn` yang sudah di-retrieve | kalimat ringkas |
| C. Transaksi | `dw_txn` = `dw_rekon_detail_voucher` | view existing | daftar dokumen/voucher entitas |
| D. Jejak GL | `dw_gl` = `dw_rekon_gl_bridge` | view existing | baris jurnal GL (debet/kredit) |

Retrieve memakai **arg existing** (`:arg_domain,:arg_entity,:arg_thn,:arg_bln,:arg_account,:arg_voucher`) — hanya **refine parameter**, tidak reload dataset penuh (§8).

---

## 3. LABEL TRANSFORMATION (TEKNIS → BISNIS)
Diterapkan sebagai **teks header kolom / judul section** (bukan ubah nama kolom DB):
| Teknis (kolom) | Label Bisnis |
|---|---|
| `voucher` | **No. Dokumen** |
| `voucher_manual` | **No. Referensi** |
| `account_id` / gl_account | **Akun Buku Besar** |
| `subledger` / `subledger_value` | **Nilai Buku Pembantu** |
| `ledger` / `ledger_value` | **Nilai GL** |
| `selisih` | **Selisih** |
| `debet` | **Debet** · `kredit` → **Kredit** |
| `tgl` | **Tanggal** |
| `modul_id` | **Sumber** |
| `anchor_type` | **Jenis Dokumen** |
| `has_subledger` | **Berjurnal GL?** |
| `rule_id` / `category` | **Kode / Jenis Anomali** |
| `nilai` | **Nilai** |

**Terjemahan NILAI (display-only, via computed column — opsional, TIDAK ubah data):**
- `anchor_type`: `INVOICE`→Faktur · `PAYMENT`→Pembayaran · `OPENING`→Saldo Awal · `ORPHAN`→Tanpa Pasangan
  Computed field: `c_jenis = case(anchor_type when='INVOICE' then 'Faktur' when='PAYMENT' then 'Pembayaran' when='OPENING' then 'Saldo Awal' else 'Tanpa Pasangan')`
- `has_subledger`: `c_berjurnal = if(has_subledger='Y','Ya','Tidak')`

---

## 4. CONTEXT HEADER — implementasi `str_rekon_ctx`
**Structure `str_rekon_ctx.srs`:**
```
global type str_rekon_ctx from structure
    string  s_domain
    string  s_entity
    string  s_identifier
    string  s_document
    string  s_status
    long    l_thn
    integer i_bln
    string  s_account
    string  s_voucher
end type
```
Popup punya instance var `str_rekon_ctx istr_ctx`. Di `open;` string param `Message.StringParm`
(format `domain|entity|periode|voucher`, delimiter `|` — konsisten pola drill existing) **di-parse ke `istr_ctx`**, lalu header di-set:
```
st_domain.text  = "Domain: "    + istr_ctx.s_domain
st_entity.text  = "Entitas: "   + istr_ctx.s_entity
st_ident.text   = "Identitas: " + istr_ctx.s_identifier   // nama vendor/customer/akun bila ada
st_doc.text     = "Dokumen: "   + istr_ctx.s_document
st_status.text  = "Status: "    + istr_ctx.s_status
```
Warna `st_status` di-set sesuai status (§7). Identitas nama = lookup opsional (bila DW punya kolom nama); bila tidak, tampil kode.

---

## 5. SMART INSIGHT BAR — logic (dari output engine, NON-hardcode)
Diisi di `open;` **membaca DataWindow yang sudah di-retrieve** (tak ada query/logic bisnis baru). Contoh (dw_gl = jejak GL):
```
long  ll_total, ll_orphan
dec   ldc_gap
string ls
ll_total  = dw_gl.RowCount()
ll_orphan = long(dw_gl.Object.Compute[1])   // compute: count(if(has_subledger='N',1,0) for all)
ldc_gap   = dec(dw_gl.Describe("evaluate('sum(if(has_subledger=~~'N~~', abs(debet)+abs(kredit),0) for all)', 1)"))
CHOOSE CASE TRUE
CASE ll_total = 0
   ls = "Belum ada baris jurnal GL untuk konteks ini."
CASE ll_orphan = 0
   ls = "Semua " + string(ll_total) + " dokumen sudah berjurnal GL. Tidak ada indikasi selisih dari sisi ini."
CASE ELSE
   ls = string(ll_orphan) + " dari " + string(ll_total) + &
        " dokumen BELUM berjurnal GL (nilai " + string(ldc_gap,'#,##0.00') + "). " + &
        "Kemungkinan sumber selisih — buka [Lihat Anomali] untuk klasifikasi (mis. R9 orphan / R11 uang muka)."
END CHOOSE
mle_insight.text = ls
```
> Kalimat **dirakit dari angka aktual** (count/sum kolom `has_subledger`), bukan kesimpulan hardcode. Nama rule (R9/R11) hanya sebagai rujukan navigasi, bukan penilaian yang di-hardcode.

**Alternatif (klasifikasi resmi):** tombol **Lihat Anomali** memanggil `sp_rekon_anomali` existing (engine), bukan menebak di UI.

---

## 6. NAVIGASI & BACK FLOW
Popup modal (response). Tombol:
| Tombol | Aksi PB | Makna |
|---|---|---|
| **Kembali** | `CloseWithReturn(this, 'BACK')` | tutup popup, balik ke daftar sebelumnya |
| **Ke Dashboard** | `CloseWithReturn(this, 'DASHBOARD')` | tutup popup; window pemanggil membuka/aktifkan dashboard |
| **Lihat Anomali** | `CloseWithReturn(this, 'ANOMALY|' + istr_ctx.s_domain + '|' + string(istr_ctx.l_thn) + '-' + ...)` | tutup popup; pemanggil buka `w_rekon_anomali` konteks sama |

Window pemanggil (mis. `w_rekon_ap`) menangani nilai balik:
```
str ls_ret
OpenWithParm(w_rekon_drill, ls_param)
ls_ret = Message.StringParm
CHOOSE CASE TRUE
CASE ls_ret = 'DASHBOARD'         ; // aktifkan sheet dashboard
CASE Pos(ls_ret,'ANOMALY|')=1     ; OpenWithParm(w_rekon_anomali, Mid(ls_ret, Pos(ls_ret,'|')+1))
CASE ELSE                         ; // 'BACK' → tetap di window pemanggil
END CHOOSE
```
> Response window **tidak** membuka sheet lain langsung (hindari masalah modal); ia mengembalikan sinyal, pemanggil yang bernavigasi. Konteks (domain/period/entity) selalu ikut (§8).

---

## 7. COLOR CODING (UI HIGHLIGHT SAJA — via DataWindow expression, tak ubah data)
Diterapkan sebagai **Background.Color / Color expression** pada kolom di DataWindow (bukan script):
| Kondisi | Warna | Expression contoh (Background.Color kolom/detail) |
|---|---|---|
| COCOK | HIJAU muda | `if(status='COCOK', rgb(224,255,224), rgb(255,255,255))` |
| SELISIH / ORPHAN | MERAH muda | `if(status='SELISIH' or anchor_type='ORPHAN' or has_subledger='N', rgb(255,224,224), rgb(255,255,255))` |
| ANOMALI HIGH | MERAH | `if(severity='HIGH', rgb(255,210,210), ...)` |
| WARNING MED | KUNING | `if(severity='MED', rgb(255,247,205), ...)` |
| INFO | ABU | `if(severity='INFO', rgb(238,238,238), rgb(255,255,255))` |
Header panel `st_status`: script `st_status.BackColor = IF(status kontan mengandung 'SELISIH', RGB(255,210,210), RGB(224,255,224))`.
> Warna hanya presentasi; nilai & logika tidak berubah.

---

## 8. CONTEXT PRESERVATION (refine param, bukan reload)
- Semua retrieve membawa **argumen yang sama** yang sudah dibawa dari drill sebelumnya (`domain, periode, entity`), hanya menambah **voucher** saat trace GL.
- `dw_txn.Retrieve(is_domain, is_entity, il_thn, ii_bln)` — sekali saat open.
- `dw_txn.doubleclicked` → `dw_gl.Retrieve(is_domain, is_account, il_thn, ii_bln, ls_voucher)` — **hanya menyempitkan** ke 1 voucher; DW lain tidak di-retrieve ulang.
- Tidak ada `Retrieve()` tanpa argumen; tidak ada full-scan dataset.

---

## 9. TOOLTIP (UX)
> **CATATAN PENTING:** atribut `tooltip.text` **TIDAK dikenali** parser source `.srd` PB 11.5
> (menyebabkan error import "incorrect syntax"). Set tooltip lewat **DataWindow painter**:
> pilih kolom → tab **Tooltip** → isi Text + centang Enabled. (Bukan via source.)
Kolom kunci & teks tooltip yang disarankan:
| Kolom | Tooltip |
|---|---|
| `voucher` (No. Dokumen) | "Klik untuk lihat detail transaksi & jurnal" |
| baris GL / `debet`/`kredit` | "Klik untuk lihat jurnal lengkap dokumen ini" |
| `has_subledger` (Berjurnal GL?) | "Tidak = dokumen belum punya jurnal GL (potensi selisih)" |
| `anchor_type` (Jenis Dokumen) | "Faktur / Pembayaran / Saldo Awal / Tanpa Pasangan" |
| (panel anomali) `category` | "Klik untuk lihat penyebab selisih" |

---

## 10. FILE & IMPORT
1. `str_rekon_ctx.srs` (import pertama — dipakai popup).
2. DataWindow di-update: `dw_rekon_gl_bridge.srd`, `dw_rekon_detail_voucher.srd` (label ramah + warna + tooltip).
3. `w_rekon_drill.srw` (response window popup).
4. Ubah pemanggil drill (`w_rekon_ap/ar/stok`, `w_rekon_voucher_detail`) agar `doubleclicked` membuka `w_rekon_drill` via `OpenWithParm(...)` dan menangani nilai balik (§6). *(perubahan event-level, bukan engine.)*

## 11. KEPATUHAN (checklist)
- ✅ Tak ada perubahan SQL engine (view/SP/snapshot). Popup & DW hanya membaca output existing.
- ✅ Tak ada tabel/logika bisnis baru; insight dirakit dari angka DW yang sudah ada.
- ✅ Tak ada hardcode akun/COA (semua via view map-driven existing).
- ✅ Traceability utuh: No. Dokumen → baris GL (`dw_gl`) → subledger tetap tersambung.
- ✅ ASA9-compatible (tak ada query baru; hanya presentasi).
