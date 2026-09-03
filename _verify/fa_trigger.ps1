$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$cn=New-Object System.Data.Odbc.OdbcConnection $cs;$cn.Open()
function Exec($lbl,$sql){ $c=$cn.CreateCommand();$c.CommandTimeout=30;$c.CommandText=$sql
  try{ $n=$c.ExecuteNonQuery(); Write-Host ("OK  $lbl") }
  catch{ Write-Host ("ERR $lbl : "+($_.Exception.Message -replace "`r`n"," ")) } }

# drop kalau sudah ada (idempoten)
Exec "drop old trigger (if any)" "if exists(select 1 from systrigger where trigname='tr_fa_asset_default_num') then drop trigger tr_fa_asset_default_num end if"

$ddl = @"
create trigger tr_fa_asset_default_num
before insert, update on FA_ASSET
referencing new as n
for each row
begin
  if n.residual_value       is null then set n.residual_value       = 0 end if;
  if n.acquisition_cost      is null then set n.acquisition_cost      = 0 end if;
  if n.useful_life_month     is null then set n.useful_life_month     = 0 end if;
  if n.accum_dep_beginning   is null then set n.accum_dep_beginning   = 0 end if;
  if n.book_value_beginning  is null then set n.book_value_beginning  = 0 end if;
  if n.remaining_life_begin  is null then set n.remaining_life_begin  = 0 end if
end
"@
Exec "create trigger tr_fa_asset_default_num" $ddl

# verifikasi
$c=$cn.CreateCommand();$c.CommandText="select trigname, event, trigtime from systrigger where trigname='tr_fa_asset_default_num'"
$rd=$c.ExecuteReader(); while($rd.Read()){Write-Host ("  VERIFY -> "+[string]$rd[0]+" event="+[string]$rd[1]+" time="+[string]$rd[2])}; $rd.Close()
$cn.Close()
