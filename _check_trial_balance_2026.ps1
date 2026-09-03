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

# 1. Total keseluruhan gl_balance opening 2026 -- apakah Debet=Kredit (balance sheet balance)?
Tab @"
select cast(sum(AmountDebet) as numeric(20,2)) total_debet, cast(sum(AmountCredit) as numeric(20,2)) total_kredit,
       cast(sum(AmountDebet)-sum(AmountCredit) as numeric(20,2)) selisih
  from gl_balance where Period='2026-01-01'
"@ "1. Total gl_balance opening 2026 SEMUA akun (harus Debet=Kredit kalau neraca balance)"

# 2. Cek apakah ada akun LAIN dgn nilai persis 23.962.637,52 (atau -nya) di opening 2026 -- kandidat pasangan entry asli
Tab @"
select AccountCode, cast(AmountDebet as numeric(16,2)) debet, cast(AmountCredit as numeric(16,2)) kredit
  from gl_balance
 where Period='2026-01-01' and (abs(AmountDebet-23962637.52)<1 or abs(AmountCredit-23962637.52)<1)
"@ "2. Cari akun lain dgn opening persis 23.962.637,52 (kandidat pasangan double-entry asli)"

# 3. Cek riwayat gl_balance MT01-0001/102-201 di tahun2 sebelumnya (kalau ada multi-tahun) utk lihat kapan gap ini pertama muncul
Tab "select Period, AccountCode, cast(AmountDebet as numeric(16,2)) debet, cast(AmountCredit as numeric(16,2)) kredit from gl_balance where AccountCode='102-201' order by Period" "3. Riwayat gl_balance 102-201 semua tahun yg tercatat"
$c.Close()
