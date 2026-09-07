$ErrorActionPreference = "Stop"
$CRLF = "`r`n"

$CTAIL  = ' font.face="Tahoma" font.height="-10" font.weight="400"  font.family="2" font.pitch="2" font.charset="0" background.mode="1" background.color="536870912" background.transparency="0" background.gradient.color="8421504" background.gradient.transparency="0" background.gradient.angle="0" background.brushmode="0" background.gradient.repetition.mode="0" background.gradient.repetition.count="0" background.gradient.repetition.length="100" background.gradient.focus="0" background.gradient.scale="100" background.gradient.spread="100" tooltip.backcolor="134217752" tooltip.delay.initial="0" tooltip.delay.visible="32000" tooltip.enabled="0" tooltip.hasclosebutton="0" tooltip.icon="0" tooltip.isbubble="0" tooltip.maxwidth="0" tooltip.textcolor="134217751" tooltip.transparency="0" transparency="0" )'
$CTAILB = ' font.face="Tahoma" font.height="-10" font.weight="700"  font.family="2" font.pitch="2" font.charset="0" background.mode="1" background.color="536870912" background.transparency="0" background.gradient.color="8421504" background.gradient.transparency="0" background.gradient.angle="0" background.brushmode="0" background.gradient.repetition.mode="0" background.gradient.repetition.count="0" background.gradient.repetition.length="100" background.gradient.focus="0" background.gradient.scale="100" background.gradient.spread="100" tooltip.backcolor="134217752" tooltip.delay.initial="0" tooltip.delay.visible="32000" tooltip.enabled="0" tooltip.hasclosebutton="0" tooltip.icon="0" tooltip.isbubble="0" tooltip.maxwidth="0" tooltip.textcolor="134217751" tooltip.transparency="0" transparency="0" )'

$colWidth = 480
$colStep  = 484
$baseX    = 2048
$ttlX     = $baseX + 12*$colStep   # 7856

# net-split condition (Other Non Operating: subtract Biaya Lain-lain instead of adding)
function NetTerm($val) { "if(fincatcode='IS2230' and parentcode='500-010',-${val},${val})" }

# --------------------------------------------------------------
# HEADER band (page-level, once)
# --------------------------------------------------------------
$hdr = @()
$hdr += "compute(band=header alignment=`"0`" expression=`"f_company()`"border=`"0`" color=`"33554432`" x=`"14`" y=`"8`" height=`"80`" width=`"1376`" format=`"[GENERAL]`" html.valueishtml=`"0`"  name=compute_1 visible=`"1`" $CTAILB"
$hdr += "compute(band=header alignment=`"0`" expression=`"'INCOME STATEMENT'`"border=`"0`" color=`"33554432`" x=`"14`" y=`"104`" height=`"80`" width=`"1376`" format=`"[GENERAL]`" html.valueishtml=`"0`"  name=compute_2 visible=`"1`" $CTAILB"
$endLabelExpr = "string(arg_bln12_akhir,'mmm yyyy')"
for ($n=11; $n -ge 1; $n--) { $endLabelExpr = "if(arg_jml_bulan=${n},string(arg_bln${n}_akhir,'mmm yyyy')," + $endLabelExpr + ")" }
$titleExpr = "'Periode : '+string(arg_bln1_awal,'mmm yyyy')+' s/d '+" + $endLabelExpr
$hdr += "compute(band=header alignment=`"0`" expression=`"$titleExpr`"border=`"0`" color=`"33554432`" x=`"14`" y=`"196`" height=`"80`" width=`"1870`" format=`"[GENERAL]`" html.valueishtml=`"0`"  name=compute_3 visible=`"1`" $CTAILB"
$hdr += "text(band=header alignment=`"2`" text=`"Description`"border=`"2`" color=`"33554432`" x=`"9`" y=`"316`" height=`"128`" width=`"1408`" html.valueishtml=`"0`"  name=t_desc visible=`"1`" $CTAILB"
$hdr += "text(band=header alignment=`"2`" text=`"Periode Lalu`"border=`"2`" color=`"33554432`" x=`"1422`" y=`"316`" height=`"128`" width=`"622`" html.valueishtml=`"0`"  name=t_lalu visible=`"1`" $CTAILB"
for ($n=1; $n -le 12; $n++) {
    $x = $baseX + ($n-1)*$colStep
    $hdr += "compute(band=header alignment=`"2`" expression=`"string(arg_bln${n}_akhir,'mmm yyyy')`"border=`"2`" color=`"33554432`" x=`"$x`" y=`"316`" height=`"128`" width=`"$colWidth`" format=`"[GENERAL]`" html.valueishtml=`"0`"  name=chdr_bln${n} visible=`"1`" $CTAILB"
}
$hdr += "text(band=header alignment=`"2`" text=`"Total`"border=`"2`" color=`"33554432`" x=`"$ttlX`" y=`"316`" height=`"128`" width=`"622`" html.valueishtml=`"0`"  name=t_ttl visible=`"1`" $CTAILB"
$headerBlock = [string]::Join($CRLF, $hdr)

# --------------------------------------------------------------
# HEADER.1 band (per fincatcode group start) - category name
# --------------------------------------------------------------
$header1Block = "column(band=header.1 id=1 alignment=`"0`" tabsequence=32766 border=`"0`" color=`"33554432`" x=`"18`" y=`"8`" height=`"76`" width=`"1400`" format=`"[GENERAL]`" html.valueishtml=`"0`"  name=fincatdes visible=`"1`" $CTAILB"

