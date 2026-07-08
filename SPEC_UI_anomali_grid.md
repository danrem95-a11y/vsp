# SPEC — UI/UX HARDENING ANOMALY GRID (w_rekon_anomali / dw_2)
**Ruang lingkup:** presentation layer saja. TIDAK mengubah `sp_rekon_anomali`/view/snapshot. Audit-grade dipertahankan.
**Kunci arsitektur:** `dw_2` (dataobject `dw_rekon_anomali`) = **DataWindow EXTERNAL** yang diisi hasil fetch `sp_rekon_anomali('ALL', thn, bln)`. Karena SP tak boleh diubah, filter Role/Domain/Severity/Rule diterapkan lewat **`DataWindow.SetFilter` yang parameter-driven** (deklaratif, bukan loop, tanpa reload); Period lewat SP-call. Ini memenuhi semua RULE.

---

## 1. FILTER PANEL — struktur (window layout)
Tambahkan di `w_rekon_anomali` (inherit `w_report`), di area atas (bersama `cb_tampil`):
| Kontrol | Tipe | Item |
|---|---|---|
| `ddlb_role` | DropDownListBox | ALL · ACCOUNTING · AUDITOR · OPERATOR |
| `ddlb_domain` | DropDownListBox | ALL · AP · AR · STOK · GL |
| `ddlb_severity` | DropDownListBox | ALL · HIGH · MED · INFO |
| `ddlb_rule` | DropDownListBox | ALL · R1..R11 |
| `dw_1` (existing) | periode | (d_rekon_periode) |
| `cb_tampil` (existing) | button | muat data periode (SP) |

Cara termudah & paling aman: **tambah 4 DDLB via DataWindow/Window painter** (drag DropDownListBox), isi Items di tab General, taruh sejajar di atas grid. Script di §2/§6.

**Item DDLB (set di painter atau constructor):**
```
ddlb_role.Reset();     ddlb_role.AddItem('ALL');ddlb_role.AddItem('ACCOUNTING');ddlb_role.AddItem('AUDITOR');ddlb_role.AddItem('OPERATOR'); ddlb_role.SelectItem(1)
ddlb_domain.Reset();   ddlb_domain.AddItem('ALL');ddlb_domain.AddItem('AP');ddlb_domain.AddItem('AR');ddlb_domain.AddItem('STOK');ddlb_domain.AddItem('GL'); ddlb_domain.SelectItem(1)
ddlb_severity.Reset(); ddlb_severity.AddItem('ALL');ddlb_severity.AddItem('HIGH');ddlb_severity.AddItem('MED');ddlb_severity.AddItem('INFO'); ddlb_severity.SelectItem(1)
ddlb_rule.Reset();     ddlb_rule.AddItem('ALL')
long i ; for i=1 to 11 ; ddlb_rule.AddItem('R'+string(i)) ; next ; ddlb_rule.SelectItem(1)
```

---

