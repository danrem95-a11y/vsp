$ErrorActionPreference = "Stop"
$CRLF = "`r`n"

# ---- reusable attribute tails (proven-valid, extracted from legacy working objects) ----
$CTAIL = ' font.face="Tahoma" font.height="-10" font.weight="400"  font.family="2" font.pitch="2" font.charset="0" background.mode="1" background.color="536870912" background.transparency="0" background.gradient.color="8421504" background.gradient.transparency="0" background.gradient.angle="0" background.brushmode="0" background.gradient.repetition.mode="0" background.gradient.repetition.count="0" background.gradient.repetition.length="100" background.gradient.focus="0" background.gradient.scale="100" background.gradient.spread="100" tooltip.backcolor="134217752" tooltip.delay.initial="0" tooltip.delay.visible="32000" tooltip.enabled="0" tooltip.hasclosebutton="0" tooltip.icon="0" tooltip.isbubble="0" tooltip.maxwidth="0" tooltip.textcolor="134217751" tooltip.transparency="0" transparency="0" )'
$CTAILB = ' font.face="Tahoma" font.height="-10" font.weight="700"  font.family="2" font.pitch="2" font.charset="0" background.mode="1" background.color="536870912" background.transparency="0" background.gradient.color="8421504" background.gradient.transparency="0" background.gradient.angle="0" background.brushmode="0" background.gradient.repetition.mode="0" background.gradient.repetition.count="0" background.gradient.repetition.length="100" background.gradient.focus="0" background.gradient.scale="100" background.gradient.spread="100" tooltip.backcolor="134217752" tooltip.delay.initial="0" tooltip.delay.visible="32000" tooltip.enabled="0" tooltip.hasclosebutton="0" tooltip.icon="0" tooltip.isbubble="0" tooltip.maxwidth="0" tooltip.textcolor="134217751" tooltip.transparency="0" transparency="0" )'

$colWidth = 480
$colStep = 484
$baseX = 2048       # x of month-1 column (cbln1)
$ttlX = $baseX + 12*$colStep   # x of Total column

# categories: fincatcode(s) that make up each rollup building block
# (OR-chains only -- PowerBuilder DWE has no IN())
function Or-Chain($col, $vals) {
    ($vals | ForEach-Object { "$col='$_'" }) -join ' or '
}
$fc_penjualan = "a.fincatcode = 'IS1001'"
$fc_hpp       = "a.fincatcode = 'IS1110'"
$fc_biaya     = "a.fincatcode = 'IS2010' or a.fincatcode = 'IS2110' or a.fincatcode = 'IS2120' or a.fincatcode = 'IS2130'"
$fc_other     = "a.fincatcode = 'IS2230'"
$fc_pajak     = "a.fincatcode = 'IS2330'"
$fc_all       = "$fc_penjualan or $fc_hpp or $fc_biaya or $fc_other or $fc_pajak"

# ============================================================
# 1) SQL retrieve string
# ============================================================
# --- inner query: account-level grain, one gl_journal scan covering awal2 + all 12 months ---
$innerCols = @"
a.fincatcode,a.fincatdes,b.parentcode,b.parentname,c.accountcode,
c.debetcredit as flag_dk,
isnull(awal.debit,0.00) as awal_debit,
isnull(awal.credit,0.00) as awal_credit,
isnull(mvmt.awal2_debit,0.00) as awal2_debit,
isnull(mvmt.awal2_credit,0.00) as awal2_credit,
"@
for ($n=1; $n -le 12; $n++) {
    $innerCols += "isnull(mvmt.bln${n}_debit,0.00) as bln${n}_debit,${CRLF}isnull(mvmt.bln${n}_credit,0.00) as bln${n}_credit,${CRLF}"
}
$innerCols = $innerCols.TrimEnd("`r`n,")

$mvmtSelect = "SELECT gl_journal.account_id,${CRLF}sum(case when tgl between :arg_tgl1 and :arg_tgl2 then isnull(debet,0) else 0 end) as awal2_debit,${CRLF}sum(case when tgl between :arg_tgl1 and :arg_tgl2 then isnull(kredit,0) else 0 end) as awal2_credit,${CRLF}"
for ($n=1; $n -le 12; $n++) {
    $mvmtSelect += "sum(case when tgl between :arg_bln${n}_awal and :arg_bln${n}_akhir then isnull(debet,0) else 0 end) as bln${n}_debit,${CRLF}"
    $mvmtSelect += "sum(case when tgl between :arg_bln${n}_awal and :arg_bln${n}_akhir then isnull(kredit,0) else 0 end) as bln${n}_credit"
    if ($n -lt 12) { $mvmtSelect += ",${CRLF}" }
}

