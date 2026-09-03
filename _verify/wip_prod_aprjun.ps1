$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=800; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $n=0; $out=@(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};$out+=("      "+($l -join " | ")); $n++}; $rd.Close()
    if($n -eq 0){Write-Host ("  [LULUS] "+$lbl)}else{Write-Host ("  [!! "+$n+" temuan] "+$lbl); $out | ForEach-Object{Write-Host $_}} }
  catch{Write-Host("  ERR "+$lbl+": "+$_.Exception.Message)} }

foreach($per in @(@('Apr','2026-04-01','2026-04-30','2026-05-01'), @('Mei','2026-05-01','2026-05-31','2026-06-01'), @('Jun','2026-06-01','2026-06-30','2026-07-01'))){
 $lbl=$per[0]; $m1=$per[1]; $m2=$per[2]; $snext=$per[3]
 $basis = $m1
 Write-Host ""; Write-Host "===== $lbl 2026 ====="
 Qry "G1 qty=0 nilai<>0 (residu nyangkut)" "select sv.stok_id,gr.persediaan,cast(sv.qty as numeric(18,2)) qty,cast(sv.nilai as numeric(18,2)) nilai from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where sv.periode='$snext' and sv.qty=0 and abs(sv.nilai)>1000 order by abs(sv.nilai) desc"
 Qry "G2 hpp_avg negatif (movavg rusak)" "select sv.stok_id,gr.persediaan,cast(sv.qty as numeric(18,2)) qty,cast(sv.hpp_avg as numeric(18,2)) hpp_avg from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where sv.periode='$snext' and sv.hpp_avg<0 order by sv.hpp_avg asc"
 Qry "G3 WIP-Out '88' menyimpang dari basis SINV awal bln" "select x.stok_id,cast(x.hpp_out as numeric(18,2)) hpp_out,cast(x.basis as numeric(18,2)) basis from (select s2.stok_id,max(s2.hpp) hpp_out,(select sum(hpp_avg) from sinv where stok_id=s2.stok_id and periode='$basis') basis from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id where s1.tipe_trans='88' and s1.tgl between '$m1' and '$m2' and isnull(s2.evap,'')<>'' group by s2.stok_id) x where x.basis is not null and abs(isnull(x.hpp_out,0)-isnull(x.basis,0))>1000 order by x.stok_id"
 Qry "G4 KONSINYASI WIP-Out<>WIP-In (pasangan sudah In)" "select o.stok_id,o.evap,cast(o.hpp_out as numeric(18,2)) hpp_out,cast(i.hpp_in as numeric(18,2)) hpp_in,cast(o.hpp_out-i.hpp_in as numeric(18,2)) selisih from (select s2.stok_id,s2.evap,s2.hpp hpp_out from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id where s1.tipe_trans='88' and s1.tgl between '$m1' and '$m2' and isnull(s2.evap,'')<>'') o join (select t2.stok_id,t2.coa_id evap,t2.hpp hpp_in from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t1.tipe_trans='88' and isnull(t2.coa_id,'')<>'') i on i.stok_id=o.stok_id and i.evap=o.evap where abs(isnull(o.hpp_out,0)-isnull(i.hpp_in,0))>1 order by o.stok_id"
 Qry "G5 WIP-sale <> WIP-Out beku" "select s1.bukti_id,s2.stok_id,s2.evap,cast(s2.hpp as numeric(18,2)) hpp_sale,cast((select max(c2.hpp) from tsales1 c1 join tsales2 c2 on c1.bukti_id=c2.bukti_id where c1.tipe_trans='88' and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0) as numeric(18,2)) hpp_wipout from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id where s1.tipe_trans in ('22','32','26','36') and isnull(s2.evap,'')<>'' and s1.tgl between '$m1' and '$m2' and exists(select 1 from tsales1 c1 join tsales2 c2 on c1.bukti_id=c2.bukti_id where c1.tipe_trans='88' and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0) and abs(isnull(s2.hpp,0)-isnull((select max(c2.hpp) from tsales1 c1 join tsales2 c2 on c1.bukti_id=c2.bukti_id where c1.tipe_trans='88' and c2.stok_id=s2.stok_id and c2.evap=s2.evap and isnull(c2.hpp,0)>0),0))>1 order by s2.stok_id"
}

