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

# 1. Konfirmasi persis: selisih Feb (harus ~0) vs Mar (harus ~10.7jt) utk 102-001
Tab @"
select cast(sum(sv.nilai) as numeric(18,2)) sinv_akhir_feb,
       cast((select b.AmountDebet-b.AmountCredit from gl_balance b where b.AccountCode='102-001' and b.Period='2026-01-01')
          + isnull((select sum(g.debet-g.kredit) from gl_journal g where g.account_id='102-001' and g.tgl between '2026-01-01' and '2026-02-28'),0) as numeric(18,2)) gl_akhir_feb
  from sinv sv join im_produk ip on ip.produk_id=sv.stok_id join im_product_group ipg on ipg.kode_group=ip.group_product
 where ipg.persediaan='102-001' and sv.periode='2026-03-01'
"@ "1a. Opname vs GL akhir Februari 2026 (harus bersih)"

Tab @"
select cast(sum(sv.nilai) as numeric(18,2)) sinv_akhir_mar,
       cast((select b.AmountDebet-b.AmountCredit from gl_balance b where b.AccountCode='102-001' and b.Period='2026-01-01')
          + isnull((select sum(g.debet-g.kredit) from gl_journal g where g.account_id='102-001' and g.tgl between '2026-01-01' and '2026-03-31'),0) as numeric(18,2)) gl_akhir_mar
  from sinv sv join im_produk ip on ip.produk_id=sv.stok_id join im_product_group ipg on ipg.kode_group=ip.group_product
 where ipg.persediaan='102-001' and sv.periode='2026-04-01'
"@ "1b. Opname vs GL akhir Maret 2026 (harusnya sdh selisih ~10,7jt)"

# 2. Bandingkan MUTASI Maret: total mutasi SINV (item-level formula) vs total mutasi GL (jurnal Maret saja)
Tab @"
select cast(sum(g.debet-g.kredit) as numeric(18,2)) net_mutasi_gl_maret, count(distinct g.voucher) n_voucher
  from gl_journal g
 where g.account_id='102-001' and g.tgl between '2026-03-01' and '2026-03-31'
"@ "2. Total mutasi GL 102-001 Maret (net debet-kredit)"

# 3. Cari voucher2 Maret dgn nilai signifikan (mendekati 10,7jt atau kelipatannya) utk kandidat root cause
Tab @"
select g.voucher, g.modul_id, min(g.tgl) tgl, sum(case when g.account_id='102-001' then g.debet-g.kredit else 0 end) net_102001, g.ket
  from gl_journal g
 where g.account_id='102-001' and g.tgl between '2026-03-01' and '2026-03-31'
 group by g.voucher, g.modul_id, g.ket
having abs(sum(case when g.account_id='102-001' then g.debet-g.kredit else 0 end)) > 1000000
 order by abs(sum(case when g.account_id='102-001' then g.debet-g.kredit else 0 end)) desc
"@ "3. Voucher Maret 102-001 dgn nilai >Rp1jt (kandidat penyebab)"
$c.Close()
