$ErrorActionPreference='Stop'
# Engine dw_refresh_stok closing untuk periode DERIVED (closing_from..closing_to) -- diparameterisasi via CREATE VARIABLE
$eng=[System.IO.File]::ReadAllText("C:\BTV\debug\_engine_sql.txt")
$eng=$eng -replace ':arg_tgl2',' (closing_to) '
$eng=$eng -replace ':arg_tgl',' (closing_from) '
$eng=[regex]::Replace($eng,'(?is)\s+ORDER\s+BY\s+[^)]*$','')

$sql = @"
-- ============================================================================
-- RECOVERY MEKANISME A -- KOREKSI SNAPSHOT OPENING (perbaikan DATA TURUNAN, NOL transaksi)
-- PARAMETERIZED: satu-satunya yang perlu diubah = target_opening_period (anchor).
--   closing_from/closing_to/prior_snapshot/move_from/move_to DIDERIVASI otomatis. NOL hardcode tahun.
-- Prinsip: prior-year (closing) FROZEN. Tidak re-close, tidak buat transaksi/mutasi/jurnal.
-- Menyentuh HANYA snapshot sinv[target_opening_period] (kolom QTY & NILAI). HPP_AVG TIDAK diubah.
-- !!! COPY-DB DULU: pastikan select property('MachineName') = mesin TEST, bukan prod. !!!
-- ============================================================================

-- ==== PARAMETER (ubah HANYA baris SET target_opening_period ini) ====
IF VAREXISTS('target_opening_period')=1 THEN DROP VARIABLE target_opening_period END IF;
CREATE VARIABLE target_opening_period DATE;
SET target_opening_period = '2026-01-01';   -- <== anchor: awal-bulan opening yang dikoreksi

-- ==== DERIVED (jangan diubah manual) ====
IF VAREXISTS('closing_from')=1   THEN DROP VARIABLE closing_from   END IF;
IF VAREXISTS('closing_to')=1     THEN DROP VARIABLE closing_to     END IF;
IF VAREXISTS('prior_snapshot')=1 THEN DROP VARIABLE prior_snapshot END IF;
IF VAREXISTS('move_from')=1      THEN DROP VARIABLE move_from      END IF;
IF VAREXISTS('move_to')=1        THEN DROP VARIABLE move_to        END IF;
CREATE VARIABLE closing_from   DATE; SET closing_from   = dateadd(month,-1,target_opening_period);      -- awal bulan prior (=snapshot beku)
CREATE VARIABLE closing_to     DATE; SET closing_to     = dateadd(day,-1,target_opening_period);        -- akhir bulan prior
CREATE VARIABLE prior_snapshot DATE; SET prior_snapshot = closing_from;                                 -- sinv prior (READ-ONLY, frozen)
CREATE VARIABLE move_from      DATE; SET move_from      = target_opening_period;                        -- awal bulan opening (mutasi)
CREATE VARIABLE move_to        DATE; SET move_to        = dateadd(day,-1,dateadd(month,1,target_opening_period)); -- akhir bulan opening
SELECT target_opening_period, closing_from, closing_to, prior_snapshot, move_from, move_to;

-- STEP 1: BACKUP + BEFORE-IMAGE (untuk bukti scope) + baseline guard
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_mekA_bak') THEN DROP TABLE _mekA_bak END IF;
SELECT * INTO _mekA_bak FROM sinv WHERE periode IN (target_opening_period, dateadd(month,1,target_opening_period), dateadd(month,2,target_opening_period));
-- before-image PENUH periode target (row-level diff)
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_sinv_target_before') THEN DROP TABLE _sinv_target_before END IF;
SELECT * INTO _sinv_target_before FROM sinv WHERE periode=target_opening_period;
-- checksum per-periode SELURUH sinv (bukti hanya target yg berubah)
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_sinv_ck_before') THEN DROP TABLE _sinv_ck_before END IF;
SELECT periode, count(*) n, cast(sum(isnull(qty,0)) as numeric(24,4)) sq, cast(sum(isnull(nilai,0)) as numeric(24,2)) sn
  INTO _sinv_ck_before FROM sinv GROUP BY periode;
