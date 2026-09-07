select fincatcode, sum(net) as total
from (
select a.fincatcode, b.parentcode, c.accountcode, c.debetcredit as flag_dk,
  (allbln.b1d-allbln.b1c+allbln.b2d-allbln.b2c+allbln.b3d-allbln.b3c+allbln.b4d-allbln.b4c+allbln.b5d-allbln.b5c+allbln.b6d-allbln.b6c) * (case when c.debetcredit='D' then 1 else -1 end) as net
from gl_cate a, gl_cate_detail b, gl_acc c,
(
  select account_id,
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
) allbln
where a.fincatcode = b.fincatcode and b.parentcode = c.parentcode and a.fincatcode like 'IS%'
and c.accountcode *= allbln.account_id
) x
group by fincatcode
order by fincatcode
