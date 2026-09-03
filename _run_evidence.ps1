$ErrorActionPreference='Stop'
$c=New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta"); $c.Open()
function RawExec([string]$sql){ $m=$c.CreateCommand(); $m.CommandText=$sql; return $m.ExecuteNonQuery() }
function StripInline([string]$txt){ ($txt -split "`n" | ForEach-Object { $i=$_.IndexOf('--'); if($i -ge 0){$_.Substring(0,$i)}else{$_} }) -join "`n" }
function RunFile([string]$path){
  Write-Output ("`n########## " + (Split-Path $path -Leaf) + " ##########")
  $txt=StripInline([System.IO.File]::ReadAllText($path)); $qn=0
  foreach($st in ($txt -split ';')){
    if((($st -replace '\s','').Length) -eq 0){ continue }
    $m=$c.CreateCommand(); $m.CommandText=$st
    try{ $rd=$m.ExecuteReader()
      if($rd.FieldCount -gt 0){ $qn++; $cols=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$cols+=$rd.GetName($i)}
        Write-Output ("`n[#$qn] "+($cols -join ' | ')); $n=0
        while($rd.Read()){ $n++; if($n -le 40){ $v=@(); for($i=0;$i -lt $rd.FieldCount;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
        if($n -gt 40){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" } }
      $rd.Close()
    }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
  }
}
$mach=(New-Object System.Data.Odbc.OdbcCommand("select property('MachineName')",$c)).ExecuteScalar()
if($mach -ne 'DESKTOP-P04P4QG'){ Write-Output "ABORT: $mach"; $c.Close(); exit 1 }
Write-Output "MESIN=$mach"
RawExec("update sinv set qty=b.qty,nilai=b.nilai,hpp_avg=b.hpp_avg from _mekA_bak b where sinv.stok_id=b.stok_id and sinv.periode=b.periode and sinv.site_id=b.site_id") | Out-Null
Write-Output "restore-phantom OK"
RunFile "C:\BTV\debug\recovery_mekA_opening.sql"
RunFile "C:\BTV\debug\validation_guard2025.sql"
$c.Close(); Write-Output "`n== SELESAI =="
