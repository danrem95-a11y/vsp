$cs = "Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn = New-Object System.Data.Odbc.OdbcConnection $cs; $cn.Open()
function Qry($lbl,$sql){ Write-Host "== $lbl =="; $c=$cn.CreateCommand(); $c.CommandTimeout=120; $c.CommandText=$sql
  try{$rd=$c.ExecuteReader(); $any=$false; while($rd.Read()){$any=$true; $l=@();for($i=0;$i -lt $rd.FieldCount;$i++){$l+=($rd.GetName($i)+"="+[string]$rd[$i])};Write-Host ("  "+($l -join " | "))}; if(-not $any){Write-Host "  (tak ada)"}; $rd.Close()}catch{Write-Host("  ERR: "+$_.Exception.Message)} }

Qry "1. Kolom tstok2 (cari satuan/unit/isi/konv)" @"
select cname from SYS.SYSCOLUMNS where tname='tstok2' order by cname
"@
Qry "2. Kolom im_produk (cari satuan/isi/konversi)" @"
select cname from SYS.SYSCOLUMNS where tname='im_produk' and (cname like '%sat%' or cname like '%isi%' or cname like '%konv%' or cname like '%unit%')
"@
$cn.Close()
