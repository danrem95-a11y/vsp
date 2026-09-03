$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=150; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 45){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 45){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}

Tab @"
select z.stok_id, z.evap, z.wo_bukti, z.voucher, z.tgl_wo, z.qty,
       cast(z.hpp_old as numeric(16,2)) hpp_beku,
       cast(isnull(sv.hpp_avg,0) as numeric(16,2)) tier1_sekarang,
       cast((isnull(sv.hpp_avg,0)-z.hpp_old)*z.qty as numeric(16,2)) delta,
       case when m.wo_bukti is not null then 'SUDAH_DIKOREKSI_SEBELUMNYA' else 'BARU' end status
  from (
    select s2.stok_id, s2.evap, s1.bukti_id wo_bukti, s1.order_client voucher,
           s1.tgl tgl_wo, s2.qty, s2.hpp hpp_old,
           dateadd(day, 1-day(s1.tgl), s1.tgl) periode_bom
      from tsales1 s1, tsales2 s2
     where s1.bukti_id=s2.bukti_id and s1.tipe_trans='88' and isnull(s2.evap,'')<>''
       and s1.tgl between '2026-01-01' and '2026-06-30'
  ) z
  left join sinv sv on sv.stok_id=z.stok_id and sv.periode=z.periode_bom
  left join ZZ_WIPFIX_MAP_20260810 m on m.wo_bukti=z.wo_bukti and m.stok_id=z.stok_id and isnull(m.evap,'')=isnull(z.evap,'')
 where isnull(sv.hpp_avg,0) > 0
   and abs(z.hpp_old - isnull(sv.hpp_avg,0)) > 1
 order by z.stok_id, z.tgl_wo
"@ "16 baris stale SEKARANG -- baru atau overlap dgn 39 yg sudah dikoreksi?"
$c.Close()
