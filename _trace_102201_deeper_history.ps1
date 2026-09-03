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

# Cek SINV tersedia dari tahun berapa (batas data)
Tab "select min(periode) periode_paling_awal, max(periode) periode_paling_akhir from sinv where stok_id='MT01-0001'" "0. Rentang data SINV MT01-0001 yg tersedia"

# Loop cek tiap tahun: gl_balance opening vs SINV opening, utk cari tahun PERSIS pertama kali gap muncul
foreach($yr in @(2018,2019,2020,2021,2022,2023,2024)){
  $q = @"
select $yr as tahun,
       cast((select b.AmountDebet-b.AmountCredit from gl_balance b where b.AccountCode='102-201' and b.Period='$yr-01-01') as numeric(18,2)) gl_opening,
       cast(isnull((select sv.nilai from sinv sv where sv.stok_id='MT01-0001' and sv.periode='$yr-01-01'),0) as numeric(18,2)) sinv_opening,
       cast((select b.AmountDebet-b.AmountCredit from gl_balance b where b.AccountCode='102-201' and b.Period='$yr-01-01')
          - isnull((select sv.nilai from sinv sv where sv.stok_id='MT01-0001' and sv.periode='$yr-01-01'),0) as numeric(18,2)) selisih
"@
  Tab $q "1. Cek gap opening tahun $yr"
}
$c.Close()
