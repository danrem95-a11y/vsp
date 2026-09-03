$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=90; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 40){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 40){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}

# 1. Chain continuity SINV -- untuk item2 di 102-201 dan 102-001, cek saldo akhir bulan N = saldo awal bulan N+1
Tab @"
select ipg.persediaan akun, sv.periode, cast(sum(sv.nilai) as numeric(18,2)) total_nilai_sinv
  from sinv sv
  join im_produk ip on ip.produk_id=sv.stok_id
  join im_product_group ipg on ipg.kode_group=ip.group_product
 where ipg.persediaan in ('102-201','102-001') and sv.periode between '2026-01-01' and '2026-07-01'
 group by ipg.persediaan, sv.periode
 order by ipg.persediaan, sv.periode
"@ "1. SINV per akun per periode (cek internal: akhir bulan N harus = awal bulan N+1, otomatis krn SAMA row)"

# 2. Chain continuity GL -- saldo akhir tiap bulan (opening + cumulative journal sampai akhir bulan itu)
foreach($acc in @('102-201','102-001')){
  $q = @"
select '$acc' akun, 'Akhir Des 2025 (opening 2026)' label,
       cast(b.AmountDebet-b.AmountCredit as numeric(18,2)) saldo
  from gl_balance b where b.AccountCode='$acc' and b.Period='2026-01-01'
"@
  Tab $q "2. GL opening 2026 (awal Jan) -- $acc"
}

# 3. SINV opening Jan 2026 (periode=2026-01-01) vs GL opening Jan 2026 -- titik AWAL selisih
foreach($acc in @('102-201','102-001')){
  $q = @"
select cast(sum(sv.nilai) as numeric(18,2)) sinv_opening_jan2026,
       cast((select b.AmountDebet-b.AmountCredit from gl_balance b where b.AccountCode='$acc' and b.Period='2026-01-01') as numeric(18,2)) gl_opening_jan2026,
       cast(sum(sv.nilai) - (select b.AmountDebet-b.AmountCredit from gl_balance b where b.AccountCode='$acc' and b.Period='2026-01-01') as numeric(18,2)) selisih_opening
  from sinv sv
  join im_produk ip on ip.produk_id=sv.stok_id
  join im_product_group ipg on ipg.kode_group=ip.group_product
 where ipg.persediaan='$acc' and sv.periode='2026-01-01'
"@
  Tab $q "3. Selisih SUDAH ADA di opening Jan 2026 (SEBELUM refresh apapun tahun ini)? -- $acc"
}
$c.Close()
