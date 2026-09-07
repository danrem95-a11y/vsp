param(
    [Parameter(Mandatory=$true)][string]$File
)

$ErrorActionPreference = "Stop"
$CRLF = "`r`n"
$content = Get-Content -Path $File -Encoding Unicode -Raw

function Req($cond, $msg) { if (-not $cond) { throw $msg } }

# Locate the saldo_awal compute object (band=detail) to clone its tail attributes and insert
# a hidden helper compute right after it, in the same band.
$saNameIdx = $content.IndexOf('name=saldo_awal visible="1" ')
Req ($saNameIdx -ge 0) "saldo_awal object not found in $File"
$saStart = $content.LastIndexOf("compute(band=detail", $saNameIdx)
Req ($saStart -ge 0) "compute(band=detail start not found before saldo_awal"
$saEnd = $content.IndexOf(")" + $CRLF, $saNameIdx)
Req ($saEnd -ge 0) "saldo_awal closing paren not found"
$saFull = $content.Substring($saStart, ($saEnd+1) - $saStart)
$saTail = $saFull.Substring($saFull.IndexOf('name=saldo_awal visible="1" ') + 'name=saldo_awal visible="1" '.Length)

$helper = "compute(band=detail alignment=`"1`" expression=`"arg_jml_bulan`"border=`"0`" color=`"33554432`" x=`"18`" y=`"4`" height=`"76`" width=`"200`" format=`"[GENERAL]`" html.valueishtml=`"0`"  name=c_jml_bulan visible=`"0`" $saTail"

$content = $content.Replace($saFull, $saFull + $CRLF + $helper)

# Repoint every visible="arg_jml_bulan>=N" (only the VISIBLE attribute usage, not expression= guarded sums) to reference the hidden compute by name.
$before = ([regex]::Matches($content, 'visible="arg_jml_bulan>=')).Count
$content = $content -replace 'visible="arg_jml_bulan>=', 'visible="c_jml_bulan>='
$after = ([regex]::Matches($content, 'visible="c_jml_bulan>=')).Count
Req ($before -gt 0) "no visible=`"arg_jml_bulan>=...`" occurrences found to fix in $File"
Req ($after -eq $before) "replacement count mismatch: before=$before after=$after"

[System.IO.File]::WriteAllText($File, $content, [System.Text.Encoding]::Unicode)
Write-Output "OK: fixed $File (repointed $before visible= gates, inserted c_jml_bulan helper)"
