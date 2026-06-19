Option Explicit
'=============================================================
' DIAG89: AUDIT SALDO BANK Januari 2026
' Selisih: 76,609,999.79 (Bank terlalu tinggi)
' Expected: 4,376,042,817.00
'=============================================================
Dim conn, rs, fso, f, line, sql
Dim outFile : outFile = "c:\BTV\debug\diag89_bank_audit_out.txt"

Set fso = CreateObject("Scripting.FileSystemObject")
Set f   = fso.CreateTextFile(outFile, True, False)

Set conn = CreateObject("ADODB.Connection")
conn.ConnectionString = "DSN=vsp;UID=dba;PWD=jakarta"
conn.Open

Sub RunQuery(label, qsql)
    f.WriteLine ""
    f.WriteLine "===== " & label & " ====="
    On Error Resume Next
    Set rs = conn.Execute(qsql)
    If Err.Number <> 0 Then
        f.WriteLine "ERROR: " & Err.Description
        Err.Clear
        On Error GoTo 0
        Exit Sub
    End If
    On Error GoTo 0
    If rs.State = 1 Then
        ' header
        Dim i, hdr : hdr = ""
        For i = 0 To rs.Fields.Count - 1
            If i > 0 Then hdr = hdr & vbTab
            hdr = hdr & rs.Fields(i).Name
        Next
        f.WriteLine hdr
        f.WriteLine String(Len(hdr)+20, "-")
        ' rows
        Dim cnt : cnt = 0
        Do While Not rs.EOF
            line = ""
            For i = 0 To rs.Fields.Count - 1
                If i > 0 Then line = line & vbTab
                Dim v : v = rs.Fields(i).Value
                If IsNull(v) Then v = "(null)"
                line = line & v
            Next
            f.WriteLine line
            cnt = cnt + 1
            rs.MoveNext
        Loop
        f.WriteLine "(" & cnt & " rows)"
        rs.Close
    Else
        f.WriteLine "(no resultset)"
    End If
End Sub

' ---- STEP 1: Akun Bank dari gl_setup ----
RunQuery "STEP1: AKUN BANK DARI GL_SETUP", _
    "SELECT acc_bank1, acc_bank2, acc_bank3, acc_bank4, acc_bank5," & _
    " acc_kas1, acc_kas2, acc_kas3 FROM gl_setup"

' ---- STEP 2: Akun bank aktual di gl_journal (kas_id>0) ----
RunQuery "STEP2: AKUN KAS/BANK DI GL_JOURNAL JAN 2026", _
    "SELECT DISTINCT g.account_id, g.modul_id, g.kas_id" & _
    " FROM gl_journal g" & _
    " WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'" & _
    " AND g.kas_id > 0" & _
    " ORDER BY g.account_id, g.modul_id"

' ---- STEP 3: Saldo bank per account_id ----
RunQuery "STEP3: SALDO BANK PER AKUN (Jan 2026)", _
    "SELECT g.account_id, g.modul_id," & _
    " SUM(g.debet) AS total_debet," & _
    " SUM(g.kredit) AS total_kredit," & _
    " SUM(g.debet - g.kredit) AS net_balance" & _
    " FROM gl_journal g" & _
    " WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'" & _
    " AND g.kas_id > 0" & _
    " GROUP BY g.account_id, g.modul_id" & _
    " ORDER BY g.account_id, g.modul_id"

' ---- STEP 4: Total saldo bank semua akun ----
RunQuery "STEP4: TOTAL SALDO BANK KESELURUHAN", _
    "SELECT SUM(g.debet) AS total_debet," & _
    " SUM(g.kredit) AS total_kredit," & _
    " SUM(g.debet - g.kredit) AS saldo_netto" & _
    " FROM gl_journal g" & _
    " WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'" & _
    " AND g.kas_id > 0"

' ---- STEP 5: Duplikat voucher_manual di akun bank ----
RunQuery "STEP5: DUPLIKAT VOUCHER_MANUAL DI BANK (cnt>2)", _
    "SELECT g.voucher_manual, g.account_id, g.modul_id," & _
    " COUNT(*) AS cnt," & _
    " SUM(g.debet) AS total_debet, SUM(g.kredit) AS total_kredit" & _
    " FROM gl_journal g" & _
    " WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'" & _
    " AND g.kas_id > 0" & _
    " GROUP BY g.voucher_manual, g.account_id, g.modul_id" & _
    " HAVING COUNT(*) > 2" & _
    " ORDER BY cnt DESC, g.voucher_manual"

' ---- STEP 6: Total tbyr1 AP vs GL CO bank ----
RunQuery "STEP6: TOTAL TBYR1 AP (pembayaran hutang Jan 2026)", _
    "SELECT t1.kas_id," & _
    " COUNT(DISTINCT t1.voucher) AS jml_payment," & _
    " SUM(t2.nilai_bayar_idr) AS total_bayar_idr" & _
    " FROM tbyr1 t1" & _
    " JOIN tbyr2 t2 ON t2.voucher = t1.voucher" & _
    " WHERE t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'" & _
    " AND t1.flag_bayar = 2" & _
    " GROUP BY t1.kas_id ORDER BY t1.kas_id"

