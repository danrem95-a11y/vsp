$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $cmd=$cn.CreateCommand(); $cmd.CommandTimeout=200; $cmd.CommandText=$sql
  try{$rd=$cmd.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "A. GL HP (COGS) sale order 10106260600001 - baris yg harus jadi 38,5jt" @"
select voucher, urut, account_id, cast(debet as numeric(18,2)) debet, cast(kredit as numeric(18,2)) kredit, modul_id, tgl, doc_reff
from gl_journal where doc_reff='10106260600001' and modul_id='HP' order by urut
"@

Qry "B. GL AS (consin/WIP-In) - relieve 102-020, apakah sudah 38,5jt?" @"
select voucher, urut, account_id, cast(debet as numeric(18,2)) debet, cast(kredit as numeric(18,2)) kredit, modul_id, tgl, doc_reff, left(ket,30) ket
from gl_journal where (doc_reff='10203260600001' or voucher='10203260600001') order by urut
"@

Qry "C. SINV NR.201A 2026-07-01 (phantom yg harus jadi 0)" @"
select periode, cast(qty as numeric(18,2)) qty, cast(nilai as numeric(18,2)) nilai, cast(hpp_avg as numeric(18,2)) hpp_avg
from sinv where stok_id='NR.201A' and periode='2026-07-01'
"@

Qry "D. Cost dari WIP-Out Mei serial 645 (referensi nilai benar)" @"
select cast(max(s2.hpp) as numeric(18,2)) cost_wipout_mei
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s1.tipe_trans='88' and s2.stok_id='NR.201A' and s2.evap='645BDEAC002' and isnull(s2.hpp,0)>0
"@

$cn.Close()
