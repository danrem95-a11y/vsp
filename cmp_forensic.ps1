$csL = "DSN=vsp;UID=dba;PWD=jakarta"
$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$L = New-Object System.Data.Odbc.OdbcConnection $csL; $L.Open()
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Rows($cn,$sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql; $out=@(); $rd=$c.ExecuteReader(); while($rd.Read()){ $o=@{}; for($i=0;$i -lt $rd.FieldCount;$i++){$o[$rd.GetName($i)]=[string]$rd[$i]}; $out+=$o }; $rd.Close(); return $out }
function Scal($cn,$sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql; $v=$c.ExecuteScalar(); if($v -eq $null -or $v -is [DBNull]){return 0}; return $v }

Write-Host "=== A. Hitung 2025: LOKAL vs PROD ==="
Write-Host ("  tbyr1 2025   : lokal=" + (Scal $L "select count(*) from tbyr1 where tgl>='2025-01-01' and tgl<'2026-01-01'") + "  prod=" + (Scal $P "select count(*) from tbyr1 where tgl>='2025-01-01' and tgl<'2026-01-01'"))
Write-Host ("  gl_journal 25: lokal=" + (Scal $L "select count(*) from gl_journal where tgl>='2025-01-01' and tgl<'2026-01-01'") + "  prod=" + (Scal $P "select count(*) from gl_journal where tgl>='2025-01-01' and tgl<'2026-01-01'"))

Write-Host "`n=== B. DIFF tbyr1 2025: voucher ADA di lokal, HILANG di prod ==="
$prodV = @{}; foreach($r in (Rows $P "select voucher from tbyr1 where tgl>='2025-01-01' and tgl<'2026-01-01'")){ $prodV[$r.voucher]=1 }
$localRows = Rows $L "select t1.voucher, cast(t1.tgl as date) tgl, t1.vendor_id, t1.flag_vendor, cast(isnull((select sum(t2.nilai_bayar_idr) from tbyr2 t2 where t2.voucher=t1.voucher),0) as numeric(18,2)) nilai from tbyr1 t1 where t1.tgl>='2025-01-01' and t1.tgl<'2026-01-01'"
$missing = $localRows | Where-Object { -not $prodV.ContainsKey($_.voucher) }
Write-Host ("  Total voucher hilang di prod: " + ($missing.Count))
$sumAR = 0; $sumAP = 0
foreach($m in $missing){ if($m.flag_vendor -eq '1'){ $sumAR += [decimal]$m.nilai } else { $sumAP += [decimal]$m.nilai } }
Write-Host ("  Nilai hilang AR(flag_vendor=1): " + ('{0:N2}' -f $sumAR) + "   AP(lainnya): " + ('{0:N2}' -f $sumAP))
Write-Host "  -- Detail (maks 40) --"
$missing | Sort-Object { -[decimal]$_.nilai } | Select-Object -First 40 | ForEach-Object { Write-Host ("   " + $_.tgl + " | " + $_.voucher + " | vend=" + $_.vendor_id + " | fv=" + $_.flag_vendor + " | " + ('{0:N2}' -f [decimal]$_.nilai)) }
$L.Close(); $P.Close()
