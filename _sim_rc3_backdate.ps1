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

# SIMULASI RC3: pakai basis NYATA TR.038A April (opening 6 unit / 1.522.286.198,94, beli=0 di April sekarang)
# Hipotesis: seandainya ADA koreksi plus dtgl April senilai Rp300.000.000 utk 1 unit (角度 what-if, TIDAK ditulis ke DB)
Tab @"
select
  cast(1522286198.94 as numeric(16,2)) opening_nilai_asli,
  cast(6 as numeric(12,2)) opening_qty_asli,
  cast(0 as numeric(16,2)) beli_nilai_SEBELUM_koreksi,
  cast(0 as numeric(12,2)) beli_qty_SEBELUM_koreksi,
  cast(1522286198.94/6 as numeric(16,2)) average_SEBELUM_koreksi_ada,
  cast(300000000 as numeric(16,2)) hipotesis_koreksi_plus_nilai,
  cast(1 as numeric(12,2)) hipotesis_koreksi_plus_qty,
  cast((1522286198.94+300000000)/(6+1) as numeric(16,2)) average_SESUDAH_koreksi_hipotesis
"@ "RC3a. Simulasi what-if: dampak 1 koreksi plus Rp300jt terhadap average TR.038A April (aritmatika murni, TIDAK ditulis ke DB)"

# RC3b: buktikan SEMUA 6 EVAP TR.038A April akan menerima average BARU yg SAMA (bukan sebagian)
# -- ini krn WHERE clause tier1/4b tidak diskriminasi per-EVAP, semua baca dari costing_helper_movavg row yg SAMA (per stok_id+periode)
Tab @"
select s2.stok_id, s2.evap, s1.bukti_id, s1.tgl,
       cast(s2.hpp as numeric(16,2)) hpp_SEBELUM_hipotesis_koreksi,
       cast((1522286198.94+300000000)/(6+1) as numeric(16,2)) hpp_SESUDAH_hipotesis_koreksi_SEHARUSNYA
  from tsales1 s1, tsales2 s2
 where s1.bukti_id=s2.bukti_id and s1.tipe_trans='88' and s2.stok_id='TR.038A'
   and s1.tgl between '2026-04-01' and '2026-04-30'
 order by s1.tgl
"@ "RC3b. Bukti SEMUA 6 EVAP April menerima average baru yg SAMA (satu formula per stok_id+bulan, bukan per-EVAP terpisah)"

# RC3c: bukti step 4b (penjualan pakai EVAP) akan ikut cascade -- cek apakah ada baris '22' yg evap-nya match salah satu dari 6 serial ini
Tab @"
select s2.stok_id, s2.evap, s1.bukti_id, s1.tgl, cast(s2.hpp as numeric(16,2)) hpp_penjualan_sekarang
  from tsales1 s1, tsales2 s2
 where s1.bukti_id=s2.bukti_id and s1.tipe_trans<>'88'
   and s2.evap in ('CIM1091571','CIM1081816','CIM1091575','CIM1091572','CIM1090965','CIM1090964')
"@ "RC3c. Cek apakah ada penjualan yg pakai salah satu EVAP TR.038A April ini (utk verifikasi cascade step 4b)"
$c.Close()
