$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=180; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 100){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 100){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}

foreach($p in @(
  @{bom='2026-02-01'; label='Jan';  gld='2026-01-31'},
  @{bom='2026-03-01'; label='Feb';  gld='2026-02-28'},
  @{bom='2026-04-01'; label='Mar';  gld='2026-03-31'},
  @{bom='2026-05-01'; label='Apr';  gld='2026-04-30'},
  @{bom='2026-06-01'; label='Mei';  gld='2026-05-31'},
  @{bom='2026-07-01'; label='Jun';  gld='2026-06-30'}
)) {
  $q = @"
select o.account_id,
       cast(o.opname_sinv as numeric(18,2)) opname_sinv,
       cast(isnull(g.ledger_gl,0) as numeric(18,2)) ledger_gl,
       cast(o.opname_sinv - isnull(g.ledger_gl,0) as numeric(18,2)) selisih
  from (
    select ipg.persediaan account_id, sum(sv.nilai) opname_sinv
      from sinv sv
      join im_produk ip on ip.produk_id=sv.stok_id
      join im_product_group ipg on ipg.kode_group=ip.group_product
     where sv.periode='$($p.bom)' and isnull(ipg.persediaan,'') like '102-%'
     group by ipg.persediaan
  ) o
  left join (
    select b.AccountCode account_id,
           b.AmountDebet-b.AmountCredit
           + isnull((select sum(g2.debet-g2.kredit) from gl_journal g2
                      where g2.account_id=b.AccountCode and g2.tgl between '2026-01-01' and '$($p.gld)'),0) as ledger_gl
      from gl_balance b
     where b.Period='2026-01-01' and b.AccountCode like '102-%'
  ) g on g.account_id=o.account_id
 where abs(o.opname_sinv - isnull(g.ledger_gl,0)) > 10
 order by abs(o.opname_sinv - isnull(g.ledger_gl,0)) desc
"@
  Tab $q "Selisih Opname vs GL -- akhir $($p.label) 2026 (threshold >Rp10, sweep penuh)"
}
$c.Close()
