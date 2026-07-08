$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Dict($sql,$k,$v){$h=@{};$c=$cn.CreateCommand();$c.CommandTimeout=300;$c.CommandText=$sql;$rd=$c.ExecuteReader();while($rd.Read()){$h[[string]$rd[$k]]=[double]$rd[$v]};$rd.Close();return $h}
$sinvJun=Dict "select g.persediaan acc, sum(s.nilai) v from sinv s,im_produk p,im_product_group g where s.periode='2026-06-01' and s.stok_id=p.produk_id and p.group_product=g.kode_group group by g.persediaan" "acc" "v"
$glMei=Dict "select acc, sum(v) v from (select AccountCode acc, sum(AmountDebet-AmountCredit) v from gl_balance where Period='2026-01-01' group by AccountCode union all select account_id acc, sum(debet-kredit) v from gl_journal where tgl between '2026-01-01' and '2026-05-31' and posting='P' group by account_id) x group by acc" "acc" "v"
$grp=@{'102-001'='TR';'102-006'='TB';'102-101'='TS';'102-102'='TL';'102-110'='L+LA';'102-003'='NR';'102-103'='NDS';'102-113'='TY';'102-010'='TYU';'102-018'='BCS';'102-254'='VL';'102-201'='MAT'}
Write-Host ("{0,-8}{1,-5}{2,18}{3,18}{4,16}" -f "akun","grp","SINV_Jun(akhirMei)","ledgerMei","SINV-ledger")
foreach($a in ($grp.Keys | Sort-Object)){
 $s=0.0; if($sinvJun.ContainsKey($a)){$s=$sinvJun[$a]}
 $g=0.0; if($glMei.ContainsKey($a)){$g=$glMei[$a]}
 Write-Host ("{0,-8}{1,-5}{2,18:N2}{3,18:N2}{4,16:N2}" -f $a,$grp[$a],$s,$g,($s-$g))
}
Write-Host ""
Write-Host "=== GL Mei per akun-BESAR selisih: cek modul (apakah HP/AS Mei sudah di-refresh?) TR & NR ==="
function Qry($s){$c=$cn.CreateCommand();$c.CommandText=$s;$rd=$c.ExecuteReader();while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host("  "+($l -join " | "))};$rd.Close()}
Qry "select account_id, modul_id, count(*) n, cast(sum(debet-kredit) as numeric(18,2)) net from gl_journal where account_id in ('102-001','102-003') and tgl between '2026-05-01' and '2026-05-31' and posting='P' group by account_id,modul_id order by account_id,modul_id"
$cn.Close()
