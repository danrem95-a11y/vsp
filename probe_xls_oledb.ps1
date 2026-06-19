param(
    [string]$InputFile,
    [string]$OutputFile
)

Add-Type -AssemblyName System.Data

$providers = @(
    "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$InputFile;Extended Properties='Excel 8.0;HDR=YES;IMEX=1';",
    "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$InputFile;Extended Properties='Excel 8.0;HDR=YES;IMEX=1';"
)

$out = @()

foreach ($connString in $providers) {
    try {
        $conn = New-Object System.Data.OleDb.OleDbConnection($connString)
        $conn.Open()

        $schema = $conn.GetOleDbSchemaTable([System.Data.OleDb.OleDbSchemaGuid]::Tables, $null)
        foreach ($row in $schema.Rows) {
            $sheet = [string]$row.TABLE_NAME
            if ($sheet -notlike '*$') { continue }

            $out += "SHEET=$sheet"
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT TOP 20 * FROM [$sheet]"
            $adapter = New-Object System.Data.OleDb.OleDbDataAdapter($cmd)
            $table = New-Object System.Data.DataTable
            [void]$adapter.Fill($table)

            $cols = @($table.Columns | ForEach-Object { $_.ColumnName })
            $out += ($cols -join '|')

            foreach ($dataRow in $table.Rows) {
                $vals = @()
                foreach ($col in $table.Columns) {
                    $vals += [string]$dataRow[$col.ColumnName]
                }
                $out += ($vals -join '|')
            }
        }

        $conn.Close()
        $out | Out-File $OutputFile -Encoding UTF8
        return
    }
    catch {
        $out += $_.Exception.Message
    }
}

$out | Out-File $OutputFile -Encoding UTF8