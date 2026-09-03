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

# Rata-rata "bulan berjalan" yg BENAR utk tiap item NR *A yg pernah WIP-out Jan-Jun:
# opening SINV(BOM) + beli bulan itu (tipe 02) / (qty opening + qty beli bulan itu)
Tab @"
select z.stok_id, z.periode_bom,
       cast(isnull(sv.qty,0) as numeric(12,2)) opening_qty, cast(isnull(sv.nilai,0) as numeric(16,2)) opening_nilai,
       cast(isnull(b.beli_qty,0) as numeric(12,2)) beli_qty, cast(isnull(b.beli_rp,0) as numeric(16,2)) beli_rp,
       cast( (isnull(sv.nilai,0)+isnull(b.beli_rp,0)) / nullif(isnull(sv.qty,0)+isnull(b.beli_qty,0),0) as numeric(16,2)) avg_bulan_berjalan_benar
  from (
    select distinct s2.stok_id, dateadd(day, 1-day(s1.tgl), s1.tgl) periode_bom
      from tsales1 s1, tsales2 s2
     where s1.bukti_id=s2.bukti_id and s1.tipe_trans='88' and isnull(s2.evap,'')<>''
       and s1.tgl between '2026-01-01' and '2026-06-30'
       and s2.stok_id like 'NR.%A'
  ) z
  left join sinv sv on sv.stok_id=z.stok_id and sv.periode=z.periode_bom
  left join (
    select t2.stok_id, dateadd(day,1-day(t1.tgl),t1.tgl) periode_bulan, sum(t2.qty) beli_qty, sum(t2.netto) beli_rp
      from tstok1 t1, tstok2 t2
     where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02'
     group by t2.stok_id, dateadd(day,1-day(t1.tgl),t1.tgl)
  ) b on b.stok_id=z.stok_id and b.periode_bulan=z.periode_bom
 order by z.stok_id, z.periode_bom
"@ "1. Rata-rata bulan berjalan YG BENAR per item NR *A (opening+beli bulan itu)"
$c.Close()
