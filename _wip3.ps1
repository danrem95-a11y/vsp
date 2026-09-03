$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 30){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 30){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}
# 1. WIP-Out '88': HPP=0 (cost-loss) -- kandidat beda 90jt
Tab @"
select case when isnull(s2.EVAP,'')='' then 'nonEVAP' else 'EVAP' end tp,
  count(*) n, cast(sum(isnull(s2.HPP,0)*isnull(s2.QTY,0)) as numeric(20,2)) nilai,
  sum(case when isnull(s2.HPP,0)=0 then 1 else 0 end) n_hpp0
from tsales1 s1 join tsales2 s2 on s1.BUKTI_ID=s2.BUKTI_ID
where s1.TIPE_TRANS='88' and s1.TGL between '2026-01-01' and '2026-07-31'
group by case when isnull(s2.EVAP,'')='' then 'nonEVAP' else 'EVAP' end
"@ "1. WIP-Out '88' EVAP/nonEVAP + HPP=0"
# 2. '88' HPP=0 detail (TR/NR): serial+tgl+bukti
Tab @"
select gr.persediaan akun, s2.STOK_ID, s2.EVAP, s1.TGL, s1.BUKTI_ID, cast(s2.QTY as numeric(6,2)) qty
from tsales1 s1 join tsales2 s2 on s1.BUKTI_ID=s2.BUKTI_ID join im_produk pr on pr.produk_id=s2.STOK_ID join im_product_group gr on gr.kode_group=pr.group_product
where s1.TIPE_TRANS='88' and isnull(s2.HPP,0)=0 and s1.TGL between '2026-01-01' and '2026-07-31'
order by gr.persediaan, s1.TGL
"@ "2. WIP-Out '88' HPP=0 detail (kandidat beda)"
# 3. sisi WIP-In (tstok '88') = GL Cr? sudah exact. Cek total per akun ulang bandingan
Tab @"
select a.akun,
  cast(a.wipout_tsales as numeric(20,2)) wipout_tsales88,
  cast(a.wipout_gl as numeric(20,2)) wipout_gl_cr,
  cast(a.wipout_gl-a.wipout_tsales as numeric(18,2)) beda
from (
 select gr.persediaan akun,
  (select sum(isnull(s2.HPP,0)*isnull(s2.QTY,0)) from tsales1 s1 join tsales2 s2 on s1.BUKTI_ID=s2.BUKTI_ID join im_produk p2 on p2.produk_id=s2.STOK_ID where p2.group_product=gr.kode_group and s1.TIPE_TRANS='88' and s1.TGL between '2026-01-01' and '2026-07-31') wipout_tsales,
  (select sum(isnull(g2.kredit,0)) from gl_journal g1 join gl_journal g2 on g1.voucher=g2.voucher and g1.tgl=g2.tgl where g1.account_id='102-020' and isnull(g1.debet,0)>0 and g1.modul_id='AS' and g2.account_id=gr.persediaan and isnull(g2.kredit,0)>0 and g1.tgl between '2026-01-01' and '2026-07-31') wipout_gl
 from im_product_group gr where gr.persediaan in ('102-001','102-003','102-006')
) a order by a.akun
"@ "3. WIP-Out per akun: tsales '88' vs GL (beda)"
$c.Close()