## 2. FILTER ENGINE (parameter-driven, no hardcode SQL, no loop, no reload)
**Load** (sudah diterapkan di `cb_tampil::clicked`): panggil `sp_rekon_anomali('ALL', thn, bln)` sekali → semua baris AP/AR/STOK termuat, lalu `dw_2.SetSort("domain A, rule_id A")`.
**Filter** = fungsi `wf_applyfilter()` yang membangun ekspresi dari nilai kontrol (parameter), lalu `SetFilter`+`Filter` — **tanpa** re-retrieve:
```powerbuilder
// window function: wf_applyfilter() returns integer
string ls_f, ls_role, ls_dom, ls_sev, ls_rule
ls_role = ddlb_role.text
ls_dom  = ddlb_domain.text
ls_sev  = ddlb_severity.text
ls_rule = ddlb_rule.text
ls_f = ''
// :arg_role → preset domain (UI convenience; bukan engine logic)
choose case ls_role
  case 'ACCOUNTING' ; ls_f = "(domain='AP' or domain='AR')"
  case 'OPERATOR'   ; ls_f = "domain='STOK'"
  case 'AUDITOR'    ; ls_f = ""      // lihat semua
end choose
// :arg_domain
if ls_dom <> 'ALL' and ls_dom <> '' then
   if ls_f <> '' then ls_f += " and "
   ls_f += "domain='" + ls_dom + "'"
end if
// :arg_severity
if ls_sev <> 'ALL' and ls_sev <> '' then
   if ls_f <> '' then ls_f += " and "
   ls_f += "severity='" + ls_sev + "'"
end if
// :arg_rule
if ls_rule <> 'ALL' and ls_rule <> '' then
   if ls_f <> '' then ls_f += " and "
   ls_f += "rule_id='" + ls_rule + "'"
end if
dw_2.SetFilter(ls_f)   // ekspresi dari parameter kontrol — bukan static/loop
dw_2.Filter()
return 1
```
Panggil `wf_applyfilter()` di **`selectionchanged`** tiap DDLB:
```
event ddlb_domain::selectionchanged ; Parent.wf_applyfilter()   // (idem: role/severity/rule)
```
> Period berubah → user klik **Tampilkan** (`cb_tampil`) → re-load SP (arg thn/bln), lalu `wf_applyfilter()` lagi. Domain/Severity/Rule/Role berubah → **instan** (SetFilter, no reload).

**Pemetaan `:arg_*`:**
| Param | Sumber | Mekanisme |
|---|---|---|
| `:arg_period` | `dw_1.periode` | SP-call `sp_rekon_anomali(thn,bln)` |
| `:arg_domain` | `ddlb_domain` | `SetFilter domain=` (+ SP 'ALL' load) |
| `:arg_severity` | `ddlb_severity` | `SetFilter severity=` |
| `:arg_rule` | `ddlb_rule` | `SetFilter rule_id=` |
| `:arg_role` | `ddlb_role` | preset → `SetFilter domain in (...)` |

---

## 3. DW dw_2 MODIFICATION — column fix (SUDAH diterapkan di `dw_rekon_anomali.srd`)
| Kolom | Header (ramah) | Lebar | Align | Catatan |
|---|---|--:|---|---|
| rule_id | **Aturan** | 200 | kiri | freeze (§3b) |
| severity | **Prioritas** | 260 | kiri | freeze; warna (§color) |
| domain | **Area** | 200 | kiri | dasar grouping |
| category | **Jenis Anomali** | 780 | kiri | lebar cukup (anti-clip) |
| account_id | **Akun** | 420 | kiri | |
| ref_key | **Referensi** | 1040 | kiri | lebar cukup (anti-clip) |
| nilai | **Nilai Selisih (Rp)** | 500 | **kanan** | `#,##0.00` |
- **Auto width / no clipping:** lebar dinaikkan (di atas) supaya teks tak terpotong; header pendek → tak terpotong.
- **Numeric align right:** `nilai` alignment=1 (sudah).
- **Header readable:** label pendek Indonesia, muat 1 baris. Untuk multi-line, di painter set header text height 2 baris + wordwrap.

**§3b FREEZE 3 kolom pertama (Aturan/Prioritas/Jenis Anomali):** fitur painter (bukan source). Di DataWindow painter: pilih kolom → properties → *(atau)* gunakan **HScrollBar + set columns.moveable=no**; cara resmi PB: taruh 3 kolom kunci di **band terpisah / gunakan "Freeze"** via `dw_2.Object.DataWindow.HorizontalScrollPosition` locking. Praktis: kecilkan lebar total agar muat tanpa scroll (lebar di atas ± muat di layar lebar). Freeze sejati = painter.

---

## 4. HEADER IMPROVEMENT
Sudah: label ramah (Aturan/Prioritas/Area/Jenis Anomali/Akun/Referensi/Nilai Selisih (Rp)).
Multi-line header (opsional, painter): naikkan tinggi band header + set header text `Autosize Height`/wordwrap.

