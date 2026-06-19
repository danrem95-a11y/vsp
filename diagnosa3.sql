output to 'C:/BTV/debug/diag3_saldo_tipe.txt' format ascii delimited by ',' quote '';
select TIPE_TRANS, count(*) as JML_FAKTUR, sum(NEW_SALDO) as TOTAL_IDR
from SALDO_AWAL_FAKTUR
where month(PERIODE)=1 and year(PERIODE)=2026
group by TIPE_TRANS;

output to 'C:/BTV/debug/diag1_aptrans_tipe.txt' format ascii delimited by ',' quote '';
select TIPE_TRANS, count(*) as JML from AP_TRANS group by TIPE_TRANS order by TIPE_TRANS;

output to 'C:/BTV/debug/diag2_vendor200.txt' format ascii delimited by ',' quote '';
select top 5 VENDOR_ID, ORDER_CLIENT, TIPE_TRANS, TGL from AP_TRANS where VENDOR_ID like '200.%' order by TGL desc;

output to 'C:/BTV/debug/diag4_cross.txt' format ascii delimited by ',' quote '';
select top 10 S.BUKTI_ID, S.VENDOR_ID, S.TIPE_TRANS, S.NEW_SALDO,
    (select count(*) from AP_TRANS A where A.ORDER_CLIENT = S.BUKTI_ID and A.TIPE_TRANS in ('02','05','06','12','16')) as ADA_AP
from SALDO_AWAL_FAKTUR S
where S.TIPE_TRANS = 1 and month(S.PERIODE)=1 and year(S.PERIODE)=2026
order by S.BUKTI_ID;

output to 'C:/BTV/debug/diag5_selisih.txt' format ascii delimited by ',' quote '';
select 'Semua' as KET, sum(NEW_SALDO) as TOTAL_IDR, count(distinct BUKTI_ID) as JML
from SALDO_AWAL_FAKTUR where month(PERIODE)=1 and year(PERIODE)=2026
union all
select 'Hanya TIPE=2', sum(NEW_SALDO), count(distinct BUKTI_ID)
from SALDO_AWAL_FAKTUR where TIPE_TRANS=2 and month(PERIODE)=1 and year(PERIODE)=2026;
