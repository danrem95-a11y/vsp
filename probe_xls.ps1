param(
    [string]$InputFile,
    [string]$OutputFile,
    [int]$MaxRows = 15,
    [int]$MaxCols = 12
)

try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false

    $wb = $excel.Workbooks.Open($InputFile)
    $sheet = $wb.Worksheets.Item(1)
    $range = $sheet.UsedRange

    $out = @()
    $rows = [Math]::Min($MaxRows, $range.Rows.Count)
    $cols = [Math]::Min($MaxCols, $range.Columns.Count)

    for ($r = 1; $r -le $rows; $r++) {
        $vals = @()
        for ($c = 1; $c -le $cols; $c++) {
            $vals += [string]$sheet.Cells.Item($r, $c).Text
        }
        $out += ($vals -join '|')
    }

    $out | Out-File $OutputFile -Encoding UTF8
}
catch {
    $_ | Out-File $OutputFile -Encoding UTF8
}
finally {
    if ($wb) { $wb.Close($false) }
    if ($excel) { $excel.Quit() }
}