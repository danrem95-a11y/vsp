param(
    [Parameter(Mandatory=$true)][string]$SourceFile,
    [Parameter(Mandatory=$true)][string]$DestFile
)

$ErrorActionPreference = "Stop"
$CRLF = "`r`n"

$content = Get-Content -Path $SourceFile -Encoding Unicode -Raw

function Req($cond, $msg) { if (-not $cond) { throw $msg } }

# Locate a single-line compute(...) object by band + name, return (fullText, xAttrValue)
function Get-ComputeObj($content, $band, $name) {
    $m = [regex]::Match($content, "compute\(band=" + [regex]::Escape($band) + "[^\r\n]*?name=" + [regex]::Escape($name) + "\b[^\r\n]*?visible=`"[^`"]*`" ")
    if (-not $m.Success) { throw "compute object band=$band name=$name not found" }
    $startIdx = $m.Index
    $tailEnd = $content.IndexOf(")" + "`r`n", $m.Index + $m.Length)
    if ($tailEnd -lt 0) { throw "closing paren for band=$band name=$name not found" }
    $full = $content.Substring($startIdx, ($tailEnd + 1) - $startIdx)
    $xm = [regex]::Match($full, 'x="(\d+)"')
    $x = if ($xm.Success) { [int]$xm.Groups[1].Value } else { $null }
    return @{ Full = $full; X = $x }
}

# ============================================================
# 1) table() column defs: mutasi_debit/credit -> 24 bln columns
# ============================================================
$oldCols = " column=(type=decimal(6) updatewhereclause=yes name=mutasi_debit dbname=`"mutasi_debit`" )" + $CRLF + " column=(type=decimal(6) updatewhereclause=yes name=mutasi_credit dbname=`"mutasi_credit`" )" + $CRLF
Req ($content.Contains($oldCols)) "column-def anchor not found"

$newCols = ""
for ($n=1; $n -le 12; $n++) {
    $newCols += " column=(type=decimal(6) updatewhereclause=yes name=bln${n}_debit dbname=`"bln${n}_debit`" )" + $CRLF
    $newCols += " column=(type=decimal(6) updatewhereclause=yes name=bln${n}_credit dbname=`"bln${n}_credit`" )" + $CRLF
}
$content = $content.Replace($oldCols, $newCols)

# ============================================================
# 2) SELECT-list projections: mutasi -> 24 bln projections
# ============================================================
$oldSel = "isnull(mutasi.debit,0.00) as mutasi_debit," + $CRLF + "isnull(mutasi.credit,0.00) as mutasi_credit," + $CRLF
Req ($content.Contains($oldSel)) "SELECT-list anchor not found"

$newSel = ""
for ($n=1; $n -le 12; $n++) {
    $newSel += "isnull(bln${n}.debit,0.00) as bln${n}_debit," + $CRLF + "isnull(bln${n}.credit,0.00) as bln${n}_credit," + $CRLF
}
$content = $content.Replace($oldSel, $newSel)

# ============================================================
# 3) FROM subquery block ("mutasi") -> 12 bln subqueries
# ============================================================
$idx3 = $content.IndexOf(":arg_tgl3")
Req ($idx3 -ge 0) "arg_tgl3 not found"
$openParen = $content.LastIndexOf($CRLF + "(" + $CRLF, $idx3)
Req ($openParen -ge 0) "subquery open-paren anchor not found"
$idx4 = $content.IndexOf(") mutasi", $idx3)
Req ($idx4 -ge 0) ") mutasi not found"
$subBlock = $content.Substring($openParen, ($idx4 + 8) - $openParen)

$newSubParts = @()
for ($n=1; $n -le 12; $n++) {
    $b = $subBlock.Replace(":arg_tgl3", ":arg_bln${n}_awal").Replace(":arg_tgl4", ":arg_bln${n}_akhir").Replace(") mutasi", ") bln${n}")
    if ($n -lt 12) { $b += "," }
    $newSubParts += $b
}
$newSub = [string]::Join("", $newSubParts)
$content = $content.Replace($subBlock, $newSub)

