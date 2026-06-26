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

Show "gl_acc columns" "select cname,coltype from SYS.SYSCOLUMNS where tname='gl_acc' order by colno"
Show "akun Donal (gl_acc)" "select * from gl_acc where lower(AccountDes) like '%donal%'"
Show "26 jurnal ket~donal (ringkas)" "select voucher,tgl,account_id,debet,kredit,posting,modul_id,ket from gl_journal where lower(ket) like '%donal%' order by tgl"
$conn.Close()
