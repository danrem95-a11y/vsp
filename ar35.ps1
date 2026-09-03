$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $cmd=$cn.CreateCommand(); $cmd.CommandTimeout=200; $cmd.CommandText=$sql
  try{$rd=$cmd.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "A. Ledger 103-001 saldo akhir per bulan 2026 (referensi yg TETAP)" @"
select mm, cast(sum(mut) over (order by mm) as numeric(18,2)) saldo_akhir from (
  select month(tgl) mm, cast(sum(debet-kredit) as numeric(18,2)) mut from gl_journal
  where posting='P' and account_id='103-001' and tgl>='2026-01-01' and tgl<'2026-07-01' group by month(tgl)
) x order by mm
"@

Qry "B. TBYR (pembayaran AR) senilai 35.000.000 - adakah? tgl?" @"
select t1.voucher, t1.voucher_manual, t1.tgl, t1.kas_id, t1.flag_bayar, t1.flag_vendor,
   cast(t2.nilai_bayar_idr as numeric(18,2)) bayar, t2.bukti_id
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
where abs(t2.nilai_bayar_idr-35000000)<1 and t1.tgl>='2026-01-01' and t1.tgl<'2026-07-01'
order by t1.tgl
"@

Qry "C. gl_journal 103-001 kredit (pembayaran ke GL) senilai 35jt - GL punya?" @"
select voucher, voucher_manual, tgl, cast(kredit as numeric(18,2)) kredit, modul_id, left(ket,40) ket
from gl_journal where posting='P' and account_id='103-001' and abs(kredit-35000000)<1 and tgl>='2026-01-01' and tgl<'2026-07-01'
order by tgl
"@

Qry "D. SALDO_AWAL_FAKTUR (opening AR) senilai 35jt" @"
select bukti_id, vendor_id, tipe_trans, periode, cast(new_saldo as numeric(18,2)) new_saldo, cast(saldo as numeric(18,2)) saldo
from saldo_awal_faktur where (abs(isnull(new_saldo,0)-35000000)<1 or abs(isnull(saldo,0)-35000000)<1)
order by periode
"@

Qry "E. TBYR2_PUTIH (DP) senilai 35jt" @"
select bukti_id, tgl_bayar, flag_order, cast(nilai_bayar_idr as numeric(18,2)) bayar
from tbyr2_putih where abs(nilai_bayar_idr-35000000)<1 and tgl_bayar>='2026-01-01' and tgl_bayar<'2026-07-01'
order by tgl_bayar
"@

Qry "F. AR_TRANS faktur senilai 35jt Feb" @"
select order_client, cust_id, tipe_trans, tgl, cast(ttl_netto as numeric(18,2)) ttl
from ar_trans where abs(isnull(ttl_netto,0)-35000000)<1 and tgl>='2026-02-01' and tgl<'2026-03-01' and order_oke='Y'
order by tgl
"@

$cn.Close()
