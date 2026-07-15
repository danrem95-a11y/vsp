-- =====================================================================
-- RUNBOOK FA: (A) Rebuild opening 2026 dari Excel + (B) Fitur Disposal
-- DB produksi vspnew, site 101. Jalankan di Interactive SQL / dbisql,
-- URUT dari atas, saat aplikasi DITUTUP (ada DDL + DELETE massal).
-- Prasyarat: fa_asset_rebuild.sql ada di C:\BTV\debug (287 INSERT).
-- =====================================================================

-- =========================== BACKUP =================================
IF NOT EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='fa_bkp_asset_20260714') THEN
  EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_asset_20260714     FROM FA_ASSET        WHERE site_id=''101''';
  EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_depr2_20260714     FROM FA_DEPRECIATION WHERE site_id=''101''';
  EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_period_20260714    FROM FA_PERIOD       WHERE site_id=''101''';
  EXECUTE IMMEDIATE 'SELECT * INTO fa_bkp_gl2_20260714       FROM gl_journal      WHERE modul_id=''FA'' AND voucher LIKE ''FA101202%''';
END IF;
COMMIT;

-- ============ A. REBUILD OPENING FA_ASSET DARI EXCEL (287 aset) ======
-- Hapus penyusutan + periode + jurnal FA + master lama (site 101).
-- (History pra-2026 tidak ada di modul; opening murni dari Excel.)
DELETE FROM gl_journal      WHERE modul_id='FA' AND voucher LIKE 'FA101202%';
DELETE FROM FA_DEPRECIATION WHERE site_id='101';
DELETE FROM FA_PERIOD       WHERE site_id='101';
DELETE FROM FA_ASSET        WHERE site_id='101';
COMMIT;

-- Insert 287 aset dari Excel (kode urut tanggal, opening balance benar):
READ "C:\\BTV\\debug\\fa_asset_rebuild.sql";
-- Pertahankan 9 aset KDR riil yg TIDAK ada di Excel (KDR-0023..0031). JANGAN dihapus.
-- Yg sudah dijual/rusak dikeluarkan lewat DISPOSAL (blok B4 di bawah), bukan delete.
READ "C:\\BTV\\debug\\fa_asset_preserve_kdr.sql";
COMMIT;

-- Regenerate + posting penyusutan Jan-Jun 2026 (engine residu sudah dipasang di
-- RUNBOOK_FA_refinement / fa_07b; pastikan sp_fa_generate_sl versi residu terpasang):
CALL sp_fa_regenerate_period('2026-01-31','101');  CALL sp_fa_build_gl_link('2026-01-31','101');
CALL sp_fa_regenerate_period('2026-02-28','101');  CALL sp_fa_build_gl_link('2026-02-28','101');
CALL sp_fa_regenerate_period('2026-03-31','101');  CALL sp_fa_build_gl_link('2026-03-31','101');
CALL sp_fa_regenerate_period('2026-04-30','101');  CALL sp_fa_build_gl_link('2026-04-30','101');
CALL sp_fa_regenerate_period('2026-05-31','101');  CALL sp_fa_build_gl_link('2026-05-31','101');
CALL sp_fa_regenerate_period('2026-06-30','101');  CALL sp_fa_build_gl_link('2026-06-30','101');
COMMIT;

-- ============ B. FITUR DISPOSAL / PELEPASAN AKTIVA ===================
-- B1. Tabel arsip disposal (audit trail; TANPA hard delete history):
IF NOT EXISTS(SELECT 1 FROM SYS.SYSTABLE WHERE table_name='FA_DISPOSAL') THEN
  EXECUTE IMMEDIATE '
   CREATE TABLE FA_DISPOSAL (
     site_id          varchar(4)  NOT NULL,
     disposal_no      varchar(20) NOT NULL,
     asset_code       varchar(20) NOT NULL,
     disposal_date    date        NOT NULL,
     disposal_type    varchar(10) NOT NULL,
     acquisition_cost numeric(18,2),
     accum_dep        numeric(18,2),
     book_value       numeric(18,2),
     proceeds         numeric(18,2) DEFAULT 0,
     gain_loss        numeric(18,2),
     journal_no       varchar(15),
     reason           varchar(200),
     disposed_by      varchar(30),
     created_date     timestamp DEFAULT CURRENT TIMESTAMP,
     PRIMARY KEY (site_id, disposal_no))';
  EXECUTE IMMEDIATE 'CREATE INDEX ix_fa_disposal_asset ON FA_DISPOSAL(site_id, asset_code)';
