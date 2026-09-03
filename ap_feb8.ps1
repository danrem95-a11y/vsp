$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "1. Di GL, ke mana 4 nilai DP ini dibukukan? (cari by nominal)" @"
select account_id, voucher, modul_id, tgl, cast(debet as numeric(18,2)) debet, cast(kredit as numeric(18,2)) kredit, left(ket,40) ket
from gl_journal where posting='P'
 and (debet in (408727854,358602456,191590656,190783392) or kredit in (408727854,358602456,191590656,190783392))
order by tgl, voucher, account_id
"@

Qry "2. TBYR2_PUTIH (tabel DP) memuat bukti ini?" @"
select bukti_id, flag_order, cast(nilai_bayar as numeric(18,2)) nb, cast(nilai_bayar_idr as numeric(18,2)) nb_idr, tgl_bayar
from tbyr2_putih where bukti_id in ('101BTB260200033','101BTB260200020','101BTB260200029','101BTB260200028')
"@

Qry "3. Semua pembayaran DPB (voucher_manual like DPB) per BULAN via tbyr" @"
select month(t1.tgl) bln, cast(sum(t2.nilai_bayar_idr) as numeric(18,2)) total_dpb_idr
from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
where t1.tgl>='2026-01-01' and t1.tgl<'2026-07-01' and t1.flag_bayar in (1,2)
  and upper(t1.voucher_manual) like '%DPB%'
group by month(t1.tgl) order by month(t1.tgl)
"@

Qry "4. Kumulatif DPB tbyr s/d akhir tiap bulan (vs gap AP)" @"
select 'sd_Feb' p, cast(sum(t2.nilai_bayar_idr) as numeric(18,2)) v from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher where t1.flag_bayar in (1,2) and upper(t1.voucher_manual) like '%DPB%' and t1.tgl<'2026-03-01'
union all select 'sd_Mar', cast(sum(t2.nilai_bayar_idr) as numeric(18,2)) from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher where t1.flag_bayar in (1,2) and upper(t1.voucher_manual) like '%DPB%' and t1.tgl<'2026-04-01'
union all select 'sd_Apr', cast(sum(t2.nilai_bayar_idr) as numeric(18,2)) from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher where t1.flag_bayar in (1,2) and upper(t1.voucher_manual) like '%DPB%' and t1.tgl<'2026-05-01'
union all select 'sd_Mei', cast(sum(t2.nilai_bayar_idr) as numeric(18,2)) from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher where t1.flag_bayar in (1,2) and upper(t1.voucher_manual) like '%DPB%' and t1.tgl<'2026-06-01'
union all select 'sd_Jun', cast(sum(t2.nilai_bayar_idr) as numeric(18,2)) from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher where t1.flag_bayar in (1,2) and upper(t1.voucher_manual) like '%DPB%' and t1.tgl<'2026-07-01'
"@
$cn.Close()
