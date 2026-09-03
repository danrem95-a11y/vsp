$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=240; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "Doc_reff yg SEBELUMNYA lintas Feb-Mei: kondisi 103-001 net Feb vs Mei SEKARANG" @"
select g.doc_reff,
   cast(sum(case when g.tgl>='2026-02-01' and g.tgl<'2026-03-01' and g.account_id='103-001' then g.debet-g.kredit else 0 end) as numeric(18,2)) feb,
   cast(sum(case when g.tgl>='2026-05-01' and g.tgl<'2026-06-01' and g.account_id='103-001' then g.debet-g.kredit else 0 end) as numeric(18,2)) mei
from gl_journal g
where g.posting='P' and g.doc_reff in
   ('10103260200033','10103260200041','10103260200060','10103260200006','10103260200039','10103260200012','10103260200070','10101260200002')
group by g.doc_reff order by g.doc_reff
"@

Qry "Masih berapa doc_reff lintas Feb-Mei? (kalau 0 = sisi Mei sudah ke-hapus refresh Feb)" @"
select count(*) n from (
  select doc_reff from gl_journal where posting='P' and isnull(doc_reff,'')<>'' and tgl>='2026-02-01' and tgl<'2026-03-01'
  intersect
  select doc_reff from gl_journal where posting='P' and isnull(doc_reff,'')<>'' and tgl>='2026-05-01' and tgl<'2026-06-01'
) x
"@
$cn.Close()
