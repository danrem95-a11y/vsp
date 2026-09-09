select
fincatcode,
sum(bln1_debit) as bln1_debit,
sum(bln2_debit) as bln2_debit,
sum(bln3_debit) as bln3_debit,
sum(bln4_debit) as bln4_debit,
sum(bln5_debit) as bln5_debit,
sum(bln6_debit) as bln6_debit,
sum(bln7_debit) as bln7_debit,
sum(bln8_debit) as bln8_debit,
sum(bln9_debit) as bln9_debit,
sum(bln10_debit) as bln10_debit,
sum(bln11_debit) as bln11_debit,
sum(bln12_debit) as bln12_debit
from
(
select
a.fincatcode,a.fincatdes,b.parentcode,b.parentname,c.accountcode,c.debetcredit as flag_dk,
isnull(awal.debit,0.00) as awal_debit,
isnull(awal.credit,0.00) as awal_credit,
isnull(awal2.debit,0.00) as awal2_debit,
isnull(awal2.credit,0.00) as awal2_credit,
isnull(bln1.debit,0.00) as bln1_debit,
isnull(bln1.credit,0.00) as bln1_credit,
isnull(bln2.debit,0.00) as bln2_debit,
isnull(bln2.credit,0.00) as bln2_credit,
isnull(bln3.debit,0.00) as bln3_debit,
isnull(bln3.credit,0.00) as bln3_credit,
isnull(bln4.debit,0.00) as bln4_debit,
isnull(bln4.credit,0.00) as bln4_credit,
isnull(bln5.debit,0.00) as bln5_debit,
isnull(bln5.credit,0.00) as bln5_credit,
isnull(bln6.debit,0.00) as bln6_debit,
isnull(bln6.credit,0.00) as bln6_credit,
isnull(bln7.debit,0.00) as bln7_debit,
isnull(bln7.credit,0.00) as bln7_credit,
isnull(bln8.debit,0.00) as bln8_debit,
isnull(bln8.credit,0.00) as bln8_credit,
isnull(bln9.debit,0.00) as bln9_debit,
isnull(bln9.credit,0.00) as bln9_credit,
isnull(bln10.debit,0.00) as bln10_debit,
isnull(bln10.credit,0.00) as bln10_credit,
isnull(bln11.debit,0.00) as bln11_debit,
isnull(bln11.credit,0.00) as bln11_credit,
isnull(bln12.debit,0.00) as bln12_debit,
isnull(bln12.credit,0.00) as bln12_credit,
a.fincatdes+' '+b.parentname+' '+c.accountcode as is_find
from
gl_cate a,gl_cate_detail b,gl_acc c,
(
SELECT gl_balance.AccountCode,
cast(sum(AmountDebet) as decimal(18,6)) as debit,
cast(sum(AmountCredit) as decimal(18,6)) as credit
FROM gl_balance
WHERE gl_balance.Period = '2026-01-01'
GROUP BY gl_balance.AccountCode
) awal,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between '2026-01-01' and '2026-01-31' and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = 1)
GROUP BY gl_journal.account_id
) awal2,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between '2026-01-01' and '2026-01-31' and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = 1)
GROUP BY gl_journal.account_id
) bln1,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between '2026-02-01' and '2026-02-28' and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = 1)
GROUP BY gl_journal.account_id
) bln2,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between '2026-03-01' and '2026-03-31' and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = 1)
GROUP BY gl_journal.account_id
) bln3,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between '2026-04-01' and '2026-04-30' and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = 1)
GROUP BY gl_journal.account_id
) bln4,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between '2026-05-01' and '2026-05-31' and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = 1)
GROUP BY gl_journal.account_id
) bln5,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between '2026-06-01' and '2026-06-30' and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = 1)
GROUP BY gl_journal.account_id
) bln6,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between '2026-07-01' and '2026-07-31' and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = 1)
GROUP BY gl_journal.account_id
) bln7,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between '2026-08-01' and '2026-08-31' and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = 1)
GROUP BY gl_journal.account_id
) bln8,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between '2026-09-01' and '2026-09-30' and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = 1)
GROUP BY gl_journal.account_id
) bln9,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between '2026-10-01' and '2026-10-31' and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = 1)
GROUP BY gl_journal.account_id
) bln10,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between '2026-11-01' and '2026-11-30' and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = 1)
GROUP BY gl_journal.account_id
) bln11,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between '2026-12-01' and '2026-12-31' and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = 1)
GROUP BY gl_journal.account_id
) bln12
where a.fincatcode = b.fincatcode and
b.parentcode = c.parentcode and
(a.fincatcode = 'IS1001' or a.fincatcode = 'IS1110' or a.fincatcode = 'IS2010' or a.fincatcode = 'IS2110' or a.fincatcode = 'IS2120' or a.fincatcode = 'IS2130' or a.fincatcode = 'IS2230' or a.fincatcode = 'IS2330') and
((isnull(c.show_hide,'1') = '1') or 1 = 1) and
c.accountcode *= awal.accountcode and
c.accountcode *= awal2.account_id and
c.accountcode *= bln1.account_id and
c.accountcode *= bln2.account_id and
c.accountcode *= bln3.account_id and
c.accountcode *= bln4.account_id and
c.accountcode *= bln5.account_id and
c.accountcode *= bln6.account_id and
c.accountcode *= bln7.account_id and
c.accountcode *= bln8.account_id and
c.accountcode *= bln9.account_id and
c.accountcode *= bln10.account_id and
c.accountcode *= bln11.account_id and
c.accountcode *= bln12.account_id
order by
a.fincatcode,b.parentcode,c.accountcode
) q
group by fincatcode
order by fincatcode