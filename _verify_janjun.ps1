$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=180; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 30){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 30){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris -- BALANCE 100%)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}

Tab "select refresh_id,periode,ts_start,ts_end,status from refresh_ledger where periode between '2026-01' and '2026-06' order by ts_start desc" "0. refresh_ledger Jan-Jun terbaru"

$engRaw = [System.IO.File]::ReadAllText("C:\BTV\debug\_engine_sql.txt")
$engRaw = [regex]::Replace($engRaw, '(?is)\s+ORDER\s+BY\s+[^)]*\)\s*A,IM_PRODUCT_GROUP', ') A,IM_PRODUCT_GROUP')

function ValidasiChain([string]$t1,[string]$t2,[string]$next,[string]$label){
  $eng = $engRaw -replace ':arg_tgl2', "'$t2'"
  $eng = $eng -replace ':arg_tgl', "'$t1'"
  $q = @"
select z.PERSEDIAAN akun,
  cast(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP) as numeric(20,2)) saldo_akhir_dihitung_ulang,
  cast((select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
          where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
            and sv.periode='$next' and gr2.persediaan=z.PERSEDIAAN) as numeric(20,2)) saldo_awal_tersimpan,
  cast(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
       - (select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
            where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
              and sv.periode='$next' and gr2.persediaan=z.PERSEDIAAN) as numeric(20,2)) selisih
from ( $eng ) z
group by z.PERSEDIAAN
having abs(sum(z.AWAL_RP + z.BELI_RP + z.RET_JUAL_RP + z.CONSIN_BY_EVAP_RP + z.CONSIN_RP + z.MUTASI_IN_RP
           - (z.JUAL_BY_EVAP_RP + z.JUAL_REAL) - z.RET_BELI_RP - z.CONSOUT_RP - z.MUTASI_OUT_RP)
       - (select isnull(sum(sv.nilai),0) from sinv sv, im_produk pr2, im_product_group gr2
            where pr2.produk_id=sv.stok_id and gr2.kode_group=pr2.group_product
              and sv.periode='$next' and gr2.persediaan=z.PERSEDIAAN)) > 1
order by z.PERSEDIAAN
"@
  Tab $q $label
}

ValidasiChain "2026-01-01" "2026-01-31" "2026-02-01" "1. Jan->Feb -- target 0 baris"
ValidasiChain "2026-02-01" "2026-02-28" "2026-03-01" "2. Feb->Mar -- target 0 baris"
ValidasiChain "2026-03-01" "2026-03-31" "2026-04-01" "3. Mar->Apr -- target 0 baris"
ValidasiChain "2026-04-01" "2026-04-30" "2026-05-01" "4. Apr->Mei -- target 0 baris"
ValidasiChain "2026-05-01" "2026-05-31" "2026-06-01" "5. Mei->Jun -- target 0 baris"

Tab @"
select gr.persediaan account_id, count(*) n_voucher_mismatch, cast(sum(abs(v.mutasi-v.glval)) as numeric(20,2)) total_selisih
  from (
    select gr2.persediaan persediaan, s1.bukti_id,
           sum(isnull(s2.HPP,0)*isnull(s2.QTY,0)) mutasi,
           isnull((select sum(isnull(g.kredit,0)) from gl_journal g where g.voucher=s1.order_client
                     and g.account_id=gr2.persediaan and g.modul_id='AS'),0) glval
      from tsales1 s1, tsales2 s2, im_produk pr, im_product_group gr2
     where s1.bukti_id=s2.bukti_id and s1.tipe_trans='88' and s1.tgl between '2026-01-01' and '2026-06-30'
       and pr.produk_id=s2.stok_id and gr2.kode_group=pr.group_product
     group by gr2.persediaan, s1.bukti_id, s1.order_client
  ) v, im_product_group gr
 where v.persediaan=gr.persediaan and abs(v.mutasi-v.glval)>1
 group by gr.persediaan
"@ "6. WIP per-voucher independen (Jan-Jun): harus 0 baris"

Tab "select gate_id,periode_from,sumber,n_pelanggaran,status,tgl_cek from costing_gate_result order by tgl_cek desc" "7. costing_gate_result"
Tab "select result_id,tgl_check,periode_from,account_id,status from wip_out_gate_result order by tgl_check desc" "8. wip_out_gate_result"
$c.Close()
