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

# 1. Item NR (102-003) yg WIP-Out '88' Jan-Jun, cek stale-freeze spt TR sebelumnya
Tab @"
select ip.produk_id, ipg.persediaan
  from im_produk ip join im_product_group ipg on ipg.kode_group=ip.group_product
 where ipg.persediaan='102-003'
"@ "1. Daftar produk_id di akun 102-003 (NR)"

Tab @"
select z.stok_id, z.evap, z.wo_bukti, z.voucher, z.tgl_wo, z.qty,
       cast(z.hpp_old as numeric(16,2)) hpp_beku,
       cast(isnull(sv.hpp_avg,0) as numeric(16,2)) tier1_sekarang,
       cast((isnull(sv.hpp_avg,0)-z.hpp_old)*z.qty as numeric(16,2)) delta
  from (
    select s2.stok_id, s2.evap, s1.bukti_id wo_bukti, s1.order_client voucher,
           s1.tgl tgl_wo, s2.qty, s2.hpp hpp_old,
           dateadd(day, 1-day(s1.tgl), s1.tgl) periode_bom
      from tsales1 s1, tsales2 s2
      join im_produk ip on ip.produk_id=s2.stok_id
      join im_product_group ipg on ipg.kode_group=ip.group_product
     where s1.bukti_id=s2.bukti_id and s1.tipe_trans='88' and isnull(s2.evap,'')<>''
       and s1.tgl between '2026-01-01' and '2026-06-30'
       and ipg.persediaan='102-003'
  ) z
  left join sinv sv on sv.stok_id=z.stok_id and sv.periode=z.periode_bom
 order by z.stok_id, z.tgl_wo
"@ "2. Semua WIP-Out 102-003 (NR) Jan-Jun -- cek frozen vs tier1 (mekanisme sama spt TR?)"

# 3. Cek total WIP-Out qty utk NR (mungkin bukan mekanisme WIP sama sekali)
Tab @"
select count(*) n_wipout_nr
  from tsales1 s1, tsales2 s2
  join im_produk ip on ip.produk_id=s2.stok_id
  join im_product_group ipg on ipg.kode_group=ip.group_product
 where s1.bukti_id=s2.bukti_id and s1.tipe_trans='88'
   and s1.tgl between '2026-01-01' and '2026-06-30'
   and ipg.persediaan='102-003'
"@ "3. Total baris WIP-Out 102-003 Jan-Jun (semua evap, termasuk kosong)"

# 4. Kapan tepatnya selisih 43.2jt mulai muncul -- cek per hari akhir April vs awal Mei
Tab @"
select cast(sum(sv.nilai) as numeric(18,2)) opname_akhir_apr
  from sinv sv join im_produk ip on ip.produk_id=sv.stok_id
  join im_product_group ipg on ipg.kode_group=ip.group_product
 where sv.periode='2026-05-01' and ipg.persediaan='102-003'
"@ "4a. Opname NR akhir April (=saldo awal Mei)"

Tab @"
select cast(g.tgl as date) tgl, g.voucher, g.modul_id, cast(g.debet as numeric(16,2)) debet, cast(g.kredit as numeric(16,2)) kredit, g.ket
  from gl_journal g
 where g.account_id='102-003' and g.tgl between '2026-05-01' and '2026-05-31'
 order by g.tgl
"@ "4b. Semua mutasi GL 102-003 bulan Mei (cari yg mencurigakan/besar)"
$c.Close()
