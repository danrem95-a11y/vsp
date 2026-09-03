$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Time($lbl,$sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$sql; $sw=[System.Diagnostics.Stopwatch]::StartNew()
  try{$rd=$c.ExecuteReader(); $rows=0; while($rd.Read()){$rows++}; $rd.Close(); $sw.Stop(); Write-Host ("  {0,-48} {1,8} baris  {2,8:N2} dtk" -f $lbl,$rows,($sw.Elapsed.TotalSeconds))}catch{$sw.Stop(); Write-Host("  $lbl ERR("+([int]$sw.Elapsed.TotalSeconds)+"s): "+$_.Exception.Message)} }
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "5. INDEX (SYS.SYSINDEXES) pada tabel closing" @"
select tname, iname, indextype, colnames from SYS.SYSINDEXES where tname in ('tsales1','tsales2','tstok1','tstok2','sinv') order by tname, iname
"@

Write-Host "== 3. EVAP subquery unbounded - RUN 2x (cek cache) =="
Time "3a. EVAP unbounded (run-1)" "select b.stok_id, isnull(b.evap,'') ev, avg(isnull(b.hpp,0)) hpp from tsales1 a, tsales2 b where a.bukti_id=b.bukti_id and a.tipe_trans='88' group by b.stok_id, isnull(b.evap,'')"
Time "3a. EVAP unbounded (run-2 warm)" "select b.stok_id, isnull(b.evap,'') ev, avg(isnull(b.hpp,0)) hpp from tsales1 a, tsales2 b where a.bukti_id=b.bukti_id and a.tipe_trans='88' group by b.stok_id, isnull(b.evap,'')"

# --- ekstrak retrieve dw_refresh_stok ---
$b=[System.IO.File]::ReadAllBytes("C:\BTV\debug\dw_refresh_stok.srd")
$t=[System.Text.Encoding]::Unicode.GetString($b)
$m=[regex]::Match($t,'(?s)retrieve="(.*?)"\s*(arguments|update=|\)\s*$|\r?\n\s*(text|column|compute)\()')
if($m.Success){
  $sql=$m.Groups[1].Value
  # cari argument tokens :xxx
  $toks=[regex]::Matches($sql,':([A-Za-z_][A-Za-z0-9_]*)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
  Write-Host "== ARGUMEN retrieve dw_refresh_stok (token :xxx) =="
  Write-Host ("  " + ($toks -join ", "))
  # substitusi utk Juni: asumsi 2 arg tanggal (tgl1, tgl2)
  $sqlJun=$sql
  foreach($tk in $toks){
    if($tk -match '2' -or $tk -match 'eom' -or $tk -match 'akhir' -or $tk -match 'sampai'){ $sqlJun=$sqlJun -replace (":"+$tk+"\b"),"'2026-06-30'" }
    else { $sqlJun=$sqlJun -replace (":"+$tk+"\b"),"'2026-06-01'" }
  }
  [System.IO.File]::WriteAllText("C:\BTV\debug\_retr_refresh_stok.sql",$sql)
  Write-Host "== TIMING retrieve dw_refresh_stok (Juni) =="
  Time "1. retrieve dw_refresh_stok (Jun)" $sqlJun
} else { Write-Host "GAGAL ekstrak retrieve" }
$cn.Close()
