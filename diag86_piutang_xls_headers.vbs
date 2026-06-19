Option Explicit
Dim inputPath, outputPath
inputPath = "c:\BTV\debug\OPNAME FAKTUR PIUTANG 2025.xls.xls"
outputPath = "c:\BTV\debug\diag86_piutang_xls_headers_out.txt"

Dim fso, outFile, excel, workbook, sheet
Dim r, c, line

Set fso = CreateObject("Scripting.FileSystemObject")
Set outFile = fso.CreateTextFile(outputPath, True)
Set excel = CreateObject("Excel.Application")
excel.Visible = False
excel.DisplayAlerts = False
Set workbook = excel.Workbooks.Open(inputPath, 0, True)
Set sheet = workbook.Worksheets(1)

For r = 1 To 10
    line = "R" & r
    For c = 1 To 26
        If Trim(CStr(sheet.Cells(r, c).Text)) <> "" Then
            line = line & "|C" & c & "=" & Replace(Trim(CStr(sheet.Cells(r, c).Text)), "|", "/")
        End If
    Next
    outFile.WriteLine line
Next

workbook.Close False
excel.Quit
outFile.Close
