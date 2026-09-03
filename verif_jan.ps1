$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Show "1. Index sinv sekarang (idx_sinv_periode hrs PERIODE dulu)" "select iname, colnames from SYS.SYSINDEXES where tname='sinv' order by iname"

Show "2. TL.203.0504 sinv per periode (Jan-end=2026-02-01 hrs terkoreksi: qty naik, hpp_avg positif)" @"
select periode, cast(qty as numeric(18,2)) qty, cast(nilai as numeric(18,2)) nilai, cast(hpp_avg as numeric(18,4)) hpp_avg
from sinv where stok_id='TL.203.0504' and periode>='2026-01-01' and periode<='2026-08-01' order by periode
"@

Show "3. INTEGRITAS 2025 - tbyr Metro & Bingshan (cross-month delete? hrs masih ADA)" @"
select left(t1.voucher,16) voucher, cast(t1.tgl as date) tgl, left(t2.bukti_id,16) bukti, cast(t2.nilai_bayar_idr as numeric(18,2)) nb
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
where t1.voucher in ('25112004R117R','25122004R009R','200410125100303') order by t1.tgl
"@

Show "4. gl_journal 2025 count (baseline 51.128) - turun = ada yg terhapus" "select count(*) gl_2025 from gl_journal where tgl>='2025-01-01' and tgl<'2026-01-01'"

Show "5. GL Januari 2026 balance? (debet-kredit hrs 0)" "select cast(sum(debet)-sum(kredit) as numeric(18,2)) selisih_jan26 from gl_journal where posting='P' and tgl>='2026-01-01' and tgl<'2026-02-01'"
$P.Close()