END IF;
COMMIT;

-- B2. Proc disposal. Param: aset, tgl, jenis(RUSAK/DIJUAL/TDKPAKAI/HIBAH),
--     proceeds(hasil jual, 0 bila rusak), alasan, akun Kas/Bank, akun Rugi, akun Laba.
--     COA existing (site 101): Rugi = 500-014 'Rugi Penjualan Aktiva' ; Laba = 500-004 'Laba Penjualan Aktiva'.
--     Bila p_loss_acc/p_gain_acc kosong/NULL -> default ke 500-014 / 500-004.
--     Jurnal: Dr Akum + Dr Kas + (Dr Rugi / Cr Laba) + Cr Aktiva. Balance dijamin.
IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE p JOIN SYS.SYSUSERPERM u ON p.creator=u.user_id WHERE u.user_name='DBA' AND p.proc_name='sp_fa_dispose')
   THEN DROP PROCEDURE sp_fa_dispose END IF;
CREATE PROCEDURE sp_fa_dispose(IN p_site varchar(4), IN p_asset varchar(20), IN p_date date,
  IN p_type varchar(10), IN p_proceeds numeric(18,2), IN p_reason varchar(200),
  IN p_cash_acc varchar(15), IN p_loss_acc varchar(15), IN p_gain_acc varchar(15))
BEGIN
  DECLARE v_cost numeric(18,2); DECLARE v_accum numeric(18,2); DECLARE v_nbv numeric(18,2);
  DECLARE v_aa varchar(15); DECLARE v_da varchar(15); DECLARE v_gl numeric(18,2);
  DECLARE v_seq int; DECLARE v_no varchar(20); DECLARE v_u int; DECLARE v_pref varchar(20);
  DECLARE v_loss varchar(15); DECLARE v_gain varchar(15);
  SET v_loss = COALESCE(NULLIF(p_loss_acc,''),'500-014');
  SET v_gain = COALESCE(NULLIF(p_gain_acc,''),'500-004');
  IF EXISTS(SELECT 1 FROM FA_ASSET WHERE site_id=p_site AND asset_code=p_asset AND status='D') THEN
     RAISERROR 18001 'Aset sudah disposal'; RETURN;
  END IF;
  SELECT a.acquisition_cost, a.asset_account, a.accum_dep_account,
         a.accum_dep_beginning + COALESCE((SELECT SUM(d.depreciation_amount) FROM FA_DEPRECIATION d
            WHERE d.site_id=a.site_id AND d.asset_code=a.asset_code AND d.period<=p_date),0)
    INTO v_cost, v_aa, v_da, v_accum
    FROM FA_ASSET a WHERE a.site_id=p_site AND a.asset_code=p_asset;
  SET v_nbv = v_cost - v_accum;
  SET v_gl  = COALESCE(p_proceeds,0) - v_nbv;   -- >0 laba, <0 rugi
  SET v_pref = 'DSP'||p_site||CAST(YEAR(p_date) AS varchar)||RIGHT('0'||CAST(MONTH(p_date) AS varchar),2);
  SELECT COALESCE(MAX(CAST(RIGHT(disposal_no,4) AS int)),0)+1 INTO v_seq
    FROM FA_DISPOSAL WHERE site_id=p_site AND disposal_no LIKE v_pref||'%';
  SET v_no = v_pref||'-'||RIGHT('000'||CAST(v_seq AS varchar),4);
  SET v_u = 0;
  IF v_accum <> 0 AND v_da IS NOT NULL THEN
    SET v_u=v_u+1;
    INSERT INTO gl_journal(voucher,urut,site_id,tgl,modul_id,account_id,debet,kredit,debet_kurs,kredit_kurs,curr_id,rate_rp,posting,voucher_manual,dk,ket)
    VALUES(v_no,v_u,p_site,p_date,'FA',v_da,v_accum,0,v_accum,0,'IDR',1,'N',v_no,'D','Disposal - Akum Peny '||p_asset);
  END IF;
  IF COALESCE(p_proceeds,0) > 0 THEN
    SET v_u=v_u+1;
    INSERT INTO gl_journal(voucher,urut,site_id,tgl,modul_id,account_id,debet,kredit,debet_kurs,kredit_kurs,curr_id,rate_rp,posting,voucher_manual,dk,ket)
    VALUES(v_no,v_u,p_site,p_date,'FA',p_cash_acc,p_proceeds,0,p_proceeds,0,'IDR',1,'N',v_no,'D','Disposal - Hasil Jual '||p_asset);
  END IF;
  IF v_gl < 0 THEN
    SET v_u=v_u+1;
    INSERT INTO gl_journal(voucher,urut,site_id,tgl,modul_id,account_id,debet,kredit,debet_kurs,kredit_kurs,curr_id,rate_rp,posting,voucher_manual,dk,ket)
    VALUES(v_no,v_u,p_site,p_date,'FA',v_loss,-v_gl,0,-v_gl,0,'IDR',1,'N',v_no,'D','Disposal - Rugi Pelepasan '||p_asset);
  ELSEIF v_gl > 0 THEN
    SET v_u=v_u+1;
    INSERT INTO gl_journal(voucher,urut,site_id,tgl,modul_id,account_id,debet,kredit,debet_kurs,kredit_kurs,curr_id,rate_rp,posting,voucher_manual,dk,ket)
    VALUES(v_no,v_u,p_site,p_date,'FA',v_gain,0,v_gl,0,v_gl,'IDR',1,'N',v_no,'K','Disposal - Laba Pelepasan '||p_asset);
  END IF;
  SET v_u=v_u+1;
  INSERT INTO gl_journal(voucher,urut,site_id,tgl,modul_id,account_id,debet,kredit,debet_kurs,kredit_kurs,curr_id,rate_rp,posting,voucher_manual,dk,ket)
  VALUES(v_no,v_u,p_site,p_date,'FA',v_aa,0,v_cost,0,v_cost,'IDR',1,'N',v_no,'K','Disposal - Aktiva '||p_asset);
  INSERT INTO FA_DISPOSAL(site_id,disposal_no,asset_code,disposal_date,disposal_type,acquisition_cost,accum_dep,book_value,proceeds,gain_loss,journal_no,reason,disposed_by,created_date)
  VALUES(p_site,v_no,p_asset,p_date,p_type,v_cost,v_accum,v_nbv,COALESCE(p_proceeds,0),v_gl,v_no,p_reason,CURRENT USER,CURRENT TIMESTAMP);
  UPDATE FA_ASSET SET status='D', disposal_date=p_date, updated_by=CURRENT USER, updated_date=CURRENT TIMESTAMP,
         remarks=COALESCE(remarks,'')||' [DISPOSAL '||p_type||' '||CAST(p_date AS varchar)||' '||v_no||']'
   WHERE site_id=p_site AND asset_code=p_asset;
  COMMIT;
