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

# Cek tabel USER_LOG_BACKUP (disebut di memori proyek sbg audit trail) utk perubahan gl_balance 102-201 sekitar 2019/2023
Tab "select top 3 * from USER_LOG_BACKUP" "0. Contoh struktur USER_LOG_BACKUP (kalau ada)"
Tab "select * from USER_LOG_BACKUP where table_name like '%gl_balance%' or table_name like '%GL_BALANCE%'" "1. Log perubahan gl_balance (kalau tercatat)"

# Cek juga apakah ada kolom modifydate/modifyby di gl_balance sendiri
Tab "select top 1 * from gl_balance where AccountCode='102-201' and Period='2019-01-01'" "2. Baris gl_balance 102-201 tahun 2019 (cek kolom audit spt modifyby/modifydate kalau ada)"
$c.Close()
