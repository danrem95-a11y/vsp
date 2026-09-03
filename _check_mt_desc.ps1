$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
$m=$c.CreateCommand(); $m.CommandText="select produk_id, produk_desc from im_produk where produk_id='MT01-0001'"; $rd=$m.ExecuteReader()
while($rd.Read()){ Write-Output ($rd.GetValue(0).ToString()+" | "+$rd.GetValue(1).ToString()) }
$rd.Close()

# Cari jurnal 102-201 sepanjang 2019 dgn nilai besar (kandidat entry penyebab gap)
$m2=$c.CreateCommand(); $m2.CommandText=@"
select cast(g.tgl as date) tgl, g.voucher, g.modul_id, cast(g.debet as numeric(16,2)) debet, cast(g.kredit as numeric(16,2)) kredit, g.ket
  from gl_journal g
 where g.account_id='102-201' and g.tgl between '2019-01-01' and '2019-12-31'
   and (abs(g.debet-73846544.24)<5000 or abs(g.kredit-73846544.24)<5000)
"@
$rd2=$m2.ExecuteReader()
Write-Output "-- kandidat jurnal 2019 dekat 73.846.544,24 --"
$n=0
while($rd2.Read()){ $n++; Write-Output ($rd2.GetValue(0).ToString()+" | "+$rd2.GetValue(1).ToString()+" | "+$rd2.GetValue(2).ToString()+" | "+$rd2.GetValue(3).ToString()+" | "+$rd2.GetValue(4).ToString()+" | "+$rd2.GetValue(5).ToString()) }
if($n -eq 0){ Write-Output "(0 baris - tidak ada match persis)" }
$rd2.Close()

# Cari jurnal 102-201 sepanjang 2022 dgn nilai besar (kandidat entry koreksi 49,88jt)
$m3=$c.CreateCommand(); $m3.CommandText=@"
select cast(g.tgl as date) tgl, g.voucher, g.modul_id, cast(g.debet as numeric(16,2)) debet, cast(g.kredit as numeric(16,2)) kredit, g.ket
  from gl_journal g
 where g.account_id='102-201' and g.tgl between '2022-01-01' and '2022-12-31'
   and (abs(g.debet-49883912.78)<5000 or abs(g.kredit-49883912.78)<5000)
"@
$rd3=$m3.ExecuteReader()
Write-Output "-- kandidat jurnal 2022 dekat 49.883.912,78 --"
$n3=0
while($rd3.Read()){ $n3++; Write-Output ($rd3.GetValue(0).ToString()+" | "+$rd3.GetValue(1).ToString()+" | "+$rd3.GetValue(2).ToString()+" | "+$rd3.GetValue(3).ToString()+" | "+$rd3.GetValue(4).ToString()+" | "+$rd3.GetValue(5).ToString()) }
if($n3 -eq 0){ Write-Output "(0 baris - tidak ada match persis)" }
$rd3.Close()
$c.Close()
