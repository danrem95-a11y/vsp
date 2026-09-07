$ErrorActionPreference = "Stop"
$CRLF = "`r`n"
$CTAIL  = ' font.face="Tahoma" font.height="-10" font.weight="400"  font.family="2" font.pitch="2" font.charset="0" background.mode="1" background.color="536870912" background.transparency="0" background.gradient.color="8421504" background.gradient.transparency="0" background.gradient.angle="0" background.brushmode="0" background.gradient.repetition.mode="0" background.gradient.repetition.count="0" background.gradient.repetition.length="100" background.gradient.focus="0" background.gradient.scale="100" background.gradient.spread="100" tooltip.backcolor="134217752" tooltip.delay.initial="0" tooltip.delay.visible="32000" tooltip.enabled="0" tooltip.hasclosebutton="0" tooltip.icon="0" tooltip.isbubble="0" tooltip.maxwidth="0" tooltip.textcolor="134217751" tooltip.transparency="0" transparency="0" )'
$CTAILB = ' font.face="Tahoma" font.height="-10" font.weight="700"  font.family="2" font.pitch="2" font.charset="0" background.mode="1" background.color="536870912" background.transparency="0" background.gradient.color="8421504" background.gradient.transparency="0" background.gradient.angle="0" background.brushmode="0" background.gradient.repetition.mode="0" background.gradient.repetition.count="0" background.gradient.repetition.length="100" background.gradient.focus="0" background.gradient.scale="100" background.gradient.spread="100" tooltip.backcolor="134217752" tooltip.delay.initial="0" tooltip.delay.visible="32000" tooltip.enabled="0" tooltip.hasclosebutton="0" tooltip.icon="0" tooltip.isbubble="0" tooltip.maxwidth="0" tooltip.textcolor="134217751" tooltip.transparency="0" transparency="0" )'
$CTAILBG = ' font.face="Tahoma" font.height="-10" font.weight="700"  font.family="2" font.pitch="2" font.charset="0" background.mode="2" background.color="12632256" background.transparency="0" background.gradient.color="8421504" background.gradient.transparency="0" background.gradient.angle="0" background.brushmode="0" background.gradient.repetition.mode="0" background.gradient.repetition.count="0" background.gradient.repetition.length="100" background.gradient.focus="0" background.gradient.scale="100" background.gradient.spread="100" tooltip.backcolor="134217752" tooltip.delay.initial="0" tooltip.delay.visible="32000" tooltip.enabled="0" tooltip.hasclosebutton="0" tooltip.icon="0" tooltip.isbubble="0" tooltip.maxwidth="0" tooltip.textcolor="134217751" tooltip.transparency="0" transparency="0" )'

$colWidth = 480
$colStep  = 484
$baseX    = 2048
$ttlX     = $baseX + 12*$colStep

