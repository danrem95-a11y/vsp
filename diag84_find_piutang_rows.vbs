Option Explicit
Dim inputPath, outputPath
inputPath = "c:\BTV\debug\OPNAME FAKTUR PIUTANG 2025.xls.xls"
outputPath = "c:\BTV\debug\diag84_find_piutang_rows_out.txt"

Dim targets
targets = Array( _
    "HK2025H0459", _
    "2025H0524", _
    "2025H0143", _
    "5001779", _
    "5001808,09", _
    "5001446,7,8", _
    "1299428763" _
)

Dim fso, outFile, excel, workbook, sheet, foundCell
Dim c, i, line

Set fso = CreateObject("Scripting.FileSystemObject")
Set outFile = fso.CreateTextFile(outputPath, True)

On Error Resume Next
Set excel = CreateObject("Excel.Application")
If Err.Number <> 0 Then
    outFile.WriteLine "ERROR_CREATE_EXCEL|" & Err.Description
    outFile.Close
    WScript.Quit 1
End If
Err.Clear
Set workbook = excel.Workbooks.Open(inputPath, 0, True)
If Err.Number <> 0 Then
    outFile.WriteLine "ERROR_OPEN_WORKBOOK|" & Err.Description
    outFile.Close
    excel.Quit
    WScript.Quit 1
End If
On Error GoTo 0

excel.Visible = False
excel.DisplayAlerts = False

For Each sheet In workbook.Worksheets
    outFile.WriteLine "SHEET|" & sheet.Name & "|ROWS=" & sheet.UsedRange.Rows.Count & "|COLS=" & sheet.UsedRange.Columns.Count

    For i = 0 To UBound(targets)
        Set foundCell = sheet.Columns(3).Find(targets(i), sheet.Cells(1, 3), -4163, 1, 1, 1, False)
        If foundCell Is Nothing Then
            outFile.WriteLine "NOT_FOUND|TARGET=" & targets(i)
        Else
            line = "FOUND|TARGET=" & targets(i) & "|ROW=" & foundCell.Row
            For c = 1 To 20
                line = line & "|C" & c & "=" & Replace(Trim(CStr(sheet.Cells(foundCell.Row, c).Text)), "|", "/")
            Next
            outFile.WriteLine line
        End If
        Set foundCell = Nothing
    Next
Next

workbook.Close False
excel.Quit
outFile.Close
