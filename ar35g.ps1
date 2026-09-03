$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
$c=$cn.CreateCommand(); $c.CommandText=@"
select 'OLD delete (semua tgl) - salah, hapus 2 bulan' jenis, count(*) n, cast(sum(debet-kredit) as numeric(18,2)) net
from gl_journal where doc_reff='10103260200033' and posting='P'
union all
select 'NEW delete saat proses retur MEI (month=5) - benar', count(*), cast(sum(debet-kredit) as numeric(18,2))
from gl_journal where doc_reff='10103260200033' and posting='P' and month(tgl)=5 and year(tgl)=2026
union all
select 'NEW delete saat proses faktur FEB (month=2) - benar', count(*), cast(sum(debet-kredit) as numeric(18,2))
from gl_journal where doc_reff='10103260200033' and posting='P' and month(tgl)=2 and year(tgl)=2026
"@
$rd=$c.ExecuteReader(); while($rd.Read()){ Write-Host ("  "+$rd[0]+" | n="+$rd[1]+" | net="+$rd[2]) }; $rd.Close()
$cn.Close()
