$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$log = "C:\BTV\debug\refresh_monitor_log2.txt"
function Scal($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=60; $c.CommandText=$sql; try{$v=$c.ExecuteScalar(); if($v -eq $null -or $v -is [DBNull]){return ''}; return [string]$v}catch{return 'ERR'} }
$start=Get-Date
("### START POLL2 "+$start.ToString('HH:mm:ss')+" ###") | Tee-Object -FilePath $log
$zero=0
for($k=0;$k -lt 45;$k++){
  $ts=(Get-Date).ToString('HH:mm:ss')
  $locks = Scal "select count(*) from sa_locks() where table_name is not null and table_name<>'DBA.CABANG_SECURITY'"
  $tabs  = Scal "select list(distinct replace(table_name,'DBA.','')) from sa_locks() where table_name is not null and table_name<>'DBA.CABANG_SECURITY'"
  $busy  = Scal "select min(connection_property('LastIdle',number)) from sa_conn_info() where number>1 and connection_property('LastIdle',number)>0"
  ("  $ts | lockData=$locks | minIdle=$busy | tabel=[$tabs]") | Tee-Object -FilePath $log -Append
  if($locks -eq '0'){ $zero++ } else { $zero=0 }
  if($zero -ge 3){ ("  >>> REFRESH SELESAI ~"+$ts+" | total "+[int]((Get-Date)-$start).TotalMinutes+" mnt sejak poll2") | Tee-Object -FilePath $log -Append; break }
  Start-Sleep -Seconds 40
}
if($k -ge 45){ "  >>> STOP: batas 30 mnt (masih jalan?)" | Tee-Object -FilePath $log -Append }
$cn.Close()
