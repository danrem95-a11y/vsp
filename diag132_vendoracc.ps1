$ErrorActionPreference='Stop'
$cs="DRIVER={SQL Anywhere 11};CommLinks=tcpip(HOST=103.233.89.43:2638);ENG=vspnew;DBN=vspnew;UID=dba;PWD=jakarta"
$conn=New-Object System.Data.Odbc.OdbcConnection($cs); $conn.Open(); $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=180
$out=@()
function Q($t,$s){ $script:out+="";$script:out+="=== $t ===";try{$cmd.CommandText=$s;$r=$cmd.ExecuteReader();$n=0;while($r.Read()){$n++;$v=@();for($i=0;$i -lt $r.FieldCount;$i++){$v+="$($r.GetName($i))=$($r[$i])"};$script:out+=($v -join ' | ')};if($n -eq 0){$script:out+="(0)"};$r.Close()}catch{$script:out+="ERR: $($_.Exception.Message)"} }

# Pemetaan vendor FR -> akun kredit (gabungan ap_trans anak + jurnalnya)
Q "Vendor FR x akun kredit (seluruh sejarah)" @"
SELECT a.vendor_id, g.account_id, COUNT(DISTINCT a.order_client) n_dok, MIN(g.tgl) tgl_min, MAX(g.tgl) tgl_max
FROM ap_trans a
JOIN gl_journal g ON g.doc_reff=a.order_client AND g.modul_id='EX' AND g.kredit>0
WHERE a.order_client LIKE '%FR%' AND a.tipe_trans='05'
GROUP BY a.vendor_id, g.account_id ORDER BY a.vendor_id, g.account_id
"@

# Apakah ke-101 baris 226-006 itu memang vendor freight yg sama (4SL.S045/S029) atau vendor real-freight beda?
Q "226-006 FR: per vendor" @"
SELECT a.vendor_id, COUNT(*) n, MIN(g.tgl) tmin, MAX(g.tgl) tmax
FROM ap_trans a JOIN gl_journal g ON g.doc_reff=a.order_client AND g.modul_id='EX' AND g.account_id='226-006' AND g.kredit>0
WHERE a.order_client LIKE '%FR%'
GROUP BY a.vendor_id ORDER BY a.vendor_id
"@

# nama vendor 4SL.S045 / S029 / L004 / X001 (cari kolom master)
Q "kolom tabel mcstsupp" "SELECT FIRST * FROM mcstsupp"
$conn.Close()
($out -join "`r`n") | Set-Content c:\BTV\debug\diag132_vendoracc_out.txt -Encoding UTF8
($out -join "`r`n")
