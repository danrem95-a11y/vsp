$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=150; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 60){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 60){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}

# bukti_id sebenarnya utk 5 voucher NR mei
Tab @"
select s1.order_client, s1.bukti_id, s1.tgl, count(s2.evap) n_baris_evap_now
  from tsales1 s1
  left join tsales2 s2 on s2.bukti_id=s1.bukti_id and isnull(s2.evap,'')<>''
 where s1.order_client in ('101260500061','101260500062','101260500063','101260500064','101260500065')
 group by s1.order_client, s1.bukti_id, s1.tgl
"@ "1. bukti_id sebenarnya + jumlah baris evap SEKARANG per voucher"

# GL kredit_total persis formula tier-3 utk masing2 voucher (account 102-003)
Tab @"
select voucher, account_id, cast(sum(isnull(kredit,0)) as numeric(16,2)) kredit_total
  from gl_journal
 where modul_id='AS' and isnull(kredit,0)>0
   and voucher in ('101260500061','101260500062','101260500063','101260500064','101260500065')
 group by voucher, account_id
"@ "2. gl.kredit_total persis formula (GROUP BY voucher, account_id, modul_id=AS, kredit>0)"
$c.Close()
