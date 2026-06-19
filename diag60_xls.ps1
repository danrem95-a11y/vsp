$ErrorActionPreference = 'Stop'
function ReadXls($path, $label) {
  Write-Host "==================== $label ($path) ===================="
  $xl = New-Object -ComObject Excel.Application
  $xl.Visible = $false
  $xl.DisplayAlerts = $false
  $wb = $xl.Workbooks.Open($path, 0, $true)
  foreach ($ws in $wb.Worksheets) {
    Write-Host "--- Sheet: $($ws.Name) (UsedRange: $($ws.UsedRange.Rows.Count) x $($ws.UsedRange.Columns.Count)) ---"
    $rows = [Math]::Min($ws.UsedRange.Rows.Count, 60)
    $cols = [Math]::Min($ws.UsedRange.Columns.Count, 25)
    for ($r = 1; $r -le $rows; $r++) {
      $line = @()
      for ($c = 1; $c -le $cols; $c++) {
        $v = $ws.Cells.Item($r, $c).Value2
        if ($null -ne $v) { $line += "[$c]$v" }
      }
      if ($line.Count -gt 0) { Write-Host "R${r}: $($line -join ' | ')" }
    }
  }
  $wb.Close($false)
  $xl.Quit()
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($xl) | Out-Null
}
ReadXls 'c:\BTV\debug\jan_opname_hutang.xls' 'JAN'
ReadXls 'c:\BTV\debug\feb_opname_hutang.xls' 'FEB'
