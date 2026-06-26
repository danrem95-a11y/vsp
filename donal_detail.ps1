$ErrorActionPreference='Stop'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open(); $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=300

function Show($label,$q){
  "`n=== $label ==="
  try{
    $cmd.CommandText=$q
    $rd=$cmd.ExecuteReader()
    $cols=$rd.FieldCount
    $hdr=@(); for($i=0;$i -lt $cols;$i++){ $hdr+=$rd.GetName($i) }
    $hdr -join ' | '
    while($rd.Read()){
      $vals=@(); for($i=0;$i -lt $cols;$i++){ $v=$rd.GetValue($i); if($v -is [DateTime]){$v=$v.ToString('yyyy-MM-dd')}; $vals+=("$v").Trim() }
      $vals -join ' | '
    }
    $rd.Close()
  }catch{ "ERR $($_.Exception.Message.Split([Environment]::NewLine)[0])" }
}

# 1) the Donal account(s)
Show "gl_acc - akun Donal" "select Account, AccountDes from gl_acc where lower(AccountDes) like '%donal%'"

# 2) columns of gl_journal
Show "gl_journal columns" "select cname, coltype from SYS.SYSCOLUMNS where tname='gl_journal' order by colno"

$conn.Close()
