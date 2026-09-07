select fincatcode,fincatdes,parentcode,parentname,accountcode,flag_dk,max(awal_debit) as awal_debit,max(awal_credit) as awal_credit,max(awal2_debit) as awal2_debit,max(awal2_credit) as awal2_credit,max(bln1_debit) as bln1_debit,max(bln1_credit) as bln1_credit,max(bln2_debit) as bln2_debit,max(bln2_credit) as bln2_credit,max(bln3_debit) as bln3_debit,max(bln3_credit) as bln3_credit,max(bln4_debit) as bln4_debit,max(bln4_credit) as bln4_credit,max(bln5_debit) as bln5_debit,max(bln5_credit) as bln5_credit,max(bln6_debit) as bln6_debit,max(bln6_credit) as bln6_credit,max(bln7_debit) as bln7_debit,max(bln7_credit) as bln7_credit,max(bln8_debit) as bln8_debit,max(bln8_credit) as bln8_credit,max(bln9_debit) as bln9_debit,max(bln9_credit) as bln9_credit,max(bln10_debit) as bln10_debit,max(bln10_credit) as bln10_credit,max(bln11_debit) as bln11_debit,max(bln11_credit) as bln11_credit,max(bln12_debit) as bln12_debit,max(bln12_credit) as bln12_credit,max(is_find) as is_find from (select
a.fincatcode,a.fincatdes,b.parentcode,b.parentname,c.accountcode,
c.debetcredit as flag_dk,
isnull(awal.debit,0.00) as awal_debit,
isnull(awal.credit,0.00) as awal_credit,
isnull(mvmt.awal2_debit,0.00) as awal2_debit,
isnull(mvmt.awal2_credit,0.00) as awal2_credit,isnull(mvmt.bln1_debit,0.00) as bln1_debit,
isnull(mvmt.bln1_credit,0.00) as bln1_credit,
isnull(mvmt.bln2_debit,0.00) as bln2_debit,
isnull(mvmt.bln2_credit,0.00) as bln2_credit,
isnull(mvmt.bln3_debit,0.00) as bln3_debit,
isnull(mvmt.bln3_credit,0.00) as bln3_credit,
isnull(mvmt.bln4_debit,0.00) as bln4_debit,
isnull(mvmt.bln4_credit,0.00) as bln4_credit,
isnull(mvmt.bln5_debit,0.00) as bln5_debit,
isnull(mvmt.bln5_credit,0.00) as bln5_credit,
isnull(mvmt.bln6_debit,0.00) as bln6_debit,
isnull(mvmt.bln6_credit,0.00) as bln6_credit,
isnull(mvmt.bln7_debit,0.00) as bln7_debit,
isnull(mvmt.bln7_credit,0.00) as bln7_credit,
isnull(mvmt.bln8_debit,0.00) as bln8_debit,
isnull(mvmt.bln8_credit,0.00) as bln8_credit,
isnull(mvmt.bln9_debit,0.00) as bln9_debit,
isnull(mvmt.bln9_credit,0.00) as bln9_credit,
isnull(mvmt.bln10_debit,0.00) as bln10_debit,
isnull(mvmt.bln10_credit,0.00) as bln10_credit,
isnull(mvmt.bln11_debit,0.00) as bln11_debit,
isnull(mvmt.bln11_credit,0.00) as bln11_credit,
isnull(mvmt.bln12_debit,0.00) as bln12_debit,
isnull(mvmt.bln12_credit,0.00) as bln12_credit,
a.fincatdes+' '+b.parentname+' '+c.accountcode as is_find
from
gl_cate a,gl_cate_detail b,gl_acc c,
(
	  			SELECT 	gl_balance.AccountCode,
							sum(AmountDebet) as debit,
							sum(AmountCredit) as credit
		 		FROM 	gl_balance
				WHERE 	gl_balance.Period = '2026-01-01'
				GROUP BY gl_balance.AccountCode
				) awal,
(
SELECT gl_journal.account_id,
sum(case when tgl between '2026-01-01' and '2025-12-31' then isnull(debet,0) else 0 end) as awal2_debit,
sum(case when tgl between '2026-01-01' and '2025-12-31' then isnull(kredit,0) else 0 end) as awal2_credit,
sum(case when tgl between '2026-01-01' and '2026-01-31' then isnull(debet,0) else 0 end) as bln1_debit,
sum(case when tgl between '2026-01-01' and '2026-01-31' then isnull(kredit,0) else 0 end) as bln1_credit,
sum(case when tgl between '2026-02-01' and '2026-02-28' then isnull(debet,0) else 0 end) as bln2_debit,
sum(case when tgl between '2026-02-01' and '2026-02-28' then isnull(kredit,0) else 0 end) as bln2_credit,
sum(case when tgl between '2026-03-01' and '2026-03-31' then isnull(debet,0) else 0 end) as bln3_debit,
sum(case when tgl between '2026-03-01' and '2026-03-31' then isnull(kredit,0) else 0 end) as bln3_credit,
sum(case when tgl between '2026-04-01' and '2026-04-30' then isnull(debet,0) else 0 end) as bln4_debit,
sum(case when tgl between '2026-04-01' and '2026-04-30' then isnull(kredit,0) else 0 end) as bln4_credit,
sum(case when tgl between '2026-05-01' and '2026-05-31' then isnull(debet,0) else 0 end) as bln5_debit,
sum(case when tgl between '2026-05-01' and '2026-05-31' then isnull(kredit,0) else 0 end) as bln5_credit,
sum(case when tgl between '2026-06-01' and '2026-06-30' then isnull(debet,0) else 0 end) as bln6_debit,
sum(case when tgl between '2026-06-01' and '2026-06-30' then isnull(kredit,0) else 0 end) as bln6_credit,
sum(case when tgl between '2026-07-01' and '2026-07-31' then isnull(debet,0) else 0 end) as bln7_debit,
sum(case when tgl between '2026-07-01' and '2026-07-31' then isnull(kredit,0) else 0 end) as bln7_credit,
sum(case when tgl between '2026-08-01' and '2026-08-31' then isnull(debet,0) else 0 end) as bln8_debit,
sum(case when tgl between '2026-08-01' and '2026-08-31' then isnull(kredit,0) else 0 end) as bln8_credit,
sum(case when tgl between '2026-09-01' and '2026-09-30' then isnull(debet,0) else 0 end) as bln9_debit,
sum(case when tgl between '2026-09-01' and '2026-09-30' then isnull(kredit,0) else 0 end) as bln9_credit,
sum(case when tgl between '2026-10-01' and '2026-10-31' then isnull(debet,0) else 0 end) as bln10_debit,
sum(case when tgl between '2026-10-01' and '2026-10-31' then isnull(kredit,0) else 0 end) as bln10_credit,
sum(case when tgl between '2026-11-01' and '2026-11-30' then isnull(debet,0) else 0 end) as bln11_debit,
sum(case when tgl between '2026-11-01' and '2026-11-30' then isnull(kredit,0) else 0 end) as bln11_credit,
sum(case when tgl between '2026-12-01' and '2026-12-31' then isnull(debet,0) else 0 end) as bln12_debit,
sum(case when tgl between '2026-12-01' and '2026-12-31' then isnull(kredit,0) else 0 end) as bln12_credit
FROM gl_journal
WHERE tgl between '2026-01-01' and '2026-12-31' and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = 0)
GROUP BY gl_journal.account_id
) mvmt
where a.fincatcode = b.fincatcode and
b.parentcode = c.parentcode and
(a.fincatcode = 'IS1001' or a.fincatcode = 'IS1110' or a.fincatcode = 'IS2010' or a.fincatcode = 'IS2110' or a.fincatcode = 'IS2120' or a.fincatcode = 'IS2130' or a.fincatcode = 'IS2230' or a.fincatcode = 'IS2330') and
((isnull(c.show_hide,'1') = '1') or 1 = 0) and
c.accountcode *= awal.accountcode and
c.accountcode *= mvmt.account_id

) xwrap group by fincatcode,fincatdes,parentcode,parentname,accountcode,flag_dk order by fincatcode,parentcode,accountcode