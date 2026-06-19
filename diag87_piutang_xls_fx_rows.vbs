Option Explicit
Dim inputPath, outputPath
inputPath = "c:\BTV\debug\OPNAME FAKTUR PIUTANG 2025.xls.xls"
outputPath = "c:\BTV\debug\diag87_piutang_xls_fx_rows_out.txt"

Dim fso, outFile, excel, workbook, sheet
Dim r, line, lastRow, countOut

Set fso = CreateObject("Scripting.FileSystemObject")
Set outFile = fso.CreateTextFile(outputPath, True)
Set excel = CreateObject("Excel.Application")
excel.Visible = False
excel.DisplayAlerts = False
Set workbook = excel.Workbooks.Open(inputPath, 0, True)
Set sheet = workbook.Worksheets(1)

lastRow = sheet.UsedRange.Rows.Count
countOut = 0
For r = 1 To lastRow
    If Trim(CStr(sheet.Cells(r, 24).Text)) <> "" Then
        line = "R" & r _
            & "|C2=" & Replace(Trim(CStr(sheet.Cells(r, 2).Text)), "|", "/") _
            & "|C3=" & Replace(Trim(CStr(sheet.Cells(r, 3).Text)), "|", "/") _
            & "|C4=" & Replace(Trim(CStr(sheet.Cells(r, 4).Text)), "|", "/") _
            & "|C5=" & Replace(Trim(CStr(sheet.Cells(r, 5).Text)), "|", "/") _
            & "|C7=" & Replace(Trim(CStr(sheet.Cells(r, 7).Text)), "|", "/") _
            & "|C9=" & Replace(Trim(CStr(sheet.Cells(r, 9).Text)), "|", "/") _
            & "|C21=" & Replace(Trim(CStr(sheet.Cells(r, 21).Text)), "|", "/") _
            & "|C22=" & Replace(Trim(CStr(sheet.Cells(r, 22).Text)), "|", "/") _
            & "|C23=" & Replace(Trim(CStr(sheet.Cells(r, 23).Text)), "|", "/") _
            & "|C24=" & Replace(Trim(CStr(sheet.Cells(r, 24).Text)), "|", "/") _
            & "|C25=" & Replace(Trim(CStr(sheet.Cells(r, 25).Text)), "|", "/") _
            & "|C26=" & Replace(Trim(CStr(sheet.Cells(r, 26).Text)), "|", "/")
        outFile.WriteLine line
        countOut = countOut + 1
    End If
Next
outFile.WriteLine "TOTAL_ROWS|" & countOut

workbook.Close False
excel.Quit
outFile.Close
