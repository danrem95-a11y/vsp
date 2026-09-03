$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=150; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 60){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 60){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}

# Semua mutasi GL 102-110 bulan Juni, urut tanggal
Tab @"
select cast(g.tgl as date) tgl, g.voucher, g.modul_id, cast(g.debet as numeric(16,2)) debet, cast(g.kredit as numeric(16,2)) kredit, g.ket
  from gl_journal g
 where g.account_id='102-110' and g.tgl between '2026-06-01' and '2026-06-30'
 order by g.tgl, g.voucher
"@ "1. Semua mutasi GL 102-110 Juni"

# ringkas per modul_id (biar kelihatan pola/sumbernya)
Tab @"
select modul_id, count(*) n, cast(sum(isnull(debet,0)) as numeric(16,2)) total_debet, cast(sum(isnull(kredit,0)) as numeric(16,2)) total_kredit
  from gl_journal
 where account_id='102-110' and tgl between '2026-06-01' and '2026-06-30'
 group by modul_id
"@ "2. Ringkas per modul_id Juni 102-110"
$c.Close()
