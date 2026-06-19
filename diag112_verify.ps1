# diag112_verify.ps1
# Verify that the f_transfer_ap.srf fix (diag112) was applied correctly.
# Checks presence of all key tokens and shows the fix block in context.

$enc = [System.Text.Encoding]::Unicode
$t = [System.IO.File]::ReadAllText('c:\BTV\debug\f_transfer_ap.srf', $enc)
$lines = $t -split "`r`n"
$out = [System.Text.StringBuilder]::new()

[void]$out.AppendLine("=== f_transfer_ap.srf diag112 verification ===")
[void]$out.AppendLine("Total lines: $($lines.Count)")
[void]$out.AppendLine("")

# --- Token checks ---
$tokens = @(
    "ldec_actual_kas",
    "ldec_total_kas",
    "ldec_selisih_kurs",
    "ls_selisih_acc",
    "ls_selisih_ket",
    "ls_tmp_acc",
    "k_row",
    "isnull(sum(kredit),0)",
    "ls_tmp_acc = ls_acckas",
    "ldec_kas = lds_update.getitemdecimal",
    "Rugi kurs",
    "Laba kurs",
    "diag112",
    "doc_reff sengaja kosong"
)
[void]$out.AppendLine("=== Token checks ===")
foreach ($tk in $tokens) {
    $status = if ($t.Contains($tk)) { "FOUND" } else { "MISSING" }
    [void]$out.AppendLine("  ${status}: $tk")
}
[void]$out.AppendLine("")

# --- Fix block location ---
$fixStart = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'Fix diag112') { $fixStart = $i; break }
}
[void]$out.AppendLine("=== Fix block location ===")
if ($fixStart -ge 0) {
    [void]$out.AppendLine("Fix block starts at line $($fixStart + 1)")
    # Show 2 lines before and the whole block
    $showFrom = [Math]::Max(0, $fixStart - 2)
    $showTo   = [Math]::Min($lines.Count - 1, $fixStart + 85)
    for ($i = $showFrom; $i -le $showTo; $i++) {
        [void]$out.AppendLine("  L$($i+1): $($lines[$i])")
    }
} else {
    [void]$out.AppendLine("  WARNING: Fix block not found!")
}
[void]$out.AppendLine("")

# --- Structural check: next → fix block → delete ---
$nextIdx   = -1
$deleteIdx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -eq 'next' -and $nextIdx -lt 0 -and $i -gt 480) { $nextIdx = $i }
    if ($lines[$i] -match '^delete from gl_journal where voucher_manual' -and $deleteIdx -lt 0 -and $i -gt 480) { $deleteIdx = $i }
}
[void]$out.AppendLine("=== Structural check ===")
[void]$out.AppendLine("  'next' at line: $($nextIdx + 1)")
[void]$out.AppendLine("  'delete from gl_journal' at line: $($deleteIdx + 1)")
[void]$out.AppendLine("  Fix block between: $($fixStart + 1) and $($deleteIdx)")
if ($fixStart -gt $nextIdx -and $fixStart -lt $deleteIdx) {
    [void]$out.AppendLine("  ORDER OK: next → fix block → delete")
} else {
    [void]$out.AppendLine("  WARNING: Fix block is NOT between next and delete!")
}

$result = $out.ToString()
Write-Host $result
$result | Set-Content 'c:\BTV\debug\diag112_verify_out.txt' -Encoding UTF8
Write-Host "Output written to diag112_verify_out.txt"
