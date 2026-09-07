param(
    [Parameter(Mandatory=$true)][string]$SourceFile,
    [Parameter(Mandatory=$true)][string]$DestFile
)

$ErrorActionPreference = "Stop"
$CRLF = "`r`n"
$content = Get-Content -Path $SourceFile -Encoding Unicode -Raw

function Req($cond, $msg) { if (-not $cond) { throw $msg } }

# ============================================================
# 1) wrapper's own arguments=(...) list: drop arg_tgl3/arg_tgl4, insert 24 bln args, append arg_jml_bulan
# ============================================================
$oldArgTgl34 = "(`"arg_tgl3`", datetime),(`"arg_tgl4`", datetime),"
Req ($content.Contains($oldArgTgl34)) "arg_tgl3/4 arg-decl anchor not found"
$content = $content.Replace($oldArgTgl34, "")

$blnArgDecl = ""
for ($n=1; $n -le 12; $n++) {
    $blnArgDecl += "(`"arg_bln${n}_awal`", datetime),(`"arg_bln${n}_akhir`", datetime),"
}
$oldArgTgl2 = "(`"arg_tgl2`", datetime),"
Req ($content.Contains($oldArgTgl2)) "arg_tgl2 arg-decl anchor not found"
$content = $content.Replace($oldArgTgl2, $oldArgTgl2 + $blnArgDecl)

$oldArgShowClose = "(`"arg_show`", number)) )"
Req ($content.Contains($oldArgShowClose)) "arg_show closing anchor not found"
$content = $content.Replace($oldArgShowClose, "(`"arg_show`", number),(`"arg_jml_bulan`", number)) )")

# ============================================================
# 2) each report(band=detail ...) nested control: repoint dataobject to _multibulan sibling,
#    widen it, and expand its nest_arguments the same way (positionally matches child's own arguments=)
# ============================================================
$reportStarts = [regex]::Matches($content, 'report\(band=detail') | ForEach-Object { $_.Index }
Req ($reportStarts.Count -eq 5) "expected exactly 5 nested report() controls, found $($reportStarts.Count)"

$rebuilt = @()
foreach ($p in $reportStarts) {
    $endIdx = $content.IndexOf(")" + $CRLF, $p)
    Req ($endIdx -ge 0) "could not find closing paren for report() at $p"
    $full = $content.Substring($p, ($endIdx + 1) - $p)

    # a) dataobject -> _multibulan sibling
    $doMatch = [regex]::Match($full, 'dataobject="(dw_rpt_is_\w+)"')
    Req $doMatch.Success "dataobject not found in report() block"
    $newDo = $doMatch.Groups[1].Value + "_multibulan"
    $newFull = $full.Replace($doMatch.Value, "dataobject=`"$newDo`"")

    # b) widen (fixed nested-report clip width) from 3342 -> 8500
    $newFull = $newFull -replace 'width="3342"', 'width="8500"'

    # c) nest_arguments: drop arg_tgl3/arg_tgl4 entries (tolerate optional inner spaces), insert 24 bln entries after arg_tgl2, append arg_jml_bulan after arg_show
    $newFull = $newFull -replace '\("\s*arg_tgl3\s*"\),\("\s*arg_tgl4\s*"\),', ''
    $blnNest = ""
    for ($n=1; $n -le 12; $n++) { $blnNest += "(`"arg_bln${n}_awal`"),(`"arg_bln${n}_akhir`")," }
    $newFull2 = $newFull -replace '\("\s*arg_tgl2\s*"\),', ('("arg_tgl2"),' + $blnNest)
    Req ($newFull2 -ne $newFull) "arg_tgl2 nest_arguments anchor not found in report() block for $newDo"
    $newFull = $newFull2 -replace '\("\s*arg_show\s*"\)\)', '("arg_show"),("arg_jml_bulan"))'
    Req ($newFull -match '"arg_jml_bulan"') "arg_jml_bulan not appended to nest_arguments for $newDo"

    $rebuilt += @{ Old = $full; New = $newFull }
}
foreach ($r in $rebuilt) { $content = $content.Replace($r.Old, $r.New) }

