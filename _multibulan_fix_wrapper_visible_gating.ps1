param(
    [Parameter(Mandatory=$true)][string]$File
)

$ErrorActionPreference = "Stop"
$CRLF = "`r`n"
$content = Get-Content -Path $File -Encoding Unicode -Raw

function Req($cond, $msg) { if (-not $cond) { throw $msg } }

$c1NameIdx = $content.IndexOf('name=compute_1 visible="1" ')
Req ($c1NameIdx -ge 0) "compute_1 (f_company header compute) not found in $File"
$c1Start = $content.LastIndexOf("compute(band=header", $c1NameIdx)
Req ($c1Start -ge 0) "compute(band=header start not found before compute_1"
$c1End = $content.IndexOf(")" + $CRLF, $c1NameIdx)
Req ($c1End -ge 0) "compute_1 closing paren not found"
$c1Full = $content.Substring($c1Start, ($c1End+1) - $c1Start)
$c1Tail = $c1Full.Substring($c1Full.IndexOf('name=compute_1 visible="1" ') + 'name=compute_1 visible="1" '.Length)

$helper = "compute(band=header alignment=`"0`" expression=`"arg_jml_bulan`"border=`"0`" color=`"33554432`" x=`"18`" y=`"280`" height=`"32`" width=`"200`" format=`"[GENERAL]`" html.valueishtml=`"0`"  name=c_jml_bulan_hdr visible=`"0`" $c1Tail"

$content = $content.Replace($c1Full, $c1Full + $CRLF + $helper)

$before = ([regex]::Matches($content, 'visible="arg_jml_bulan>=')).Count
$content = $content -replace 'visible="arg_jml_bulan>=', 'visible="c_jml_bulan_hdr>='
$after = ([regex]::Matches($content, 'visible="c_jml_bulan_hdr>=')).Count
Req ($before -gt 0) "no visible=`"arg_jml_bulan>=...`" occurrences found to fix in $File"
Req ($after -eq $before) "replacement count mismatch: before=$before after=$after"

[System.IO.File]::WriteAllText($File, $content, [System.Text.Encoding]::Unicode)
Write-Output "OK: fixed $File (repointed $before visible= gates, inserted c_jml_bulan_hdr helper)"
