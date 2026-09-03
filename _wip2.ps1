$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) }
    if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}
# 1. 102-020 closing 2026 (= opening + gerakan 2026) = Outstanding
Tab "select cast((select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode='102-020' and Period='2026-01-01') as numeric(20,2)) opening, cast((select sum(isnull(debet,0)-isnull(kredit,0)) from gl_journal where account_id='102-020' and tgl between '2026-01-01' and '2026-07-31') as numeric(20,2)) mov2026, cast((select sum(AmountDebet-AmountCredit) from gl_balance where AccountCode='102-020' and Period='2026-01-01')+(select sum(isnull(debet,0)-isnull(kredit,0)) from gl_journal where account_id='102-020' and tgl between '2026-01-01' and '2026-07-31') as numeric(20,2)) closing_outstanding" "1. 102-020 closing 2026 (=Outstanding)"
# 2. identifikasi grup akun WIP (TR/NR/TB)
Tab "select gr.persediaan, gr.kode_group, gr.nama_group from im_product_group gr where gr.persediaan in ('102-001','102-003','102-006') order by gr.persediaan" "2. Grup akun WIP (TR/NR/TB)"
# 3. WIP-Out GL (Dr 102-020) per counterpart Cr -- akun asal, bandingkan tsales '88'
Tab @"
select g2.account_id akun_cr, cast(sum(isnull(g2.kredit,0)) as numeric(20,2)) gl_wipout_cr
from gl_journal g1 join gl_journal g2 on g1.voucher=g2.voucher and g1.tgl=g2.tgl
where g1.account_id='102-020' and isnull(g1.debet,0)>0 and g1.modul_id='AS'
  and g2.account_id like '102-0%' and g2.account_id<>'102-020' and isnull(g2.kredit,0)>0
  and g1.tgl between '2026-01-01' and '2026-07-31'
group by g2.account_id order by g2.account_id
"@ "3. WIP-Out GL (Cr counterpart) per akun asal"
# 4. WIP-Out tsales '88' EVAP vs non-EVAP + hpp=0 (sumber beda 90jt?)
Tab "select case when isnull(s2.EVAP,'')='' then 'non-EVAP' else 'EVAP' end tipe, count(*) n, cast(sum(isnull(s2.HPP,0)*isnull(s2.QTY,0)) as numeric(20,2)) nilai, count(case when isnull(s2.HPP,0)=0 then 1 end) n_hpp0 from tsales1 s1 join tsales2 s2 on s1.BUKTI_ID=s2.BUKTI_ID where s1.TIPE_TRANS='88' and s1.TGL between '2026-01-01' and '2026-07-31' group by 1" "4. WIP-Out '88' EVAP/non-EVAP + HPP=0"
$c.Close()
