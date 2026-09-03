$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=800; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

$acc = "(select distinct persediaan acc from im_product_group where isnull(persediaan,'')<>'')"
function Mon($lbl,$bom,$eom,$next){ @"
select g.acc,
  cast(isnull(sz.stk,0)-isnull(sa.stk,0) as numeric(20,2))  mutasi_STOK,
  cast(isnull(mvm.mov,0) as numeric(20,2))                  mutasi_LEDGER,
  cast((isnull(sz.stk,0)-isnull(sa.stk,0))-isnull(mvm.mov,0) as numeric(20,2)) selisih_MUTASI,
  cast(isnull(sz.stk,0) as numeric(20,2))                   stok_akhir,
  cast(isnull(op.opn,0)+isnull(mve.mov,0) as numeric(20,2)) ledger_akhir,
  cast(isnull(sz.stk,0)-(isnull(op.opn,0)+isnull(mve.mov,0)) as numeric(20,2)) selisih_AKHIR
from $acc g
left join (select gr.persediaan acc,sum(s.nilai) stk from sinv s join im_produk pr on pr.produk_id=s.stok_id join im_product_group gr on gr.kode_group=pr.group_product where s.periode='$bom' group by gr.persediaan) sa on sa.acc=g.acc
left join (select gr.persediaan acc,sum(s.nilai) stk from sinv s join im_produk pr on pr.produk_id=s.stok_id join im_product_group gr on gr.kode_group=pr.group_product where s.periode='$next' group by gr.persediaan) sz on sz.acc=g.acc
left join (select accountcode acc,sum(amountdebet)-sum(amountcredit) opn from gl_balance where period='2026-01-01' group by accountcode) op on op.acc=g.acc
left join (select account_id acc,sum(debet)-sum(kredit) mov from gl_journal where posting='P' and tgl between '2026-01-01' and '$eom' group by account_id) mve on mve.acc=g.acc
left join (select account_id acc,sum(debet)-sum(kredit) mov from gl_journal where posting='P' and tgl between '$bom' and '$eom' group by account_id) mvm on mvm.acc=g.acc
order by g.acc
"@ }

Qry "JAN 2026  (mutasi STOK vs LEDGER  +  saldo akhir)" (Mon 'Jan' '2026-01-01' '2026-01-31' '2026-02-01')
Qry "FEB 2026  (mutasi STOK vs LEDGER  +  saldo akhir)" (Mon 'Feb' '2026-02-01' '2026-02-28' '2026-03-01')
Qry "MAR 2026  (mutasi STOK vs LEDGER  +  saldo akhir)" (Mon 'Mar' '2026-03-01' '2026-03-31' '2026-04-01')

# ---- Continuity: Saldo AKHIR Feb  =  Saldo AWAL Maret ----
Qry "KONTINUITAS: Saldo AKHIR Feb  vs  Saldo AWAL Maret (STOK & LEDGER)" @"
select g.acc,
  cast(isnull(fk.stk,0)  as numeric(20,2)) stok_akhir_feb,
  cast(isnull(ma.stk,0)  as numeric(20,2)) stok_awal_mar,
  cast(isnull(fk.stk,0)-isnull(ma.stk,0) as numeric(20,2)) sel_stok,
  cast(isnull(op.opn,0)+isnull(lf.mov,0) as numeric(20,2)) ledger_akhir_feb,
  cast(isnull(op.opn,0)+isnull(lf.mov,0) as numeric(20,2)) ledger_awal_mar
from $acc g
left join (select gr.persediaan acc,sum(s.nilai) stk from sinv s join im_produk pr on pr.produk_id=s.stok_id join im_product_group gr on gr.kode_group=pr.group_product where s.periode='2026-03-01' group by gr.persediaan) fk on fk.acc=g.acc
left join (select gr.persediaan acc,sum(s.nilai) stk from sinv s join im_produk pr on pr.produk_id=s.stok_id join im_product_group gr on gr.kode_group=pr.group_product where s.periode='2026-03-01' group by gr.persediaan) ma on ma.acc=g.acc
left join (select accountcode acc,sum(amountdebet)-sum(amountcredit) opn from gl_balance where period='2026-01-01' group by accountcode) op on op.acc=g.acc
left join (select account_id acc,sum(debet)-sum(kredit) mov from gl_journal where posting='P' and tgl between '2026-01-01' and '2026-02-28' group by account_id) lf on lf.acc=g.acc
order by g.acc
"@

# ---- TOTAL mutasi check per bulan (ringkas) ----
Qry "RINGKAS: total mutasi STOK vs LEDGER seluruh akun persediaan per bulan" @"
select 'Jan' bln,
  cast((select sum(nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where sv.periode='2026-02-01')
      -(select sum(nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where sv.periode='2026-01-01') as numeric(20,2)) mutasi_stok,
  cast((select sum(debet-kredit) from gl_journal where posting='P' and account_id in $acc and tgl between '2026-01-01' and '2026-01-31') as numeric(20,2)) mutasi_ledger
union all select 'Feb',
  cast((select sum(nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where sv.periode='2026-03-01')
      -(select sum(nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where sv.periode='2026-02-01') as numeric(20,2)),
  cast((select sum(debet-kredit) from gl_journal where posting='P' and account_id in $acc and tgl between '2026-02-01' and '2026-02-28') as numeric(20,2))
union all select 'Mar',
  cast((select sum(nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where sv.periode='2026-04-01')
      -(select sum(nilai) from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where sv.periode='2026-03-01') as numeric(20,2)),
  cast((select sum(debet-kredit) from gl_journal where posting='P' and account_id in $acc and tgl between '2026-03-01' and '2026-03-31') as numeric(20,2))
"@
$cn.Close()
