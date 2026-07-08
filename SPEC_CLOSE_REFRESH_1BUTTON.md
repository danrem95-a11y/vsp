# SPEC: Satu Tombol "CLOSE & REFRESH STOK" (Closing → Refresh → Re-Closing)

Tujuan: user cukup klik 1× di window **w_refresh_journal**. Menu Closing Stock tidak dipakai lagi
untuk operasi bulanan (Closing Kas & GL akhir tahun tetap di menu Closing).

Prinsip: **tidak mengubah logika valuasi apa pun** — hanya (a) membungkus proses closing jadi fungsi
yang bisa dipanggil senyap, (b) melewati dialog konfirmasi saat dijalankan otomatis, (c) menambah 1
tombol yang memanggil urutannya.

WAJIB: implementasi & uji di **PB IDE pada SALINAN** dulu (bukan produksi). Ini kode window/PowerScript
yang tidak bisa diuji di luar IDE.

===================================================================================================
## BAGIAN A — w_closing_stok.srw : buat window function `wf_closing`
===================================================================================================

### A1. Tambah window function (Declare → Window Functions):

```
public function integer wf_closing (datetime adt_periode, boolean ab_silent)
```

### A2. Isi fungsi = SALIN seluruh isi blok `if dwo.name = 'b_proses' then ... end if`
(event `dw_arg::buttonclicked`, kira-kira baris 543–938) ke dalam fungsi, DENGAN 5 penyesuaian:

1) Deklarasi lokal di awal fungsi (sebelumnya ada di event):
```
datetime ldt_periode,ldt_tgl1,ldt_tgl2,ldt_next
long ll_row,i,ll_found,ll_minus,ll_replace,ll_konfirm,ll_count
decimal ld_qty,ld_awal_rp,ld_nilai,ld_hpp,ld_qty_current,ld_qty_awal,ld_qty_update,ld_nilai_awal,ld_nilai_update,ld_nilai_set
decimal ldec_beli,ldec_beli_rp,ldec_mutasi,ldec_mutasi_rp
string ls_stok,ls_group
decimal ldec_debug,ldec_final,ldec_total_qty,ldec_total_nilai
boolean lb_replace = false
```

2) Sumber periode & flag — ganti referensi `this.` (dulu = dw_arg) menjadi `dw_arg.` dan pakai parameter:
   - `this.accepttext( )`            → HAPUS (tak perlu)
   - `ldt_tgl1 = this.object.periode[1]`   → `ldt_tgl1 = adt_periode`
   - `ll_minus   = this.object.oto_minus[1]`   → `ll_minus   = dw_arg.object.oto_minus[1]`
   - `ll_replace = this.object.replace_stok[1]` → `ll_replace = dw_arg.object.replace_stok[1]`
   - (semua `this.object.xxx` lain → `dw_arg.object.xxx`)

3) Konfirmasi utama (baris ~565):
```
   if Messagebox('Konfirmasi!','Yakin untuk melakukan closing stock ?',Question!,Yesno!,2)=2 then return
```
   → GANTI menjadi:
```
   if not ab_silent then
      if Messagebox('Konfirmasi!','Yakin untuk melakukan closing stock ?',Question!,Yesno!,2)=2 then return -1
   end if
```

4) Blok akhir-tahun (baris ~568–594) — bungkus SELURUHNYA dengan `if not ab_silent`, dan saat silent
   pakai setelan `ll_replace` apa adanya (tanpa dialog):
```
   if string(ldt_next,'mm') = '01' then
      if not ab_silent then
         ... (biarkan seluruh blok choose/messagebox yg lama di sini, TAPI setiap `return` → `return -1`) ...
      else
         lb_replace = (ll_replace = 1)      // silent: ikuti setelan replace_stok yg ada, tanpa tanya
      end if
   end if
```

5) Pesan sukses (baris ~934) & error → bungkus, dan tambahkan nilai balik:
   - `messagebox('Sukses','Proses berhasil..!')`  → `if not ab_silent then messagebox('Sukses','Proses berhasil..!')`
   - `messagebox('','Error..!')` (baris ~812) → biarkan (error tetap ditampilkan), tapi baris `return` sesudahnya → `return -1`
   - Di AKHIR fungsi tambahkan:  `return 1`

CATATAN: JANGAN sertakan blok `if dwo.name = 'b_cek' then ... end if` (itu fungsi cek terpisah).

### A3. Ubah event `dw_arg::buttonclicked` blok b_proses menjadi pemanggil fungsi:
```
if dwo.name = 'b_proses' then
    this.accepttext()
    wf_closing(this.object.periode[1], false)   // false = tampilkan dialog seperti biasa
end if
```
(biarkan blok `b_cek` apa adanya)

===================================================================================================
## BAGIAN B — w_refresh_journal.srw : flag silent + lewati dialog di 9 tombol
===================================================================================================