$fromSub = @"
gl_cate a,gl_cate_detail b,gl_acc c,
(
	  			SELECT 	gl_balance.AccountCode,
							sum(AmountDebet) as debit,
							sum(AmountCredit) as credit
		 		FROM 	gl_balance
				WHERE 	gl_balance.Period = :arg_tgl1
				GROUP BY gl_balance.AccountCode
				) awal,
(
$mvmtSelect
FROM gl_journal
WHERE tgl between :arg_tgl1 and :arg_bln12_akhir and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)
GROUP BY gl_journal.account_id
) mvmt
"@

$joinLines = @('c.accountcode *= awal.accountcode', 'c.accountcode *= mvmt.account_id')
$joinStr = [string]::Join(" and${CRLF}", $joinLines)

# Account-level grain (proven fast: ~550ms full combination vs 85s+ for a SQL-side parentcode
# re-aggregation wrap on this DB/optimizer). Parentcode-level display aggregation is instead
# done natively by PowerBuilder's own group-2 trailer (sum(... for group 2)), mirroring the
# already-proven group-1 (fincatcode) trailer mechanism.
$innerCols += ",${CRLF}a.fincatdes+' '+b.parentname+' '+c.accountcode as is_find"
$sql = "select${CRLF}${innerCols}${CRLF}from${CRLF}${fromSub}${CRLF}where a.fincatcode = b.fincatcode and${CRLF}b.parentcode = c.parentcode and${CRLF}(${fc_all}) and${CRLF}((isnull(c.show_hide,'1') = '1') or 1 = :arg_show) and${CRLF}${joinStr}${CRLF}order by${CRLF}a.fincatcode,b.parentcode,c.accountcode"

# ============================================================
# 2) column defs
# ============================================================
$cols = @'
column=(type=char(10) updatewhereclause=yes name=fincatcode dbname="fincatcode" )
 column=(type=char(50) updatewhereclause=yes name=fincatdes dbname="fincatdes" )
 column=(type=char(25) updatewhereclause=yes name=parentcode dbname="parentcode" )
 column=(type=char(100) updatewhereclause=yes name=parentname dbname="parentname" )
 column=(type=char(15) updatewhereclause=yes name=accountcode dbname="accountcode" )
 column=(type=char(1) updatewhereclause=yes name=flag_dk dbname="flag_dk" )
 column=(type=decimal(6) updatewhereclause=yes name=awal_debit dbname="awal_debit" )
 column=(type=decimal(6) updatewhereclause=yes name=awal_credit dbname="awal_credit" )
 column=(type=decimal(6) updatewhereclause=yes name=awal2_debit dbname="awal2_debit" )
 column=(type=decimal(6) updatewhereclause=yes name=awal2_credit dbname="awal2_credit" )
'@
$cols = $cols -replace "`r?`n", $CRLF
for ($n=1; $n -le 12; $n++) {
    $cols += " column=(type=decimal(6) updatewhereclause=yes name=bln${n}_debit dbname=`"bln${n}_debit`" )${CRLF}"
    $cols += " column=(type=decimal(6) updatewhereclause=yes name=bln${n}_credit dbname=`"bln${n}_credit`" )${CRLF}"
}
$cols += " column=(type=char(218) updatewhereclause=yes name=is_find dbname=`"is_find`" )"

# ============================================================
# 3) arguments
# ============================================================
$argDecl = '("arg_tgl1", datetime),("arg_tgl2", datetime),'
for ($n=1; $n -le 12; $n++) { $argDecl += "(`"arg_bln${n}_awal`", datetime),(`"arg_bln${n}_akhir`", datetime)," }
$argDecl += '("arg_show", number),("arg_jml_bulan", number)'

Write-Output "SQL length: $($sql.Length)"
Write-Output "Cols length: $($cols.Length)"
Write-Output "Args: $argDecl"

# stash intermediate pieces for the next script stage
$sql       | Out-File -FilePath c:\BTV\debug\_flat_sql.txt -Encoding utf8 -NoNewline
$cols      | Out-File -FilePath c:\BTV\debug\_flat_cols.txt -Encoding utf8 -NoNewline
$argDecl   | Out-File -FilePath c:\BTV\debug\_flat_args.txt -Encoding utf8 -NoNewline
