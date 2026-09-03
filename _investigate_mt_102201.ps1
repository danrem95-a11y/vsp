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

# 1. Item apa saja yg masuk akun 102-201
Tab "select ip.produk_id, ip.produk_desc from im_produk ip join im_product_group ipg on ipg.kode_group=ip.group_product where ipg.persediaan='102-201'" "1. Daftar item 102-201 (MT)"

# 2. SINV per item 102-201 di opening Jan 2026 (periode=2026-01-01)
Tab @"
select sv.stok_id, cast(sv.qty as numeric(12,2)) qty, cast(sv.nilai as numeric(18,2)) nilai, cast(sv.hpp_avg as numeric(16,2)) hpp_avg
  from sinv sv join im_produk ip on ip.produk_id=sv.stok_id join im_product_group ipg on ipg.kode_group=ip.group_product
 where ipg.persediaan='102-201' and sv.periode='2026-01-01' and (sv.qty<>0 or sv.nilai<>0)
 order by sv.stok_id
"@ "2. SINV opening Jan 2026 per item 102-201"

# 3. Cek SINV Desember 2025 (kalau ada) utk item yg sama -- closing 2025 = opening 2026?
Tab @"
select sv.stok_id, sv.periode, cast(sv.qty as numeric(12,2)) qty, cast(sv.nilai as numeric(18,2)) nilai
  from sinv sv join im_produk ip on ip.produk_id=sv.stok_id join im_product_group ipg on ipg.kode_group=ip.group_product
 where ipg.persediaan='102-201' and sv.periode between '2025-11-01' and '2026-01-01'
 order by sv.stok_id, sv.periode
"@ "3. SINV Nov 2025 - Jan 2026 per item 102-201 (cek transisi tahun)"

# 4. GL journal 102-201 sekitar akhir Des 2025 / awal Jan 2026 (cari kejadian penyebab)
Tab @"
select cast(g.tgl as date) tgl, g.voucher, g.modul_id, cast(g.debet as numeric(16,2)) debet, cast(g.kredit as numeric(16,2)) kredit, g.ket
  from gl_journal g
 where g.account_id='102-201' and g.tgl between '2025-12-01' and '2026-01-31'
 order by g.tgl
"@ "4. GL 102-201 Des 2025 - Jan 2026 (cari voucher besar/mencurigakan)"
$c.Close()