# --------------------------------------------------------------
# DETAIL band: accountdes column + value computes + 11 category-rollup helper computes ("for all")
# --------------------------------------------------------------
$det = @()
$det += "column(band=detail id=1 alignment=`"0`" tabsequence=32766 border=`"0`" color=`"33554432`" x=`"69`" y=`"4`" height=`"76`" width=`"1340`" format=`"[GENERAL]`" html.valueishtml=`"0`"  name=parentname visible=`"1`" $CTAIL"
$det += "compute(band=detail alignment=`"1`" expression=`"(awal_debit - awal_credit) + (awal2_debit - awal2_credit) * if(flag_dk = 'D',1,(-1))`"border=`"0`" color=`"33554432`" x=`"1422`" y=`"4`" height=`"76`" width=`"622`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=saldo_awal visible=`"1`" $CTAIL"
for ($n=1; $n -le 12; $n++) {
    $x = $baseX + ($n-1)*$colStep
    $expr = "(bln${n}_debit - bln${n}_credit) * if(flag_dk='D',1,(-1))"
    $det += "compute(band=detail alignment=`"1`" expression=`"$expr`"border=`"0`" color=`"33554432`" x=`"$x`" y=`"4`" height=`"76`" width=`"$colWidth`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=cbln${n} visible=`"1`" $CTAIL"
}
$ttlExpr = "saldo_awal + cbln1"
for ($n=2; $n -le 12; $n++) { $ttlExpr += " + if(arg_jml_bulan>=${n},cbln${n},0)" }
$det += "compute(band=detail alignment=`"1`" expression=`"$ttlExpr`"border=`"0`" color=`"33554432`" x=`"$ttlX`" y=`"4`" height=`"76`" width=`"622`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=cttl visible=`"1`" $CTAIL"

# 11 rollup building blocks, each across 14 "periods" (0=saldo_awal/lalu, 1..12=months, 13=total)
# category filters (fincatcode-based, OR-chains only -- PB DWE has no IN())
$catFilters = @{
    penjualan  = "fincatcode='IS1001'"
    hpp        = "fincatcode='IS1110'"
    biaya      = "(fincatcode='IS2010' or fincatcode='IS2110' or fincatcode='IS2120' or fincatcode='IS2130')"
    pendapatan = "(fincatcode='IS2230' and parentcode='500-000')"
    biayalain  = "(fincatcode='IS2230' and parentcode='500-010')"
    pajak      = "fincatcode='IS2330'"
}
foreach ($cat in $catFilters.Keys) {
    $filter = $catFilters[$cat]
    # lalu (saldo_awal based)
    $x = 18
    $det += "compute(band=detail alignment=`"1`" expression=`"sum(if($filter,saldo_awal,0) for all)`"border=`"0`" color=`"33554432`" x=`"$x`" y=`"1`" height=`"1`" width=`"1`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=tot_${cat}_lalu visible=`"1`" $CTAIL"
    for ($n=1; $n -le 12; $n++) {
        $det += "compute(band=detail alignment=`"1`" expression=`"sum(if($filter,cbln${n},0) for all)`"border=`"0`" color=`"33554432`" x=`"$x`" y=`"1`" height=`"1`" width=`"1`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=tot_${cat}_bln${n} visible=`"1`" $CTAIL"
    }
    $totExpr = "tot_${cat}_lalu + tot_${cat}_bln1"
    for ($n=2; $n -le 12; $n++) { $totExpr += " + if(arg_jml_bulan>=${n},tot_${cat}_bln${n},0)" }
    $det += "compute(band=detail alignment=`"1`" expression=`"$totExpr`"border=`"0`" color=`"33554432`" x=`"$x`" y=`"1`" height=`"1`" width=`"1`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=tot_${cat}_ttl visible=`"1`" $CTAIL"
}
# 5 derived rollups, each across 14 periods (p = lalu, bln1..12, ttl)
$periods = @('lalu') + (1..12 | ForEach-Object { "bln$_" }) + @('ttl')
foreach ($p in $periods) {
    $det += "compute(band=detail alignment=`"1`" expression=`"tot_penjualan_$p - tot_hpp_$p`"border=`"0`" color=`"33554432`" x=`"18`" y=`"1`" height=`"1`" width=`"1`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=labakotor_$p visible=`"1`" $CTAIL"
    $det += "compute(band=detail alignment=`"1`" expression=`"labakotor_$p - tot_biaya_$p`"border=`"0`" color=`"33554432`" x=`"18`" y=`"1`" height=`"1`" width=`"1`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=labaoperasional_$p visible=`"1`" $CTAIL"
    $det += "compute(band=detail alignment=`"1`" expression=`"tot_pendapatan_$p - tot_biayalain_$p`"border=`"0`" color=`"33554432`" x=`"18`" y=`"1`" height=`"1`" width=`"1`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=othernonop_$p visible=`"1`" $CTAIL"
    $det += "compute(band=detail alignment=`"1`" expression=`"labaoperasional_$p + othernonop_$p`"border=`"0`" color=`"33554432`" x=`"18`" y=`"1`" height=`"1`" width=`"1`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=labasblmpajak_$p visible=`"1`" $CTAIL"
    $det += "compute(band=detail alignment=`"1`" expression=`"labasblmpajak_$p - tot_pajak_$p`"border=`"0`" color=`"33554432`" x=`"18`" y=`"1`" height=`"1`" width=`"1`" format=`"#,##0.00`" html.valueishtml=`"0`"  name=labaBersih_$p visible=`"1`" $CTAIL"
}
$detailBlock = [string]::Join($CRLF, $det)

Write-Output "header objects: $($hdr.Count)"
Write-Output "detail objects: $($det.Count)"

$headerBlock | Out-File -FilePath c:\BTV\debug\_flat_header.txt -Encoding utf8 -NoNewline
$header1Block | Out-File -FilePath c:\BTV\debug\_flat_header1.txt -Encoding utf8 -NoNewline
$detailBlock | Out-File -FilePath c:\BTV\debug\_flat_detail.txt -Encoding utf8 -NoNewline