EXCEPTION WHEN OTHERS THEN ROLLBACK; RESIGNAL;
END;

-- B3. Batal disposal (reversal sebelum closing): hapus jurnal DSP + arsip, status kembali.
IF EXISTS(SELECT 1 FROM SYS.SYSPROCEDURE p JOIN SYS.SYSUSERPERM u ON p.creator=u.user_id WHERE u.user_name='DBA' AND p.proc_name='sp_fa_dispose_cancel')
   THEN DROP PROCEDURE sp_fa_dispose_cancel END IF;
CREATE PROCEDURE sp_fa_dispose_cancel(IN p_site varchar(4), IN p_disposal_no varchar(20))
BEGIN
  DECLARE v_asset varchar(20); DECLARE v_nbv numeric(18,2);
  SELECT asset_code, book_value INTO v_asset, v_nbv FROM FA_DISPOSAL WHERE site_id=p_site AND disposal_no=p_disposal_no;
  DELETE FROM gl_journal  WHERE site_id=p_site AND voucher=p_disposal_no AND modul_id='FA';
  DELETE FROM FA_DISPOSAL WHERE site_id=p_site AND disposal_no=p_disposal_no;
  UPDATE FA_ASSET SET status=(CASE WHEN v_nbv<=0.005 THEN 'F' ELSE 'A' END), disposal_date=NULL,
         updated_by=CURRENT USER, updated_date=CURRENT TIMESTAMP
   WHERE site_id=p_site AND asset_code=v_asset;
  COMMIT;
