$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

# DETEKTOR: pembayaran Dr 226-001 yg order_reff=NOITEM, & akun apa yg di-kredit faktur NOITEM itu
Qry "DETEKTOR mismatch: bayar Dr 226-001 tapi faktur NOITEM di akun lain (227.x)" @"
select cast(p.tgl as date) tgl, p.voucher pay_voucher, p.order_reff noitem,
  cast(p.debet as numeric(18,2)) bayar_226, left(isnull(p.ket,''),30) ket,
  i.faktur_acc, cast(i.faktur_cr as numeric(18,2)) faktur_cr,
  case when i.faktur_acc is null then '(faktur tak ketemu)'
       when i.faktur_acc='226-001' then 'OK (sama 226)'
       else 'MISMATCH -> '+i.faktur_acc end status
from gl_journal p
left join (
   select voucher, account_id faktur_acc, sum(kredit) faktur_cr
   from gl_journal where site_id='101' and posting='P' and kredit>0 and voucher like 'NOITEM%'
   group by voucher, account_id
) i on i.voucher = p.order_reff
where p.site_id='101' and p.posting='P' and p.account_id='226-001' and p.debet>0
  and p.order_reff like 'NOITEM%' and p.tgl between '2026-01-01' and '2026-07-31'
order by p.tgl
"@

# RINGKAS per bulan: berapa sering & total nilai bayar-226 yg order_reff NOITEM
Qry "Frekuensi per bulan (bayar Dr 226 dgn order_reff NOITEM)" @"
select left(convert(varchar,p.tgl,120),7) bln, count(*) jml, cast(sum(p.debet) as numeric(18,2)) total_226
from gl_journal p
where p.site_id='101' and p.posting='P' and p.account_id='226-001' and p.debet>0
  and p.order_reff like 'NOITEM%' and p.tgl between '2026-01-01' and '2026-07-31'
group by left(convert(varchar,p.tgl,120),7) order by 1
"@
$cn.Close()
