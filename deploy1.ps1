$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Exec($label,$s){$c=$cn.CreateCommand();$c.CommandTimeout=120;$c.CommandText=$s
  try{$n=$c.ExecuteNonQuery();Write-Host ("  OK  "+$label+" (rows="+$n+")")}catch{Write-Host ("  ERR "+$label+": "+$_.Exception.Message)}}
function Qry($s){$c=$cn.CreateCommand();$c.CommandTimeout=120;$c.CommandText=$s;try{$rd=$c.ExecuteReader()}catch{Write-Host("  ERR:"+$_.Exception.Message);return};while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("  "+($l -join " | "))};$rd.Close()}

Write-Host "===== STEP 1: CREATE TABLE rekon_account_map + index ====="
Exec "create table" "CREATE TABLE rekon_account_map ( domain VARCHAR(4) NOT NULL, account_type VARCHAR(20) NOT NULL, account_id VARCHAR(20) NOT NULL, site_id VARCHAR(10) NOT NULL DEFAULT '*', is_active CHAR(1) NOT NULL DEFAULT 'Y', effective_from TIMESTAMP NOT NULL DEFAULT '1900-01-01', effective_to TIMESTAMP NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT TIMESTAMP, created_by VARCHAR(30) NOT NULL DEFAULT USER, PRIMARY KEY (domain, account_type, account_id, site_id, effective_from) )"
Exec "idx acc_site" "CREATE INDEX idx_ram_acc_site ON rekon_account_map (account_id, site_id, is_active)"
Exec "idx domain"   "CREATE INDEX idx_ram_domain   ON rekon_account_map (domain, is_active, account_id)"
Exec "commit" "COMMIT"

Write-Host "===== STEP 2: MIGRATION (dari gl_setup + im_product_group) ====="
Exec "2.1 STOK/INVENTORY" "INSERT INTO rekon_account_map (domain, account_type, account_id, site_id, is_active, effective_from) SELECT 'STOK','INVENTORY', d.persediaan, (SELECT CASE WHEN ISNULL(gs.site_code,'')='' THEN '*' ELSE gs.site_code END FROM gl_setup gs), 'Y', (SELECT ISNULL(gs2.tgl_start,'1900-01-01') FROM gl_setup gs2) FROM (SELECT DISTINCT persediaan FROM im_product_group WHERE ISNULL(persediaan,'') <> '') d WHERE NOT EXISTS (SELECT 1 FROM rekon_account_map m WHERE m.domain='STOK' AND m.account_type='INVENTORY' AND m.account_id=d.persediaan)"
Exec "2.2 AP/PAYABLE" "INSERT INTO rekon_account_map (domain, account_type, account_id, site_id, is_active, effective_from) SELECT 'AP','PAYABLE', gs.acc_ap, CASE WHEN ISNULL(gs.site_code,'')='' THEN '*' ELSE gs.site_code END, 'Y', ISNULL(gs.tgl_start,'1900-01-01') FROM gl_setup gs WHERE ISNULL(gs.acc_ap,'') <> '' AND NOT EXISTS (SELECT 1 FROM rekon_account_map m WHERE m.domain='AP' AND m.account_type='PAYABLE' AND m.account_id=gs.acc_ap)"
Exec "2.3 AP/PAYABLE_FREIGHT" "INSERT INTO rekon_account_map (domain, account_type, account_id, site_id, is_active, effective_from) SELECT 'AP','PAYABLE_FREIGHT', gs.acc_biaya_ekpedisi, CASE WHEN ISNULL(gs.site_code,'')='' THEN '*' ELSE gs.site_code END, 'Y', ISNULL(gs.tgl_start,'1900-01-01') FROM gl_setup gs WHERE ISNULL(gs.acc_biaya_ekpedisi,'') <> '' AND NOT EXISTS (SELECT 1 FROM rekon_account_map m WHERE m.domain='AP' AND m.account_type='PAYABLE_FREIGHT' AND m.account_id=gs.acc_biaya_ekpedisi)"
Exec "2.4 AR/RECEIVABLE" "INSERT INTO rekon_account_map (domain, account_type, account_id, site_id, is_active, effective_from) SELECT 'AR','RECEIVABLE', gs.acc_ar, CASE WHEN ISNULL(gs.site_code,'')='' THEN '*' ELSE gs.site_code END, 'Y', ISNULL(gs.tgl_start,'1900-01-01') FROM gl_setup gs WHERE ISNULL(gs.acc_ar,'') <> '' AND NOT EXISTS (SELECT 1 FROM rekon_account_map m WHERE m.domain='AR' AND m.account_type='RECEIVABLE' AND m.account_id=gs.acc_ar)"
Exec "commit" "COMMIT"

Write-Host "===== STEP 3: SANITY CHECK ====="
Qry "SELECT domain, account_type, COUNT(*) AS n FROM rekon_account_map GROUP BY domain, account_type ORDER BY domain, account_type"
Write-Host "--- isi map (semua baris) ---"
Qry "SELECT domain, account_type, account_id, site_id, is_active, effective_from FROM rekon_account_map ORDER BY domain, account_type, account_id"
$cn.Close()
