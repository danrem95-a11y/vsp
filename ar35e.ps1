$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $cmd=$cn.CreateCommand(); $cmd.CommandTimeout=240; $cmd.CommandText=$sql
  try{$rd=$cmd.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "1. doc_reff punya entri gl (semua akun) di Feb DAN Mei (delete by doc_reff bisa lintas bulan?)" @"
select count(*) n_docreff_lintas from (
  select doc_reff from gl_journal where posting='P' and isnull(doc_reff,'')<>'' and tgl>='2026-02-01' and tgl<'2026-03-01'
  intersect
  select doc_reff from gl_journal where posting='P' and isnull(doc_reff,'')<>'' and tgl>='2026-05-01' and tgl<'2026-06-01'
) x
"@

Qry "2. voucher_manual punya entri gl di Feb DAN Mei (delete by voucher_manual bisa lintas bulan?)" @"
select count(*) n_vm_lintas from (
  select voucher_manual from gl_journal where posting='P' and isnull(voucher_manual,'')<>'' and tgl>='2026-02-01' and tgl<'2026-03-01'
  intersect
  select voucher_manual from gl_journal where posting='P' and isnull(voucher_manual,'')<>'' and tgl>='2026-05-01' and tgl<'2026-06-01'
) x
"@

Qry "3. Contoh voucher_manual lintas Feb-Mei (kalau ada) + akun/nilai" @"
select top 15 vm, cast(feb as numeric(18,2)) feb_nilai, cast(mei as numeric(18,2)) mei_nilai from (
  select voucher_manual vm,
    sum(case when tgl>='2026-02-01' and tgl<'2026-03-01' then debet+kredit else 0 end) feb,
    sum(case when tgl>='2026-05-01' and tgl<'2026-06-01' then debet+kredit else 0 end) mei
  from gl_journal where posting='P' and isnull(voucher_manual,'')<>'' group by voucher_manual
) y where feb>0 and mei>0 order by feb desc
"@

Qry "4. Entri gl 103-001 di Feb yg voucher_manual-nya juga muncul di Mei (kandidat yg 'kena')" @"
select count(*) n, cast(sum(g.debet-g.kredit) as numeric(18,2)) net_feb_terancam
from gl_journal g
where g.posting='P' and g.account_id='103-001' and g.tgl>='2026-02-01' and g.tgl<'2026-03-01'
  and g.voucher_manual in (select voucher_manual from gl_journal where posting='P' and tgl>='2026-05-01' and tgl<'2026-06-01' and isnull(voucher_manual,'')<>'')
"@

$cn.Close()
