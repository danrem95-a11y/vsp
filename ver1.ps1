$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Dict($sql,$kcol,$vcol){ $h=@{}; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql; $rd=$c.ExecuteReader()
  while($rd.Read()){ $k=[string]$rd[$kcol]; $v=[double]$rd[$vcol]; $h[$k]=$v }; $rd.Close(); return $h }

$sinv = Dict "select g.persediaan acc, sum(s.nilai) v from sinv s, im_produk p, im_product_group g where s.periode='2026-05-01' and s.stok_id=p.produk_id and p.group_product=g.kode_group group by g.persediaan" "acc" "v"
$glopen = Dict "select AccountCode acc, sum(AmountDebet-AmountCredit) v from gl_balance where Period='2026-01-01' group by AccountCode" "acc" "v"
$gljrn = Dict "select account_id acc, sum(debet-kredit) v from gl_journal where tgl between '2026-01-01' and '2026-04-30' and posting='P' group by account_id" "acc" "v"

# checklist April: acc = @(namaMutasi, namaLedger)
$chk = @{
 "102-001"=@(7528916451.31,7528916451.77,"TR");
 "102-101"=@(7139345107.72,7139345102.38,"TS");
 "102-102"=@(165559506.85,165559498.29,"TL");
 "102-110"=@(3238748698.26,3239396331.05,"L+LA");
 "102-003"=@(55094965.00,55094965.15,"NR");
 "102-113"=@(96065711.76,96065711.54,"TY");
 "102-006"=@(1729884420.49,1729884419.70,"TB");
 "102-010"=@(248216000.41,248216000.12,"TYU");
 "102-020"=@(1839530040.82,1839530040.82,"WIP");
 "102-103"=@(136458389.77,136458389.66,"NDS");
 "102-018"=@(0,0,"BCS")
}
Write-Host ("{0,-9} {1,-5} {2,18} {3,18} {4,18} {5,14} {6,14}" -f "ACC","GRP","SINV(mutasi)","GL(ledger)","CHK-Ledger","dLed_vsGL","dLed_vsCHK")
foreach($a in ($chk.Keys | Sort-Object)){
  $m = if($sinv.ContainsKey($a)){$sinv[$a]}else{0}
  $o = if($glopen.ContainsKey($a)){$glopen[$a]}else{0}
  $j = if($gljrn.ContainsKey($a)){$gljrn[$a]}else{0}
  $gl = $o + $j
  $cl = $chk[$a][1]; $grp=$chk[$a][2]
  $dGL = $m - $gl                 # mutasi - ledger (harus ~0)
  $dCHK = $gl - $cl               # ledger - checklist
  Write-Host ("{0,-9} {1,-5} {2,18:N0} {3,18:N0} {4,18:N0} {5,14:N0} {6,14:N0}" -f $a,$grp,$m,$gl,$cl,$dGL,$dCHK)
}
$cn.Close()
