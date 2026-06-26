$ErrorActionPreference='Stop'
$c = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
try{ $c.Open() }catch{ "OPEN FAIL => $($_.Exception.Message.Split([Environment]::NewLine)[0])"; exit }
$cmd=$c.CreateCommand(); $cmd.CommandTimeout=120
function Q($label,$q){
  "`n=== $label ==="
  try{ $cmd.CommandText=$q; $rd=$cmd.ExecuteReader(); $n=$rd.FieldCount
    $h=@(); for($i=0;$i -lt $n;$i++){ $h+=$rd.GetName($i) }; ($h -join ' | ')
    while($rd.Read()){ $v=@(); for($i=0;$i -lt $n;$i++){ $x=$rd.GetValue($i); if($x -is [DateTime]){$x=$x.ToString('yyyy-MM-dd')}; $v+=("$x").Trim() }; ($v -join ' | ') }
    $rd.Close()
  }catch{ "ERR $($_.Exception.Message.Split([Environment]::NewLine)[0])" }
}
Q "108-310 TOTAL (posted)" "select count(*) n, cast(sum(debet) as numeric(18,2)) debet, cast(sum(kredit) as numeric(18,2)) kredit, cast(sum(debet)-sum(kredit) as numeric(18,2)) saldo from gl_journal where account_id='108-310' and posting='P'"
Q "108-310 ledger lengkap" "select cast(tgl as date) tgl, voucher, modul_id, posting, cast(debet as numeric(18,2)) debet, cast(kredit as numeric(18,2)) kredit, ket from gl_journal where account_id='108-310' order by tgl, voucher"
$c.Close()
