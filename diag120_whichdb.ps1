$ErrorActionPreference='Stop'
"=== DSN 'vsp' registry definition (32-bit) ==="
$paths = @(
 'HKLM:\SOFTWARE\WOW6432Node\ODBC\ODBC.INI\vsp',
 'HKCU:\SOFTWARE\ODBC\ODBC.INI\vsp',
 'HKLM:\SOFTWARE\ODBC\ODBC.INI\vsp'
)
foreach($p in $paths){
  if(Test-Path $p){ "--- $p ---"; (Get-ItemProperty $p).PSObject.Properties | Where-Object {$_.Name -notlike 'PS*'} | ForEach-Object { "{0} = {1}" -f $_.Name,$_.Value } }
}

"`n=== Runtime: server & database actually connected ==="
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open()
"ConnString DataSource = $($conn.DataSource)"
"Database (driver)     = $($conn.Database)"
"ServerVersion         = $($conn.ServerVersion)"
$cmd=$conn.CreateCommand(); $cmd.CommandTimeout=60
$q = @{
 'db_name()'                       = "SELECT db_name()"
 'ServerName'                      = "SELECT property('ServerName')"
 'MachineName(host)'               = "SELECT property('MachineName')"
 'TcpIpAddresses'                  = "SELECT property('TcpIpAddresses')"
 'DBFileName'                      = "SELECT db_property('File')"
 'CurrentTime'                     = "SELECT now(*)"
 'gl_journal rowcount'             = "SELECT COUNT(*) FROM gl_journal"
}
foreach($k in $q.Keys){ try{ $cmd.CommandText=$q[$k]; "{0,-22}= {1}" -f $k,$cmd.ExecuteScalar() }catch{ "{0,-22}= ERR {1}" -f $k,$_.Exception.Message } }
$conn.Close()
