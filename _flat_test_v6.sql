select fincatcode, count(*) as cnt, sum(net) as total
from (
select a.fincatcode, b.parentcode, c.accountcode, c.debetcredit as flag_dk,
  (isnull(awal.debit,0)-isnull(awal.credit,0)+isnull(mvmt.awal2_debit,0)-isnull(mvmt.awal2_credit,0)+isnull(mvmt.b1d,0)-isnull(mvmt.b1c,0)+isnull(mvmt.b2d,0)-isnull(mvmt.b2c,0)+isnull(mvmt.b3d,0)-isnull(mvmt.b3c,0)+isnull(mvmt.b4d,0)-isnull(mvmt.b4c,0)+isnull(mvmt.b5d,0)-isnull(mvmt.b5c,0)+isnull(mvmt.b6d,0)-isnull(mvmt.b6c,0)+isnull(mvmt.b7d,0)-isnull(mvmt.b7c,0)+isnull(mvmt.b8d,0)-isnull(mvmt.b8c,0)+isnull(mvmt.b9d,0)-isnull(mvmt.b9c,0)+isnull(mvmt.b10d,0)-isnull(mvmt.b10c,0)+isnull(mvmt.b11d,0)-isnull(mvmt.b11c,0)+isnull(mvmt.b12d,0)-isnull(mvmt.b12c,0)) * (case when c.debetcredit='D' then 1 else -1 end) as net
from gl_cate a, gl_cate_detail b, gl_acc c,
(SELECT gl_balance.AccountCode, sum(AmountDebet) as debit, sum(AmountCredit) as credit FROM gl_balance WHERE gl_balance.Period = '2026-01-01' GROUP BY gl_balance.AccountCode) awal,
(
  select account_id,
    sum(case when tgl between '2026-01-01' and '2025-12-31' then isnull(debet,0) else 0 end) as awal2_debit,
    sum(case when tgl between '2026-01-01' and '2025-12-31' then isnull(kredit,0) else 0 end) as awal2_credit,
    sum(case when tgl between '2026-01-01' and '2026-01-31' then isnull(debet,0) else 0 end) as b1d,
    sum(case when tgl between '2026-01-01' and '2026-01-31' then isnull(kredit,0) else 0 end) as b1c,
    sum(case when tgl between '2026-02-01' and '2026-02-28' then isnull(debet,0) else 0 end) as b2d,
    sum(case when tgl between '2026-02-01' and '2026-02-28' then isnull(kredit,0) else 0 end) as b2c,
    sum(case when tgl between '2026-03-01' and '2026-03-31' then isnull(debet,0) else 0 end) as b3d,
    sum(case when tgl between '2026-03-01' and '2026-03-31' then isnull(kredit,0) else 0 end) as b3c,
    sum(case when tgl between '2026-04-01' and '2026-04-30' then isnull(debet,0) else 0 end) as b4d,
    sum(case when tgl between '2026-04-01' and '2026-04-30' then isnull(kredit,0) else 0 end) as b4c,
    sum(case when tgl between '2026-05-01' and '2026-05-31' then isnull(debet,0) else 0 end) as b5d,
    sum(case when tgl between '2026-05-01' and '2026-05-31' then isnull(kredit,0) else 0 end) as b5c,
    sum(case when tgl between '2026-06-01' and '2026-06-30' then isnull(debet,0) else 0 end) as b6d,
    sum(case when tgl between '2026-06-01' and '2026-06-30' then isnull(kredit,0) else 0 end) as b6c,
    sum(case when tgl between '2026-07-01' and '2026-07-31' then isnull(debet,0) else 0 end) as b7d,
    sum(case when tgl between '2026-07-01' and '2026-07-31' then isnull(kredit,0) else 0 end) as b7c,
    sum(case when tgl between '2026-08-01' and '2026-08-31' then isnull(debet,0) else 0 end) as b8d,
    sum(case when tgl between '2026-08-01' and '2026-08-31' then isnull(kredit,0) else 0 end) as b8c,
    sum(case when tgl between '2026-09-01' and '2026-09-30' then isnull(debet,0) else 0 end) as b9d,
    sum(case when tgl between '2026-09-01' and '2026-09-30' then isnull(kredit,0) else 0 end) as b9c,
    sum(case when tgl between '2026-10-01' and '2026-10-31' then isnull(debet,0) else 0 end) as b10d,
    sum(case when tgl between '2026-10-01' and '2026-10-31' then isnull(kredit,0) else 0 end) as b10c,
    sum(case when tgl between '2026-11-01' and '2026-11-30' then isnull(debet,0) else 0 end) as b11d,
    sum(case when tgl between '2026-11-01' and '2026-11-30' then isnull(kredit,0) else 0 end) as b11c,
    sum(case when tgl between '2026-12-01' and '2026-12-31' then isnull(debet,0) else 0 end) as b12d,
    sum(case when tgl between '2026-12-01' and '2026-12-31' then isnull(kredit,0) else 0 end) as b12c
  from gl_journal
  where tgl between '2026-01-01' and '2026-12-31'
    and ((isnull(show_hide,'1') = '1') or 1 = 0)
  group by account_id
) mvmt
where a.fincatcode = b.fincatcode and b.parentcode = c.parentcode
and (a.fincatcode = 'IS1001' or a.fincatcode = 'IS1110' or a.fincatcode = 'IS2010' or a.fincatcode = 'IS2110' or a.fincatcode = 'IS2120' or a.fincatcode = 'IS2130' or a.fincatcode = 'IS2230' or a.fincatcode = 'IS2330')
and ((isnull(c.show_hide,'1') = '1') or 1 = 0)
and c.accountcode *= awal.accountcode and c.accountcode *= mvmt.account_id
) x
group by fincatcode
order by fincatcode
