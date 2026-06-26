# Desain Perbaikan Permanen — Rutin Alokasi Ekspedisi (w_ekspedisi.srw)

> Tujuan: menghilangkan freight-mismatch di sumbernya (window input), agar nilai jurnal ekspedisi vendor-1 = nilai faktur yang diinput, dan tidak ter-revert setiap simpan/refresh.
> Status: **RANCANGAN untuk ditinjau & diuji di DB copy** sebelum diterapkan ke produksi. Belum dieksekusi.

---

## 1. Invariant yang harus dijaga (akar masalah)

Transfer GL membentuk jurnal dari `tstok2`, bukan dari header:
- `d_trace_ekspedisi` (jurnal induk / vendor-1): `ttl_kotor = Σ(tstok2.biaya_ekspedisi × qty) − Σ_anak(ttl_netto + freight)`
- `d_trace_freight` (jurnal FR / vendor-2): `Σ_anak(ttl_netto + freight)`

Maka **main + FR = total alokasi tstok2**. Agar jurnal vendor-1 = faktur, window WAJIB memenuhi:

```
Σ(tstok2.biaya_ekspedisi × qty) = induk.ttl_kotor + Σ_anak(ttl_netto + freight)
                                  └── vendor-1 ──┘   └──── vendor-2 (sama persis dgn GL) ────┘
```

**Bukti**: semua dokumen ekspedisi sehat memenuhi invariant ini (mis. 10126010500002: 8.337.955 + 2.346.000 = 10.683.955 = tstok2). Hanya 2 dokumen yang pernah diedit-tanpa-realokasi (10126040500001/02) yang melanggar.

---

## 2. Cacat pada kode saat ini ([w_ekspedisi.srw:592-693](w_ekspedisi.srw#L592-L693))

Rutin alokasi (event simpan tab Freight) bermasalah pada:

1. **Kontribusi vendor-2 tidak sinkron dengan GL.** Window memakai `ldec_bayar1_idr` yang dirakit dari `freight × freight_kurs`, `bayar1 × kurs1`, `bea masuk` ([L599-634](w_ekspedisi.srw#L599)) — menghasilkan mis. 11.859.885, padahal GL mengarve `ttl_netto + freight` anak = 13.328.000. Selisihnya (1.468.115) = persis nilai yang "hilang" dari vendor-1.
2. **Akumulasi di dalam loop.** [L652-653](w_ekspedisi.srw#L652) menambah `ldec_bayar1`/`ldec_bayar1_idr` tiap iterasi baris → total teralokasi tak deterministik.
3. **Basis pembagian tidak konsisten.** Pembilang `ld_netto_row` sudah digelembungkan freight ([L658-660](w_ekspedisi.srw#L658)), penyebut `ld_netto_detail` = nilai asli ([L629](w_ekspedisi.srw#L629)) → Σ alokasi ≠ target.
4. **Pemicu salah tempat.** Alokasi hanya jalan saat simpan tab Freight. **Edit header faktur tidak memicu re-alokasi**, sehingga koreksi nilai tidak nyangkut dan ter-revert saat dokumen disimpan ulang.

---

## 2.5 VERIFIKASI (ii) — titik pemicu & basis netto (2026-06-24)

**Temuan kunci: ada DUA jalur alokasi, dan jalur simpan-induk SUDAH BENAR.**

| Jalur | Lokasi | Total alokasi | Status |
|---|---|---|---|
| **Simpan dokumen induk** (tombol Simpan utama) | [L1130-1294](w_ekspedisi.srw#L1130-L1294) | `ldec_total = induk.ttl_kotor + Σ_anak(ttl_netto) + Σ_anak(freight)` ([L1189-1218](w_ekspedisi.srw#L1218)) = **invariant** | ✅ BENAR |
| **Simpan tab Freight/Vendor-2** | [L468-709](w_ekspedisi.srw#L468-L709) | `ldec_total(induk saja) + ldec_bayar1_idr(pool freight berbelit)` ([L673](w_ekspedisi.srw#L673)) | ❌ BUGGY |

- Jalur induk **re-alokasi tanpa syarat** setiap simpan ([L1182-1290](w_ekspedisi.srw#L1182)) lalu `f_transfer_ekspedisi_new` ([L1294](w_ekspedisi.srw#L1294)). Jadi edit header + simpan via tombol utama **sudah** menghasilkan alokasi benar. Korupsi 26.572.609 berasal **khusus** dari jalur simpan tab Freight.

**Basis netto AMAN (tidak sirkular):**
- Basis rasio = `cnetto_beli = hrg_beli × kurs_beli × qty` (compute) — `hrg_beli/kurs_beli` dari subquery `texpedisi` (harga beli **sumber**, stabil), **bukan** dari `netto` yang dimutasi.
- `call_beli = sum(cnetto_beli for all)` → Σ rasio = 1, alokasi menjumlah persis ke total.
- Jalur induk menyetel `netto = harga2 × qty` ([L1278](w_ekspedisi.srw#L1278)); `harga2` dari `texpedisi` → **idempoten** antar-simpan. (Penggelembungan `netto` oleh freight hanya ada di jalur Freight yang buggy, [L658-660](w_ekspedisi.srw#L658).)

**Konsekuensi untuk desain:** tidak perlu algoritma baru dari nol. Cukup **promosikan logika jalur-induk yang sudah benar** menjadi fungsi bersama, lalu pakai di kedua jalur. Risiko jauh lebih kecil (reuse kode yang terbukti benar).

---

## 3. Rancangan: ekstrak logika jalur-induk jadi `of_alokasi_ekspedisi(string as_induk)`

**Pendekatan utama (disarankan, risiko rendah):** ekstrak blok alokasi jalur-induk yang sudah benar ([L1185-1290](w_ekspedisi.srw#L1185-L1290)) menjadi fungsi `of_alokasi_ekspedisi(as_induk)`, lalu:
- **Ganti** blok buggy tab Freight ([L592-693](w_ekspedisi.srw#L592)) dengan pemanggilan `of_alokasi_ekspedisi(is_key_old)`.
- **Ganti** blok jalur induk ([L1185-1290](w_ekspedisi.srw#L1185)) dengan pemanggilan `of_alokasi_ekspedisi(ls_bukti)`.

Dengan ini copy yang divergen/buggy hilang, dua jalur memakai satu sumber yang benar.

Logika fungsi (ekuivalen dengan jalur-induk yang sudah benar, dirapikan):

```powerscript
public subroutine of_alokasi_ekspedisi (string as_induk)
// Menyetel tstok2.biaya_ekspedisi & netto_hpp untuk dokumen induk, dengan invariant:
//   Σ(biaya_ekspedisi*qty) = induk.ttl_kotor + Σ_anak(ttl_netto+freight)
decimal ldec_v1, ldec_v2, ldec_total, ldec_base
decimal ldec_netto_i, ldec_qty_i, ldec_porsi_i, ldec_unit_i
decimal ldec_akum, ldec_sisa, ldec_unit_last, ldec_qty_last
long ll_i, ll_n, ll_last

// (1) Vendor-1 = ekspedisi induk (nilai faktur yang diinput)
SELECT isnull(ttl_kotor,0) INTO :ldec_v1
FROM ap_trans WHERE bukti_id = :as_induk USING sqlca;

// (2) Vendor-2 = SAMA dengan yang dipakai GL (d_trace): Σ(ttl_netto+freight) dokumen anak
SELECT isnull(SUM(isnull(ttl_netto,0)+isnull(freight,0)),0) INTO :ldec_v2
FROM ap_trans WHERE order_reff = :as_induk AND bukti_id <> :as_induk USING sqlca;

ldec_total = ldec_v1 + ldec_v2

// (3) Basis pembagian = Σ netto tstok2 induk (definisi stabil, sama dgn netto_beli di d_trace)
SELECT isnull(SUM(isnull(netto,0)),0) INTO :ldec_base
FROM tstok2 WHERE bukti_id = :as_induk USING sqlca;
IF ldec_base = 0 THEN ldec_base = 1   // cegah div-by-zero

// (4) Alokasi proporsional netto, per baris di idw12 (tstok2 induk)
ll_n = idw12.RowCount()
ldec_akum = 0; ll_last = 0
FOR ll_i = 1 TO ll_n
    ldec_netto_i = idw12.object.netto[ll_i]
    ldec_qty_i   = idw12.object.qty[ll_i]
    IF IsNull(ldec_netto_i) THEN ldec_netto_i = 0
    IF IsNull(ldec_qty_i) OR ldec_qty_i = 0 THEN ldec_qty_i = 1
    ldec_porsi_i = Round((ldec_netto_i / ldec_base) * ldec_total, 2)   // total ekspedisi utk baris
    ldec_unit_i  = Round(ldec_porsi_i / ldec_qty_i, 2)                 // per unit (kolom biaya_ekspedisi)
    idw12.SetItem(ll_i, 'biaya_ekspedisi', ldec_unit_i)
    idw12.SetItem(ll_i, 'netto_hpp', ldec_netto_i + (ldec_unit_i * ldec_qty_i))
    ldec_akum = ldec_akum + (ldec_unit_i * ldec_qty_i)
    ll_last = ll_i
NEXT

// (5) Tampung sisa pembulatan di baris TERAKHIR agar Σ(biaya*qty) = ldec_total PERSIS
ldec_sisa = ldec_total - ldec_akum
IF ll_last > 0 AND ldec_sisa <> 0 THEN
    ldec_qty_last  = idw12.object.qty[ll_last]
    IF IsNull(ldec_qty_last) OR ldec_qty_last = 0 THEN ldec_qty_last = 1
    ldec_unit_last = idw12.object.biaya_ekspedisi[ll_last] + Round(ldec_sisa / ldec_qty_last, 2)
    idw12.SetItem(ll_last, 'biaya_ekspedisi', ldec_unit_last)
    idw12.SetItem(ll_last, 'netto_hpp',
        idw12.object.netto[ll_last] + (ldec_unit_last * ldec_qty_last))
END IF

idw12.AcceptText()
IF idw12.Update() <> 1 THEN
    RollBack;
    MessageBox('Error!','Gagal menyimpan alokasi ekspedisi dokumen '+as_induk,StopSign!)
    RETURN
END IF
COMMIT;
end subroutine
```

Catatan implementasi:
- **Kolom `netto`** dipakai sebagai basis. Pastikan ini netto pembelian yang stabil (tidak digelembungkan freight di tempat lain). Bila ada fitur "freight dalam faktur" yang sengaja menambah `netto`/`hrg` item, pisahkan dari alokasi `biaya_ekspedisi` (jangan dipakai sebagai basis ratio agar tidak sirkular).
- Fungsi menulis `biaya_ekspedisi` (per unit) dan `netto_hpp` saja — selaras dengan kolom yang memang di-update DW tstok2 (yang where-clause-nya sudah diperbaiki ke Key Columns).

---

## 4. Perbaikan pemicu (agar edit header nyangkut)

Panggil `of_alokasi_ekspedisi(<induk>)` dari **dua** jalur, SEBELUM `f_transfer_ekspedisi_new`:
1. **Simpan tab Freight/Vendor-2** — menggantikan blok lama [L592-693](w_ekspedisi.srw#L592). `as_induk = is_key_old`.
2. **Simpan dokumen induk** (event simpan utama, sekitar [L1130-1183](w_ekspedisi.srw#L1130-L1183)) — setelah `idw11.update()`. `as_induk = ls_bukti` induk.

Dengan ini, mengedit nilai faktur induk ATAU nilai vendor-2 selalu memicu alokasi ulang → jurnal selalu = faktur, koreksi tidak ter-revert.

---

## 5. Konsistensi dengan transfer GL (tanpa ubah d_trace)

Rancangan ini **tidak mengubah** `d_trace_ekspedisi`/`d_trace_freight`/`f_transfer_freight`. Karena window kini menjamin `Σ(biaya_ekspedisi*qty) = induk.ttl_kotor + Σ_anak(ttl_netto+freight)`, maka otomatis:
- Jurnal induk (d_trace_ekspedisi) = `total − Σanak` = **induk.ttl_kotor** (vendor-1 benar).
- Jurnal FR (d_trace_freight) = **Σ_anak(ttl_netto+freight)** (vendor-2 benar, kredit 102-601 setelah fix regresi `f_transfer_freight`).

---

## 6. Rencana uji (WAJIB di DB copy dulu)

Restore copy DB produksi, terapkan fungsi, lalu uji skenario:
1. **1 vendor (tanpa anak)**: induk.ttl_kotor=X, tanpa FR → tstok2_total=X, jurnal induk=X, tak ada FR. 
2. **2 vendor (induk + FR)**: mis. 14.712.724 + 13.328.000 → tstok2=28.040.724; jurnal induk=14.712.724 (Cr 226-006), FR=13.328.000 (Cr 102-601).
3. **Multi-FR** (>1 dokumen anak): Σanak benar, alokasi & pembulatan tepat.
4. **Edit header** dari 14.712.724 → nilai lain → simpan → jurnal ikut berubah (tidak ter-revert).
5. **Pembulatan**: Σ(biaya*qty) = total persis (cek baris penampung).
6. Bandingkan hasil dengan dokumen sehat existing (regression test).

Verifikasi tiap skenario:
```sql
SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id='<induk>';   -- = ttl_kotor induk + Σanak
SELECT doc_reff,SUM(debet) dr,SUM(kredit) cr FROM gl_journal
 WHERE modul_id='EX' AND doc_reff IN ('<induk>','<fr>') GROUP BY doc_reff;
```

---

## 7. Urutan rollout
1. **Prasyarat**: fix regresi `f_transfer_freight` (102-601) sudah ter-deploy.
2. Implementasi `of_alokasi_ekspedisi` + ubah 2 pemicu → uji lengkap di DB copy (bagian 6).
3. Koreksi data 2 dokumen rusak (tstok2 → 28.040.724 / 45.517.210) via prosedur ber-backup + Refresh EXP (paket terpisah, perlu approval akuntansi).
4. Deploy window ke produksi (import PBL 11.5 → regen → deploy).
5. Pemantauan: jalankan query invariant (bagian 1) untuk dokumen ekspedisi baru beberapa periode.

---

## 8. Catatan
- Bug penomoran `voucher_manual` EX duplikat per bulan ([f_transfer_ekspedisi_new](f_transfer_ekspedisi_new.srf) scan `voucher` seharusnya `voucher_manual`) adalah isu terpisah — bisa dirapikan bersamaan saat menyentuh modul ini.
- `tstok2` update where-clause sudah diperbaiki ke Key Columns (fix "Row changed"), aman dipakai fungsi ini.