---

## 5. GROUPING (visual only)
- **SUDAH:** `dw_2.SetSort("domain A, rule_id A") ; dw_2.Sort()` sesudah load → baris tersusun per **Area (AP/AR/STOK)** lalu per **Aturan (R1..R11)**.
- **Group band (opsional, painter):** DataWindow painter → **Rows ▸ Create Group** → level-1 by `domain`, level-2 by `rule_id`; centang "New Page on Group Break" = off; tambah group header text `domain` / `'Aturan '+rule_id`. (NO SQL — murni DW grouping.)

---

## 6. QUICK FILTER BUTTONS (UX)
Tambah 4 command button (painter), tiap `clicked` set filter langsung (SetFilter param, no loop):
```
event cb_ap::clicked    ; ddlb_domain.SelectItem(2) /*AP*/ ; Parent.wf_applyfilter()
event cb_ar::clicked    ; ddlb_domain.SelectItem(3) /*AR*/ ; Parent.wf_applyfilter()
event cb_high::clicked  ; ddlb_severity.SelectItem(2) /*HIGH*/ ; Parent.wf_applyfilter()
event cb_r11::clicked   ; ddlb_rule.SelectItem(12) /*R11*/ ; Parent.wf_applyfilter()
```
> Tombol hanya menyetel kontrol + panggil filter yang sama → konsisten, satu sumber logika.

---

## 7. DOUBLE-CLICK DRILLDOWN UX (SUDAH diterapkan)
`dw_2::doubleclicked` sekarang membuka **RESPONSE WINDOW `w_rekon_drill`** membawa konteks:
```powerbuilder
ls_dom = this.GetItemString(row, 'domain')      // tipe string (bukan Any)
ls_ref = this.GetItemString(row, 'ref_key')
le = pos(ls_ref, "=")                            // ambil voucher dari 'vmanual=..'/'voucher=..'
if le > 0 then ls_key = mid(ls_ref, le + 1)
...
ls_param = ls_dom + "||" + ls_per + "|" + ls_key // domain | (kosong) | periode | voucher
openwithparm(lw, ls_param, "w_rekon_drill")
```
`w_rekon_drill` diperluas: bila field voucher terisi → `dw_gl.Retrieve(domain,'',thn,bln,voucher)` → langsung menampilkan **baris jurnal GL voucher tsb** + header konteks (Domain/Periode/Dokumen) + insight bar. Traceable: anomali → voucher → baris GL. (`str_rekon_ctx` diisi domain/rule/ref_key/severity di popup.)

> Catatan: memakai `GetItemString/GetItemDecimal` (bukan `this.object.col[row]`) — menghindari error runtime "Any → boolean".

---

## FILE
- **`dw_rekon_anomali.srd`** — header ramah + lebar anti-clip + `nilai` align kanan + **row-color per Prioritas** (HIGH=merah, MED=kuning, INFO=abu). *(sudah regen)*
- **`w_rekon_anomali.srw`** — load `ALL` (client-filter), `SetSort` grouping, doubleclick→`w_rekon_drill`. *(sudah regen)*
- **`w_rekon_drill.srw`** — terima voucher → filter GL. *(sudah regen)*
- **Ditambah di painter:** 4 DDLB filter + 4 quick button + `wf_applyfilter()` (§2), group band + freeze (§3b/§5) — kode paste-ready di atas.

## KEPATUHAN
- ✅ Tak ubah SP/view/snapshot. Filter = `SetFilter` deklaratif (bukan loop, bukan reload).
- ✅ Tak ada tabel/logika bisnis baru; role→domain hanya preset UI.
- ✅ ASA9-safe (tak ada query baru). Traceable ke voucher & GL utuh.
- ✅ Filter <3 klik (quick button = 1 klik); kolom tak terpotong; AP/AR/STOK tersusun jelas (sort+group).