$tr = @()
$rowH = 76
$y0 = 8
# --- normal per-fincatcode subtotal row (y0) ---
$tr += "compute(band=trailer.1 alignment=`"0`" expression=`"'TOTAL '+fincatdes`"border=`"0`" color=`"33554432`" x=`"18`" y=`"$y0`" height=`"$rowH`" width=`"1400`" format=`"[GENERAL]`" html.valueishtml=`"0`"  name=t_total_label visible=`"1`" $CTAILB"
$tr += "compute(band=trailer.1 alignment=`"1`" expression=`"sum(if(fincatcode='IS2230' and parentcode='500-010',-saldo_awal,saldo_awal) for group 1)`"border=`"0`" color=`"33554432`" x=`"1422`" y=`"$y0`" height=`"$rowH`" width=`"622`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=g_saldo_awal visible=`"1`" $CTAILB"
for ($n=1; $n -le 12; $n++) {
    $x = $baseX + ($n-1)*$colStep
    $expr = "sum(if(fincatcode='IS2230' and parentcode='500-010',-cbln${n},cbln${n}) for group 1)"
    $tr += "compute(band=trailer.1 alignment=`"1`" expression=`"$expr`"border=`"0`" color=`"33554432`" x=`"$x`" y=`"$y0`" height=`"$rowH`" width=`"$colWidth`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=g_cbln${n} visible=`"1`" $CTAILB"
}
$gttlExpr = "g_saldo_awal + g_cbln1"
for ($n=2; $n -le 12; $n++) { $gttlExpr += " + if(arg_jml_bulan>=${n},g_cbln${n},0)" }
$tr += "compute(band=trailer.1 alignment=`"1`" expression=`"$gttlExpr`"border=`"0`" color=`"33554432`" x=`"$ttlX`" y=`"$y0`" height=`"$rowH`" width=`"622`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=g_ttl visible=`"1`" $CTAILB"

# --- 5 conditional rollup rows, each gated visible="fincatcode='ISxxxx'" (row-level, column-value based - NOT the arg-based mechanism that failed) ---
$rollups = @(
    @{ gate="fincatcode='IS1110'"; label="LABA KOTOR PENJUALAN"; prefix="labakotor" },
    @{ gate="fincatcode='IS2130'"; label="GRAND TOTAL BIAYA"; prefix="__biaya_grand__" },
    @{ gate="fincatcode='IS2130'"; label="LABA (RUGI) OPERASIONAL"; prefix="labaoperasional" },
    @{ gate="fincatcode='IS2230'"; label="LABA (RUGI) SEBELUM PAJAK"; prefix="labasblmpajak" },
    @{ gate="fincatcode='IS2330'"; label="LABA (RUGI) BERSIH"; prefix="labaBersih" }
)
$rowIdx = 1
foreach ($r in $rollups) {
    $y = $y0 + $rowIdx * ($rowH + 8)
    $gate = $r.gate
    $label = $r.label
    $prefix = $r.prefix
    $tr += "compute(band=trailer.1 alignment=`"0`" expression=`"'$label'`"border=`"0`" color=`"33554432`" x=`"18`" y=`"$y`" height=`"$rowH`" width=`"1400`" format=`"[GENERAL]`" html.valueishtml=`"0`"  name=lbl_${rowIdx} visible=`"$gate`" $CTAILBG"
    if ($prefix -eq "__biaya_grand__") {
        $tr += "compute(band=trailer.1 alignment=`"1`" expression=`"tot_biaya_lalu`"border=`"0`" color=`"33554432`" x=`"1422`" y=`"$y`" height=`"$rowH`" width=`"622`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=rlp_${rowIdx}_lalu visible=`"$gate`" $CTAILBG"
        for ($n=1; $n -le 12; $n++) {
            $x = $baseX + ($n-1)*$colStep
            $tr += "compute(band=trailer.1 alignment=`"1`" expression=`"tot_biaya_bln${n}`"border=`"0`" color=`"33554432`" x=`"$x`" y=`"$y`" height=`"$rowH`" width=`"$colWidth`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=rlp_${rowIdx}_bln${n} visible=`"$gate`" $CTAILBG"
        }
        $tr += "compute(band=trailer.1 alignment=`"1`" expression=`"tot_biaya_ttl`"border=`"0`" color=`"33554432`" x=`"$ttlX`" y=`"$y`" height=`"$rowH`" width=`"622`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=rlp_${rowIdx}_ttl visible=`"$gate`" $CTAILBG"
    } else {
        $tr += "compute(band=trailer.1 alignment=`"1`" expression=`"${prefix}_lalu`"border=`"0`" color=`"33554432`" x=`"1422`" y=`"$y`" height=`"$rowH`" width=`"622`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=rlp_${rowIdx}_lalu visible=`"$gate`" $CTAILBG"
        for ($n=1; $n -le 12; $n++) {
            $x = $baseX + ($n-1)*$colStep
            $tr += "compute(band=trailer.1 alignment=`"1`" expression=`"${prefix}_bln${n}`"border=`"0`" color=`"33554432`" x=`"$x`" y=`"$y`" height=`"$rowH`" width=`"$colWidth`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=rlp_${rowIdx}_bln${n} visible=`"$gate`" $CTAILBG"
        }
        $tr += "compute(band=trailer.1 alignment=`"1`" expression=`"${prefix}_ttl`"border=`"0`" color=`"33554432`" x=`"$ttlX`" y=`"$y`" height=`"$rowH`" width=`"622`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=rlp_${rowIdx}_ttl visible=`"$gate`" $CTAILBG"
    }
    $rowIdx++
}
$trailer1Block = [string]::Join($CRLF, $tr)
$trailer1Height = $y0 + ($rowIdx) * ($rowH + 8) + 20

