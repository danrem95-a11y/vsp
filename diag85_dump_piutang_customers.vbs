Option Explicit
Dim inputPath, outputPath
inputPath = "c:\BTV\debug\OPNAME FAKTUR PIUTANG 2025.xls.xls"
outputPath = "c:\BTV\debug\diag85_dump_piutang_customers_out.txt"

Dim targets
targets = Array("4SL.D014", "4SL.0301", "4SL.0309")

Dim fso, outFile, excel, workbook, sheet, foundCell
Dim i, r, c, line, startRow, endRow

Set fso = CreateObject("Scripting.FileSystemObject")
Set outFile = fso.CreateTextFile(outputPath, True)
Set excel = CreateObject("Excel.Application")
excel.Visible = False
excel.DisplayAlerts = False
Set workbook = excel.Workbooks.Open(inputPath, 0, True)

For Each sheet In workbook.Worksheets
    outFile.WriteLine "SHEET|" & sheet.Name
    For i = 0 To UBound(targets)
        Set foundCell = sheet.Columns(2).Find(targets(i), sheet.Cells(1, 2), -4163, 1, 1, 1, False)
        If foundCell Is Nothing Then
            outFile.WriteLine "NOT_FOUND|TARGET=" & targets(i)
        Else
            outFile.WriteLine "BLOCK|TARGET=" & targets(i) & "|ROW=" & foundCell.Row
            startRow = foundCell.Row
            endRow = foundCell.Row + 12
            For r = startRow To endRow
                line = "R" & r
                For c = 1 To 20
                    If Trim(CStr(sheet.Cells(r, c).Text)) <> "" Then
                        line = line & "|C" & c & "=" & Replace(Trim(CStr(sheet.Cells(r, c).Text)), "|", "/")
                    End If
                Next
                outFile.WriteLine line
            Next
        End If
        Set foundCell = Nothing
    Next
Next

workbook.Close False
excel.Quit
outFile.Close
