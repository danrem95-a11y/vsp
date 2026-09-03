$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "0. Kolom TBYR1" "select cname from SYS.SYSCOLUMNS where tname='tbyr1' order by cname"
Qry "0b. Kolom TBYR2" "select cname from SYS.SYSCOLUMNS where tname='tbyr2' order by cname"

Qry "1. TBYR1 - cari voucher R117/R009 (Nov/Des 2025)" @"
select * from tbyr1 where voucher in ('25112004R117','25122004R009') or voucher_manual in ('25112004R117','25122004R009')
"@

Qry "2. GL 103-001 pembayaran (kredit) Metro Motor Nov-Des 2025" @"
select left(voucher,18) voucher, left(isnull(doc_reff,''),16) doc_reff, cast(tgl as date) tgl, cast(debet as numeric(18,2)) db, cast(kredit as numeric(18,2)) kr, modul_id, left(ket,34) ket
from gl_journal where posting='P' and account_id='103-001' and tgl>='2025-11-01' and tgl<'2026-01-01' and kredit>0
  and (ket like '%METRO%' or ket like '%M096%' or ket like '%R117%' or ket like '%R009%' or kredit in (200000000,50000000))
order by tgl
"@
$cn.Close()
