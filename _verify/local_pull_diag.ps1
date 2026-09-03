$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=localhost;port=2638);ENG=vsp;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs
try{$cn.Open()}catch{Write-Host ("LOKAL OPEN ERR: "+$_.Exception.Message); exit}
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "DB + kolom source_ref ada?" "select db_name() db, (select count(*) from syscolumn c join systable t on t.table_id=c.table_id where t.table_name='FA_ASSET' and c.column_name='source_ref') ada_source_ref"

Qry "FA_CATEGORY asset_account (lokal)" "select category_code, asset_account, depreciable_yn from FA_CATEGORY where site_id='101' order by category_code"

Qry "SEMUA GL debit ke akun aktiva JULI 2026 (tanpa filter belum-ditarik)" @"
select cast(g.tgl as date) tgl, g.account_id, g.voucher, g.urut, left(isnull(g.ket,''),30) ket,
  cast(g.debet as numeric(18,2)) debet, g.posting,
  (select count(*) from FA_ASSET a where a.site_id='101' and a.source_ref=g.voucher||'#'||cast(g.urut as varchar)) sudah_link,
  (select count(*) from FA_ASSET a where a.site_id='101' and a.asset_account=g.account_id and cast(a.acquisition_date as date)=cast(g.tgl as date) and a.acquisition_cost=g.debet) ada_aset_serupa
from gl_journal g
where g.site_id='101' and g.debet>0
  and g.account_id in (select asset_account from FA_CATEGORY where site_id='101')
  and cast(g.tgl as date) between '2026-07-01' and '2026-07-31'
order by g.account_id, g.tgl
"@

Qry "KANDIDAT (persis query preview) Juli 2026" @"
select g.voucher, g.urut, cast(g.tgl as date) tgl, isnull(g.ket,'') nama, cat.category_code gol, cast(g.debet as numeric(18,2)) harga
from gl_journal g
join FA_CATEGORY cat on cat.site_id=g.site_id and cat.asset_account=g.account_id
where g.posting='P' and g.site_id='101' and g.debet>0
  and cast(g.tgl as date) between '2026-07-01' and '2026-07-31'
  and not exists(select 1 from FA_ASSET a where a.site_id=g.site_id and a.source_ref = g.voucher||'#'||cast(g.urut as varchar))
order by cat.category_code, g.tgl
"@
$cn.Close()