EXCEPTION WHEN OTHERS THEN ROLLBACK; RESIGNAL;
END;

-- CATATAN AKUN (sudah dikonfirmasi ada di gl_acc site 101):
--   Rugi Pelepasan = 500-014 'Rugi Penjualan Aktiva'  (default p_loss_acc)
--   Laba Pelepasan = 500-004 'Laba Penjualan Aktiva'  (default p_gain_acc)
--   p_cash_acc = akun Kas/Bank/Piutang tujuan hasil jual (isi hanya bila DIJUAL).
-- Contoh panggilan: call sp_fa_dispose('101','KDR-0005','2026-07-31','RUSAK',0,'Rusak total','', '500-014','500-004');

-- ---------- B4. DISPOSAL 9 aset KDR yg sudah dijual/rusak (OPSIONAL) ----------
-- Keputusan: aset yg BENAR-BENAR sudah dijual/rusak dikeluarkan lewat disposal (bukan delete),
-- sisanya tetap aktif. Kode preserve: KDR-0023..0031 (lihat fa_asset_preserve_kdr.sql).
--   KDR-0023 Kijang B2203 SY(A)  KDR-0024 Avanza B.1880(A)  KDR-0025 Avanza B.1468(A)
--   KDR-0026 Avanza B.1469(A)    KDR-0027 Veloz B.1024(F,NBV0)  KDR-0028 Avanza B1023(F,NBV0)
--   KDR-0029 Avanza B1002(F,NBV0) KDR-0030 Veloz B.1541(A)     KDR-0031 Camry 2015(A)
-- Kandidat kuat (habis susut/lama): KDR-0027, KDR-0028, KDR-0029. Aktifkan HANYA yg memang sudah keluar.
-- Bila DIJUAL isi proceeds + akun kas/bank; bila RUSAK/dibuang proceeds 0.
-- Jalankan SETELAH regenerate Jan-Jun (accum s/d bln disposal sudah ada).
--
-- call sp_fa_dispose('101','KDR-0027','2026-06-30','TDKPAKAI',0,'Avanza lama tdk dipakai','','500-014','500-004');
-- call sp_fa_dispose('101','KDR-0028','2026-06-30','DIJUAL',35000000,'Jual bekas','101-xxx','500-014','500-004');
-- commit;
-- (atau lakukan interaktif lewat window w_fa_disposal setelah EXE di-build.)

-- =========================== VERIFIKASI =============================
SELECT category_code, COUNT(*) n, ROUND(SUM(acquisition_cost),0) harga,
       ROUND(SUM(accum_dep_beginning),0) akum_awal, ROUND(SUM(book_value_beginning),0) nbv_awal
  FROM FA_ASSET WHERE site_id='101' AND status<>'D' GROUP BY category_code ORDER BY category_code;
-- Harapan: TNH 11/17.934.062.500 ; BGN 38/3.712.136.932 ; PBK 38/221.324.363 ; PKT 178/950.446.516 ;
--   KDR 31/6.974.040.958 (=22 Excel 5.223.064.476 + 9 preserve 1.750.976.482) ; TOTAL 296 aset.
SELECT period, COUNT(*) n, ROUND(SUM(depreciation_amount),2) tot FROM FA_DEPRECIATION WHERE site_id='101' GROUP BY period ORDER BY period;
SELECT voucher, SUM(debet) dr, SUM(kredit) kr, SUM(debet)-SUM(kredit) selisih FROM gl_journal WHERE modul_id='FA' AND voucher LIKE 'FA101202%' GROUP BY voucher ORDER BY voucher;

-- =========================== ROLLBACK ==============================
-- DELETE FROM FA_DEPRECIATION WHERE site_id='101'; DELETE FROM FA_ASSET WHERE site_id='101';
-- INSERT INTO FA_ASSET SELECT * FROM fa_bkp_asset_20260714;
-- INSERT INTO FA_DEPRECIATION SELECT * FROM fa_bkp_depr2_20260714;
-- DELETE FROM gl_journal WHERE modul_id='FA' AND voucher LIKE 'FA101202%';
-- INSERT INTO gl_journal SELECT * FROM fa_bkp_gl2_20260714;
-- DELETE FROM FA_PERIOD WHERE site_id='101'; INSERT INTO FA_PERIOD SELECT * FROM fa_bkp_period_20260714;
-- COMMIT;
