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

# 1. Total debet/kredit 102-110 per bulan Jan-Jun (cari bulan mana yg berubah)
Tab @"
select year(tgl) th, month(tgl) bln, cast(sum(isnull(debet,0)) as numeric(16,2)) debet, cast(sum(isnull(kredit,0)) as numeric(16,2)) kredit, count(*) n
  from gl_journal
 where account_id='102-110' and tgl between '2026-01-01' and '2026-06-30'
 group by year(tgl), month(tgl)
 order by 1,2
"@ "1. Ringkas GL 102-110 per bulan (cek jumlah baris & total, cari yg beda dari cek sebelumnya)"

# 2. GL 102-110 yg dibuat/diubah PALING BARU (kalau ada kolom created/modified date)
Tab "select top 3 * from gl_journal where account_id='102-110'" "2. Contoh baris GL 102-110 (cek kolom yg ada, siapa tau ada timestamp)"
$c.Close()
