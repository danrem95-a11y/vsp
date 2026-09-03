$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $cmd=$cn.CreateCommand(); $cmd.CommandTimeout=240; $cmd.CommandText=$sql
  try{$rd=$cmd.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "16 doc_reff lintas Feb-Mei: rincian akun/modul + net 103-001 Feb" @"
select g.doc_reff,
   cast(sum(case when g.tgl>='2026-02-01' and g.tgl<'2026-03-01' and g.account_id='103-001' then g.debet-g.kredit else 0 end) as numeric(18,2)) ar_feb_net,
   cast(sum(case when g.tgl>='2026-05-01' and g.tgl<'2026-06-01' and g.account_id='103-001' then g.debet-g.kredit else 0 end) as numeric(18,2)) ar_mei_net,
   count(distinct g.account_id) n_akun
from gl_journal g
where g.posting='P' and g.doc_reff in (
   select doc_reff from gl_journal where posting='P' and isnull(doc_reff,'')<>'' and tgl>='2026-02-01' and tgl<'2026-03-01'
   intersect
   select doc_reff from gl_journal where posting='P' and isnull(doc_reff,'')<>'' and tgl>='2026-05-01' and tgl<'2026-06-01')
group by g.doc_reff order by abs(sum(case when g.tgl>='2026-02-01' and g.tgl<'2026-03-01' and g.account_id='103-001' then g.debet-g.kredit else 0 end)) desc
"@

Qry "TOTAL 103-001 Feb yg doc_reff-nya juga muncul di Mei (yg berisiko ke-hapus saat refresh Mei)" @"
select count(*) n, cast(sum(g.debet-g.kredit) as numeric(18,2)) ar_feb_terancam
from gl_journal g
where g.posting='P' and g.account_id='103-001' and g.tgl>='2026-02-01' and g.tgl<'2026-03-01'
  and g.doc_reff in (select doc_reff from gl_journal where posting='P' and tgl>='2026-05-01' and tgl<'2026-06-01' and isnull(doc_reff,'')<>'')
"@

$cn.Close()
