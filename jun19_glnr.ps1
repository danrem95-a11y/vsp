$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=180; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== Akun grup NR (persediaan / hpp) ==="
Reader "select kode_group, nama_group, persediaan, hpp from im_product_group where kode_group='NR'"

Write-Host "`n=== GL utk JUAL serial 645 (30 Jun) - refs order 10106260600001 / consin 10206260600001 ==="
Reader @"
select account_id, cast(debet as numeric(18,2)) debet, cast(kredit as numeric(18,2)) kredit, modul_id, tgl, doc_reff, voucher, left(ket,30) ket
from gl_journal
where doc_reff in ('10106260600001','10206260600001') or voucher in ('10106260600001','10206260600001')
order by tgl, modul_id
"@

Write-Host "`n=== GL utk WIP-out Mei serial 645 (order 101260500063) ==="
Reader @"
select account_id, cast(debet as numeric(18,2)) debet, cast(kredit as numeric(18,2)) kredit, modul_id, tgl, doc_reff, voucher, left(ket,30) ket
from gl_journal
where doc_reff in ('101260500063','10206260500002') or voucher in ('101260500063')
order by tgl, modul_id
"@

Write-Host "`n=== Bandingkan: GL utk serial 174 yg BENAR (jual 11 Mei, order 10106260500001) ==="
Reader @"
select modul_id, account_id, cast(sum(debet) as numeric(18,2)) debet, cast(sum(kredit) as numeric(18,2)) kredit
from gl_journal where doc_reff='10106260500001'
group by modul_id, account_id order by modul_id, account_id
"@

$cn.Close()