### B1. Tambah Instance Variable window w_refresh_journal:
```
boolean ib_silent = false
```

### B2. Di SETIAP 9 event `clicked` tombol berikut, bungkus 2 dialog dengan `if not ib_silent`:
Tombol: cb_9(SO) cb_8(PO) cb_10(Non Item) cb_6(EXP) cb_5(AR) cb_7(AP) cb_11(Adj) cb_13(Cons OUT) cb_14(Cons IN)

- Konfirmasi awal (contoh):
```
   if messagebox('Konfirmasi!','Yakin untuk melanjutkan proses..?',question!,yesno!,2) = 2 then return
```
  → GANTI:
```
   if not ib_silent then
      if messagebox('Konfirmasi!','Yakin untuk melanjutkan proses..?',question!,yesno!,2) = 2 then return
   end if
```

- Pesan selesai (contoh: `messagebox('Finish!','Proses finish!')`, `messagebox('Sukses..!','Refresh AR sukses..!')`):
```
   if not ib_silent then messagebox('Finish!','Proses finish!')
```
  (pesan Error/Warning `stopsign!` BIARKAN tampil — jangan dibungkus)

===================================================================================================
## BAGIAN C — w_refresh_journal.srw : tombol orkestrator
===================================================================================================

### C1. Tambah 1 CommandButton (via painter) — text: `CLOSE & REFRESH STOK`  (mis. nama cb_cr)

### C2. Event clicked:
```
integer li_rc
datetime ldt_periode

// periode dari dw_arg (samakan dgn yg dipakai refresh)
dw_arg.accepttext()
ldt_periode = f_bom(dw_arg.object.tgl1[1])

if messagebox('Konfirmasi', &
   'Jalankan CLOSING -> REFRESH -> RE-CLOSING stok untuk periode ' &
   + string(ldt_periode,'mmm-yyyy') + ' sekali jalan?', Question!, YesNo!, 2) = 2 then return

setpointer(HourGlass!)
ib_silent = true

// ---------- 1) CLOSING ----------
open(w_closing_stok)
li_rc = w_closing_stok.wf_closing(ldt_periode, true)
close(w_closing_stok)
if li_rc <> 1 then
   ib_silent = false
   messagebox('Batal','Closing pertama gagal/dibatalkan. Proses dihentikan.',StopSign!)
   return
end if

// ---------- 2) REFRESH (urutan sesuai manual) ----------
cb_9.TriggerEvent(Clicked!)    // SO + HPP
cb_8.TriggerEvent(Clicked!)    // PO
cb_10.TriggerEvent(Clicked!)   // Non Item
cb_6.TriggerEvent(Clicked!)    // EXP
cb_5.TriggerEvent(Clicked!)    // AR
cb_7.TriggerEvent(Clicked!)    // AP
cb_11.TriggerEvent(Clicked!)   // Adj
cb_13.TriggerEvent(Clicked!)   // Cons OUT
cb_14.TriggerEvent(Clicked!)   // Cons IN

// ---------- 3) RE-CLOSING ----------
open(w_closing_stok)
li_rc = w_closing_stok.wf_closing(ldt_periode, true)
close(w_closing_stok)

ib_silent = false
setpointer(Arrow!)

if li_rc = 1 then
   messagebox('Selesai','Closing -> Refresh -> Re-Closing SELESAI untuk periode '+string(ldt_periode,'mmm-yyyy'))
else
   messagebox('Perhatian','Re-Closing gagal. Cek data.',StopSign!)
end if
```

CATATAN penting:
- Pastikan nama tombol cb_5..cb_14 di atas COCOK dengan window Anda (peta: SO=cb_9, PO=cb_8,
  NonItem=cb_10, EXP=cb_6, AR=cb_5, AP=cb_7, Adj=cb_11, ConsOUT=cb_13, ConsIN=cb_14).
  Jika berbeda di produksi, sesuaikan.
- `w_closing_stok` HARUS di-`open` sebelum memanggil `wf_closing` (fungsi memakai kontrol dw_view/
  dw_sinv di window itu), lalu di-`close`. Jika window sudah muncul mengganggu, boleh set
  `w_closing_stok.Hide()` setelah open, atau buka sebagai window tersembunyi.
- Transaksi: pastikan tiap langkah commit/rollback sendiri (kode existing sudah begitu).

===================================================================================================
## PENGUJIAN (WAJIB di SALINAN)
===================================================================================================
1. Backup DB. Jalankan tombol untuk 1 periode uji (mis. April 2026).
2. Verifikasi:
   - Mutasi Stok = Ledger (per akun) — beda hanya pembulatan.
   - SINV bulan berikut = SINV bulan ini + mutasi GL (kontinuitas).
   - Tidak ada dialog nyangkut / proses berhenti di tengah.
3. Bandingkan hasil dengan cara lama (close→refresh→close manual) — harus identik.
4. Baru terapkan ke produksi setelah cocok.
