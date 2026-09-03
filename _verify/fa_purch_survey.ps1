$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "FA_CATEGORY (semua) -> akun aktiva per golongan" @"
select category_code, category_name, asset_account, accum_dep_account, dep_expense_account,
  useful_life_month, cast(residual_percent as numeric(6,2)) residu_pct, depreciable_yn
from FA_CATEGORY where site_id='101' order by category_code
"@

Qry "GL debit ke akun aktiva (asset_account kategori) th 2026 - per voucher; sudah jadi aset?" @"
select cast(g.tgl as date) tgl, g.account_id, g.voucher, left(isnull(g.ket,''),34) ket,
  cast(g.debet as numeric(18,2)) debet,
  (select count(*) from FA_ASSET fa where fa.site_id='101' and fa.bank_voucher=g.voucher) sudah_aset
from gl_journal g
where g.posting='P' and g.site_id='101' and g.debet>0
  and g.account_id in (select asset_account from FA_CATEGORY where site_id='101' and depreciable_yn='Y')
  and g.tgl between '2026-01-01' and '2026-07-31'
order by g.tgl desc, g.account_id
"@
$cn.Close()