Write-Output "trailer.1 objects: $($tr.Count)"
Write-Output "trailer.1 height needed: $trailer1Height"

$trailer1Block | Out-File -FilePath c:\BTV\debug\_flat_trailer1.txt -Encoding utf8 -NoNewline
$trailer1Height | Out-File -FilePath c:\BTV\debug\_flat_trailer1_height.txt -Encoding utf8 -NoNewline

# ============================================================
# trailer.2 (parentcode) -- REAL/visible row (the actual per-line-item row shown to the user,
# since one parentcode can span multiple gl_acc.accountcode rows -- confirmed via DB catalog:
# e.g. IS1001/400-000 alone had 5+ distinct accountcodes). Detail band itself is suppressed
# (height=0); this trailer.2 band IS the visible "line item" row. Mirrors trailer.1's proven
# sum(...for group N) mechanism, scoped to group 2 instead of group 1.
# ============================================================
$tr2 = @()
$tr2 += "column(band=trailer.2 id=1 alignment=`"0`" tabsequence=32766 border=`"0`" color=`"33554432`" x=`"69`" y=`"$y0`" height=`"$rowH`" width=`"1340`" format=`"[GENERAL]`" html.valueishtml=`"0`"  name=t2_parentname visible=`"1`" $CTAIL"
$tr2 += "compute(band=trailer.2 alignment=`"1`" expression=`"sum(if(fincatcode='IS2230' and parentcode='500-010',-saldo_awal,saldo_awal) for group 2)`"border=`"0`" color=`"33554432`" x=`"1422`" y=`"$y0`" height=`"$rowH`" width=`"622`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=g2_saldo_awal visible=`"1`" $CTAIL"
for ($n=1; $n -le 12; $n++) {
    $x = $baseX + ($n-1)*$colStep
    $expr = "sum(if(fincatcode='IS2230' and parentcode='500-010',-cbln${n},cbln${n}) for group 2)"
    $tr2 += "compute(band=trailer.2 alignment=`"1`" expression=`"$expr`"border=`"0`" color=`"33554432`" x=`"$x`" y=`"$y0`" height=`"$rowH`" width=`"$colWidth`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=g2_cbln${n} visible=`"1`" $CTAIL"
}
$g2ttlExpr = "g2_saldo_awal + g2_cbln1"
for ($n=2; $n -le 12; $n++) { $g2ttlExpr += " + if(arg_jml_bulan>=${n},g2_cbln${n},0)" }
$tr2 += "compute(band=trailer.2 alignment=`"1`" expression=`"$g2ttlExpr`"border=`"0`" color=`"33554432`" x=`"$ttlX`" y=`"$y0`" height=`"$rowH`" width=`"622`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=g2_ttl visible=`"1`" $CTAIL"
$trailer2Block = [string]::Join($CRLF, $tr2)
$trailer2Height = $y0 + $rowH + 16

Write-Output "trailer.2 objects: $($tr2.Count)"
Write-Output "trailer.2 height needed: $trailer2Height"

$trailer2Block | Out-File -FilePath c:\BTV\debug\_flat_trailer2.txt -Encoding utf8 -NoNewline
$trailer2Height | Out-File -FilePath c:\BTV\debug\_flat_trailer2_height.txt -Encoding utf8 -NoNewline
