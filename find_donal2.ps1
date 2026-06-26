$ErrorActionPreference='Stop'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open(); $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=300

# Tables related to payment / journal / cash-bank
$cmd.CommandText=@"
select distinct t.table_name
from systable t
where t.table_type='BASE'
and ( lower(t.table_name) like '%byr%' or lower(t.table_name) like '%bayar%'
   or lower(t.table_name) like '%journal%' or lower(t.table_name) like '%jurnal%'
   or lower(t.table_name) like '%kas%'   or lower(t.table_name) like '%bank%'
   or lower(t.table_name) like '%gl_%'   or lower(t.table_name) like '%transfer%'
   or lower(t.table_name) like '%voucher%' )
order by t.table_name
"@
$rd=$cmd.ExecuteReader(); $tabs=@()
while($rd.Read()){ $tabs += $rd.GetString(0) }
$rd.Close()
"=== candidate payment/journal tables ($($tabs.Count)) ==="
$tabs -join ', '

# char/varchar columns of those tables (name/desc/keterangan focus)
"`n=== text columns scanned per table ==="
foreach($t in $tabs){
  $cmd.CommandText="select cname from SYS.SYSCOLUMNS where tname='$t' and coltype in ('char','varchar')"
  $rd=$cmd.ExecuteReader(); $cols=@()
  while($rd.Read()){ $cols += $rd.GetString(0) }
  $rd.Close()
  foreach($c in $cols){
    try{
      $cmd.CommandText="select count(*) from `"$t`" where lower(`"$c`") like '%donal%'"
      $n=[int]$cmd.ExecuteScalar()
      if($n -gt 0){ "HIT  $t.$c = $n row(s)" }
    }catch{}
  }
}
$conn.Close()
"`n--- done ---"
