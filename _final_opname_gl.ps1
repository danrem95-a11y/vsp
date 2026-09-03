$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=150; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 45){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 45){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}
$engRaw = [System.IO.File]::ReadAllText("C:\BTV\debug\_engine_sql.txt")
$engRaw = [regex]::Replace($engRaw, '(?is)\s+ORDER\s+BY\s+[^)]*\)\s*A,IM_PRODUCT_GROUP', ') A,IM_PRODUCT_GROUP')

foreach($p in @(
  @{tgl1='2026-03-01'; tgl2='2026-03-31'; bom='2026-04-01'; label='Akhir Maret'; gld='2026-03-31'},
  @{tgl1='2026-04-01'; tgl2='2026-04-30'; bom='2026-05-01'; label='Akhir April'; gld='2026-04-30'},
  @{tgl1='2026-05-01'; tgl2='2026-05-31'; bom='2026-06-01'; label='Akhir Mei';   gld='2026-05-31'},
  @{tgl1='2026-06-01'; tgl2='2026-06-30'; bom='2026-07-01'; label='Akhir Juni';  gld='2026-06-30'}
)) {
  $eng = $engRaw -replace ':arg_tgl2', "'$($p.tgl2)'"
  $eng = $eng -replace ':arg_tgl', "'$($p.tgl1)'"
  $q = @"
select
  cast(sum(isnull((select sv.nilai from sinv sv where sv.stok_id=z.PRODUK_ID and sv.periode='$($p.bom)'),0)) as numeric(20,2)) opname_sinv,
  cast((select b.AmountDebet-b.AmountCredit from gl_balance b where b.AccountCode='102-001' and b.Period='2026-01-01')
     + isnull((select sum(g.debet-g.kredit) from gl_journal g where g.account_id='102-001' and g.tgl between '2026-01-01' and '$($p.gld)'),0) as numeric(20,2)) ledger_gl,
  cast(sum(isnull((select sv.nilai from sinv sv where sv.stok_id=z.PRODUK_ID and sv.periode='$($p.bom)'),0))
     - ((select b.AmountDebet-b.AmountCredit from gl_balance b where b.AccountCode='102-001' and b.Period='2026-01-01')
       + isnull((select sum(g.debet-g.kredit) from gl_journal g where g.account_id='102-001' and g.tgl between '2026-01-01' and '$($p.gld)'),0)) as numeric(20,2)) selisih
from ( $eng ) z
where z.PERSEDIAAN='102-001'
"@
  Tab $q "Opname vs GL 102-001 -- $($p.label)"
}
$c.Close()
