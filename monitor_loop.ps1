$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$log = "C:\BTV\debug\refresh_monitor_log.txt"
function Scal($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=60; $c.CommandText=$sql; try{$v=$c.ExecuteScalar(); if($v -eq $null -or $v -is [DBNull]){return ''}; return [string]$v}catch{return 'ERR'} }
$start = Get-Date
"### START POLL "+($start.ToString('HH:mm:ss'))+" ###" | Tee-Object -FilePath $log
$idle = 0; $sawTsales2 = $false
for($k=0; $k -lt 30; $k++){
  $ts = (Get-Date).ToString('HH:mm:ss')
  $big  = Scal "select count(*) from sa_locks() where table_name in ('DBA.SINV','DBA.TSTOK1','DBA.TSTOK2','DBA.TSALES1','DBA.TSALES2','DBA.GL_JOURNAL')"
  $tabs = Scal "select list(distinct replace(table_name,'DBA.','')) from sa_locks() where table_name is not null"
  $sinvJ= Scal "select count(*) from sinv where periode='2026-07-01'"
  if($tabs -match 'TSALES2'){ $sawTsales2 = $true }
  $line = "  $ts | lockStok=$big | tabel=[$tabs] | sinvJul=$sinvJ"
  $line | Tee-Object -FilePath $log -Append
  if($big -eq '0'){ $idle++ } else { $idle = 0 }
  if($idle -ge 2){ ("  >>> SELESAI: lock stok lepas 2x. Durasi poll: "+([int]((Get-Date)-$start).TotalMinutes)+" mnt. TSALES2/closing terlihat="+$sawTsales2) | Tee-Object -FilePath $log -Append; break }
  Start-Sleep -Seconds 40
}
if($k -ge 30){ "  >>> STOP: batas 20 mnt tercapai (refresh mungkin masih jalan)." | Tee-Object -FilePath $log -Append }
$cn.Close()
