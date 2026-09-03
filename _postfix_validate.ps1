$ErrorActionPreference='Stop'
$cs="Driver={Adaptive Server Anywhere 9.0};UID=dba;PWD=jakarta;CommLinks=tcpip(host=103.233.89.43;port=2638);ENG=vspnew;Pooling=false"
$c=New-Object System.Data.Odbc.OdbcConnection($cs); $c.Open()
function Tab([string]$q,[string]$label){
  Write-Output "== $label =="
  try{ $m=$c.CreateCommand(); $m.CommandText=$q; $m.CommandTimeout=150; $rd=$m.ExecuteReader(); $fc=$rd.FieldCount
    $cols=@(); for($i=0;$i -lt $fc;$i++){$cols+=$rd.GetName($i)}; Write-Output ("  "+($cols -join ' | '))
    $n=0; while($rd.Read()){ $n++; if($n -le 45){ $v=@(); for($i=0;$i -lt $fc;$i++){ $x=$rd.GetValue($i); if($x -is [decimal]-or $x -is [double]){$v+=('{0:N2}' -f $x)}else{$v+=[string]$x} }; Write-Output ("  "+($v -join ' | ')) } }
    if($n -gt 45){ Write-Output "  ... ($n baris)" }; if($n -eq 0){ Write-Output "  (0 baris)" }; $rd.Close()
  }catch{ Write-Output ("  ERR: "+$_.Exception.Message.Split([char]10)[0]) }
}

# 1. STEP 6a -- sisa stale-freeze, harus 0 sekarang
Tab @"
select count(*) sisa_stale
  from (
    select s2.stok_id, s2.hpp, dateadd(day, 1-day(s1.tgl), s1.tgl) periode_bom
      from tsales1 s1, tsales2 s2
     where s1.bukti_id=s2.bukti_id and s1.tipe_trans='88' and isnull(s2.evap,'')<>''
       and s1.tgl between '2026-01-01' and '2026-06-30'
  ) z
  left join sinv sv on sv.stok_id=z.stok_id and sv.periode=z.periode_bom
 where isnull(sv.hpp_avg,0) > 0
   and abs(z.hpp - isnull(sv.hpp_avg,0)) > 1
"@ "1. STEP6a -- sisa stale-freeze (harus 0)"

# 2. STEP 6b -- GL balance per voucher (39 voucher), harus 0 baris tidak-balance
Tab @"
select voucher,
       sum(case when account_id='102-020' then debet else 0 end) dr_wip,
       sum(case when account_id='102-001' then kredit else 0 end) cr_persediaan
  from gl_journal
 where voucher in (select distinct voucher from ZZ_WIPFIX_MAP_20260810)
   and modul_id='AS'
 group by voucher
having sum(case when account_id='102-020' then debet else 0 end) <>
       sum(case when account_id='102-001' then kredit else 0 end)
"@ "2. STEP6b -- voucher GL tidak balance (harus 0 baris)"

# 3. Spot-check: TSALES2 88 dan 22 sekarang = hpp_new dari map, TSTOK2 WIP-in juga
Tab @"
select count(*) n_ok
  from ZZ_WIPFIX_MAP_20260810 m, tsales2 s2
 where s2.bukti_id=m.wo_bukti and s2.stok_id=m.stok_id and isnull(s2.evap,'')=isnull(m.evap,'')
   and abs(s2.hpp - round(m.hpp_new,2)) < 0.01
"@ "3. Cek TSALES2 88 sudah = hpp_new (harus 39)"

Tab @"
select count(*) n_ok
  from ZZ_WIPFIX_MAP_20260810 m, tsales2 s2
 where s2.bukti_id=m.bukti_id_22 and s2.stok_id=m.stok_id and isnull(s2.evap,'')=isnull(m.evap,'')
   and abs(s2.hpp - round(m.hpp_new,2)) < 0.01
"@ "4. Cek TSALES2 22 sudah = hpp_new (harus 39)"

Tab @"
select count(*) n_ok
  from ZZ_WIPFIX_MAP_20260810 m, tstok2 t2
 where t2.bukti_id=m.wipin_bukti and t2.stok_id=m.stok_id
   and abs(t2.hpp - round(m.hpp_new,0)) < 1
"@ "5. Cek TSTOK2 WIP-In sudah = hpp_new (harus 39)"

Tab @"
select count(*) n_ok
  from ZZ_WIPFIX_MAP_20260810 m, gl_journal g
 where g.voucher=m.voucher and g.account_id='102-020' and g.modul_id='AS'
   and abs(g.debet - round(m.hpp_new,2)) < 0.01
"@ "6. Cek GL Dr 102-020 sudah = hpp_new (harus 39)"

# 7. Apr->Mei chain residual utk TR.038A -- harus 0 sekarang (dulu 32.953.937,10)
Tab @"
select cast(sum((hpp_new-hpp_old)*qty) as numeric(16,2)) residual_seharusnya_sudah_nol
  from ZZ_WIPFIX_MAP_20260810
 where stok_id='TR.038A' and tgl_wo between '2026-04-01' and '2026-04-30'
"@ "7. Referensi delta April TR.038A yg sudah dikoreksi (harusnya sudah masuk ke GL/TSALES2, bukan 'sisa')"

# 8. Total GL debet vs kredit sitewide Jan-Jun -- pastikan tetap balance (tidak ada kebocoran akibat koreksi)
Tab @"
select cast(sum(debet) as numeric(20,2)) total_debet, cast(sum(kredit) as numeric(20,2)) total_kredit,
       cast(sum(debet)-sum(kredit) as numeric(20,2)) selisih
  from gl_journal
 where tgl between '2026-01-01' and '2026-06-30'
"@ "8. Total GL Jan-Jun sitewide (Debet harus = Kredit)"

$c.Close()
