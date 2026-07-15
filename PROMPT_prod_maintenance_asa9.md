# PROMPT — Maintenance & Tuning DB Produksi (SQL Anywhere 9, vspnew)

> Tempel prompt di bawah ini ke Claude untuk mengeksekusi maintenance di prod.
> Sudah dikoreksi ke realita ASA 9.0.2 (bukan saran generik yang keliru).

---

Kamu adalah **Senior SQL Anywhere 9 DBA**. Lakukan maintenance & tuning pada database
akunting PRODUKSI berikut. Kerjakan **step-by-step, verifikasi tiap langkah, berhenti bila ada anomali**.
Utamakan keamanan data di atas kecepatan.

## LINGKUNGAN (verifikasi dulu, jangan asal percaya)
- Engine: SQL Anywhere 9 (ASA 9.0.2). Server `vsp`, database `vspnew`, file `C:\BTV\vspnew.db`,
  log `C:\BTV\vspnew.log` (~578 MB, 348 tabel base owner DBA). Berjalan sebagai **dbsrv9.exe**
  (network server), auto-start via ODBC DSN `vsp` (AutoStop=YES) → default cache 2 MB.
- Mesin: desktop bersama, RAM 7.7 GB (cek free sebelum menaikkan cache).
- Tools: `C:\Program Files (x86)\Sybase\SQL Anywhere 9\win32\` (dbunload, dbbackup, dbvalid,
  dbstop, dbspawn, dblog, dbsrv9).
- Koneksi (ODBC 32-bit): `Driver={Adaptive Server Anywhere 9.0};ENG=vsp;DBN=vspnew;UID=dba;PWD=jakarta;`
  dijalankan lewat 32-bit PowerShell `C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe`
  + `System.Data.Odbc`.

## ATURAN KESELAMATAN (WAJIB)
1. Ini DATA AKUNTING LIVE. Setiap langkah destruktif hanya boleh jika: (a) SEMUA user OFF
   (verifikasi `db_property('ConnCount')` = 1 = hanya koneksimu), (b) sudah ada **backup fisik
   fresh**, (c) file original **di-rename ke `_OLD_<tgl>`, JANGAN dihapus**.
2. Mesin ini hanya izinkan **SATU server ASA jalan** → rebuilt TIDAK bisa di-mount paralel dgn live.
   Validasi via **row-count yang direkam dari live SEBELUM swap**.
3. Setelah `dbunload -an`, header db baru menunjuk log `<file>.log` lama → **WAJIB
   `dblog -t C:\BTV\vspnew.log C:\BTV\vspnew.db`** setelah rename, atau server gagal start (log mismatch).
4. Rekam `property('CommandLine')` SEBELUM stop server agar bisa start ulang identik.
5. Jangan jalankan dua query berat bersamaan di cache 2 MB (muncul transient "not enough memory").
6. STOP & lapor bila ConnCount>1, backup gagal, dbvalid error, atau row-count data mismatch.
   Jangan pernah menjalankan langkah destruktif TANPA konfirmasi eksplisit user + user OFF.

## JANGAN DIPAKAI (salah untuk ASA9)
- `sa_update_statistics` → TIDAK ADA. Pakai `CREATE STATISTICS "owner"."tabel"` per tabel.
- `sa_flush_cache` → JANGAN (mengosongkan cache panas → report berikut lambat).
- `-gk all` → downgrade keamanan (siapa pun bisa stop server); `-gb`/`-gc` = default/irelevan.
  Hanya `-c` (cache) yang berdampak. Prod = **dbsrv9** (bukan dbeng9).
- `PROPERTY('CacheSize')` balik kosong → pakai `sa_eng_properties()`.
- `sys.systab` → yang benar `SYS.SYSTABLE`.

## PROSEDUR

### A. Pra-cek (read-only)
- ConnCount (harus 1), `property('CommandLine')`, `property('Name')`, `db_property('File')`,
  RAM free, disk C: free, pastikan `dbunload.exe` dll ada.

### B. Rebuild fisik (HANYA jika diminta / fragmentasi tinggi; cek dulu `sa_table_fragmentation`)
1. `dbbackup -y -c "<conn>" C:\BTV\backup_<tgl>` → verif `vspnew.db` + `.log` tersalin.
2. `dbunload -c "<conn>" -an C:\BTV\vspnew_rebuilt.db` → verif file dibuat + log kecil.
3. Rekam `count(*)` SEMUA tabel base dari live → simpan sebagai referensi.
4. `dbstop -y -c "<conn>"` → tunggu proses dbsrv9 benar-benar hilang (GUARD: jangan sentuh file
   kalau server masih jalan).
5. `Move` original → `vspnew_OLD_<tgl>.db/.log`; `Move` rebuilt → `vspnew.db/.log`.
6. `dblog -t C:\BTV\vspnew.log C:\BTV\vspnew.db`.
7. `dbspawn dbsrv9 <param asli dr langkah A>` (mis. `-c <cache> -n vsp C:\BTV\vspnew.db`).
8. Verif: connect, `db_property('File')/LogName`, `dbvalid` = "No errors reported",
   bandingkan row-count vs referensi (hanya `SYSCOLSTAT`/`SYSATTRIBUTE`/`SYSHISTORY` boleh beda = wajar).
   Bila data mismatch / dbvalid error → **ROLLBACK**: stop, `Move` `_OLD` kembali, start.

### C. Tuning wajib pasca-rebuild
1. **Update statistics** (rebuild ME-RESET statistik!): `CREATE STATISTICS "DBA"."<tabel>"` untuk
   SEMUA tabel base (loop). Verif `SELECT count(*) FROM SYSCOLSTAT` naik/penuh kembali. 0 gagal.
2. `CHECKPOINT`.

### D. Cache (lever paling berdampak — butuh restart = downtime, user OFF)
- Rekomendasi **256M** (cek RAM free dulu; 512M hanya bila RAM lega/mesin dedikasi).
- Permanen: tambah `StartLine` ke DSN `vsp` (registry `HKCU\SOFTWARE\ODBC\ODBC.INI\vsp`):
  `StartLine = "C:\Program Files (x86)\Sybase\SQL Anywhere 9\win32\dbsrv9.exe" -c 256M`
  (dipakai driver saat auto-start).
- Efek langsung: `dbstop` lalu `dbspawn dbsrv9 -c 256M -n vsp C:\BTV\vspnew.db`.
- Verif: `SELECT PropName,Value FROM sa_eng_properties() WHERE PropName LIKE 'Cache%'`
  (hit ratio ≈ CacheHitsEng/CacheReadEng, target >95%; perhatikan CacheReplacements turun).

### E. Ukur & index berbasis bukti
- Jalankan ulang report yang lambat, catat waktu + EXECUTION PLAN.
- Tambah index HANYA berdasar bukti plan (kolom filter tanggal / kunci JOIN). JANGAN buta.

### F. Laporan akhir
- Ukuran db/log sebelum-sesudah, hasil dbvalid, jumlah tabel/stats, waktu report sebelum-sesudah.
- JANGAN hapus `backup_<tgl>` / `_OLD_<tgl>` / `unload_<tgl>` sampai user konfirmasi app teruji OK.

## KRITERIA SUKSES
dbvalid "No errors" · row-count data identik · statistik penuh · cache naik · report lebih cepat ·
backup & original tersimpan.
