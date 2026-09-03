$csL = "DSN=vsp;UID=dba;PWD=jakarta"
$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$L = New-Object System.Data.Odbc.OdbcConnection $csL; $L.Open()
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Map($cn){ $c=$cn.CreateCommand(); $c.CommandTimeout=200
  $c.CommandText="select sv.stok_id, max(left(pr.produk_desc,40)) nm, cast(sum(sv.qty) as numeric(18,2)) qty, cast(sum(sv.nilai) as numeric(18,2)) nilai from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-001' and sv.periode='2026-01-01' group by sv.stok_id"
  $m=@{}; $rd=$c.ExecuteReader(); while($rd.Read()){ $m[[string]$rd['stok_id']]=@{nm=[string]$rd['nm']; qty=[decimal]$rd['qty']; nilai=[decimal]$rd['nilai']} }; $rd.Close(); return $m }
$mp = Map $P; $ml = Map $L
$keys = ($mp.Keys + $ml.Keys) | Sort-Object -Unique
$rows=@()
foreach($k in $keys){
  $p = if($mp.ContainsKey($k)){$mp[$k]}else{@{nm='';qty=0;nilai=0}}
  $l = if($ml.ContainsKey($k)){$ml[$k]}else{@{nm='';qty=0;nilai=0}}
  $nm = if($p.nm){$p.nm}else{$l.nm}
  $rows += [pscustomobject]@{ stok_id=$k; nama=$nm; prod_qty=$p.qty; prod_nilai=$p.nilai; lokal_qty=$l.qty; lokal_nilai=$l.nilai; selisih_nilai=($p.nilai-$l.nilai); selisih_qty=($p.qty-$l.qty) }
}
$csv = "C:\BTV\debug\SALDO_AWAL_102-001_perItem.csv"
$rows | Sort-Object { -[decimal]$_.prod_nilai } | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
Write-Host "CSV lengkap ditulis: $csv (`$($rows.Count) item)"
Write-Host ""
Write-Host ("{0,-14} {1,-30} {2,8} {3,18} {4,8} {5,18}" -f 'stok_id','nama','p_qty','prod_nilai','l_qty','selisih_nilai')
$rows | Sort-Object { -[math]::Abs([decimal]$_.selisih_nilai) } | Select-Object -First 20 | ForEach-Object {
  Write-Host ("{0,-14} {1,-30} {2,8:N0} {3,18:N2} {4,8:N0} {5,18:N2}" -f $_.stok_id,$_.nama.PadRight(30).Substring(0,30),$_.prod_qty,$_.prod_nilai,$_.lokal_qty,$_.selisih_nilai)
}
$tp=($rows | Measure-Object prod_nilai -Sum).Sum; $tl=($rows | Measure-Object lokal_nilai -Sum).Sum
Write-Host ""
Write-Host ("TOTAL prod={0:N2}  lokal={1:N2}  selisih={2:N2}" -f $tp,$tl,($tp-$tl))
Write-Host ("gl_balance saldo awal 102-001 = 12,999,133,239.62  (prod sinv lebih tinggi = "+('{0:N2}' -f ($tp-12999133239.62))+")")
$L.Close(); $P.Close()
