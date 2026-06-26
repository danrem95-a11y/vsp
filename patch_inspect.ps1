$files="d_detail_ekspedisi","dw_ekspedisi_entry12_freight","dw_ekspedisi_entry12xx"
foreach($f in $files){
  $p="C:\BTV\debug\$f.srd"
  $t=[System.IO.File]::ReadAllText($p,[System.Text.Encoding]::Unicode)
  $lines=$t -split "`r`n"
  $src = $lines | Where-Object { $_ -match 'column=\(' -and $_ -match 'dbname=' }
  $keys = @(); $uwcYes=0; $uwcNonKey=0
  foreach($l in $src){
    $name=[regex]::Match($l,'name=(\w+)').Groups[1].Value
    $isKey = $l -match 'key=yes'
    $isUwc = $l -match 'updatewhereclause=yes'
    if($isKey){ $keys += $name }
    if($isUwc){ $uwcYes++ ; if(-not $isKey){ $uwcNonKey++ } }
  }
  Write-Output ("{0}: src_cols={1}  KEY=[{2}]  uwc=yes total={3}  (non-key yg akan diubah={4})" -f $f,$src.Count, ($keys -join ','), $uwcYes, $uwcNonKey)
}