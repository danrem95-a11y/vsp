$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=90; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 40){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N4}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 40){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}

# ===== RC2: Verifikasi matematis murni formula (opening+beli)/(qty) =====
Tab @"
select cast((200000+400000) as numeric(16,2)) nilai_total,
       cast((100+100) as numeric(12,2)) qty_total,
       cast((200000+400000)/(100+100) as numeric(16,2)) average_hasil_formula
"@ "RC2. Verifikasi aritmatika murni formula opening+beli (contoh Bapak: harus =3000)"

# ===== RC1: Pilih 1 WIP-Out April nyata yg sudah dikoreksi sesi ini, buktikan formula BARU cocok dgn hasil koreksi manual =====
Tab @"
select z.stok_id, z.evap, z.wo_bukti, z.tgl_wo,
       cast(z.hpp_sekarang as numeric(16,2)) hpp_tersimpan_sekarang,
       cast(h.opening_nilai as numeric(16,2)) opening_nilai,
       cast(h.opening_qty as numeric(12,2)) opening_qty,
       cast(h.beli_nilai as numeric(16,2)) beli_nilai,
       cast(h.beli_qty as numeric(12,2)) beli_qty,
       cast( (isnull(h.opening_nilai,0)+isnull(h.beli_nilai,0)) / nullif(isnull(h.opening_qty,0)+isnull(h.beli_qty,0),0) as numeric(16,2)) formula_baru_hasil
  from (
    select s2.stok_id, s2.evap, s1.bukti_id wo_bukti, s1.tgl tgl_wo, s2.hpp hpp_sekarang,
           dateadd(day,1-day(s1.tgl),s1.tgl) periode_bom
      from tsales1 s1, tsales2 s2
     where s1.bukti_id=s2.bukti_id and s1.tipe_trans='88' and isnull(s2.evap,'')<>''
       and s1.tgl between '2026-04-01' and '2026-04-30' and s2.stok_id='TR.038A'
  ) z
  left join ( -- replikasi PERSIS logika costing_helper_movavg utk 1 stok_id+1 bulan (read-only, tdk nulis ke tabel)
    select x.stok_id,
           isnull(o.oqty,0) opening_qty, isnull(o.onil,0) opening_nilai,
           isnull(b.bqty,0) beli_qty, isnull(b.bnil,0) beli_nilai
      from ( select 'TR.038A' stok_id ) x
      left join ( select stok_id, sum(isnull(qty,0)) oqty, sum(isnull(nilai,0)) onil from sinv where periode='2026-04-01' and stok_id='TR.038A' group by stok_id ) o on o.stok_id=x.stok_id
      left join (
        select u.stok_id sid, sum(u.qty) bqty, sum(u.nilai) bnil
          from (
            select t2.stok_id, isnull(t2.qty,0) qty, isnull(t2.netto,0)*isnull(t1.kurs,1) nilai
              from tstok1 t1, tstok2 t2
             where t1.bukti_id=t2.bukti_id and t1.tipe_trans='02' and isnull(t1.order_oke,'N')='Y'
               and t1.tgl between '2026-04-01' and '2026-04-30' and t2.stok_id='TR.038A'
            union all
            select t2.stok_id, 0, abs(isnull(t2.biaya_ekspedisi,0))*abs(isnull(t2.qty,0))
              from tstok1 t1, tstok2 t2
             where t1.bukti_id=t2.bukti_id and t1.tipe_trans='05'
               and t1.tgl between '2026-04-01' and '2026-04-30' and t2.stok_id='TR.038A'
            union all
            select t2.stok_id, isnull(t2.qty,0), isnull(t2.netto,0)
              from tstok1 t1, tstok2 t2
             where t1.bukti_id=t2.bukti_id and t1.tipe_trans='09'
               and t1.tgl between '2026-04-01' and '2026-04-30' and t2.stok_id='TR.038A'
            union all
            select s2.stok_id, isnull(s2.qty,0), abs(isnull(s2.netto,0)*isnull(s1.kurs,1))
              from tsales1 s1, tsales2 s2, mcust c
             where s1.bukti_id=s2.bukti_id and s1.cust_id=c.cust_id and s1.tipe_trans in ('32','26','36')
               and s1.tgl between '2026-04-01' and '2026-04-30' and s2.stok_id='TR.038A'
               and isnull(s2.qty,0)<>0 and isnull(s2.hrg,0)<>0
          ) u
         group by u.stok_id
      ) b on b.sid=x.stok_id
  ) h on h.stok_id=z.stok_id
 order by z.tgl_wo
"@ "RC1. Simulasi formula BARU (tier1) utk TR.038A April 2026 -- bandingkan dgn HPP tersimpan (hasil koreksi Round1-3)"
$c.Close()
