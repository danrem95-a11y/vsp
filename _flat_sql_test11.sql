select a.fincatcode, b.parentcode, c.accountcode, a.fincatdes+' '+b.parentname+' '+c.accountcode as is_find from
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
