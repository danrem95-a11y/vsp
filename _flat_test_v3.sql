select fincatcode, count(*) as cnt, sum(net) as total
from (
select a.fincatcode, b.parentcode, c.accountcode, c.debetcredit as flag_dk,
  (isnull(awal.debit,0)-isnull(awal.credit,0)+isnull(mvmt.awal2_debit,0)-isnull(mvmt.awal2_credit,0)) as saldo_awal,
  (isnull(mvmt.b1d,0)-isnull(mvmt.b1c,0)+isnull(mvmt.b2d,0)-isnull(mvmt.b2c,0)+isnull(mvmt.b3d,0)-isnull(mvmt.b3c,0)+isnull(mvmt.b4d,0)-isnull(mvmt.b4c,0)+isnull(mvmt.b5d,0)-isnull(mvmt.b5c,0)+isnull(mvmt.b6d,0)-isnull(mvmt.b6c,0)) * (case when c.debetcredit='D' then 1 else -1 end) as net
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
    sum(case when tgl between '2026-06-01' and '2026-06-30' then isnull(kredit,0) else 0 end) as b6c
  from gl_journal
  where tgl between '2026-01-01' and '2026-06-30'
  group by account_id
) mvmt
where a.fincatcode = b.fincatcode and b.parentcode = c.parentcode and a.fincatcode like 'IS%'
and c.accountcode *= awal.accountcode and c.accountcode *= mvmt.account_id
) x
group by fincatcode
order by fincatcode
