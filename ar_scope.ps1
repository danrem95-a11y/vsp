$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

# derived: per faktur, GL-payment 2025 (kredit 103-001, semua modul) vs TBYR 2025
$base = @"
select gj.doc_reff faktur, max(gj.modul_id) modul,
  cast(sum(gj.kredit) as numeric(18,2)) gl_pay,
  cast(isnull((select sum(t2.nilai_bayar_idr) from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
        where t2.bukti_id=gj.doc_reff and t1.tgl>='2025-01-01' and t1.tgl<'2026-01-01' and t1.flag_bayar in (1,2)),0) as numeric(18,2)) tbyr_pay
from gl_journal gj
where gj.posting='P' and gj.account_id='103-001' and gj.kredit>0 and gj.tgl>='2025-01-01' and gj.tgl<'2026-01-01'
  and isnull(gj.doc_reff,'')<>''
group by gj.doc_reff
"@

Qry "1. Pembayaran 103-001 th2025 per MODUL (kredit) - modul mana yg bayar AR" @"
select modul_id, count(*) n, cast(sum(kredit) as numeric(18,2)) total_kredit
from gl_journal where posting='P' and account_id='103-001' and kredit>0 and tgl>='2025-01-01' and tgl<'2026-01-01'
group by modul_id order by sum(kredit) desc
"@

Qry "2. RINGKAS berlubang (GL bayar 2025 > TBYR 2025)" @"
select count(*) n_faktur, cast(sum(gl_pay-tbyr_pay) as numeric(18,2)) total_berlubang, cast(sum(gl_pay) as numeric(18,2)) total_gl, cast(sum(tbyr_pay) as numeric(18,2)) total_tbyr
from ($base) x where (gl_pay - tbyr_pay) > 1
"@

Qry "3. Berlubang per PELANGGAN (top 20)" @"
select at.cust_id, left(max(mc.cust_name),22) nama, count(*) n_faktur, cast(sum(x.gl_pay-x.tbyr_pay) as numeric(18,2)) berlubang
from ($base) x join ar_trans at on at.order_client=x.faktur left join mcust mc on mc.cust_id=at.cust_id
where (x.gl_pay - x.tbyr_pay) > 1
group by at.cust_id order by sum(x.gl_pay-x.tbyr_pay) desc
"@
$cn.Close()
