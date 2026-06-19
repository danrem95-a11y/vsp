$bytes = [System.IO.File]::ReadAllBytes('c:\BTV\debug\.vscode\tasks.json')
$content = [System.Text.Encoding]::UTF8.GetString($bytes)

# Check if already added
if ($content -match 'diag112') {
    Write-Host "Tasks already added"
    exit
}

# Find the ending
$suffix = '"group": "build"' + "`n`t`t`t}`n`t`t]`n}"
$replacement = '"group": "build"' + "`n`t`t`t},`n`t`t{`n`t`t`t`"label`": `"diag112-fix-selisih-kurs`",`n`t`t`t`"type`": `"shell`",`n`t`t`t`"command`": `"C:\\\\Windows\\\\SysWOW64\\\\WindowsPowerShell\\\\v1.0\\\\powershell.exe -ExecutionPolicy Bypass -File \`"c:\\\\BTV\\\\debug\\\\diag112_fix_selisih_kurs.ps1\`"`",`n`t`t`t`"group`": `"build`"`n`t`t},`n`t`t{`n`t`t`t`"label`": `"diag112-verify`",`n`t`t`t`"type`": `"shell`",`n`t`t`t`"command`": `"C:\\\\Windows\\\\SysWOW64\\\\WindowsPowerShell\\\\v1.0\\\\powershell.exe -ExecutionPolicy Bypass -File \`"c:\\\\BTV\\\\debug\\\\diag112_verify.ps1\`"`",`n`t`t`t`"group`": `"build`"`n`t`t}`n`t]`n}"

if ($content.EndsWith($suffix)) {
    $base = $content.Substring(0, $content.Length - $suffix.Length)
    $newContent = $base + $replacement
    [System.IO.File]::WriteAllText('c:\BTV\debug\.vscode\tasks.json', $newContent, [System.Text.Encoding]::UTF8)
    Write-Host "Tasks added successfully"
} else {
    Write-Host "End pattern not found. Last 50 chars:"
    Write-Host $content.Substring($content.Length - 50)
}
