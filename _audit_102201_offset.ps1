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

# HIPOTESIS: apakah gl_balance(2026) = gl_balance(2025) + SUM(gl_journal 2025)?
# Kalau YA -> rantai internal GL sendiri konsisten, artinya masalahnya di tahun 2025 (GL vs SINV 2025 sudah beda dari awal)
Tab @"
select cast((select b.AmountDebet-b.AmountCredit from gl_balance b where b.AccountCode='102-201' and b.Period='2025-01-01') as numeric(18,2)) opening_2025,
       cast(isnull((select sum(g.debet-g.kredit) from gl_journal g where g.account_id='102-201' and g.tgl between '2025-01-01' and '2025-12-31'),0) as numeric(18,2)) mutasi_2025,
       cast((select b.AmountDebet-b.AmountCredit from gl_balance b where b.AccountCode='102-201' and b.Period='2025-01-01')
          + isnull((select sum(g.debet-g.kredit) from gl_journal g where g.account_id='102-201' and g.tgl between '2025-01-01' and '2025-12-31'),0) as numeric(18,2)) hasil_2025opening_plus_mutasi,
       cast((select b.AmountDebet-b.AmountCredit from gl_balance b where b.AccountCode='102-201' and b.Period='2026-01-01') as numeric(18,2)) opening_2026_tersimpan
"@ "1. Cek apakah gl_balance 2026 = gl_balance 2025 + mutasi GL 2025 (rantai internal GL sendiri)"

# 2. Kalau internal GL konsisten, cek mutasi SINV 2025 (item MT01-0001) vs mutasi GL 2025 -- apakah SUDAH beda dari 2025?
Tab @"
select sv1.periode periode_awal_2025, cast(sv1.nilai as numeric(18,2)) sinv_awal_2025,
       sv2.periode periode_akhir_2025, cast(sv2.nilai as numeric(18,2)) sinv_akhir_2025,
       cast(sv2.nilai - sv1.nilai as numeric(18,2)) mutasi_sinv_2025
  from sinv sv1, sinv sv2
 where sv1.stok_id='MT01-0001' and sv1.periode='2025-01-01'
   and sv2.stok_id='MT01-0001' and sv2.periode='2026-01-01'
"@ "2. Mutasi SINV 2025 (item MT01-0001, awal->akhir tahun)"
$c.Close()
