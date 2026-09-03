$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=150; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 60){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 60){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}

# 1. Detail 5 PO Mei 2026 (voucher 101BTB260500040-044) -- stok_id, evap/serial, qty, netto
Tab @"
select t1.bukti_id, t1.tgl, t2.stok_id, t2.evap, t2.qty, cast(t2.netto as numeric(16,2)) netto, cast(t2.hpp as numeric(16,2)) hpp
  from tstok1 t1, tstok2 t2
 where t1.bukti_id=t2.bukti_id
   and t1.bukti_id in (select order_client from gl_journal where voucher in
        ('101BTB260500040','101BTB260500041','101BTB260500042','101BTB260500043','101BTB260500044'))
"@ "1a. Coba cari via order_client (mungkin salah pendekatan)"

Tab @"
select t1.bukti_id, t1.tipe_trans, t1.tgl, t2.stok_id, t2.evap, t2.qty, cast(t2.netto as numeric(16,2)) netto, cast(t2.hpp as numeric(16,2)) hpp
  from tstok1 t1, tstok2 t2
 where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02'
   and t1.tgl between '2026-05-01' and '2026-05-31'
   and t2.stok_id like 'NR.%'
 order by t1.tgl
"@ "1b. Semua pembelian (tipe 02) NR bulan Mei -- cari 5 PO tsb + serial-nya"

# 2. Bandingkan dgn 5 serial yg di-WIP-out (sudah tahu dari investigasi sebelumnya)
Tab @"
select stok_id, evap, count(*) muncul_di_wipout
  from tsales2 s2, tsales1 s1
 where s1.bukti_id=s2.bukti_id and s1.tipe_trans='88'
   and s1.tgl between '2026-05-01' and '2026-05-31'
   and s2.stok_id like 'NR.%'
 group by stok_id, evap
"@ "2. Serial yg di-WIP-Out Mei (utk dibandingkan dgn serial yg dibeli)"

# 3. Cek SINV NR akhir Mei per stok_id (apakah item2 yg dibeli tapi TIDAK di-wipout muncul di SINV)
Tab @"
select sv.stok_id, cast(sv.qty as numeric(10,2)) qty, cast(sv.nilai as numeric(16,2)) nilai
  from sinv sv
 where sv.periode='2026-06-01' and sv.stok_id like 'NR.%' and (sv.qty<>0 or sv.nilai<>0)
 order by sv.stok_id
"@ "3. SINV NR akhir Mei (saldo awal Juni) per item"
$c.Close()