# ============================================================
# 3) header band: t_1 ("Periode Ini") -> 12 dynamic month-label computes; t_2 ("Sampai Dengan Periode Ini") -> "Total" label
# ============================================================
$t1NameIdx = $content.IndexOf('name=t_1 visible="1" ')
Req ($t1NameIdx -ge 0) "t_1 header text not found"
$t1Start = $content.LastIndexOf("text(band=header", $t1NameIdx)
Req ($t1Start -ge 0) "text(band=header start not found before t_1"
$t1End = $content.IndexOf(")" + $CRLF, $t1NameIdx)
$t1Full = $content.Substring($t1Start, ($t1End+1) - $t1Start)
$t1Tail = $t1Full.Substring($t1Full.IndexOf('name=t_1 visible="1" ') + 'name=t_1 visible="1" '.Length)

$baseX = 2048
$colStep = 484
$colWidth = 480
$hdrParts = @()
for ($n=1; $n -le 12; $n++) {
    $x = $baseX + ($n-1)*$colStep
    $hdrParts += "compute(band=header alignment=`"2`" expression=`"string(arg_bln${n}_akhir,'mmm yyyy')`"border=`"2`" color=`"33554432`" x=`"$x`" y=`"316`" height=`"128`" width=`"$colWidth`" format=`"[GENERAL]`" html.valueishtml=`"0`"  name=chdr_bln${n} visible=`"arg_jml_bulan>=${n}`" $t1Tail"
}
$content = $content.Replace($t1Full, [string]::Join($CRLF, $hdrParts))

$t2NameIdx = $content.IndexOf('name=t_2 visible="1" ')
Req ($t2NameIdx -ge 0) "t_2 header text not found"
$t2Start = $content.LastIndexOf("text(band=header", $t2NameIdx)
Req ($t2Start -ge 0) "text(band=header start not found before t_2"
$t2End = $content.IndexOf(")" + $CRLF, $t2NameIdx)
$t2Full = $content.Substring($t2Start, ($t2End+1) - $t2Start)
$ttlX = $baseX + 12*$colStep
$newT2 = $t2Full.Replace('text="Sampai Dengan' + $CRLF + 'Periode Ini"', 'text="Total"').Replace('x="2674"', "x=`"$ttlX`"").Replace("name=t_2 visible=", "name=t_ttl visible=")
Req ($newT2 -ne $t2Full) "t_2 text/x substitution had no effect"
$content = $content.Replace($t2Full, $newT2)

# ============================================================
# 4) header title compute_3: 'Periode : '+string(arg_tgl3,'mmm yyyy')  ->  'Periode : '+bln1_awal+' s/d '+<last selected month, nested-if on arg_jml_bulan>
# ============================================================
$endLabelExpr = "string(arg_bln12_akhir,'mmm yyyy')"
for ($n=11; $n -ge 1; $n--) {
    $endLabelExpr = "if(arg_jml_bulan=${n},string(arg_bln${n}_akhir,'mmm yyyy')," + $endLabelExpr + ")"
}
$newTitleExpr = "'Periode : '+string(arg_bln1_awal,'mmm yyyy')+' s/d '+" + $endLabelExpr
$oldTitle = 'expression="' + "'Periode : '+string(arg_tgl3,'mmm yyyy')" + '"'
Req ($content.Contains($oldTitle)) "compute_3 title anchor not found"
$content = $content.Replace($oldTitle, 'expression="' + $newTitleExpr + '"')

# ============================================================
# write output
# ============================================================
[System.IO.File]::WriteAllText($DestFile, $content, [System.Text.Encoding]::Unicode)
Write-Output "OK: wrote $DestFile"
