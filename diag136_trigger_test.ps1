$conn=New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open(); $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=120
function Ex($s){ $cmd.CommandText=$s; return $cmd.ExecuteNonQuery() }
function Scalar($s){ $cmd.CommandText=$s; return $cmd.ExecuteScalar() }
function Quiet($s){ try{ $cmd.CommandText=$s; [void]$cmd.ExecuteNonQuery() }catch{ "  (info: "+$_.Exception.Message+")" } }

"=== 1. Buat trigger ==="
Quiet "DROP TRIGGER trg_eksp_fix"
$ddl = @"
CREATE TRIGGER trg_eksp_fix AFTER UPDATE OF biaya_ekspedisi ON tstok2
REFERENCING NEW AS n
FOR EACH ROW
BEGIN
   DECLARE v_target numeric(18,2);
   DECLARE v_base numeric(18,4);
   DECLARE v_cur numeric(18,2);
   IF (SELECT MAX(tipe_trans) FROM tstok1 WHERE bukti_id = n.bukti_id) = '05' THEN
      SET v_target = (SELECT isnull(ttl_kotor,0) FROM ap_trans WHERE order_client = n.bukti_id)
                   + (SELECT isnull(SUM(isnull(ttl_netto,0)+isnull(freight,0)),0) FROM ap_trans WHERE order_reff = n.bukti_id AND bukti_id <> n.bukti_id);
      SET v_base = (SELECT SUM(isnull(netto,0)) FROM tstok2 WHERE bukti_id = n.bukti_id);
      SET v_cur  = (SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id = n.bukti_id);
      IF v_base > 0 AND v_target > 0 AND ABS(v_cur - v_target) > 1 THEN
         UPDATE tstok2
            SET biaya_ekspedisi = round( (isnull(netto,0)/v_base) * v_target / (CASE WHEN isnull(qty,0)=0 THEN 1 ELSE qty END), 2)
            WHERE bukti_id = n.bukti_id;
      END IF;
   END IF;
END
"@
try{ [void](Ex $ddl); "  trigger dibuat OK" }catch{ "  GAGAL buat trigger: "+$_.Exception.Message }

"`n=== 2. Kondisi doc1 SEBELUM simulasi simpan ==="
"  tstok2_total = {0:N2}" -f [decimal](Scalar "SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id='10126040500001'")

"`n=== 3. SIMULASI 'Simpan' kode lama (set biaya_ekspedisi acak/salah) -> trigger harus koreksi ==="
[void](Ex "UPDATE tstok2 SET biaya_ekspedisi = round(biaya_ekspedisi*0.5,2) WHERE bukti_id='10126040500001'")
"  tstok2_total SESUDAH update+trigger = {0:N2}  (target 28.040.724)" -f [decimal](Scalar "SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id='10126040500001'")

"`n=== 4. Simulasi lagi dgn nilai beda (cek idempoten) ==="
[void](Ex "UPDATE tstok2 SET biaya_ekspedisi = 1 WHERE bukti_id='10126040500001'")
"  tstok2_total = {0:N2}" -f [decimal](Scalar "SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id='10126040500001'")

"`n=== 5. Cek doc2 tidak terganggu (belum di-update) ==="
"  doc2 tstok2_total = {0:N2}" -f [decimal](Scalar "SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id='10126040500002'")
$conn.Close()
