$ErrorActionPreference='Stop'
$enc=[System.Text.Encoding]::Unicode
$files="d_detail_ekspedisi","dw_ekspedisi_entry12_freight","dw_ekspedisi_entry12xx"
foreach($f in $files){
  $p="C:\BTV\debug\$f.srd"
  $t=[System.IO.File]::ReadAllText($p,$enc)
  Copy-Item $p "$p.bak_rowchanged" -Force
  $lines=$t -split "`r`n"
  $changed=0
  for($i=0;$i -lt $lines.Count;$i++){
    $l=$lines[$i]
    if($l -match 'column=\(' -and $l -match 'dbname=' -and $l -match 'updatewhereclause=yes' -and ($l -notmatch 'key=yes')){
      $lines[$i]=$l -replace 'updatewhereclause=yes','updatewhereclause=no'
      $changed++
    }
  }
  $nt=$lines -join "`r`n"
  [System.IO.File]::WriteAllText($p,$nt,$enc)
  # verifikasi
  $v=$nt -split "`r`n"
  $src=$v | Where-Object { $_ -match 'column=\(' -and $_ -match 'dbname=' }
  $uwcYes = ($src | Where-Object { $_ -match 'updatewhereclause=yes' })
  $keysWithUwc = ($uwcYes | ForEach-Object { [regex]::Match($_,'name=(\w+)').Groups[1].Value }) -join ','
  $bom = [System.IO.File]::ReadAllBytes($p)[0..1]
  Write-Output ("{0}: diubah={1}  sisa uwc=yes={2} [{3}]  BOM={4:X2}{5:X2}" -f $f,$changed,$uwcYes.Count,$keysWithUwc,$bom[0],$bom[1])
}