Write-Host ""; Write-Host "===== INV-03 outstanding WIP-Out vs GL 102-020 (informasional, Jan-Jun) ====="
foreach($eom in @('2026-01-31','2026-02-28','2026-03-31','2026-04-30','2026-05-31','2026-06-30')){
 $c=$cn.CreateCommand(); $c.CommandTimeout=800
 $c.CommandText="select cast((select sum(isnull(s2.hpp,0)*isnull(s2.qty,0)) from tsales1 s1 join tsales2 s2 on s1.bukti_id=s2.bukti_id where s1.tipe_trans='88' and isnull(s2.evap,'')<>'' and s1.tgl<='$eom' and not exists(select 1 from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id where t1.tipe_trans='88' and t2.stok_id=s2.stok_id and isnull(t2.coa_id,'')=s2.evap and t1.tgl<='$eom')) as numeric(20,2)) wipout, cast((select isnull(sum(amountdebet-amountcredit),0) from gl_balance where accountcode='102-020' and period='2026-01-01')+(select isnull(sum(debet-kredit),0) from gl_journal where posting='P' and account_id='102-020' and tgl between '2026-01-01' and '$eom') as numeric(20,2)) gl102020"
 $rd=$c.ExecuteReader(); while($rd.Read()){Write-Host ("  @"+$eom+"  outstanding_WIPout="+[string]$rd[0]+"   GL_102-020="+[string]$rd[1])}; $rd.Close()
}

Write-Host ""; Write-Host "===== 102-020 Ledger vs Mutasi Stok per bulan (langsung, spt akun lain) ====="
$months = @('2026-01-01','2026-02-01','2026-03-01','2026-04-01','2026-05-01','2026-06-01','2026-07-01')
$monthnames=@{0='Jan';1='Feb';2='Mar';3='Apr';4='Mei';5='Jun'}
for($i=0;$i -lt 6;$i++){
  $m0=$months[$i]; $m1=$months[$i+1]; $mend=(Get-Date $m1).AddDays(-1).ToString('yyyy-MM-dd')
  $c=$cn.CreateCommand(); $c.CommandTimeout=800
  $c.CommandText="select cast(isnull((select sum(sv.nilai) from sinv sv join im_produk ip on ip.produk_id=sv.stok_id join im_product_group ipg on ipg.kode_group=ip.group_product where ipg.persediaan='102-020' and sv.periode='$m0'),0) as numeric(20,2)) sinv_open, cast(isnull((select sum(sv.nilai) from sinv sv join im_produk ip on ip.produk_id=sv.stok_id join im_product_group ipg on ipg.kode_group=ip.group_product where ipg.persediaan='102-020' and sv.periode='$m1'),0) as numeric(20,2)) sinv_close, cast(isnull((select sum(g.debet-g.kredit) from gl_journal g where g.account_id='102-020' and g.tgl between '$m0' and '$mend'),0) as numeric(20,2)) gl_mutasi"
  $rd=$c.ExecuteReader()
  while($rd.Read()){
    $so=[decimal]$rd[0]; $sc=[decimal]$rd[1]; $gm=[decimal]$rd[2]; $sm=$sc-$so; $sel=$gm-$sm
    Write-Host ("  "+$monthnames[$i]+" | open="+$so.ToString('N2')+" | close="+$sc.ToString('N2')+" | mutasi_sinv="+$sm.ToString('N2')+" | mutasi_gl="+$gm.ToString('N2')+" | selisih="+$sel.ToString('N2'))
  }
  $rd.Close()
}
$cn.Close()
