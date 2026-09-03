$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "1. Cust Metro Motor" @"
select cust_id, cust_name from mcust where upper(cust_name) like '%METRO MOTOR%'
"@

Qry "2. GL utk 2 voucher (voucher / doc_reff / ket)" @"
select left(voucher,16) voucher, left(isnull(doc_reff,''),16) doc_reff, account_id, cast(debet as numeric(18,2)) db, cast(kredit as numeric(18,2)) kr, cast(tgl as date) tgl, modul_id, left(ket,32) ket
from gl_journal where voucher in ('25112004R117','25122004R009') or doc_reff in ('25112004R117','25122004R009')
   or ket like '%25112004R117%' or ket like '%25122004R009%'
order by tgl, voucher, account_id
"@

Qry "3. TBYR1 (header bayar) utk 2 voucher" @"
select left(voucher,16) voucher, left(isnull(voucher_manual,''),16) vm, cast(tgl as date) tgl, flag_bayar, flag_vendor, left(isnull(ket,''),24) ket
from tbyr1 where voucher in ('25112004R117','25122004R009') or voucher_manual in ('25112004R117','25122004R009')
"@

Qry "4. TBYR2 (detail bayar) utk 2 voucher" @"
select left(t2.voucher,16) voucher, left(t2.bukti_id,18) bukti_id, cast(t2.nilai_bayar as numeric(18,2)) nb, cast(t2.nilai_bayar_idr as numeric(18,2)) nb_idr, t2.flag_vendor
from tbyr2 t2 where t2.voucher in ('25112004R117','25122004R009')
   or t2.voucher in (select voucher from tbyr1 where voucher_manual in ('25112004R117','25122004R009'))
"@
$cn.Close()
