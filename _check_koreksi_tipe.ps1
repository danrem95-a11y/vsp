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

# Daftar semua tipe_trans distinct di TSTOK1 beserta contoh keterangan, utk identifikasi kode Koreksi Plus/Minus
Tab @"
select tipe_trans, count(*) n, min(ket) contoh_ket
  from tstok1
 where tgl between '2026-01-01' and '2026-06-30'
 group by tipe_trans
 order by tipe_trans
"@ "1. Semua tipe_trans di TSTOK1 Jan-Jun 2026 (cari kode koreksi plus/minus)"

# Cek juga apakah ada tabel referensi kode transaksi (master tipe_trans)
Tab "select * from ms_tipe_trans" "2. Master tipe_trans (kalau ada tabel referensinya)"
$c.Close()
