$conn = New-Object System.Data.Odbc.OdbcConnection("DSN=vsp")
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandText = "SELECT top 1 * FROM tbyr2 WHERE flag_order = 2"
$rd = $cmd.ExecuteReader()
# Column names
$cols = @()
for($c=0; $c -lt $rd.FieldCount; $c++){ $cols += $rd.GetName($c) }
Write-Host ($cols -join " | ")
if($rd.Read()){
    $vals = @()
    for($c=0; $c -lt $rd.FieldCount; $c++){ $vals += [string]$rd[$c] }
    Write-Host ($vals -join " | ")
}
$conn.Close()
