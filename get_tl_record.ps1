$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Show "1. Record tstok2 salah (bukti 10126010200006, TL.203.0504) - SEMUA field qty/nilai" @"
select cast(qty as numeric(18,2)) qty, cast(qty1 as numeric(18,2)) qty1, cast(qty2 as numeric(18,2)) qty2, cast(qty3 as numeric(18,2)) qty3,
 cast(netto as numeric(18,2)) netto, cast(kotor as numeric(18,2)) kotor, cast(netto_hpp as numeric(18,2)) netto_hpp, cast(hpp as numeric(18,4)) hpp, cast(hrg as numeric(18,4)) hrg,
 sat_kecil, sat_sedang, sat_besar, gudang_id, urut
from tstok2 where bukti_id='10126010200006' and stok_id='TL.203.0504'
"@

Show "2. PEMBANDING - record beli TL.203.0504 yg BENAR (26 Jan, qty 20.000) semua field" @"
select cast(qty as numeric(18,2)) qty, cast(qty1 as numeric(18,2)) qty1, cast(netto as numeric(18,2)) netto, cast(kotor as numeric(18,2)) kotor, cast(netto_hpp as numeric(18,2)) netto_hpp, cast(hpp as numeric(18,4)) hpp, cast(hrg as numeric(18,4)) hrg, sat_kecil
from tstok2 where bukti_id='10126010200040' and stok_id='TL.203.0504'
"@

Show "3. Ada berapa baris di bukti 10126010200006 (pastikan tak salah target)" @"
select stok_id, cast(qty as numeric(18,2)) qty, cast(netto as numeric(18,2)) netto from tstok2 where bukti_id='10126010200006' order by stok_id
"@
$P.Close()
