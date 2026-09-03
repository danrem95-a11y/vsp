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

$map = @"
    select z.stok_id, z.evap, z.wo_bukti, z.voucher, z.tgl_wo, z.qty, z.hpp_old,
           isnull(sv.hpp_avg,0) hpp_new, z.bukti_id_22
      from (
        select s2.stok_id, s2.evap, s1.bukti_id wo_bukti, s1.order_client voucher,
               s1.tgl tgl_wo, s2.qty, s2.hpp hpp_old,
               dateadd(day, 1-day(s1.tgl), s1.tgl) periode_bom,
               (select s1b.bukti_id from tsales1 s1b, tsales2 s2b
                  where s1b.bukti_id=s2b.bukti_id and s1b.tipe_trans='22'
                    and s2b.stok_id=s2.stok_id and isnull(s2b.evap,'')=isnull(s2.evap,'')) bukti_id_22
          from tsales1 s1, tsales2 s2
         where s1.bukti_id=s2.bukti_id and s1.tipe_trans='88' and isnull(s2.evap,'')<>''
           and s1.tgl between '2026-01-01' and '2026-06-30'
      ) z
      left join sinv sv on sv.stok_id=z.stok_id and sv.periode=z.periode_bom
     where isnull(sv.hpp_avg,0) > 0
       and abs(z.hpp_old - isnull(sv.hpp_avg,0)) > 1
"@

Tab "select count(*) n_map, sum(case when bukti_id_22 is null then 1 else 0 end) n_22_null from ($map) zz" "0b. Peta Round2 (harus 16, n_22_null=0)"

Tab @"
select count(*) n_match_tstok2
  from ($map) zz, tstok2 t2x
 where t2x.bukti_id = ('102'+substr(zz.bukti_id_22,4,11)) and t2x.stok_id=zz.stok_id
   and isnull(t2x.coa_id,'')=zz.evap
"@ "STEP4 simulasi -- match TSTOK2 dgn guard (harus 16)"

Tab @"
select count(*) n_match_gl_dr
  from ( select voucher, cast(sum(hpp_new*qty) as numeric(16,2)) new_total from ($map) zz group by voucher ) t, gl_journal g
 where g.voucher=t.voucher and g.account_id='102-020' and g.modul_id='AS'
"@ "STEP5 simulasi -- match GL Dr (harus 16, atau jumlah voucher distinct)"
$c.Close()
