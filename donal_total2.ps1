$ErrorActionPreference='Stop'
function RunQ($label,$q){
  "`n=== $label ==="
  $c = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
  try{
    $c.Open(); $cmd=$c.CreateCommand(); $cmd.CommandTimeout=300; $cmd.CommandText=$q
    $rd=$cmd.ExecuteReader(); $n=$rd.FieldCount
    $hdr=@(); for($i=0;$i -lt $n;$i++){ $hdr+=$rd.GetName($i) }; ($hdr -join ' | ')
    while($rd.Read()){ $v=@(); for($i=0;$i -lt $n;$i++){ $x=$rd.GetValue($i); if($x -is [DateTime]){$x=$x.ToString('yyyy-MM-dd')}; $v+=("$x").Trim() }; ($v -join ' | ') }
    $rd.Close()
  }catch{ "ERR $($_.Exception.Message.Split([Environment]::NewLine)[0])" }
  finally{ $c.Close() }
}

RunQ "108-310 TOTAL posted (transfer ke Donal vs bayar balik)" "select count(*) n, cast(sum(debet) as numeric(18,2)) debet_transfer_ke_donal, cast(sum(kredit) as numeric(18,2)) kredit_bayar_balik, cast(sum(debet)-sum(kredit) as numeric(18,2)) saldo_net from gl_journal where account_id='108-310' and posting='P'"

RunQ "108-310 per posting flag" "select posting, count(*) n, cast(sum(debet) as numeric(18,2)) debet, cast(sum(kredit) as numeric(18,2)) kredit from gl_journal where account_id='108-310' group by posting"

RunQ "108-310 rentang tanggal (posted)" "select cast(min(tgl) as date) tgl_awal, cast(max(tgl) as date) tgl_akhir from gl_journal where account_id='108-310' and posting='P'"

RunQ "Buku besar 108-310 (semua)" "select cast(tgl as date) tgl, voucher, modul_id, posting, cast(debet as numeric(18,2)) debet, cast(kredit as numeric(18,2)) kredit, ket from gl_journal where account_id='108-310' order by tgl, voucher"

RunQ "Kas/Bank keluar ket~donal per akun (posted)" "select account_id, count(*) n, cast(sum(kredit) as numeric(18,2)) total_keluar from gl_journal where lower(ket) like '%donal%' and kredit>0 and posting='P' group by account_id order by total_keluar desc"
