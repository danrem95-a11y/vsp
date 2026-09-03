$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=240; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }
function Exec($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=240; $c.CommandText=$sql
  try{$n=$c.ExecuteNonQuery(); Write-Host ("  OK rows="+$n)}catch{Write-Host ("  ERR: "+$_.Exception.Message)} }

Write-Host "=== BEFORE: baris orphan voucher 10203260600055 (modul AS) ==="
Reader @"
select account_id, cast(debet as numeric(18,2)) debet, cast(kredit as numeric(18,2)) kredit, modul_id, posting, tgl, urut, doc_reff
from gl_journal where voucher='10203260600055' and modul_id='AS' order by urut
"@

Write-Host "`n=== BACKUP ke gl_bkp_orphan_055_20260723 (bila belum ada) ==="
$chk=$cn.CreateCommand(); $chk.CommandText="select count(*) from SYS.SYSTABLE where table_name='gl_bkp_orphan_055_20260723'"
$exists=[int]$chk.ExecuteScalar()
if($exists -eq 0){
  Exec "select * into gl_bkp_orphan_055_20260723 from gl_journal where voucher='10203260600055' and modul_id='AS'"
} else { Write-Host "  (tabel backup sudah ada, skip)" }
Reader "select count(*) n_backup from gl_bkp_orphan_055_20260723"

Write-Host "`n=== DELETE orphan + COMMIT ==="
Exec "delete from gl_journal where voucher='10203260600055' and modul_id='AS'"
Exec "commit"

Write-Host "`n=== AFTER: sisa baris voucher 10203260600055 (harus 0) ==="
Reader "select count(*) n_sisa from gl_journal where voucher='10203260600055'"

Write-Host "`n=== REKON ULANG 102-001 Juni: LEDGER akhir vs STOK akhir ==="
Reader @"
select cast(p.opening+isnull(j.ytd,0) as numeric(18,2)) gl_end,
       cast(isnull(s.stok_end,0) as numeric(18,2)) stok_end,
       cast((p.opening+isnull(j.ytd,0))-isnull(s.stok_end,0) as numeric(18,2)) selisih
from (select sum(amountdebet-amountcredit) opening from gl_balance where site_id='101' and period='2026-01-01' and accountcode='102-001') p,
     (select sum(debet-kredit) ytd from gl_journal where posting='P' and tgl>='2026-01-01' and tgl<'2026-07-01' and account_id='102-001') j,
     (select sum(sv.nilai) stok_end from sinv sv join im_produk pr on pr.produk_id=sv.stok_id join im_product_group gr on gr.kode_group=pr.group_product where gr.persediaan='102-001' and sv.periode='2026-07-01') s
"@

$cn.Close()
