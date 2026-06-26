$ErrorActionPreference='Stop'
$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open(); $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=300
function Show($label,$q){
  "`n=== $label ==="
  try{
    $cmd.CommandText=$q; $rd=$cmd.ExecuteReader(); $cols=$rd.FieldCount
    $hdr=@(); for($i=0;$i -lt $cols;$i++){ $hdr+=$rd.GetName($i) }; ($hdr -join ' | ')
    while($rd.Read()){ $vals=@(); for($i=0;$i -lt $cols;$i++){ $v=$rd.GetValue($i); if($v -is [DateTime]){$v=$v.ToString('yyyy-MM-dd')}; $vals+=("$v").Trim() }; ($vals -join ' | ') }
    $rd.Close()
  }catch{ "ERR $($_.Exception.Message.Split([Environment]::NewLine)[0])" }
}

# A) ALL postings to Donal account 108-310, grouped by posting flag
Show "Akun 108-310 (Donal) - rekap per posting" @"
select posting, count(*) n,
 cast(sum(debet) as numeric(18,2)) total_debet,
 cast(sum(kredit) as numeric(18,2)) total_kredit,
 cast(sum(debet)-sum(kredit) as numeric(18,2)) net_debet,
 min(tgl) tgl_awal, max(tgl) tgl_akhir
from gl_journal where account_id='108-310' group by posting
"@

# B) Posted-only grand total
Show "Akun 108-310 - TOTAL (posting='P')" @"
select count(*) n,
 cast(sum(debet) as numeric(18,2)) transfer_ke_donal_debet,
 cast(sum(kredit) as numeric(18,2)) bayar_balik_kredit,
 cast(sum(debet)-sum(kredit) as numeric(18,2)) saldo_piutang_net
from gl_journal where account_id='108-310' and posting='P'
"@

# C) Full ledger of 108-310
Show "Buku besar 108-310 (semua, kronologis)" @"
select tgl, voucher, modul_id, posting,
 cast(debet as numeric(18,2)) debet, cast(kredit as numeric(18,2)) kredit, ket
from gl_journal where account_id='108-310' order by tgl, voucher
"@

# D) Cash/bank OUT mentioning Donal (kredit kas) = uang fisik keluar utk Donal
Show "Kas/Bank KELUAR (kredit) ket~donal - per akun" @"
select account_id, count(*) n, cast(sum(kredit) as numeric(18,2)) total_keluar
from gl_journal where lower(ket) like '%donal%' and kredit>0 and posting='P'
group by account_id order by total_keluar desc
"@
$conn.Close()
