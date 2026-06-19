output to 'C:/BTV/diag3.txt' format ascii delimited by ',' quote '';
select TIPE_TRANS, count(*) as JML, sum(NEW_SALDO) as TOTAL
from SALDO_AWAL_FAKTUR where month(PERIODE)=1 and year(PERIODE)=2026
group by TIPE_TRANS;

output to 'C:/BTV/diag1.txt' format ascii delimited by ',' quote '';
select TIPE_TRANS, count(*) as JML from AP_TRANS group by TIPE_TRANS;

output to 'C:/BTV/diag2.txt' format ascii delimited by ',' quote '';
select top 3 VENDOR_ID, ORDER_CLIENT, TIPE_TRANS from AP_TRANS where VENDOR_ID like '200.%';

output to 'C:/BTV/diag4.txt' format ascii delimited by ',' quote '';
select top 5 S.BUKTI_ID, S.VENDOR_ID, S.TIPE_TRANS,
    (select count(*) from AP_TRANS A where A.ORDER_CLIENT = S.BUKTI_ID) as ADA
from SALDO_AWAL_FAKTUR S
where S.TIPE_TRANS = 1 and month(S.PERIODE)=1 and year(S.PERIODE)=2026;
