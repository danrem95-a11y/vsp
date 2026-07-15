# PROMPT — Percepat Report Mutasi Stok di SERVER PRODUKSI (SQL Anywhere 9)

> Tempel ke Claude yang berjalan DI server produksi. DB ada di folder D:\Database, UID=dba PWD=jakarta.
> Sudah dikoreksi ke realita ASA 9.0.2 + guardrail keselamatan.

---

Kamu **Senior SQL Anywhere 9 DBA**. Tujuan: mempercepat cetak report **Mutasi Stok**
(`dw_stok_gl_mutasi`) di SERVER PRODUKSI ini. Akar masalah sudah didiagnosis pada DB identik
di mesin lain: (1) tabel **SINV** ratusan-ribu baris **tanpa index leading-PERIODE** → full-scan;
(2) **cache server kekecilan** → disk-bound (run warm malah lebih lambat dari cold);
(3) SQL kuno **`*=` 9 derived-table + `NOT IN` key konkatenasi string**.
Terapkan fix BERTAHAP dengan ukur before/after. Utamakan keamanan data. Verifikasi fakta, jangan asumsi.

## LINGKUNGAN — DISCOVER DULU (jangan hardcode path)
- Engine SQL Anywhere 9 (ASA 9.0.x). DB produksi ada di folder **D:\Database** (temukan file `.db`-nya,
  mis. `vspnew.db`). Kredensial **UID=dba PWD=jakarta**.
- Temukan server yang jalan: PowerShell `Get-Process dbsrv9` (atau dbeng9). Ambil path exe → folder tools.
- Ambil parameter start via SQL: `SELECT property('Name')` (nama server / ENG),
  `SELECT property('CommandLine')` (catat `-n <server>`, `-c <cache>`, path `.db`),
  `SELECT db_property('File')` & `db_property('LogName')` → konfirmasi menunjuk ke `D:\Database\...`.
- Kalau tak tahu ENG: cek DSN app di registry `HKCU\SOFTWARE\ODBC\ODBC.INI\*` / `HKLM\...\WOW6432Node\ODBC\ODBC.INI\*`
  yang `DatabaseFile` = D:\Database\... → ambil `EngineName`.
- Koneksi (ODBC 32-bit): `Driver={Adaptive Server Anywhere 9.0};ENG=<server>;UID=dba;PWD=jakarta;`
  dijalankan lewat `C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe` + `System.Data.Odbc`.

## ATURAN KESELAMATAN
- Data akunting LIVE. **Backup fisik dulu**: `dbbackup -y -c "<conn>" <dir_backup>` (verif `.db`+`.log` tersalin).
- `CREATE INDEX` butuh lock tabel; ganti cache butuh **restart = downtime**. Lakukan saat **user OFF**
  (verifikasi `SELECT db_property('ConnCount')` = 1 = hanya koneksimu).
- **Rekam `property('CommandLine')` SEBELUM stop server** agar start ulang identik (hanya ubah `-c`).
- Ukur before/after tiap langkah. STOP & lapor bila ada anomali. JANGAN hapus backup.

## JANGAN DIPAKAI (salah untuk ASA9)
- `sa_update_statistics` → TIDAK ADA (pakai `CREATE STATISTICS "owner"."tabel"`).
- `sa_flush_cache` → JANGAN (mengosongkan cache panas).
- `-gk all` → downgrade keamanan; `-gb/-gc` default. Hanya `-c` (cache) berdampak. Prod = **dbsrv9** (bukan dbeng9).
- `PROPERTY('CacheSize')` balik kosong → pakai `sa_eng_properties()` (filter `PropName LIKE 'Cache%'`).
- `sys.systab` → yang benar `SYS.SYSTABLE` / `SYS.SYSINDEXES`.

## PROSEDUR

### A. Baseline (read-only)
1. Discover server/db/tools + cek RAM free & disk free.
2. Index inventory: `SELECT tname,iname,colnames FROM SYS.SYSINDEXES WHERE tname IN
   ('SINV','TSTOK1','TSTOK2','TSALES1','TSALES2') ORDER BY tname`. Konfirmasi **SINV tak punya
   index dengan PERIODE sebagai kolom pertama**; catat `SELECT count(*) FROM SINV`.
3. Ukur waktu (pilih 1 bulan yang ada datanya, mis. `<bln>`='2026-04-01'..'2026-04-30'):
   - Proxy bottleneck (tak butuh file .srd) — subquery AWAL:
     `SELECT SINV.STOK_ID, SUM(SINV.QTY), SUM(SINV.NILAI) FROM SINV
      WHERE SINV.PERIODE >= '2026-04-01' AND SINV.PERIODE < '2026-05-01' GROUP BY SINV.STOK_ID`
     — jalankan 2× (cold+warm), catat detik (pakai Stopwatch).
   - Bila `dw_stok_gl_mutasi.srd` tersedia di server: ekstrak `retrieve=` (UTF-16; kupas `~"`),
     ganti param literal: `:arg_tgl`→'2026-04-01', `:arg_tgl2`→'2026-04-30' (replace `:arg_tgl2`
     DULU sebelum `:arg_tgl`), `:arg_group`→'', `:arg_all1`→1, `:arg_zero`→0, `:flag_minus`→1;
     jalankan 2×, catat detik + jumlah baris.

### B. FIX #1 — Index (dampak terbesar per usaha; aman & droppable)
- Bila belum ada index leading-PERIODE: `CREATE INDEX idx_sinv_periode ON DBA.SINV(PERIODE, STOK_ID);`
- Ulangi pengukuran A.3. Catat before → after (harusnya subquery AWAL turun drastis).

### C. FIX #2 — Cache (restart, user OFF)
- Cek RAM free. Pilih `-c 256M` (aman) atau `512M` (bila RAM lega/mesin dedikasi).
- `dbstop -y -c "ENG=<server>;UID=dba;PWD=jakarta"`; tunggu proses dbsrv9 benar-benar hilang.
- `dbspawn dbsrv9 -c <size> -n <server> "D:\Database\<file>.db"` (parameter lain SAMA seperti
  `property('CommandLine')` asli, hanya `-c` yang diubah).
- Permanen: tambah `StartLine` ke DSN app (registry ODBC.INI DSN yang dipakai):
  `StartLine = "<path>\dbsrv9.exe" -c <size>` — dipakai saat driver auto-start.
- Verif: `SELECT PropName,Value FROM sa_eng_properties() WHERE PropName LIKE 'Cache%'`
  (hit ratio ≈ CacheHitsEng/CacheReadEng >95%, CacheReplacements turun). Ulangi pengukuran.

### D. FIX #3 — Rewrite SQL (TERAKHIR, hanya bila masih lambat)
- Ubah `*=` → ANSI `LEFT JOIN`; `NOT IN (key konkatenasi)` → `NOT EXISTS`.
- Ini mengubah **`dw_stok_gl_mutasi.srd` (PowerBuilder), BUKAN DB**. Wajib validasi angka **identik**
  vs versi lama di LOCAL sebelum deploy, lalu re-import PB + Full Build. JANGAN sentuh DB prod utk ini.

### E. LAPOR
Waktu before → after #1 → after #2 (proxy AWAL & full report), index yang dibuat, parameter cache baru,
rekomendasi apakah #3 perlu.

## KRITERIA SUKSES
Report Mutasi Stok jauh lebih cepat & **konsisten** (run warm ≤ run cold), **angka tidak berubah**,
backup tersimpan, tidak ada langkah destruktif tanpa user OFF + konfirmasi.