RunQuery "STEP6b: GL KREDIT BANK MODUL CO (Jan 2026)", _
    "SELECT g.account_id, g.kas_id," & _
    " COUNT(DISTINCT g.voucher_manual) AS jml_voucher," & _
    " SUM(g.kredit) AS total_kredit_bank" & _
    " FROM gl_journal g" & _
    " WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'" & _
    " AND g.modul_id = 'CO' AND g.kas_id > 0 AND g.kredit > 0" & _
    " GROUP BY g.account_id, g.kas_id ORDER BY g.account_id"

' ---- STEP 7: Payment AP tanpa entry Bank di GL ----
RunQuery "STEP7: PAYMENT AP TANPA ENTRY BANK DI GL", _
    "SELECT t1.voucher, t1.voucher_manual, t1.tgl, t1.vendor_id," & _
    " (SELECT SUM(t2b.nilai_bayar_idr) FROM tbyr2 t2b WHERE t2b.voucher=t1.voucher) AS nilai_idr" & _
    " FROM tbyr1 t1" & _
    " WHERE t1.tgl BETWEEN '2026-01-01' AND '2026-01-31'" & _
    " AND t1.flag_bayar = 2" & _
    " AND NOT EXISTS (SELECT 1 FROM gl_journal g" & _
    "   WHERE g.voucher_manual = t1.voucher_manual" & _
    "   AND g.modul_id = 'CO' AND g.kas_id > 0)" & _
    " ORDER BY t1.tgl"

' ---- STEP 8: GL CO tanpa tbyr1 (orphan) ----
RunQuery "STEP8: ORPHAN GL CO (ada di GL tapi tidak di tbyr1)", _
    "SELECT g.voucher, g.voucher_manual, g.tgl, g.account_id," & _
    " g.kredit AS kredit_bank, g.debet AS debet_bank" & _
    " FROM gl_journal g" & _
    " WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'" & _
    " AND g.modul_id = 'CO' AND g.kas_id > 0" & _
    " AND NOT EXISTS (SELECT 1 FROM tbyr1 t1" & _
    "   WHERE t1.voucher_manual = g.voucher_manual)" & _
    " ORDER BY g.tgl"

' ---- STEP 9: Cari transaksi senilai selisih 76,609,999.79 ----
RunQuery "STEP9: TRANSAKSI BANK MENDEKATI SELISIH 76.609.999,79", _
    "SELECT g.voucher, g.voucher_manual, g.tgl, g.modul_id," & _
    " g.account_id, g.debet, g.kredit, g.ket" & _
    " FROM gl_journal g" & _
    " WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'" & _
    " AND g.kas_id > 0" & _
    " AND (ABS(g.debet-76609999.79)<2000" & _
    "   OR ABS(g.kredit-76609999.79)<2000" & _
    "   OR ABS(g.debet-76610000)<2000)" & _
    " ORDER BY g.tgl"

' ---- STEP 10: Transaksi FX di bank (kurs berbeda IDR) ----
RunQuery "STEP10: TRANSAKSI FX DI BANK (kurs <> nilai_idr)", _
    "SELECT g.voucher, g.voucher_manual, g.tgl, g.account_id, g.modul_id," & _
    " g.debet, g.kredit, g.debet_kurs, g.kredit_kurs, g.ket" & _
    " FROM gl_journal g" & _
    " WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'" & _
    " AND g.kas_id > 0" & _
    " AND (g.kredit <> g.kredit_kurs OR g.debet <> g.debet_kurs)" & _
    " AND (g.debet_kurs <> 0 OR g.kredit_kurs <> 0)" & _
    " ORDER BY g.tgl"

' ---- STEP 11: Pergerakan bank harian ----
RunQuery "STEP11: PERGERAKAN BANK HARIAN JAN 2026", _
    "SELECT CAST(g.tgl AS DATE) AS tanggal," & _
    " SUM(g.debet) AS debet_hari," & _
    " SUM(g.kredit) AS kredit_hari," & _
    " SUM(g.debet-g.kredit) AS netto_hari," & _
    " COUNT(*) AS jml_entry" & _
    " FROM gl_journal g" & _
    " WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'" & _
    " AND g.kas_id > 0" & _
    " GROUP BY CAST(g.tgl AS DATE)" & _
    " ORDER BY CAST(g.tgl AS DATE)"

' ---- STEP 12: Top 20 kredit bank terbesar ----
RunQuery "STEP12: TOP 20 KREDIT BANK TERBESAR", _
    "SELECT TOP 20 g.voucher, g.voucher_manual, g.tgl," & _
    " g.account_id, g.modul_id, g.kredit, g.ket, g.doc_reff" & _
    " FROM gl_journal g" & _
    " WHERE g.tgl BETWEEN '2026-01-01' AND '2026-01-31'" & _
    " AND g.kas_id > 0 AND g.kredit > 0" & _
    " ORDER BY g.kredit DESC"

conn.Close
f.Close

WScript.Echo "Done. Output: " & outFile
