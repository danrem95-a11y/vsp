$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host ""; Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=600; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $hdr=@(); for($i=0;$i -lt $rd.FieldCount;$i++){$hdr+=$rd.GetName($i)}; Write-Host ("   "+($hdr -join " | "))
    while($rd.Read()){$l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=[string]$rd[$i]};Write-Host ("   "+($l -join " | "))}; $rd.Close()}catch{Write-Host("   ERR: "+$_.Exception.Message)} }

Qry "LABA RUGI per bulan Jan-Jul 2026 (Rp) - GL movement, akun FinCatCode IS*" @"
select
 datepart(month,g.tgl) bln,
 cast(sum(case when a.FinCatCode='IS1001' then g.kredit-g.debet else 0 end) as numeric(20,2)) pendapatan,
 cast(sum(case when a.FinCatCode='IS1110' then g.debet-g.kredit else 0 end) as numeric(20,2)) hpp,
 cast(sum(case when a.FinCatCode in ('IS2010','IS2110','IS2120','IS2130') then g.debet-g.kredit else 0 end) as numeric(20,2)) beban_usaha,
 cast(sum(case when a.FinCatCode not in ('IS1001','IS1110','IS2010','IS2110','IS2120','IS2130') then g.kredit-g.debet else 0 end) as numeric(20,2)) lain_net,
 cast(sum(g.kredit-g.debet) as numeric(20,2)) laba_bersih
from gl_journal g join gl_acc a on a.AccountCode=g.account_id and a.site_id='101'
where g.posting='P' and a.FinCatCode like 'IS%' and g.tgl>='2026-01-01' and g.tgl<='2026-07-31'
group by datepart(month,g.tgl) order by bln
"@

Qry "Jul: cek kelengkapan data (jumlah faktur & max tgl jurnal Jul)" @"
select cast(max(g.tgl) as date) max_tgl_jul, count(distinct g.voucher) n_voucher_jul
from gl_journal g where g.posting='P' and g.tgl>='2026-07-01' and g.tgl<='2026-07-31'
"@
$cn.Close()
