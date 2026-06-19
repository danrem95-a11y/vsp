$ErrorActionPreference='Continue'
$conn=New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;Uid=dba;Pwd=jakarta;");$conn.Open()
function Q($l,$s){Write-Host "";Write-Host "===== $l =====";try{$c=$conn.CreateCommand();$c.CommandText=$s;$c.CommandTimeout=120;$r=$c.ExecuteReader();$cols=@();for($i=0;$i -lt $r.FieldCount;$i++){$cols+=$r.GetName($i)};Write-Host ($cols -join "`t");$n=0;while($r.Read()){$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$x=$r.GetValue($i);if($x -is [System.DBNull]){$x='(null)'};$v+=$x};Write-Host ($v -join "`t");$n++};$r.Close();Write-Host "($n rows)"}catch{Write-Host "ERR: $_"}}

# The 5 assets that would need deletion to get DB(6974M) down to GL book(5223M) per memo R70-R74
Q "Aset yg harus DIHAPUS utk turunkan ke GL (per memo R70-R74)" @"
SELECT asset_code, asset_name, CAST(acquisition_cost AS numeric(20,2)) cost,
       CAST(book_value_beginning AS numeric(20,2)) nbv_awal, status
FROM FA_ASSET WHERE site_id='101'
AND acquisition_cost IN (175911139,178638000,193897458,176885845,240000000)
ORDER BY acquisition_cost
"@

# Do these assets have POSTED 2026 depreciation? (deleting them = breaking validated journals)
Q "Penyusutan 2026 TERPOSTING utk aset Expander (yg basisnya audit-uplift)" @"
SELECT d.asset_code, COUNT(*) bln, CAST(SUM(d.depreciation_amount) AS numeric(20,2)) total_2026,
       MIN(d.posting_status) post
FROM FA_DEPRECIATION d
JOIN FA_ASSET a ON a.site_id=d.site_id AND a.asset_code=d.asset_code
WHERE d.site_id='101' AND a.category_code='KDR' AND d.period<='2026-06-30'
  AND a.acquisition_cost IN (525798600,788697900)
GROUP BY d.asset_code ORDER BY d.asset_code
"@
$conn.Close()
