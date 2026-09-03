$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "1. GL 103-001 faktur 10103251100061 (debet faktur, kredit bayar)" @"
select left(voucher,18) voucher, cast(tgl as date) tgl, modul_id, cast(debet as numeric(18,2)) db, cast(kredit as numeric(18,2)) kr, left(ket,34) ket
from gl_journal where posting='P' and account_id='103-001' and doc_reff='10103251100061' order by tgl
"@
Qry "2. Saldo GL faktur ini (harus 0 kalau lunas)" @"
select cast(sum(debet)-sum(kredit) as numeric(18,2)) saldo_gl from gl_journal where posting='P' and account_id='103-001' and doc_reff='10103251100061'
"@
Qry "3. TBYR2 utk bukti 10103251100061 (ADA pembayaran di sub-ledger?)" @"
select left(voucher,18) voucher, cast(nilai_bayar_idr as numeric(18,2)) nb_idr from tbyr2 where bukti_id='10103251100061'
"@
Qry "4. AR_TRANS faktur 10103251100061 (pemilik & nilai)" @"
select left(order_client,18) oc, cust_id, cast(tgl as date) tgl, tipe_trans, cast(ttl_netto as numeric(18,2)) ttl, left(isnull(bukti_reff,''),16) reff from ar_trans where order_client='10103251100061'
"@
Qry "5. Semua bukti bayar modul CI Metro Motor 2025 yg TIDAK ada di tbyr" @"
select left(gj.doc_reff,18) faktur, cast(sum(gj.kredit) as numeric(18,2)) kr_ci,
  (select count(*) from tbyr2 t2 where t2.bukti_id=gj.doc_reff) ada_tbyr
from gl_journal gj where gj.posting='P' and gj.account_id='103-001' and gj.modul_id='CI' and gj.tgl>='2025-01-01' and gj.tgl<'2026-01-01'
  and gj.doc_reff in (select order_client from ar_trans where cust_id='200.M096')
group by gj.doc_reff order by faktur
"@
$cn.Close()
