$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=150; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 45){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 45){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}

# 1. Apakah selisih sitewide Rp5,77M itu SUDAH ADA SEBELUM fix kita?
#    Buktikan matematis: hitung total selisih debet-kredit HANYA utk 39 voucher kita
#    sebelum vs sesudah (pakai backup) -- harus 0 (delta debet = delta kredit persis)
Tab @"
select
  cast(sum(case when g.account_id='102-020' then g.debet else 0 end)
     - sum(case when b.account_id='102-020' then b.debet_old else 0 end) as numeric(16,2)) delta_debet_39voucher,
  cast(sum(case when g.account_id='102-001' then g.kredit else 0 end)
     - sum(case when b.account_id='102-001' then b.kredit_old else 0 end) as numeric(16,2)) delta_kredit_39voucher
  from ZZ_BAK_WIPFIX_GL_20260810 b, gl_journal g
 where g.voucher=b.voucher and g.account_id=b.account_id and g.modul_id='AS'
"@ "1. Bukti fix kita TIDAK mempengaruhi selisih sitewide (delta debet harus = delta kredit)"

# 2. Opname (SINV) vs Ledger (GL) 102-001 -- akun utama yg jadi keluhan awal
Tab @"
select cast(sum(qty) as numeric(16,2)) qty_sinv, cast(sum(nilai) as numeric(20,2)) nilai_sinv
  from sinv where stok_id like 'TR.%' and periode='2026-07-01'
"@ "2a. SINV opening Juli 2026 (=closing Juni) utk TR.*"

Tab @"
select b.AmountDebet-b.AmountCredit
     + isnull((select sum(g.debet-g.kredit) from gl_journal g
                where g.account_id='102-001' and g.tgl between '2026-01-01' and '2026-06-30'),0) as saldo_gl_102001_akhir_juni
  from gl_balance b where b.AccountCode='102-001' and b.Period='2026-01-01'
"@ "2b. Saldo GL 102-001 akhir Juni 2026 (formula gl_balance + mutasi)"

# 3. Chain Apr->Mei spesifik TR.038A (residual dulu 32.953.937,10, harus 0 sekarang)
#    pakai perbandingan saldo akhir April vs saldo awal Mei utk TR.038A
Tab @"
select cast(sum(qty) as numeric(16,2)) qty, cast(sum(nilai) as numeric(20,2)) nilai
  from sinv where stok_id='TR.038A' and periode='2026-05-01'
"@ "3a. SINV TR.038A saldo awal Mei 2026 (= akhir April)"
$c.Close()
