$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Cols($t){ $c=$cn.GetSchema("Columns",@($null,$null,$t,$null)); $n=@(); foreach($r in ($c.Rows|Sort-Object {[int]$_["ORDINAL_POSITION"]})){ $n+=$r["COLUMN_NAME"] }; Write-Host ("  "+$t+": "+($n -join ", ")) }
function Qry($s){$c=$cn.CreateCommand();$c.CommandTimeout=120;$c.CommandText=$s;$rd=$c.ExecuteReader();while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("   "+($l -join " | "))};$rd.Close()}
Write-Host "=== kolom tabel invoice & payment ==="
Cols "TSALES1"; Cols "TSTOK1"; Cols "trace_ar1"; Cols "trace_ap1"; Cols "TDP"
Write-Host "=== tabel mengandung 'dp' / 'nota' / 'retur' / 'bayar' ==="
$t=$cn.GetSchema("Tables"); foreach($r in $t.Rows){ if($r["TABLE_TYPE"] -eq "TABLE"){ $nm=[string]$r["TABLE_NAME"]; if($nm -match '(?i)^tdp|nota|retur|tbayar|bayar_|_bayar|tpay'){ Write-Host ("  "+$nm) } } }
Write-Host "=== TINKASO2.bukti_id nyambung ke TSALES1.bukti_id? (sample) ==="
Qry "select top 3 k.bukti_id, cast(k.nilai as numeric(18,2)) nilai, s.cust_id, s.tipe_trans, cast(s.ttl_netto as numeric(18,2)) ttl_netto from TINKASO2 k, TSALES1 s where k.bukti_id=s.bukti_id"
$cn.Close()
