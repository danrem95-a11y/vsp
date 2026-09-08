$content = Get-Content -Path "c:\BTV\debug\dw_rpt_is_flat_multibulan.srd" -Encoding Unicode -Raw

function Get-BalancedEnd($content, $start) {
    $depth = 0; $inQuote = $false
    for ($i = $start; $i -lt $content.Length; $i++) {
        $ch = $content[$i]
        if ($ch -eq '"') { $inQuote = -not $inQuote; continue }
        if ($inQuote) { continue }
        if ($ch -eq '(') { $depth++ }
        elseif ($ch -eq ')') { $depth--; if ($depth -eq 0) { return $i } }
    }
    return -1
}

# Skip the header line ($PBExportHeader$... and release 11.5;)
$pos = $content.IndexOf("datawindow(")
$objCount = 0
$errors = @()

while ($pos -lt $content.Length) {
    # skip whitespace/CRLF
    while ($pos -lt $content.Length -and ($content[$pos] -eq "`r" -or $content[$pos] -eq "`n" -or $content[$pos] -eq ' ')) { $pos++ }
    if ($pos -ge $content.Length) { break }
    # find next '(' - the token before it is the object keyword
    $parenIdx = $content.IndexOf('(', $pos)
    if ($parenIdx -lt 0) {
        $rest = $content.Substring($pos)
        if ($rest.Trim().Length -gt 0) { $errors += "Trailing non-empty content with no more '(' found at pos $pos : [$($rest.Substring(0,[Math]::Min(80,$rest.Length)))]" }
        break
    }
    $keyword = $content.Substring($pos, $parenIdx - $pos)
    if ($keyword -notmatch '^[a-zA-Z_.]+$') {
        $errors += "UNEXPECTED TOKEN before '(' at pos $pos (line approx $((($content.Substring(0,$pos)) -split "`r`n").Count)): keyword=[$keyword] context=[$($content.Substring([Math]::Max(0,$pos-40),80))]"
        break
    }
    $end = Get-BalancedEnd $content $parenIdx
    if ($end -lt 0) {
        $errors += "UNCLOSED object '$keyword' starting at pos $pos"
        break
    }
    $objCount++
    $pos = $end + 1
}

Write-Output "Objects successfully parsed: $objCount"
Write-Output "Errors: $($errors.Count)"
$errors | ForEach-Object { Write-Output $_ }
