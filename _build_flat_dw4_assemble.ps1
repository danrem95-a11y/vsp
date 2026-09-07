$ErrorActionPreference = "Stop"
$CRLF = "`r`n"

$sql        = Get-Content -Path c:\BTV\debug\_flat_sql.txt -Raw
$cols       = Get-Content -Path c:\BTV\debug\_flat_cols.txt -Raw
$argDecl    = Get-Content -Path c:\BTV\debug\_flat_args.txt -Raw
$headerBlk  = Get-Content -Path c:\BTV\debug\_flat_header.txt -Raw
$header1Blk = Get-Content -Path c:\BTV\debug\_flat_header1.txt -Raw
$detailBlk  = Get-Content -Path c:\BTV\debug\_flat_detail.txt -Raw
$trailer1Blk= Get-Content -Path c:\BTV\debug\_flat_trailer1.txt -Raw
$trailer1H  = (Get-Content -Path c:\BTV\debug\_flat_trailer1_height.txt -Raw).Trim()
$trailer2Blk= Get-Content -Path c:\BTV\debug\_flat_trailer2.txt -Raw
$trailer2H  = (Get-Content -Path c:\BTV\debug\_flat_trailer2_height.txt -Raw).Trim()

# escape embedded double-quotes inside the SQL for the retrieve="..." attribute (none expected, SQL uses single quotes only)
$name = "dw_rpt_is_flat_multibulan"

$content = @()
$content += "`$PBExportHeader`$$name.srd"
$content += "release 11.5;"
$content += "datawindow(units=0 timer_interval=0 color=1073741824 brushmode=0 transparency=0 gradient.angle=0 gradient.color=8421504 gradient.focus=0 gradient.repetition.count=0 gradient.repetition.length=100 gradient.repetition.mode=0 gradient.scale=100 gradient.spread=100 gradient.transparency=0 picture.blur=0 picture.clip.bottom=0 picture.clip.left=0 picture.clip.right=0 picture.clip.top=0 picture.mode=0 picture.scale.x=100 picture.scale.y=100 picture.transparency=0 processing=0 HTMLDW=no print.printername=`"`" print.documentname=`"`" print.orientation = 1 print.margin.left = 110 print.margin.right = 110 print.margin.top = 96 print.margin.bottom = 96 print.paper.source = 0 print.paper.size = 0 print.canusedefaultprinter=yes print.prompt=no print.buttons=no print.preview.buttons=no print.cliptext=no print.overrideprintjob=no print.collate=yes print.background=no print.preview.background=no print.preview.outline=yes hidegrayline=no showbackcoloronxp=no picture.file=`"`" )"
$content += "header(height=460 color=`"536870912`" transparency=`"0`" gradient.color=`"8421504`" gradient.transparency=`"0`" gradient.angle=`"0`" brushmode=`"0`" gradient.repetition.mode=`"0`" gradient.repetition.count=`"0`" gradient.repetition.length=`"100`" gradient.focus=`"0`" gradient.scale=`"100`" gradient.spread=`"100`" )"
$content += "summary(height=0 color=`"536870912`" transparency=`"0`" gradient.color=`"8421504`" gradient.transparency=`"0`" gradient.angle=`"0`" brushmode=`"0`" gradient.repetition.mode=`"0`" gradient.repetition.count=`"0`" gradient.repetition.length=`"100`" gradient.focus=`"0`" gradient.scale=`"100`" gradient.spread=`"100`" )"
$content += "footer(height=0 color=`"536870912`" transparency=`"0`" gradient.color=`"8421504`" gradient.transparency=`"0`" gradient.angle=`"0`" brushmode=`"0`" gradient.repetition.mode=`"0`" gradient.repetition.count=`"0`" gradient.repetition.length=`"100`" gradient.focus=`"0`" gradient.scale=`"100`" gradient.spread=`"100`" )"
$content += "detail(height=0 color=`"536870912`" transparency=`"0`" gradient.color=`"8421504`" gradient.transparency=`"0`" gradient.angle=`"0`" brushmode=`"0`" gradient.repetition.mode=`"0`" gradient.repetition.count=`"0`" gradient.repetition.length=`"100`" gradient.focus=`"0`" gradient.scale=`"100`" gradient.spread=`"100`" )"
$content += "table($cols"
$content += " retrieve=`"$sql`" arguments=($argDecl)  sort=`"fincatcode A parentcode A accountcode A `" )"
$content += "group(level=1 header.height=92 trailer.height=$trailer1H by=(`"fincatcode`" ) header.color=`"536870912`" header.transparency=`"0`" header.gradient.color=`"8421504`" header.gradient.transparency=`"0`" header.gradient.angle=`"0`" header.brushmode=`"0`" header.gradient.repetition.mode=`"0`" header.gradient.repetition.count=`"0`" header.gradient.repetition.length=`"100`" header.gradient.focus=`"0`" header.gradient.scale=`"100`" header.gradient.spread=`"100`" trailer.color=`"536870912`" trailer.transparency=`"0`" trailer.gradient.color=`"8421504`" trailer.gradient.transparency=`"0`" trailer.gradient.angle=`"0`" trailer.brushmode=`"0`" trailer.gradient.repetition.mode=`"0`" trailer.gradient.repetition.count=`"0`" trailer.gradient.repetition.length=`"100`" trailer.gradient.focus=`"0`" trailer.gradient.scale=`"100`" trailer.gradient.spread=`"100`" )"
$content += "group(level=2 header.height=0 trailer.height=$trailer2H by=(`"parentcode`" ) header.suppress=yes header.color=`"536870912`" header.transparency=`"0`" header.gradient.color=`"8421504`" header.gradient.transparency=`"0`" header.gradient.angle=`"0`" header.brushmode=`"0`" header.gradient.repetition.mode=`"0`" header.gradient.repetition.count=`"0`" header.gradient.repetition.length=`"100`" header.gradient.focus=`"0`" header.gradient.scale=`"100`" header.gradient.spread=`"100`" trailer.color=`"536870912`" trailer.transparency=`"0`" trailer.gradient.color=`"8421504`" trailer.gradient.transparency=`"0`" trailer.gradient.angle=`"0`" trailer.brushmode=`"0`" trailer.gradient.repetition.mode=`"0`" trailer.gradient.repetition.count=`"0`" trailer.gradient.repetition.length=`"100`" trailer.gradient.focus=`"0`" trailer.gradient.scale=`"100`" trailer.gradient.spread=`"100`" )"
$content += $headerBlk
$content += $header1Blk
$content += $detailBlk
$content += $trailer2Blk
$content += $trailer1Blk
$content += "htmltable(border=`"1`" )"
$content += "xhtml(controlblock=`"no`" visibleburnin=`"no`" )"
$content += "export.xml(headgroup=no metadata=no linkschema=no id=no)"
$content += "import.xml(encoding=`"iso-8859-1`" )"

$final = [string]::Join($CRLF, $content)
[System.IO.File]::WriteAllText("c:\BTV\debug\$name.srd", $final, [System.Text.Encoding]::Unicode)
Write-Output ("wrote $name.srd, length=" + $final.Length)

# structural checks
$openP = ([regex]::Matches($final, '[(]')).Count
$closeP = ([regex]::Matches($final, '[)]')).Count
Write-Output ("paren balance diff=" + ($openP-$closeP))
$argCount = ([regex]::Matches($argDecl, '\("')).Count
Write-Output ("declared arg count=" + $argCount)