# ============================================================
# 4) WHERE outer-join line: mutasi -> 12 bln joins
# ============================================================
$oldJoin = "c.accountcode *= mutasi.account_id"
Req ($content.Contains($oldJoin)) "mutasi outer-join line not found"
$joinParts = @()
for ($n=1; $n -le 12; $n++) {
    $j = "c.accountcode *= bln${n}.account_id"
    if ($n -lt 12) { $j += " and" }
    $joinParts += $j
}
$newJoin = [string]::Join($CRLF, $joinParts)
$content = $content.Replace($oldJoin, $newJoin)

# ============================================================
# 5) arguments=(...) list: drop arg_tgl3/arg_tgl4, insert 24 bln date args, append arg_jml_bulan
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

$oldArgShowClose = "(`"arg_show`", number))  sort="
Req ($content.Contains($oldArgShowClose)) "arg_show closing anchor not found"
$content = $content.Replace($oldArgShowClose, "(`"arg_show`", number),(`"arg_jml_bulan`", number))  sort=")

# ============================================================
# 6) detail-band computes: clalu -> saldo_awal; cmutasi -> 12x cbln{N}; compute_4 -> cttl
#    (positions read dynamically per-file, not hardcoded)
# ============================================================
$clalu = Get-ComputeObj $content "detail" "clalu"
$content = $content.Replace($clalu.Full, $clalu.Full.Replace("name=clalu visible=", "name=saldo_awal visible="))

$cmutasi = Get-ComputeObj $content "detail" "cmutasi"
$cmutasiTail = $cmutasi.Full.Substring($cmutasi.Full.IndexOf('name=cmutasi visible="1" ') + 'name=cmutasi visible="1" '.Length)

