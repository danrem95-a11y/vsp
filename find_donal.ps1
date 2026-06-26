$ErrorActionPreference='Stop'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open(); $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=300

"=== Server ==="
"ServerVersion = $($conn.ServerVersion)"

# 1) gather char/varchar columns whose name looks like a name/description/keterangan
$cmd.CommandText=@"
select tname, cname from SYS.SYSCOLUMNS
where coltype in ('char','varchar')
and ( lower(cname) like '%nam%' or lower(cname) like '%desc%'
   or lower(cname) like '%ket%' or lower(cname) like '%uraian%'
   or lower(cname) like '%note%' or lower(cname) like '%memo%' )
order by tname, cname
"@
$rd=$cmd.ExecuteReader()
$pairs=@()
while($rd.Read()){ $pairs += ,@($rd.GetString(0),$rd.GetString(1)) }
$rd.Close()
"`nScanning $($pairs.Count) name/desc columns for 'donal'...`n"

foreach($p in $pairs){
  $t=$p[0]; $c=$p[1]
  try{
    $cmd.CommandText="select count(*) from `"$t`" where lower(`"$c`") like '%donal%'"
    $n=[int]$cmd.ExecuteScalar()
    if($n -gt 0){ "HIT  $t.$c  = $n row(s)" }
  }catch{ "skip $t.$c => $($_.Exception.Message.Split([Environment]::NewLine)[0])" }
}
$conn.Close()
"`n--- done ---"
