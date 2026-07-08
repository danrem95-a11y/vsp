$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
# GL ledger per akun (opening + jurnal s/d 30 Apr)
$gl=@{}
$c=$cn.CreateCommand();$c.CommandText="select acc, sum(v) v from (select AccountCode acc, sum(AmountDebet-AmountCredit) v from gl_balance where Period='2026-01-01' group by AccountCode union all select account_id acc, sum(debet-kredit) v from gl_journal where tgl between '2026-01-01' and '2026-04-30' and posting='P' group by account_id) x group by acc"
$rd=$c.ExecuteReader(); while($rd.Read()){ $gl[[string]$rd["acc"]]=[double]$rd["v"] }; $rd.Close()
# report Saldo Akhir Rp per persediaan (query final)
$sql=Get-Content C:/BTV/debug/_dwsgl3.sql -Raw
$akhir="(isnull(q.AWAL_RP,0)+isnull(q.BELI_RP,0)+isnull(q.RET_JUAL_RP,0)+isnull(q.CONSIN_BY_EVAP_RP,0)+isnull(q.CONSIN_RP,0)+isnull(q.MUTASI_IN_RP,0)-(isnull(q.JUAL_BY_EVAP_RP,0)+isnull(q.JUAL_REAL,0))-isnull(q.RET_BELI_RP,0)-isnull(q.CONSOUT_RP,0)-isnull(q.MUTASI_OUT_RP,0))"
$q="select q.PERSEDIAAN acc, cast(sum($akhir) as numeric(18,2)) rp from ( $sql ) q group by q.PERSEDIAAN order by q.PERSEDIAAN"
$c2=$cn.CreateCommand();$c2.CommandTimeout=600;$c2.CommandText=$q
$grp=@{'102-001'='TR';'102-006'='TB';'102-101'='TS';'102-102'='TL';'102-110'='L+LA';'102-003'='NR';'102-103'='NDS';'102-113'='TY';'102-010'='TYU';'102-018'='BCS';'102-254'='VL';'102-201'='MAT'}
Write-Host ("{0,-9}{1,-6}{2,20}{3,20}{4,18}" -f "akun","grp","report_akhir","GL_ledger","selisih")
$rd2=$c2.ExecuteReader()
while($rd2.Read()){
  $a=[string]$rd2["acc"]; if($a.Trim() -eq ''){continue}
  $r=[double]$rd2["rp"]; $g=0.0; if($gl.ContainsKey($a)){$g=$gl[$a]}
  $gn=''; if($grp.ContainsKey($a)){$gn=$grp[$a]}
  if([math]::Abs($r)-gt 1 -or [math]::Abs($g)-gt 1){
    Write-Host ("{0,-9}{1,-6}{2,20:N2}{3,20:N2}{4,18:N2}" -f $a,$gn,$r,$g,($r-$g))
  }
}
$rd2.Close(); $cn.Close()
