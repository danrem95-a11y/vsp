select
a.fincatcode,a.fincatdes,b.parentcode,b.parentname,c.accountcode,c.accountdes,c.debetcredit as flag_dk,
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
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between :arg_tgl1 and :arg_tgl2 and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)
GROUP BY gl_journal.account_id
) awal2,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between :arg_bln1_awal and :arg_bln1_akhir and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)
GROUP BY gl_journal.account_id
) bln1,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between :arg_bln2_awal and :arg_bln2_akhir and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)
GROUP BY gl_journal.account_id
) bln2,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between :arg_bln3_awal and :arg_bln3_akhir and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)
GROUP BY gl_journal.account_id
) bln3,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between :arg_bln4_awal and :arg_bln4_akhir and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)
GROUP BY gl_journal.account_id
) bln4,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between :arg_bln5_awal and :arg_bln5_akhir and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)
GROUP BY gl_journal.account_id
) bln5,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between :arg_bln6_awal and :arg_bln6_akhir and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)
GROUP BY gl_journal.account_id
) bln6,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between :arg_bln7_awal and :arg_bln7_akhir and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)
GROUP BY gl_journal.account_id
) bln7,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between :arg_bln8_awal and :arg_bln8_akhir and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)
GROUP BY gl_journal.account_id
) bln8,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between :arg_bln9_awal and :arg_bln9_akhir and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)
GROUP BY gl_journal.account_id
) bln9,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between :arg_bln10_awal and :arg_bln10_akhir and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)
GROUP BY gl_journal.account_id
) bln10,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between :arg_bln11_awal and :arg_bln11_akhir and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)
GROUP BY gl_journal.account_id
) bln11,
(
SELECT gl_journal.account_id,
cast(sum(isnull(debet,0)) as decimal(18,6)) as debit,
cast(sum(isnull(kredit,0)) as decimal(18,6)) as credit
FROM gl_journal
WHERE tgl between :arg_bln12_awal and :arg_bln12_akhir and
((isnull(gl_journal.show_hide,'1') = '1') or 1 = :arg_show)
GROUP BY gl_journal.account_id
) bln12
where a.fincatcode = b.fincatcode and
b.parentcode = c.parentcode and
(a.fincatcode = 'IS1001' or a.fincatcode = 'IS1110' or a.fincatcode = 'IS2010' or a.fincatcode = 'IS2110' or a.fincatcode = 'IS2120' or a.fincatcode = 'IS2130' or a.fincatcode = 'IS2230' or a.fincatcode = 'IS2330') and
((isnull(c.show_hide,'1') = '1') or 1 = :arg_show) and
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