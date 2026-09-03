$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | "))}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

$flt = "a.FinCatCode like 'IS%' and (upper(a.AccountDes) like '%GAJI%' or upper(a.AccountDes) like '%TUNJANGAN%' or upper(a.AccountDes) like '%LEMBUR%' or upper(a.AccountDes) like '%INSENTIF%' or upper(a.AccountDes) like '%HONOR%' or upper(a.AccountDes) like '%THR%' or upper(a.AccountDes) like '%BONUS%' or upper(a.AccountDes) like '%BPJS%' or upper(a.AccountDes) like '%JAMSOSTEK%' or upper(a.AccountDes) like '%ASTEK%' or upper(a.AccountDes) like '%KARYAWAN%' or upper(a.AccountDes) like '%HADIR%' or upper(a.AccountDes) like '%KESEJAHTERAAN%' or upper(a.AccountDes) like '%TENAGA KERJA%' or upper(a.AccountDes) like '%PERSONALIA%')"

Qry "Akun personil/gaji (IS) yang cocok - beban per bulan (debet-kredit)" @"
select a.AccountCode acc, a.AccountDes, a.FinCatCode grp,
 cast(sum(case when datepart(month,g.tgl)=1 then g.debet-g.kredit else 0 end) as numeric(20,2)) jan,
 cast(sum(case when datepart(month,g.tgl)=2 then g.debet-g.kredit else 0 end) as numeric(20,2)) feb,
 cast(sum(case when datepart(month,g.tgl)=3 then g.debet-g.kredit else 0 end) as numeric(20,2)) mar,
 cast(sum(case when datepart(month,g.tgl)=4 then g.debet-g.kredit else 0 end) as numeric(20,2)) apr,
 cast(sum(case when datepart(month,g.tgl)=5 then g.debet-g.kredit else 0 end) as numeric(20,2)) mei,
 cast(sum(case when datepart(month,g.tgl)=6 then g.debet-g.kredit else 0 end) as numeric(20,2)) jun,
 cast(sum(case when datepart(month,g.tgl)=7 then g.debet-g.kredit else 0 end) as numeric(20,2)) jul
from gl_journal g join gl_acc a on a.AccountCode=g.account_id and a.site_id='101'
where g.posting='P' and $flt and g.tgl>='2026-01-01' and g.tgl<='2026-07-31'
group by a.AccountCode, a.AccountDes, a.FinCatCode
having sum(abs(g.debet-g.kredit))>0
order by a.AccountCode
"@

Qry "TOTAL beban personil per bulan + per departemen (grup IS)" @"
select isnull(a.FinCatCode,'?') grp,
 cast(sum(case when datepart(month,g.tgl)=1 then g.debet-g.kredit else 0 end) as numeric(20,2)) jan,
 cast(sum(case when datepart(month,g.tgl)=2 then g.debet-g.kredit else 0 end) as numeric(20,2)) feb,
 cast(sum(case when datepart(month,g.tgl)=3 then g.debet-g.kredit else 0 end) as numeric(20,2)) mar,
 cast(sum(case when datepart(month,g.tgl)=4 then g.debet-g.kredit else 0 end) as numeric(20,2)) apr,
 cast(sum(case when datepart(month,g.tgl)=5 then g.debet-g.kredit else 0 end) as numeric(20,2)) mei,
 cast(sum(case when datepart(month,g.tgl)=6 then g.debet-g.kredit else 0 end) as numeric(20,2)) jun,
 cast(sum(case when datepart(month,g.tgl)=7 then g.debet-g.kredit else 0 end) as numeric(20,2)) jul
from gl_journal g join gl_acc a on a.AccountCode=g.account_id and a.site_id='101'
where g.posting='P' and $flt and g.tgl>='2026-01-01' and g.tgl<='2026-07-31'
group by a.FinCatCode order by a.FinCatCode
"@
$cn.Close()
