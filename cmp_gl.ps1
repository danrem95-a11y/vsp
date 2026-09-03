$csL = "DSN=vsp;UID=dba;PWD=jakarta"
$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$L = New-Object System.Data.Odbc.OdbcConnection $csL; $L.Open()
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Map($cn,$sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql; $m=@{}; $rd=$c.ExecuteReader(); while($rd.Read()){ $m[[string]$rd[0]]=(""+$rd[1]+"|"+$rd[2]+"|"+$rd[3]) }; $rd.Close(); return $m }

$sqlMonth = "select month(tgl) bln, count(*) n, cast(sum(debet) as numeric(18,2)) db, cast(sum(kredit) as numeric(18,2)) kr from gl_journal where posting='P' and tgl>='2025-01-01' and tgl<'2026-01-01' group by month(tgl)"
Write-Host "=== GL_JOURNAL 2025 per bulan: LOKAL vs PROD ==="
$ml = Map $L $sqlMonth; $mp = Map $P $sqlMonth
Write-Host ("  {0,-4} {1,-34} {2,-34} {3}" -f 'Bln','LOKAL (n|debet|kredit)','PROD (n|debet|kredit)','MATCH?')
foreach($b in 1..12){ $k="$b"; $lv=if($ml.ContainsKey($k)){$ml[$k]}else{'-'}; $pv=if($mp.ContainsKey($k)){$mp[$k]}else{'-'}; $ok=if($lv -eq $pv){'OK'}else{'*** BEDA ***'}; Write-Host ("  {0,-4} {1,-34} {2,-34} {3}" -f $b,$lv,$pv,$ok) }

# Trial balance 2025 per akun - cari akun yg beda (indikasi GL terhapus)
Write-Host "`n=== Akun dgn NET 2025 beda (lokal vs prod) - top indikasi ==="
$sqlAcc = "select account_id, cast(sum(debet)-sum(kredit) as numeric(18,2)) net from gl_journal where posting='P' and tgl>='2025-01-01' and tgl<'2026-01-01' group by account_id"
$al = Map $L ($sqlAcc -replace 'count\(\*\) n, ',''); # reuse Map: key=account, val=net (only 2 cols -> adjust)
$c=$L.CreateCommand(); $c.CommandText=$sqlAcc; $c.CommandTimeout=400; $la=@{}; $rd=$c.ExecuteReader(); while($rd.Read()){$la[[string]$rd[0]]=[decimal]$rd[1]}; $rd.Close()
$c=$P.CreateCommand(); $c.CommandText=$sqlAcc; $c.CommandTimeout=400; $pa=@{}; $rd=$c.ExecuteReader(); while($rd.Read()){$pa[[string]$rd[0]]=[decimal]$rd[1]}; $rd.Close()
$keys = ($la.Keys + $pa.Keys) | Sort-Object -Unique
$diffCount=0
foreach($k in $keys){ $lv=if($la.ContainsKey($k)){$la[$k]}else{0}; $pv=if($pa.ContainsKey($k)){$pa[$k]}else{0}; if([math]::Abs($lv-$pv) -gt 1){ $diffCount++; Write-Host ("   akun $k : lokal="+('{0:N2}' -f $lv)+"  prod="+('{0:N2}' -f $pv)+"  selisih="+('{0:N2}' -f ($lv-$pv))) } }
if($diffCount -eq 0){ Write-Host "   (tak ada akun berbeda -> GL 2025 identik lokal=prod)" }
$L.Close(); $P.Close()
