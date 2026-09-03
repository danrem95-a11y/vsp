$csP = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$P = New-Object System.Data.Odbc.OdbcConnection $csP; $P.Open()
function Rows($sql){ $c=$P.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql; $o=@(); $rd=$c.ExecuteReader(); while($rd.Read()){ $r=@{}; for($i=0;$i -lt $rd.FieldCount;$i++){$r[$rd.GetName($i)]=$rd[$i]}; $o+=$r }; $rd.Close(); return $o }
function Show($lbl,$sql){ Write-Host "== $lbl =="; $c=$P.CreateCommand(); $c.CommandTimeout=300; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $a=@();for($i=0;$i -lt $rd.FieldCount;$i++){$a+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($a -join " | "))}; if(-not $any){Write-Host "  (kosong)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Show "1. TOTAL cons-in '88' 2025 (tstok) utk 102-001 & 102-006 - vs selisih akun" @"
select gr.persediaan akun, count(*) n_baris, cast(sum(t2.qty) as numeric(18,2)) qty, cast(sum(t2.netto) as numeric(18,2)) nilai
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id join im_produk pr on pr.produk_id=t2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan in ('102-001','102-006') and t1.tipe_trans='88' and t1.tgl>='2025-01-01' and t1.tgl<'2026-01-01'
group by gr.persediaan order by gr.persediaan
"@

Show "2. Supplier/pemilik konsinyasi (vendor '88' cons-in 2025) 102-001/006" @"
select t1.vendor_id, left(max(isnull(s.nama,'')),26) nama, count(*) n, cast(sum(t2.qty) as numeric(18,2)) qty, cast(sum(t2.netto) as numeric(18,2)) nilai
from tstok1 t1 join tstok2 t2 on t1.bukti_id=t2.bukti_id join im_produk pr on pr.produk_id=t2.stok_id join im_product_group gr on gr.kode_group=pr.group_product
 left join mcstsupp s on s.vendor_id=t1.vendor_id
where gr.persediaan in ('102-001','102-006') and t1.tipe_trans='88' and t1.tgl>='2025-01-01' and t1.tgl<'2026-01-01'
group by t1.vendor_id order by sum(t2.netto) desc
"@

# Per item: sinv year-end vs cons-in '88' 2025 -> CSV
$items = Rows @"
select gr.persediaan akun, sv.stok_id, left(max(pr.produk_desc),40) nm,
  cast(sum(sv.qty) as numeric(18,2)) sinv_qty, cast(sum(sv.nilai) as numeric(18,2)) sinv_nilai,
  cast(isnull((select sum(b.qty) from tstok1 a join tstok2 b on a.bukti_id=b.bukti_id where b.stok_id=sv.stok_id and a.tipe_trans='88' and a.tgl>='2025-01-01' and a.tgl<'2026-01-01'),0) as numeric(18,2)) consin88_qty,
  cast(isnull((select sum(b.netto) from tstok1 a join tstok2 b on a.bukti_id=b.bukti_id where b.stok_id=sv.stok_id and a.tipe_trans='88' and a.tgl>='2025-01-01' and a.tgl<'2026-01-01'),0) as numeric(18,2)) consin88_nilai
from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product
where gr.persediaan in ('102-001','102-006') and sv.periode='2026-01-01' and sv.qty<>0 group by gr.persediaan, sv.stok_id
"@
$obj = $items | ForEach-Object { [pscustomobject]@{ akun=$_.akun; stok_id=$_.stok_id; nama=$_.nm; sinv_qty=$_.sinv_qty; sinv_nilai=$_.sinv_nilai; consin88_2025_qty=$_.consin88_qty; consin88_2025_nilai=$_.consin88_nilai } }
$csv="C:\BTV\debug\KONSINYASI_88_perItem.csv"
$obj | Sort-Object akun, { -[decimal]$_.sinv_nilai } | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
Write-Host "`nCSV per-item (sinv vs cons-in '88'): $csv"
Write-Host "`n== Top 12 item (102-001/006): sinv_qty | sinv_nilai | consin88_qty =="
$obj | Sort-Object { -[decimal]$_.sinv_nilai } | Select-Object -First 12 | ForEach-Object {
  Write-Host ("  {0} {1,-26} sinvQ={2,6:N0} sinvRp={3,18:N2} consinQ={4,6:N0}" -f $_.akun,$_.nama.PadRight(26).Substring(0,26),[decimal]$_.sinv_qty,[decimal]$_.sinv_nilai,[decimal]$_.consin88_2025_qty)
}
$P.Close()
