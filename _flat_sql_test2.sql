select
a.fincatcode,a.fincatdes,b.parentcode,b.parentname,c.accountcode,c.accountdes,
c.debetcredit as flag_dk,
isnull(awal.debit,0.00) as awal_debit,
isnull(awal.credit,0.00) as awal_credit,
isnull(awal2.debit,0.00) as awal2_debit,
isnull(awal2.credit,0.00) as awal2_credit,isnull(allbln.bln1_debit,0.00) as bln1_debit,
isnull(allbln.bln1_credit,0.00) as bln1_credit,
isnull(allbln.bln2_debit,0.00) as bln2_debit,
isnull(allbln.bln2_credit,0.00) as bln2_credit,
isnull(allbln.bln3_debit,0.00) as bln3_debit,
isnull(allbln.bln3_credit,0.00) as bln3_credit,
isnull(allbln.bln4_debit,0.00) as bln4_debit,
isnull(allbln.bln4_credit,0.00) as bln4_credit,
isnull(allbln.bln5_debit,0.00) as bln5_debit,
isnull(allbln.bln5_credit,0.00) as bln5_credit,
isnull(allbln.bln6_debit,0.00) as bln6_debit,
isnull(allbln.bln6_credit,0.00) as bln6_credit,
isnull(allbln.bln7_debit,0.00) as bln7_debit,
isnull(allbln.bln7_credit,0.00) as bln7_credit,
isnull(allbln.bln8_debit,0.00) as bln8_debit,
isnull(allbln.bln8_credit,0.00) as bln8_credit,
isnull(allbln.bln9_debit,0.00) as bln9_debit,
isnull(allbln.bln9_credit,0.00) as bln9_credit,
isnull(allbln.bln10_debit,0.00) as bln10_debit,
isnull(allbln.bln10_credit,0.00) as bln10_credit,
isnull(allbln.bln11_debit,0.00) as bln11_debit,
isnull(allbln.bln11_credit,0.00) as bln11_credit,
isnull(allbln.bln12_debit,0.00) as bln12_debit,
isnull(allbln.bln12_credit,0.00) as bln12_credit,
a.fincatdes+' '+b.parentname+' '+c.accountdes+' '+c.accountcode as is_find
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
	   			SELECT 	gl_journal.account_id,
							sum(isnull(debet,0)) as debit,
							sum(isnull(kredit,0)) as credit
		 		FROM 	gl_journal
				WHERE 	tgl between '2026-01-01' and '2026-01-01' and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = 0)
				GROUP BY gl_journal.account_id
				) awal2,
(
SELECT gl_journal.account_id,sum(case when tgl between '2026-01-01' and '2026-01-31' then isnull(debet,0) else 0 end) as bln1_debit,
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
) allbln
where a.fincatcode = b.fincatcode and
b.parentcode = c.parentcode and
(a.fincatcode = 'IS1001' or a.fincatcode = 'IS1110' or a.fincatcode = 'IS2010' or a.fincatcode = 'IS2110' or a.fincatcode = 'IS2120' or a.fincatcode = 'IS2130' or a.fincatcode = 'IS2230' or a.fincatcode = 'IS2330') and
((isnull(c.show_hide,'1') = '1') or 1 = 0) and
c.accountcode *= awal.accountcode and
c.accountcode *= awal2.account_id and
c.accountcode *= allbln.account_id
order by
a.fincatcode,b.parentcode,c.accountcode