$colWidth = 480
$colStep = 484
$baseX = $cmutasi.X
$cblnParts = @()
for ($n=1; $n -le 12; $n++) {
    $x = $baseX + ($n-1)*$colStep
    $expr = "(bln${n}_debit - bln${n}_credit) * if(flag_dk='D',1,(-1))"
    $cblnParts += "compute(band=detail alignment=`"1`" expression=`"$expr`"border=`"0`" color=`"33554432`" x=`"$x`" y=`"4`" height=`"76`" width=`"$colWidth`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=cbln${n} visible=`"arg_jml_bulan>=${n}`" $cmutasiTail"
}
$content = $content.Replace($cmutasi.Full, [string]::Join($CRLF, $cblnParts))

$c4 = Get-ComputeObj $content "detail" "compute_4"
$c4Tail = $c4.Full.Substring($c4.Full.IndexOf('name=compute_4 visible="1" ') + 'name=compute_4 visible="1" '.Length)
$ttlX = $baseX + 12*$colStep
$ttlExpr = "saldo_awal + cbln1"
for ($n=2; $n -le 12; $n++) { $ttlExpr += " + if(arg_jml_bulan>=${n},cbln${n},0)" }
$newCttl = "compute(band=detail alignment=`"1`" expression=`"$ttlExpr`"border=`"0`" color=`"33554432`" x=`"$ttlX`" y=`"4`" height=`"76`" width=`"622`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=cttl visible=`"1`" $c4Tail"
$content = $content.Replace($c4.Full, $newCttl)

# ============================================================
# 7) trailer.1 computes: compute_9 (sum clalu) -> sum saldo_awal; compute_11 (sum cmutasi) -> 12x sum cbln{N}; compute_10 -> guarded total
#    SPECIAL CASE: pendapatan_rekap/pajak_rekap split each figure by parentcode='500-000' via hidden
#    helper computes (lalu_500/lalu_510, mutasi_500/mutasi_510) so trailer.1 can net two sub-groups
#    into one subtotal row (sum(lalu_500 - lalu_510 for group 1) etc). Detect and handle that pattern.
# ============================================================
$hasNetSplit = $content.Contains("name=lalu_500 ")

if (-not $hasNetSplit) {
    $c9 = Get-ComputeObj $content "trailer.1" "compute_9"
    $content = $content.Replace($c9.Full, $c9.Full.Replace("sum(clalu for group 1)", "sum(saldo_awal for group 1)"))

    $c11 = Get-ComputeObj $content "trailer.1" "compute_11"
    $c11Tail = $c11.Full.Substring($c11.Full.IndexOf('name=compute_11 visible="1" ') + 'name=compute_11 visible="1" '.Length)
    $tCblnParts = @()
    for ($n=1; $n -le 12; $n++) {
        $x = $baseX + ($n-1)*$colStep
        $expr = "sum(cbln${n} for group 1)"
        $tCblnParts += "compute(band=trailer.1 alignment=`"1`" expression=`"$expr`"border=`"0`" color=`"33554432`" x=`"$x`" y=`"8`" height=`"76`" width=`"$colWidth`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=t_cbln${n} visible=`"arg_jml_bulan>=${n}`" $c11Tail"
    }
    $content = $content.Replace($c11.Full, [string]::Join($CRLF, $tCblnParts))

    $c10 = Get-ComputeObj $content "trailer.1" "compute_10"
    $tTtlExpr = "sum(saldo_awal for group 1) + sum(cbln1 for group 1)"
    for ($n=2; $n -le 12; $n++) { $tTtlExpr += " + if(arg_jml_bulan>=${n},sum(cbln${n} for group 1),0)" }
    $newC10 = $c10.Full -replace [regex]::Escape('expression="sum(clalu + cmutasi for group 1)"'), ('expression="' + $tTtlExpr + '"')
    Req ($newC10 -ne $c10.Full) "compute_10 expression substitution had no effect"
    $newC10 = $newC10.Replace("name=compute_10 visible=", "name=t_cttl visible=")
    $content = $content.Replace($c10.Full, $newC10)
} else {
    # --- lalu_500 / lalu_510: rename their internal "clalu" reference to "saldo_awal" ---
    $lalu500 = Get-ComputeObj $content "detail" "lalu_500"
    Req ($lalu500.Full.Contains("clalu")) "lalu_500 does not reference clalu as expected"
    $content = $content.Replace($lalu500.Full, $lalu500.Full.Replace("clalu", "saldo_awal"))

    $lalu510 = Get-ComputeObj $content "detail" "lalu_510"
    Req ($lalu510.Full.Contains("clalu")) "lalu_510 does not reference clalu as expected"
    $content = $content.Replace($lalu510.Full, $lalu510.Full.Replace("clalu", "saldo_awal"))

    # --- mutasi_500 / mutasi_510: replace with 12x cbln{N}_500 / cbln{N}_510 hidden helper pairs ---
    $mutasi500 = Get-ComputeObj $content "detail" "mutasi_500"
    Req ($mutasi500.Full.Contains("cmutasi")) "mutasi_500 does not reference cmutasi as expected"
    $m500Tail = $mutasi500.Full.Substring($mutasi500.Full.IndexOf('name=mutasi_500 visible="0" ') + 'name=mutasi_500 visible="0" '.Length)
    $m500ExprTpl = [regex]::Match($mutasi500.Full, 'expression="([^"]*)"').Groups[1].Value

    $mutasi510 = Get-ComputeObj $content "detail" "mutasi_510"
    Req ($mutasi510.Full.Contains("cmutasi")) "mutasi_510 does not reference cmutasi as expected"
    $m510Tail = $mutasi510.Full.Substring($mutasi510.Full.IndexOf('name=mutasi_510 visible="0" ') + 'name=mutasi_510 visible="0" '.Length)
    $m510ExprTpl = [regex]::Match($mutasi510.Full, 'expression="([^"]*)"').Groups[1].Value

    $helperParts = @()
    for ($n=1; $n -le 12; $n++) {
        $y = 220 + $n*20
        $e500 = $m500ExprTpl.Replace("cmutasi", "cbln${n}")
        $e510 = $m510ExprTpl.Replace("cmutasi", "cbln${n}")
        $helperParts += "compute(band=detail alignment=`"0`" expression=`"$e500`"border=`"0`" color=`"33554432`" x=`"823`" y=`"$y`" height=`"64`" width=`"457`" format=`"[GENERAL]`" html.valueishtml=`"0`"  name=cbln${n}_500 visible=`"0`" $m500Tail"
        $helperParts += "compute(band=detail alignment=`"0`" expression=`"$e510`"border=`"0`" color=`"33554432`" x=`"1344`" y=`"$y`" height=`"64`" width=`"457`" format=`"[GENERAL]`" html.valueishtml=`"0`"  name=cbln${n}_510 visible=`"0`" $m510Tail"
    }
    $content = $content.Replace($mutasi500.Full, [string]::Join($CRLF, $helperParts))
    $content = $content.Replace($mutasi510.Full, "")

    # --- compute_9: already valid as-is (sum(lalu_500 - lalu_510 for group 1); lalu_500/510 still exist) ---

    # --- compute_11 -> 12x net-split trailer sums ---
    $c11 = Get-ComputeObj $content "trailer.1" "compute_11"
    $c11Tail = $c11.Full.Substring($c11.Full.IndexOf('name=compute_11 visible="1" ') + 'name=compute_11 visible="1" '.Length)
    $tCblnParts = @()
    for ($n=1; $n -le 12; $n++) {
        $x = $baseX + ($n-1)*$colStep
        $expr = "sum(cbln${n}_500 - cbln${n}_510 for group 1)"
        $tCblnParts += "compute(band=trailer.1 alignment=`"1`" expression=`"$expr`"border=`"0`" color=`"33554432`" x=`"$x`" y=`"8`" height=`"76`" width=`"$colWidth`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=t_cbln${n} visible=`"arg_jml_bulan>=${n}`" $c11Tail"
    }
    $content = $content.Replace($c11.Full, [string]::Join($CRLF, $tCblnParts))

    # --- compute_10 -> guarded net total ---
    $c10 = Get-ComputeObj $content "trailer.1" "compute_10"
    $tTtlExpr = "sum(lalu_500 - lalu_510 for group 1) + sum(cbln1_500 - cbln1_510 for group 1)"
    for ($n=2; $n -le 12; $n++) { $tTtlExpr += " + if(arg_jml_bulan>=${n},sum(cbln${n}_500 - cbln${n}_510 for group 1),0)" }
    $newC10 = $c10.Full -replace [regex]::Escape('expression="sum((lalu_500 - lalu_510) + (mutasi_500 - mutasi_510) for group 1)"'), ('expression="' + $tTtlExpr + '"')
    Req ($newC10 -ne $c10.Full) "compute_10 (net-split) expression substitution had no effect"
    $newC10 = $newC10.Replace("name=compute_10 visible=", "name=t_cttl visible=")
    $content = $content.Replace($c10.Full, $newC10)
}

# ============================================================
# 8) header.2 computes (group-2 "parentcode" header, suppressed but must stay valid) - mirror of trailer.1 for "group 2"
# ============================================================
$c6 = Get-ComputeObj $content "header.2" "compute_6"
$content = $content.Replace($c6.Full, $c6.Full.Replace("sum(clalu for group 2)", "sum(saldo_awal for group 2)"))

$c8 = Get-ComputeObj $content "header.2" "compute_8"
$c8Tail = $c8.Full.Substring($c8.Full.IndexOf('name=compute_8 visible="1" ') + 'name=compute_8 visible="1" '.Length)
$hCblnParts = @()
for ($n=1; $n -le 12; $n++) {
    $x = $baseX + ($n-1)*$colStep
    $expr = "sum(cbln${n} for group 2)"
    $hCblnParts += "compute(band=header.2 alignment=`"1`" expression=`"$expr`"border=`"0`" color=`"33554432`" x=`"$x`" y=`"4`" height=`"76`" width=`"$colWidth`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=h_cbln${n} visible=`"arg_jml_bulan>=${n}`" $c8Tail"
}
$content = $content.Replace($c8.Full, [string]::Join($CRLF, $hCblnParts))

$c7 = Get-ComputeObj $content "header.2" "compute_7"
$hTtlExpr = "sum(saldo_awal for group 2) + sum(cbln1 for group 2)"
for ($n=2; $n -le 12; $n++) { $hTtlExpr += " + if(arg_jml_bulan>=${n},sum(cbln${n} for group 2),0)" }
$newC7 = $c7.Full -replace [regex]::Escape('expression="sum(clalu + cmutasi for group 2)"'), ('expression="' + $hTtlExpr + '"')
Req ($newC7 -ne $c7.Full) "compute_7 expression substitution had no effect"
$newC7 = $newC7.Replace("name=compute_7 visible=", "name=h_cttl visible=")
$content = $content.Replace($c7.Full, $newC7)

# ============================================================
# write output (preserve UTF-16LE + BOM)
# ============================================================
[System.IO.File]::WriteAllText($DestFile, $content, [System.Text.Encoding]::Unicode)
Write-Output "OK: wrote $DestFile (baseX=$baseX)"
