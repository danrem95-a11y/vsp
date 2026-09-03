# Tarik Aktiva dari Pembelian — Frontend (plug ke w_fa_generate)

Reuse window `w_fa_generate` (sudah ada dw_1=param tgl1/tgl2, dw_2=grid, tombol "Proses").
Tambah: 1 DataWindow preview + 2 tombol.

## 1) DataWindow baru: `dw_fa_purchase_preview` (grid, editable)
Retrieve arguments: `as_site` (string), `ad_from` (date), `ad_to` (date)

```sql
SELECT g.voucher, g.urut, g.tgl, ISNULL(g.ket,'') AS nama_aset,
       cat.category_code AS golongan, cat.useful_life_month AS umur,
       g.debet AS harga, 'Y' AS pilih
FROM   gl_journal g
JOIN   FA_CATEGORY cat ON cat.site_id = g.site_id AND cat.asset_account = g.account_id
WHERE  g.posting = 'P' AND g.site_id = :as_site AND g.debet > 0
  AND  g.tgl BETWEEN :ad_from AND :ad_to
  AND  NOT EXISTS (SELECT 1 FROM FA_ASSET a
                   WHERE a.site_id = g.site_id
                     AND a.source_ref = g.voucher || '#' || CAST(g.urut AS VARCHAR))
ORDER BY cat.category_code, g.tgl
```
Kolom & sifat:
- `pilih`      : checkbox (Y/N), default **Y**  -> centang baris yg mau dibuat
- `nama_aset`  : **editable** (edit) -> boleh perbaiki nama
- `golongan`   : **editable** (DropDownDW dari FA_CATEGORY) -> koreksi golongan bila akun ambigu
- `umur`       : **editable** (edit, number) -> override umur bila perlu
- `voucher,urut,tgl,harga` : read-only (protect=1)

## 2) Tombol "Tarik dari Pembelian"  (cb_tarik::clicked)
```powerbuilder
datetime ldt_from, ldt_to
dw_1.accepttext()
ldt_from = dw_1.object.tgl1[1]
ldt_to   = dw_1.object.tgl2[1]
if isnull(ldt_from) or isnull(ldt_to) then
   messagebox('', 'Isi Dari/ Sampai Tanggal..!'); return
end if
dw_2.dataobject = "dw_fa_purchase_preview"
dw_2.settransobject(sqlca)
dw_2.retrieve(gs_site, date(ldt_from), date(ldt_to))
if dw_2.rowcount() <= 0 then
   messagebox('Info','Tidak ada pembelian aktiva yang belum ditarik pada periode ini.')
end if
```

## 3) Tombol "Generate Aktiva"  (cb_generate::clicked)
```powerbuilder
long    ll, ll_cnt
string  ls_sql, ls_vch, ls_cat, ls_name
integer li_urut, li_ul
dw_2.accepttext()
if dw_2.dataobject <> "dw_fa_purchase_preview" then
   messagebox('', 'Klik "Tarik dari Pembelian" dulu.'); return
end if
if messagebox('Konfirmasi','Buat aktiva dari baris tercentang?',question!,yesno!) = 2 then return
ll_cnt = 0
for ll = 1 to dw_2.rowcount()
   if dw_2.object.pilih[ll] = 'Y' then
      ls_vch  = dw_2.object.voucher[ll]
      li_urut = dw_2.object.urut[ll]
      ls_cat  = dw_2.object.golongan[ll]
      ls_name = dw_2.object.nama_aset[ll]
      li_ul   = dw_2.object.umur[ll]
      // escape petik satu di nama (hindari SQL error)
      ls_name = f_replace(ls_name, "'", "''")   // atau: gs_replace/PB replace
      ls_sql  = "call sp_fa_pull_one('" + gs_site + "','" + ls_vch + "'," + string(li_urut) + &
                ",'" + ls_cat + "','" + ls_name + "'," + string(li_ul) + ")"
      execute immediate :ls_sql using sqlca;
      if sqlca.sqlcode <> 0 then
         messagebox('Error', ls_vch + ': ' + sqlca.sqlerrtext)
         rollback using sqlca; return
      end if
      ll_cnt ++
   end if
next
commit using sqlca;
messagebox('Info', string(ll_cnt) + ' aktiva dibuat. Klik "Proses" untuk hitung penyusutan periode ybs.')
// refresh preview: yg sudah ditarik otomatis hilang
dw_2.retrieve(gs_site, date(dw_1.object.tgl1[1]), date(dw_1.object.tgl2[1]))
```

## Alur akhir untuk Pak Wira
1. Isi **Dari–Sampai** bulan → **Tarik dari Pembelian** → muncul daftar pembelian aktiva belum ditarik.
2. Cek/edit **nama, golongan, umur** → hilangkan centang yg tak mau.
3. **Generate Aktiva** → FA_ASSET dibuat (nomor otomatis PKT-0181 dst).
4. **Proses** (tombol lama) → penyusutan periode ybs langsung terhitung.

Backend: `RUNBOOK_fa_pull_from_purchase.sql` (proc sp_fa_pull_one / sp_fa_pull_from_purchase + kolom source_ref + backfill).
