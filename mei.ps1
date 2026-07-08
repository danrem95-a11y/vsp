$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Dict($sql,$k,$v){$h=@{};$c=$cn.CreateCommand();$c.CommandTimeout=600;$c.CommandText=$sql;$rd=$c.ExecuteReader();while($rd.Read()){$h[[string]$rd[$k]]=[double]$rd[$v]};$rd.Close();return $h}
# saldo akhir April = SINV(2026-05-01) per akun ; saldo akhir Mei ref = SINV(2026-06-01)
$aprEnd=Dict "select g.persediaan acc, sum(s.nilai) v from sinv s,im_produk p,im_product_group g where s.periode='2026-05-01' and s.stok_id=p.produk_id and p.group_product=g.kode_group group by g.persediaan" "acc" "v"
$meiEndSinv=Dict "select g.persediaan acc, sum(s.nilai) v from sinv s,im_produk p,im_product_group g where s.periode='2026-06-01' and s.stok_id=p.produk_id and p.group_product=g.kode_group group by g.persediaan" "acc" "v"
# ledger Mei = gl_balance(2026) + jurnal s/d 2026-05-31
$glMei=Dict "select acc, sum(v) v from (select AccountCode acc, sum(AmountDebet-AmountCredit) v from gl_balance where Period='2026-01-01' group by AccountCode union all select account_id acc, sum(debet-kredit) v from gl_journal where tgl between '2026-01-01' and '2026-05-31' and posting='P' group by account_id) x group by acc" "acc" "v"
# report Mei: saldo awal (AWAL_RP) & saldo akhir (akhir_rpxx) per persediaan
$sql=Get-Content C:/BTV/debug/_mei.sql -Raw
$akhir="(isnull(q.AWAL_RP,0)+isnull(q.BELI_RP,0)+isnull(q.RET_JUAL_RP,0)+isnull(q.CONSIN_BY_EVAP_RP,0)+isnull(q.CONSIN_RP,0)+isnull(q.MUTASI_IN_RP,0)-(isnull(q.JUAL_BY_EVAP_RP,0)+isnull(q.JUAL_REAL,0))-isnull(q.RET_BELI_RP,0)-isnull(q.CONSOUT_RP,0)-isnull(q.MUTASI_OUT_RP,0))"
$q="select q.PERSEDIAAN acc, cast(sum(isnull(q.AWAL_RP,0)) as numeric(18,2)) awal, cast(sum($akhir) as numeric(18,2)) akhir from ( $sql ) q group by q.PERSEDIAAN order by q.PERSEDIAAN"
$c=$cn.CreateCommand();$c.CommandTimeout=600;$c.CommandText=$q
$grp=@{'102-001'='TR';'102-006'='TB';'102-101'='TS';'102-102'='TL';'102-110'='L+LA';'102-003'='NR';'102-103'='NDS';'102-113'='TY';'102-010'='TYU';'102-018'='BCS';'102-254'='VL';'102-201'='MAT'}
Write-Host ("{0,-8}{1,-5}{2,16}{3,16}{4,16}{5,16}{6,14}" -f "akun","grp","awalMei_rpt","akhirApr_SINV","akhirMei_rpt","ledgerMei","aw-akhApr|ak-led")
$rd=$c.ExecuteReader()
while($rd.Read()){
 $a=[string]$rd["acc"]; if($a.Trim() -eq ''){continue}
 $aw=[double]$rd["awal"]; $ak=[double]$rd["akhir"]
 $apr=0.0; if($aprEnd.ContainsKey($a)){$apr=$aprEnd[$a]}
 $led=0.0; if($glMei.ContainsKey($a)){$led=$glMei[$a]}
 $gn=''; if($grp.ContainsKey($a)){$gn=$grp[$a]}
 if([math]::Abs($aw)-gt 1 -or [math]::Abs($led)-gt 1){
   Write-Host ("{0,-8}{1,-5}{2,16:N0}{3,16:N0}{4,16:N0}{5,16:N0}  {6,7:N0}/{7,7:N0}" -f $a,$gn,$aw,$apr,$ak,$led,($aw-$apr),($ak-$led))
 }
}
$rd.Close();$cn.Close()
