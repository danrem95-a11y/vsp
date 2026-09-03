$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=400; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    $n=0; while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | ")); $n++}
    if($n -eq 0){Write-Host "   <kosong>"}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

# link via voucher_manual: GL breakdown per akun utk penerimaan AR valas Jun
Qry "GL per akun utk receipt AR valas Jun (link voucher_manual)" @"
select g.account_id, max(gl.AccountDes) nm,
 cast(sum(g.debet) as numeric(20,2)) debet, cast(sum(g.kredit) as numeric(20,2)) kredit
from gl_journal g left join gl_acc gl on gl.AccountCode=g.account_id and gl.site_id='101'
where g.posting='P' and g.site_id='101' and g.voucher_manual in (
  select distinct t1.voucher_manual from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
  where t1.tgl>='2026-06-01' and t1.tgl<='2026-06-30' and t1.flag_bayar in (1,2)
    and abs(t2.nilai_bayar - t2.nilai_bayar_idr) >= 1
    and exists(select 1 from ar_trans a2 where a2.order_client=t2.bukti_id))
group by g.account_id order by abs(sum(g.debet-g.kredit)) desc
"@

# Ringkas: total tbyr_idr (opname kurangi) vs total 103-kredit (GL kurangi) vs selisih-kurs, utk receipt AR valas Jun
Qry "Ringkas Jun: opname-kurang vs GL-103-kredit vs selisih (link voucher_manual)" @"
select
 cast((select sum(t2.nilai_bayar_idr) from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
       where t1.tgl>='2026-06-01' and t1.tgl<='2026-06-30' and t1.flag_bayar in (1,2)
         and abs(t2.nilai_bayar - t2.nilai_bayar_idr) >= 1
         and exists(select 1 from ar_trans a2 where a2.order_client=t2.bukti_id)) as numeric(20,2)) opname_kurang,
 cast((select sum(g.kredit-g.debet) from gl_journal g where g.posting='P' and g.site_id='101' and g.account_id='103-001'
       and g.voucher_manual in (select distinct t1.voucher_manual from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
          where t1.tgl>='2026-06-01' and t1.tgl<='2026-06-30' and t1.flag_bayar in (1,2)
            and abs(t2.nilai_bayar - t2.nilai_bayar_idr) >= 1
            and exists(select 1 from ar_trans a2 where a2.order_client=t2.bukti_id))) as numeric(20,2)) gl103_kredit,
 cast((select sum(g.debet-g.kredit) from gl_journal g where g.posting='P' and g.site_id='101' and g.account_id in ('500-003','500-013')
       and g.voucher_manual in (select distinct t1.voucher_manual from tbyr1 t1 join tbyr2 t2 on t2.voucher=t1.voucher
          where t1.tgl>='2026-06-01' and t1.tgl<='2026-06-30' and t1.flag_bayar in (1,2)
            and abs(t2.nilai_bayar - t2.nilai_bayar_idr) >= 1
            and exists(select 1 from ar_trans a2 where a2.order_client=t2.bukti_id))) as numeric(20,2)) selisih_kurs
"@
$cn.Close()
