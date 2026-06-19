Option Explicit
Dim inputPath, outputPath
inputPath = "c:\BTV\debug\OPNAME FAKTUR PIUTANG 2025.xls.xls"
outputPath = "c:\BTV\debug\diag83_probe_piutang_xls_out.txt"

Dim fso, outFile, excel, workbook, sheet, usedRange
Dim r, c, maxRows, maxCols, line, cellText

Set fso = CreateObject("Scripting.FileSystemObject")
Set outFile = fso.CreateTextFile(outputPath, True)

On Error Resume Next
Set excel = CreateObject("Excel.Application")
If Err.Number <> 0 Then
    outFile.WriteLine "ERROR_CREATE_EXCEL|" & Err.Description
    outFile.Close
    WScript.Quit 1
End If
On Error GoTo 0

excel.Visible = False
excel.DisplayAlerts = False

On Error Resume Next
Set workbook = excel.Workbooks.Open(inputPath, 0, True)
If Err.Number <> 0 Then
    outFile.WriteLine "ERROR_OPEN_WORKBOOK|" & Err.Description
    outFile.Close
    excel.Quit
    WScript.Quit 1
End If
On Error GoTo 0

For Each sheet In workbook.Worksheets
    Set usedRange = sheet.UsedRange
    outFile.WriteLine "SHEET|" & sheet.Name & "|ROWS=" & usedRange.Rows.Count & "|COLS=" & usedRange.Columns.Count
    maxRows = usedRange.Rows.Count
    If maxRows > 40 Then maxRows = 40
    maxCols = usedRange.Columns.Count
    If maxCols > 20 Then maxCols = 20

    For r = 1 To maxRows
        line = "R" & r
        For c = 1 To maxCols
            cellText = Trim(CStr(sheet.Cells(r, c).Text))
            If cellText <> "" Then
                line = line & "|C" & c & "=" & Replace(cellText, "|", "/")
            End If
        Next
        If line <> "R" & r Then outFile.WriteLine line
    Next
Next

workbook.Close False
excel.Quit
outFile.Close
