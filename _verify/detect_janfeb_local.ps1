$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=localhost;port=2638);ENG=vsp;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong / LULUS>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

# ---- STOK per-account decomposition at FEB closing (sinv 2026-03-01 vs opening+movement Jan-Feb) ----
Qry "STOK per-akun @ Feb closing (sinv 2026-03-01 vs GL opening+mvmt)" @"
select g.acc,
  cast(isnull(sv.sinv,0) as numeric(20,2)) sinv_nilai,
  cast(isnull(op.opn,0)+isnull(mv.mov,0) as numeric(20,2)) gl_nilai,
  cast(isnull(sv.sinv,0)-(isnull(op.opn,0)+isnull(mv.mov,0)) as numeric(20,2)) selisih
from (select distinct persediaan acc from im_product_group where isnull(persediaan,'')<>'') g
left join (select gr.persediaan acc, sum(s.nilai) sinv from sinv s join im_produk pr on pr.produk_id=s.stok_id join im_product_group gr on gr.kode_group=pr.group_product where s.periode='2026-03-01' group by gr.persediaan) sv on sv.acc=g.acc
left join (select accountcode acc, sum(amountdebet)-sum(amountcredit) opn from gl_balance where period='2026-01-01' group by accountcode) op on op.acc=g.acc
left join (select account_id acc, sum(debet)-sum(kredit) mov from gl_journal where posting='P' and tgl between '2026-01-01' and '2026-02-28' group by account_id) mv on mv.acc=g.acc
where abs(isnull(sv.sinv,0)-(isnull(op.opn,0)+isnull(mv.mov,0)))>1
order by abs(isnull(sv.sinv,0)-(isnull(op.opn,0)+isnull(mv.mov,0))) desc
"@

# ---- STOK MUTASI-only check: does the movement match (offset constant Jan vs Feb)? ----
Qry "STOK offset Jan vs Feb (harus KONSTAN = pure saldo-awal, mutasi bersih)" @"
select 'Jan' bln, cast(sum(sv.nilai) as numeric(20,2)) sinv,
  cast((select isnull(sum(amountdebet-amountcredit),0) from gl_balance where accountcode in (select distinct persediaan from im_product_group where isnull(persediaan,'')<>'') and period='2026-01-01')
     + (select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and account_id in (select distinct persediaan from im_product_group where isnull(persediaan,'')<>'') and tgl between '2026-01-01' and '2026-01-31') as numeric(20,2)) gl
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where sv.periode='2026-02-01'
union all
select 'Feb', cast(sum(sv.nilai) as numeric(20,2)),
  cast((select isnull(sum(amountdebet-amountcredit),0) from gl_balance where accountcode in (select distinct persediaan from im_product_group where isnull(persediaan,'')<>'') and period='2026-01-01')
     + (select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and account_id in (select distinct persediaan from im_product_group where isnull(persediaan,'')<>'') and tgl between '2026-01-01' and '2026-02-28') as numeric(20,2))
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where sv.periode='2026-03-01'
"@

# ================= WIP / KONSINYASI residue gates =================
foreach($per in @(@('Jan','2026-01-01','2026-01-31','2026-02-01'), @('Feb','2026-02-01','2026-02-28','2026-03-01'))){
 $lbl=$per[0]; $m1=$per[1]; $m2=$per[2]; $snext=$per[3]

 Qry "[$lbl] G1 qty=0 tapi nilai<>0 (residu nyangkut) @ sinv $snext" @"
select sv.stok_id, gr.persediaan, cast(sv.qty as numeric(18,2)) qty, cast(sv.nilai as numeric(18,2)) nilai
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where sv.periode='$snext' and sv.qty=0 and abs(sv.nilai)>1000 order by abs(sv.nilai) desc
"@

 Qry "[$lbl] G2 hpp_avg NEGATIF (moving-avg rusak) @ sinv $snext" @"
select sv.stok_id, gr.persediaan, cast(sv.qty as numeric(18,2)) qty, cast(sv.hpp_avg as numeric(18,2)) hpp_avg, cast(sv.nilai as numeric(18,2)) nilai
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where sv.periode='$snext' and sv.hpp_avg<0 order by sv.hpp_avg asc
"@

 Qry "[$lbl] G4 KONSINYASI WIP-Out<>WIP-In (pasangan sudah In, selisih>1)" @"
select o.stok_id, o.evap, cast(o.hpp_out as numeric(18,2)) hpp_out, cast(i.hpp_in as numeric(18,2)) hpp_in, cast(o.hpp_out-i.hpp_in as numeric(18,2)) selisih
from (select s2.stok_id, s2.evap, s2.hpp hpp_out from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
      where s1.tipe_trans='88' and s1.tgl between '$m1' and '$m2' and isnull(s2.evap,'')<>'') o
join (select t2.stok_id, t2.coa_id evap, t2.hpp hpp_in from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id
      where t1.tipe_trans='88' and isnull(t2.coa_id,'')<>'') i on i.stok_id=o.stok_id and i.evap=o.evap
where abs(isnull(o.hpp_out,0)-isnull(i.hpp_in,0))>1 order by o.stok_id
"@

 Qry "[$lbl] G5 WIP-sale <> WIP-Out beku (bocor average, selisih>1)" @"
select s1.bukti_id, s2.stok_id, s2.evap, cast(s2.hpp as numeric(18,2)) hpp_sale,
  cast((select max(c2.hpp) from tsales1 c1 join tsales2 c2 on c1.bukti_id=c2.bukti_id where c1.tipe_trans='88' and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0) as numeric(18,2)) hpp_wipout
from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
where s1.tipe_trans in ('22','32','26','36') and isnull(s2.evap,'')<>'' and s1.tgl between '$m1' and '$m2'
  and exists (select 1 from tsales1 c1 join tsales2 c2 on c1.bukti_id=c2.bukti_id where c1.tipe_trans='88' and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0)
  and abs(isnull(s2.hpp,0)-isnull((select max(c2.hpp) from tsales1 c1 join tsales2 c2 on c1.bukti_id=c2.bukti_id where c1.tipe_trans='88' and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0),0))>1
order by s2.stok_id
"@
}

# ---- INV-03 outstanding WIP-Out vs GL 102-020 @ Feb eom ----
Qry "INV-03 outstanding WIP-Out (belum di-In) vs GL 102-020 @ 2026-02-28 (informasional)" @"
select cast((select sum(isnull(s2.hpp,0)*isnull(s2.qty,0)) from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id
        where s1.tipe_trans='88' and isnull(s2.evap,'')<>'' and s1.tgl<='2026-02-28'
        and not exists (select 1 from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t1.tipe_trans='88' and t2.stok_id=s2.stok_id and isnull(t2.coa_id,'')=s2.evap and t1.tgl<='2026-02-28')) as numeric(20,2)) outstanding_wipout,
  cast((select isnull(sum(amountdebet-amountcredit),0) from gl_balance where accountcode='102-020' and period='2026-01-01')
     + (select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and account_id='102-020' and tgl between '2026-01-01' and '2026-02-28') as numeric(20,2)) gl_102020
"@
$cn.Close()
