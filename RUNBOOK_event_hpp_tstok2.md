# B4 — Event "UPDATE HPP_TSTOK2": temuan & keputusan (evidence-based)

Diverifikasi langsung di DB prod (vspnew, 103.233.89.43) 2026-07-31.

## Fakta (bukan asumsi)
- **Jadwal:** recurring tiap **1 jam** (interval_units=HH, amt=1), 07:00–23:59, sejak 01-03-2008. `enabled = Y`.
- **Isi sebenarnya** (bukan seperti namanya — TIDAK menyentuh HPP):
  ```sql
  update TSTOK1 as A, TSTOK2 as B set
    B.COA_ID     = substring(B.DESCRIPTION, locate(B.DESCRIPTION,':',-1)+1, ...),
    B.PRODUK_ID  = substring(B.DESCRIPTION, locate(B.DESCRIPTION,':',-1)+1, ...)
  where A.BUKTI_ID=B.BUKTI_ID and A.TIPE_TRANS='88'
    and isnull(B.COA_ID,'')='' and isnull(B.DESCRIPTION,'')<>'';
  ```
  → mengisi **serial (COA_ID) + PRODUK_ID** pada WIP-In (`tstok '88'`) dari kolom DESCRIPTION, **hanya bila COA_ID kosong**.
- **Sifat:** monoton/idempoten — hanya mengisi yang KOSONG, tidak pernah menimpa serial yang sudah ada.
- **Target saat ini:** **0** dari 4.717 baris WIP-In '88' (semua sudah ber-COA_ID). Event **dorman**.

## Keputusan
**JANGAN dimatikan.** Alasan:
1. Event = jaring pengaman self-healing untuk defect lama (WIP-In tanpa serial dari koreksi stok 09/19 & mutasi BPB 17/07 — lihat remark event).
2. Tidak bisa merusak linkage: hanya mengisi blank dengan nilai turunan DESCRIPTION yang memang benar; tak pernah menimpa.
3. Tidak menulis HPP maupun tsales2 → **tidak melanggar I9** (I9 = writer tsales2.hpp; event ini menulis tstok2.coa_id).
4. Saat ini dorman (0 target).

**Yang dilakukan sebagai gantinya:** pantau via `INVARIANT_CHECKER.sql` → blok **B4-MONITOR** (`B4_BLANK_COA` harus 0). Bila > 0, artinya ada jalur yang membuat WIP-In tanpa serial → perbaiki SUMBER-nya, bukan matikan event.

## Opsional (hanya jika audit ketat menuntut zero-writer-during-refresh)
Karena event idempoten & dorman, ini TIDAK direkomendasikan. Bila tetap diminta, matikan **hanya selama jendela refresh** lalu hidupkan lagi:
```sql
ALTER EVENT "UPDATE HPP_TSTOK2" DISABLE;   -- sebelum refresh
-- ... jalankan refresh ...
ALTER EVENT "UPDATE HPP_TSTOK2" ENABLE;    -- sesudah refresh
```
Rollback (kembalikan ke normal, selalu enabled): `ALTER EVENT "UPDATE HPP_TSTOK2" ENABLE;`

> Catatan: **jangan** biarkan event mati permanen — WIP-In tanpa serial dari tool lama tak akan ter-repair, memutus pasangan WIP-Out↔WIP-In (INV-03/INV-04).
