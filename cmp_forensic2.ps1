$csL = "DSN=vsp;UID=dba;PWD=jakarta"
$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$L = New-Object System.Data.Odbc.OdbcConnection $csL; $L.Open()
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Rows($cn,$sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql; $out=@(); $rd=$c.ExecuteReader(); while($rd.Read()){ $o=@{}; for($i=0;$i -lt $rd.FieldCount;$i++){$o[$rd.GetName($i)]=[string]$rd[$i]}; $out+=$o }; $rd.Close(); return $out }

Write-Host "=== A. DIRECT: voucher 25112004R117R & 25122004R009R di PROD ==="
Write-Host "  -- PROD tbyr1 --"
Rows $P "select voucher, cast(tgl as date) tgl, vendor_id from tbyr1 where voucher in ('25112004R117R','25122004R009R')" | ForEach-Object { Write-Host ("    "+$_.voucher+" | "+$_.tgl+" | "+$_.vendor_id) }
Write-Host "  -- PROD tbyr2 (alokasi) --"
Rows $P "select voucher, bukti_id, urut, cast(nilai_bayar_idr as numeric(18,2)) nb from tbyr2 where voucher in ('25112004R117R','25122004R009R')" | ForEach-Object { Write-Host ("    "+$_.voucher+" | bukti="+$_.bukti_id+" | urut="+$_.urut+" | "+$_.nb) }
Write-Host "  -- LOKAL tbyr2 (pembanding) --"
Rows $L "select voucher, bukti_id, urut, cast(nilai_bayar_idr as numeric(18,2)) nb from tbyr2 where voucher in ('25112004R117R','25122004R009R')" | ForEach-Object { Write-Host ("    "+$_.voucher+" | bukti="+$_.bukti_id+" | urut="+$_.urut+" | "+$_.nb) }

Write-Host "`n=== B. DIFF tbyr2 2025 (key voucher|bukti|urut) : ADA di lokal HILANG di prod ==="
$q = "select t1.voucher+'|'+t2.bukti_id+'|'+cast(t2.urut as varchar(4)) k, cast(t1.tgl as date) tgl, t1.vendor_id, t2.bukti_id, cast(t2.nilai_bayar_idr as numeric(18,2)) nb from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher where t1.tgl>='2025-01-01' and t1.tgl<'2026-01-01'"
$prodK = @{}; foreach($r in (Rows $P $q)){ $prodK[$r.k]=1 }
$localR = Rows $L $q
$miss = $localR | Where-Object { -not $prodK.ContainsKey($_.k) }
Write-Host ("  Alokasi tbyr2 2025 ADA di lokal, HILANG di prod: " + ($miss.Count))
$tot = 0; foreach($m in $miss){ $tot += [decimal]$m.nb }
Write-Host ("  Total nilai: " + ('{0:N2}' -f $tot))
$miss | Sort-Object { -[decimal]$_.nb } | Select-Object -First 40 | ForEach-Object { Write-Host ("   "+$_.tgl+" | "+$_.k+" | vend="+$_.vendor_id+" | "+('{0:N2}' -f [decimal]$_.nb)) }
$L.Close(); $P.Close()
