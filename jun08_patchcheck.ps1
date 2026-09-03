$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Reader($sql){ $c=$cn.CreateCommand(); $c.CommandTimeout=240; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader()}catch{Write-Host ("  ERR: "+$_.Exception.Message);return}
  while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; $rd.Close() }

Write-Host "=== Faktur induk patch: tsales1 tipe22 bukti_id=10126062200168 (transform dari consin) ==="
Reader "select bukti_id, order_client, tipe_trans, tgl, order_oke from tsales1 where bukti_id='10126062200168'"

Write-Host "`n=== Apakah patch WIP-IN akan MENANGKAP voucher 055? (replikasi cursor cur_wfk utk consin ini) ==="
Reader @"
select distinct f.bukti_id faktur, f.tgl f_tgl, w.bukti_id consin, w.tgl w_tgl
from tstok1 w, tsales1 f
where w.tipe_trans='88' and f.tipe_trans='22'
  and f.bukti_id = '101' + substr(w.bukti_id,4)
  and (month(w.tgl)<>month(f.tgl) or year(w.tgl)<>year(f.tgl))
  and w.bukti_id='10226062200168'
"@

Write-Host "`n=== BERAPA BANYAK consin cross-month yg patch tangkap SELURUH sistem (sizing)? ==="
Reader @"
select count(distinct f.bukti_id) n_faktur
from tstok1 w, tsales1 f
where w.tipe_trans='88' and f.tipe_trans='22'
  and f.bukti_id = '101' + substr(w.bukti_id,4)
  and (month(w.tgl)<>month(f.tgl) or year(w.tgl)<>year(f.tgl))
"@

Write-Host "`n=== Konteks: apakah GL voucher 10203260600055 punya doc_reff yg dipakai delete oleh refresh consin? ==="
Reader @"
select 'gl_by_docreff_055' k, count(*) n from gl_journal where doc_reff='10203260600055'
union all
select 'gl_by_voucher_055', count(*) from gl_journal where voucher='10203260600055'
"@

$cn.Close()