-- baseline guard prior-year + WIP/HPP (NULL-safe: isnull cegah warning 109 & kehilangan baris ber-NULL)
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_guard') THEN DROP TABLE _guard END IF;
SELECT 'prior_open_qty' k, cast(sum(isnull(qty,0))   as numeric(24,2)) v INTO _guard FROM sinv WHERE periode=prior_snapshot;
INSERT INTO _guard SELECT 'prior_open_nil', cast(sum(isnull(nilai,0)) as numeric(24,2)) FROM sinv WHERE periode=prior_snapshot;
INSERT INTO _guard SELECT 'gl_prior', cast(sum(isnull(debet,0)-isnull(kredit,0)) as numeric(24,2)) FROM gl_journal WHERE tgl<=closing_to;
INSERT INTO _guard SELECT 'move_tx', cast((SELECT isnull(sum(isnull(qty,0)),0) FROM tsales2 s2 JOIN tsales1 s1 ON s1.bukti_id=s2.bukti_id WHERE s1.tgl BETWEEN move_from AND move_to) as numeric(24,2));
INSERT INTO _guard SELECT 'wip020', cast(sum(isnull(debet,0)-isnull(kredit,0)) as numeric(24,2)) FROM gl_journal WHERE account_id='102-020';
INSERT INTO _guard SELECT 'hppwip', cast(sum(isnull(hpp,0)*isnull(qty,0)) as numeric(24,2)) FROM tsales1 s1 JOIN tsales2 s2 ON s1.bukti_id=s2.bukti_id WHERE s1.tipe_trans='88';
COMMIT;

-- STEP 2: MATERIALISASI engine closing prior (READ-ONLY; TIDAK menulis ke prior)
IF EXISTS(SELECT 1 FROM sys.systable WHERE table_name='_engine_dec') THEN DROP TABLE _engine_dec END IF;
CREATE TABLE _engine_dec (stok_id varchar(20) PRIMARY KEY, akhir numeric(18,2), nilai numeric(20,2));
INSERT INTO _engine_dec(stok_id,akhir) SELECT z.PRODUK_ID, z.AKHIR FROM ( $eng ) z WHERE z.PRODUK_ID IS NOT NULL;
UPDATE _engine_dec SET nilai=round(isnull(akhir,0)*isnull((SELECT hpp_avg FROM sinv WHERE stok_id=_engine_dec.stok_id AND periode=target_opening_period),0),2);
COMMIT;

-- STEP 3: PREVIEW item terdampak -- BACA & SETUJUI dulu
SELECT gr.persediaan akun, e.stok_id,
  cast(sv.qty as numeric(14,2)) qty_lama, cast(e.akhir as numeric(14,2)) qty_baru,
  cast(sv.nilai as numeric(20,2)) nilai_lama, cast(e.nilai as numeric(20,2)) nilai_baru,
  cast(sv.nilai-e.nilai as numeric(20,2)) phantom
FROM _engine_dec e JOIN sinv sv ON sv.stok_id=e.stok_id AND sv.periode=target_opening_period
JOIN im_produk pr ON pr.produk_id=e.stok_id JOIN im_product_group gr ON gr.kode_group=pr.group_product
WHERE abs(sv.nilai-e.nilai)>1 ORDER BY abs(sv.nilai-e.nilai) DESC;

-- STEP 3b: GUARD COVERAGE (harus keduanya 0/aman sebelum UPDATE)
SELECT 'sinv_not_in_engine(HARUS 0)' cek, count(*) n, cast(isnull(sum(isnull(sv.nilai,0)),0) as numeric(20,2)) nilai
  FROM sinv sv WHERE sv.periode=target_opening_period AND NOT EXISTS(SELECT 1 FROM _engine_dec e WHERE e.stok_id=sv.stok_id)
UNION ALL
SELECT 'engine_not_in_sinv(nilai HARUS 0)', count(*), cast(isnull(sum(isnull(e.nilai,0)),0) as numeric(20,2))
  FROM _engine_dec e WHERE NOT EXISTS(SELECT 1 FROM sinv sv WHERE sv.periode=target_opening_period AND sv.stok_id=e.stok_id);

-- STEP 4: KOREKSI SNAPSHOT OPENING -- SATU-SATUNYA penulisan ke tabel bisnis.
--   Scope terkunci: WHERE periode=target_opening_period. Set QTY & NILAI saja. HPP_AVG TIDAK disentuh.
UPDATE sinv SET qty=e.akhir, nilai=e.nilai FROM _engine_dec e
  WHERE sinv.stok_id=e.stok_id AND sinv.periode=target_opening_period;
COMMIT;
-- >>> LALU: evidence_scope_proof.sql (bukti hanya target berubah) + validation_guard2025.sql + evidence_4way_recon.sql
-- >>> LALU: recompute move-bulan berikut via Refresh normal (of_run ab_sinv_only) -- lihat RUNBOOK.

-- ROLLBACK:
-- UPDATE sinv SET qty=b.qty, nilai=b.nilai, hpp_avg=b.hpp_avg FROM _mekA_bak b
--   WHERE sinv.stok_id=b.stok_id AND sinv.periode=b.periode AND sinv.site_id=b.site_id; COMMIT;
"@

[System.IO.File]::WriteAllText("C:\BTV\debug\recovery_mekA_opening.sql", $sql, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("recovery_mekA_opening.sql (parameterized) dibuat: {0} bytes" -f (Get-Item "C:\BTV\debug\recovery_mekA_opening.sql").Length)
