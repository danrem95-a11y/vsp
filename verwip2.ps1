$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($s){ $c=$cn.CreateCommand(); $c.CommandTimeout=200; $c.CommandText=$s
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== WIP1: rekap per BULAN 102-020 (masuk=debet, keluar=kredit) posting=P ==="
Reader "select month(tgl) bln, cast(sum(debet) as numeric(18,2)) wip_masuk, cast(sum(kredit) as numeric(18,2)) wip_keluar, cast(sum(debet-kredit) as numeric(18,2)) net from GL_JOURNAL where account_id='102-020' and tgl between '2026-01-01' and '2026-04-30' and posting='P' group by month(tgl) order by bln"

Write-Host "=== WIP2: opening + net = saldo vs checklist(1.839.530.040,82) ==="
Reader "select cast((select sum(AmountDebet-AmountCredit) from GL_BALANCE where AccountCode='102-020' and Period='2026-01-01') as numeric(18,2)) opening, cast((select sum(debet-kredit) from GL_JOURNAL where account_id='102-020' and tgl between '2026-01-01' and '2026-04-30' and posting='P') as numeric(18,2)) net_jrn"

Write-Host "=== WIP3: 12 posting TERBESAR 102-020 (deteksi sisa inflasi) ==="
Reader "select top 12 tgl, cast(debet as numeric(18,2)) d, cast(kredit as numeric(18,2)) k, left(ket,55) ket from GL_JOURNAL where account_id='102-020' and tgl between '2026-01-01' and '2026-04-30' and posting='P' order by (case when debet>kredit then debet else kredit end) desc"

Write-Host "=== WIP4: adakah posting > 1e8 (indikasi korupsi tersisa)? ==="
Reader "select count(*) n_besar, cast(sum(debet) as numeric(18,2)) sdeb, cast(sum(kredit) as numeric(18,2)) skre from GL_JOURNAL where account_id='102-020' and tgl between '2026-01-01' and '2026-04-30' and posting='P' and (debet>100000000 or kredit>100000000)"

Write-Host "=== WIP5: sumber - tstok2 COA_ID=102-020 (WIP dari mutasi stok) per tipe ==="
Reader "select t1.tipe_trans, count(*) n, cast(sum(abs(t2.netto_hpp)) as numeric(18,2)) sum_nhpp from TSTOK1 t1,TSTOK2 t2 where t1.bukti_id=t2.bukti_id and t2.coa_id='102-020' and t1.tgl between '2026-01-01' and '2026-04-30' group by t1.tipe_trans order by t1.tipe_trans"
$cn.Close()
