$conn=New-Object System.Data.Odbc.OdbcConnection("DSN=vsp;UID=dba;PWD=jakarta")
$conn.Open(); $cmd=$conn.CreateCommand(); $cmd.CommandTimeout=180
function Ex($s){ $cmd.CommandText=$s; return $cmd.ExecuteNonQuery() }
function Scalar($s){ $cmd.CommandText=$s; return $cmd.ExecuteScalar() }
function Quiet($s){ try{ $cmd.CommandText=$s; [void]$cmd.ExecuteNonQuery() }catch{} }

# backup
Quiet "DROP TABLE diag135_bkp_tstok2"
Quiet "DROP TABLE diag135_bkp_gl"
[void](Ex "SELECT * INTO diag135_bkp_tstok2 FROM tstok2 WHERE bukti_id IN ('10126040500001','10126040500002')")
[void](Ex "SELECT * INTO diag135_bkp_gl FROM gl_journal WHERE modul_id='EX' AND doc_reff IN ('10126040500001','10126040500002','1012604FR05001','1012604FR05002')")
"BACKUP lokal: tstok2={0} gl={1}" -f (Scalar "SELECT COUNT(*) FROM diag135_bkp_tstok2"),(Scalar "SELECT COUNT(*) FROM diag135_bkp_gl")

$docs=@(
 @{doc='10126040500001';cur=26572609.03;tgt=28040724;jrn=14712724;oldj=13244609},
 @{doc='10126040500002';cur=43898656.04;tgt=45517210;jrn=19209210;oldj=17590656}
)
foreach($d in $docs){
  [void](Ex ("UPDATE tstok2 SET biaya_ekspedisi=round(biaya_ekspedisi*{0}.0/{1},2) WHERE bukti_id='{2}'" -f $d.tgt,$d.cur,$d.doc))
  $newtot=[decimal](Scalar ("SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id='{0}'" -f $d.doc))
  $mu=Scalar ("SELECT MAX(urut) FROM tstok2 WHERE bukti_id='{0}'" -f $d.doc)
  $q=[decimal](Scalar ("SELECT qty FROM tstok2 WHERE bukti_id='{0}' AND urut={1}" -f $d.doc,$mu)); if($q -eq 0){$q=1}
  $adj=[math]::Round(([decimal]$d.tgt-$newtot)/$q,2)
  [void](Ex ("UPDATE tstok2 SET biaya_ekspedisi=biaya_ekspedisi+({0}) WHERE bukti_id='{1}' AND urut={2}" -f $adj,$d.doc,$mu))
  $u1=Ex ("UPDATE gl_journal SET debet={0},debet_kurs={0} WHERE modul_id='EX' AND doc_reff='{1}' AND account_id='102-101' AND debet>0" -f $d.jrn,$d.doc)
  $u2=Ex ("UPDATE gl_journal SET kredit={0},kredit_kurs={0} WHERE modul_id='EX' AND doc_reff='{1}' AND account_id='226-006' AND kredit={2}" -f $d.jrn,$d.doc,$d.oldj)
  $ft=[decimal](Scalar ("SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id='{0}'" -f $d.doc))
  "{0}: tstok2_akhir={1:N2} | jurnal Dr_upd={2} Cr_upd={3}" -f $d.doc,$ft,$u1,$u2
}
# verifikasi
"`n=== VERIFIKASI lokal ==="
$cmd.CommandText=@"
SELECT a.order_client doc,
 (SELECT SUM(biaya_ekspedisi*qty) FROM tstok2 WHERE bukti_id=a.order_client) tstok2,
 (SELECT SUM(debet) FROM gl_journal WHERE doc_reff=a.order_client AND modul_id='EX' AND account_id='102-101') persediaan,
 (SELECT SUM(debet)-SUM(kredit) FROM gl_journal WHERE doc_reff=a.order_client AND modul_id='EX') balance
FROM ap_trans a WHERE a.order_client IN ('10126040500001','10126040500002')
"@
$r=$cmd.ExecuteReader()
while($r.Read()){ "doc={0} tstok2={1:N2} persediaan={2:N0} balance={3:N2}" -f $r['doc'],[decimal]$r['tstok2'],[decimal]$r['persediaan'],[decimal]$r['balance'] }
$r.Close(); $conn.Close()
