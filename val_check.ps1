$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host ("  SYNTAX/RUN ERR: "+$_.Exception.Message)} }

Reader "S0 SYS.DUMMY + getdate + cast date (kompat ASA9)" "select getdate() now_ts, cast('2026-06-01' as date) d1, 'x'||'y' concat_test from SYS.DUMMY"

Reader "GATE Harden Dup-Cost (>1 HPP consout per stok+evap)" @"
select count(*) n_dup from (
  select c2.stok_id,c2.evap from tsales1 c1,tsales2 c2
  where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88' and isnull(c2.evap,'')<>'' and isnull(c2.hpp,0)>0
  group by c2.stok_id,c2.evap having count(distinct cast(c2.hpp as numeric(18,2)))>1
) d
"@

Reader "GATE Harden Future-Cost (tipe22 Jun-Jul, consout hanya stlh jual)" @"
select count(*) n_future from tsales1 s1,tsales2 s2
where s1.bukti_id=s2.bukti_id and s1.tipe_trans='22' and isnull(s2.evap,'')<>'' and isnull(s2.hpp,0)=0
  and s1.tgl>='2026-06-01' and s1.tgl<'2026-08-01'
  and not exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
       and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0 and c1.tgl<=s1.tgl)
  and exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
       and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0 and c1.tgl>s1.tgl)
"@

Reader "GATE Harden Orphan (tipe22 Jun-Jul, jual EVAP hpp=0 tanpa consout)" @"
select count(*) n_orphan, cast(sum(s2.qty) as numeric(18,2)) qty from tsales1 s1,tsales2 s2
where s1.bukti_id=s2.bukti_id and s1.tipe_trans='22' and isnull(s2.evap,'')<>'' and isnull(s2.hpp,0)=0 and s2.qty>0
  and s1.tgl>='2026-06-01' and s1.tgl<'2026-08-01'
  and not exists(select 1 from tsales1 c1,tsales2 c2 where c1.bukti_id=c2.bukti_id and c1.tipe_trans='88'
       and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0)
"@

Reader "COGS modul HP tersedia? (sanity modul_id)" @"
select modul_id, count(*) n, cast(sum(debet) as numeric(18,0)) debet from gl_journal
where posting='P' and tgl>='2026-06-01' and tgl<'2026-07-01' and account_id like '402-%' group by modul_id order by 2 desc
"@

$cn.Close()
