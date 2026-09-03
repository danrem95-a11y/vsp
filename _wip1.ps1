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
# 1. 102-020: saldo awal 2026 (gl_balance) + movement 2026 + closing
Tab "select cast(sum(AmountDebet-AmountCredit) as numeric(20,2)) saldo_awal_2026 from gl_balance where AccountCode='102-020' and Period='2026-01-01'" "1a. 102-020 saldo awal 2026 (gl_balance)"
Tab "select cast(sum(AmountDebet-AmountCredit) as numeric(20,2)) saldo_awal_2025 from gl_balance where AccountCode='102-020' and Period='2025-01-01'" "1b. 102-020 saldo awal 2025"
Tab "select cast(sum(isnull(debet,0)-isnull(kredit,0)) as numeric(20,2)) mov_2025 from gl_journal where account_id='102-020' and tgl between '2025-01-01' and '2025-12-31'" "1c. 102-020 movement 2025 (utk closing 2025 = awal + mov)"
# 2. 102-020 GL 2026 per modul + Dr/Cr (WIP-Out=Dr, WIP-In=Cr)
Tab "select modul_id, cast(sum(isnull(debet,0)) as numeric(20,2)) debet_wipout, cast(sum(isnull(kredit,0)) as numeric(20,2)) kredit_wipin from gl_journal where account_id='102-020' and tgl between '2026-01-01' and '2026-07-31' group by modul_id order by modul_id" "2. 102-020 GL 2026 per modul (Dr=WIP-Out, Cr=WIP-In)"
# 3. WIP-Out (tsales '88') 2026 per counterpart -- akun TR/NR/TB
Tab "select gr.persediaan akun_asal, count(*) n, cast(sum(isnull(s2.HPP,0)*isnull(s2.QTY,0)) as numeric(20,2)) wipout_nilai, cast(sum(isnull(s2.QTY,0)) as numeric(12,2)) qty from tsales1 s1 join tsales2 s2 on s1.BUKTI_ID=s2.BUKTI_ID join im_produk pr on pr.produk_id=s2.STOK_ID join im_product_group gr on gr.kode_group=pr.group_product where s1.TIPE_TRANS='88' and s1.TGL between '2026-01-01' and '2026-07-31' group by gr.persediaan order by gr.persediaan" "3. WIP-Out tsales '88' 2026 per akun asal"
# 4. WIP-In (tstok '88') 2026 per counterpart
Tab "select gr.persediaan akun, count(*) n, cast(sum(isnull(t2.NETTO,0)) as numeric(20,2)) wipin_nilai, cast(sum(isnull(t2.QTY,0)) as numeric(12,2)) qty from tstok1 t1 join tstok2 t2 on t1.BUKTI_ID=t2.BUKTI_ID join im_produk pr on pr.produk_id=t2.STOK_ID join im_product_group gr on gr.kode_group=pr.group_product where t1.TIPE_TRANS='88' and t1.TGL between '2026-01-01' and '2026-07-31' group by gr.persediaan order by gr.persediaan" "4. WIP-In tstok '88' 2026 per akun"
$c.Close()
