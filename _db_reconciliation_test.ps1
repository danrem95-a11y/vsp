$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=90; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 40){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 40){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}

# 1. Cek konsistensi EVAP '88' vs penjualan yg pakai EVAP sama (utk 63 baris TR+NR yg sudah dikoreksi)
Tab @"
select count(*) n_tidak_konsisten
  from tsales1 s1w, tsales2 s2w
  join tsales2 s2j on s2j.stok_id=s2w.stok_id and isnull(s2j.evap,'')=isnull(s2w.evap,'') and isnull(s2w.evap,'')<>''
  join tsales1 s1j on s1j.bukti_id=s2j.bukti_id and s1j.tipe_trans<>'88'
 where s1w.bukti_id=s2w.bukti_id and s1w.tipe_trans='88'
   and s1w.tgl between '2026-01-01' and '2026-06-30'
   and abs(isnull(s2w.hpp,0) - isnull(s2j.hpp,0)) > 1
"@ "1. Penjualan yg HPP-nya BEDA dari EVAP asal '88' (harus 0 -- step 4b harus selalu konsisten)"

# 2. WIP Outstanding (belum terjual) -- total nilai = SUM(EVAP HPP) utk unit yg masih 88 tanpa penjualan
Tab @"
select count(*) n_outstanding, cast(sum(isnull(s2.hpp,0)*isnull(s2.qty,0)) as numeric(20,2)) total_nilai_outstanding
  from tsales1 s1, tsales2 s2
 where s1.bukti_id=s2.bukti_id and s1.tipe_trans='88' and isnull(s2.evap,'')<>''
   and s1.tgl between '2026-01-01' and '2026-06-30'
   and not exists (
     select 1 from tsales1 s1x, tsales2 s2x
      where s1x.bukti_id=s2x.bukti_id and s1x.tipe_trans<>'88'
        and s2x.stok_id=s2.stok_id and isnull(s2x.evap,'')=isnull(s2.evap,'')
   )
"@ "2. WIP Outstanding Jan-Jun (belum terjual) -- total nilai"

# 3. GL 102-020 saldo akhir Juni vs total WIP Outstanding (harus dekat, toleransi kecil krn item pra-existing)
Tab @"
select cast((select b.AmountDebet-b.AmountCredit from gl_balance b where b.AccountCode='102-020' and b.Period='2026-01-01')
   + isnull((select sum(g.debet-g.kredit) from gl_journal g where g.account_id='102-020' and g.tgl between '2026-01-01' and '2026-06-30'),0) as numeric(20,2)) saldo_gl_102020_akhir_juni
"@ "3. Saldo GL 102-020 akhir Juni (referensi pembanding)"
$c.Close()
