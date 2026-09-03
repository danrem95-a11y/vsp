$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Show "1. sinv TR.038A: opening(01-01) vs hasil(02-01)" @"
select periode, cast(qty as numeric(18,2)) qty, cast(nilai as numeric(18,2)) nilai from sinv where stok_id='TR.038A' and periode in ('2026-01-01','2026-02-01') order by periode
"@
Show "2. TSTOK TR.038A Januari per tipe (qty & jumlah baris)" @"
select t1.tipe_trans, count(*) n_baris, cast(sum(t2.qty) as numeric(18,2)) sum_qty
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
where t2.stok_id='TR.038A' and t1.tgl>='2026-01-01' and t1.tgl<'2026-02-01' group by t1.tipe_trans order by t1.tipe_trans
"@
Show "3. TSALES TR.038A Januari per tipe (qty & jumlah baris)" @"
select s1.tipe_trans, count(*) n_baris, cast(sum(s2.qty) as numeric(18,2)) sum_qty
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s2.stok_id='TR.038A' and s1.tgl>='2026-01-01' and s1.tgl<'2026-02-01' group by s1.tipe_trans order by s1.tipe_trans
"@
Show "4. Konsinyasi IN '88' TR.038A: berapa baris tstok1 vs tstok2 (cek penggandaan join)" @"
select (select count(*) from tstok1 where tipe_trans='88' and tgl>='2026-01-01' and tgl<'2026-02-01' and bukti_id in (select bukti_id from tstok2 where stok_id='TR.038A')) t1_88,
       (select count(*) from tstok2 t2 join tstok1 t1 on t1.bukti_id=t2.bukti_id where t2.stok_id='TR.038A' and t1.tipe_trans='88' and t1.tgl>='2026-01-01' and t1.tgl<'2026-02-01') t2_88_joined
from SYS.DUMMY
"@
$P.Close()
