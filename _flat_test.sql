select fincatcode, sum(net) as total
from (
select a.fincatcode, b.parentcode, c.accountcode, c.debetcredit as flag_dk,
  (isnull(bln1.debit,0)-isnull(bln1.credit,0)+isnull(bln2.debit,0)-isnull(bln2.credit,0)+isnull(bln3.debit,0)-isnull(bln3.credit,0)+isnull(bln4.debit,0)-isnull(bln4.credit,0)+isnull(bln5.debit,0)-isnull(bln5.credit,0)+isnull(bln6.debit,0)-isnull(bln6.credit,0)) * (case when c.debetcredit='D' then 1 else -1 end) as net
from gl_cate a, gl_cate_detail b, gl_acc c,
(select account_id, sum(isnull(debet,0)) debit, sum(isnull(kredit,0)) credit from gl_journal where tgl between '2026-01-01' and '2026-01-31' group by account_id) bln1,
(select account_id, sum(isnull(debet,0)) debit, sum(isnull(kredit,0)) credit from gl_journal where tgl between '2026-02-01' and '2026-02-28' group by account_id) bln2,
(select account_id, sum(isnull(debet,0)) debit, sum(isnull(kredit,0)) credit from gl_journal where tgl between '2026-03-01' and '2026-03-31' group by account_id) bln3,
(select account_id, sum(isnull(debet,0)) debit, sum(isnull(kredit,0)) credit from gl_journal where tgl between '2026-04-01' and '2026-04-30' group by account_id) bln4,
(select account_id, sum(isnull(debet,0)) debit, sum(isnull(kredit,0)) credit from gl_journal where tgl between '2026-05-01' and '2026-05-31' group by account_id) bln5,
(select account_id, sum(isnull(debet,0)) debit, sum(isnull(kredit,0)) credit from gl_journal where tgl between '2026-06-01' and '2026-06-30' group by account_id) bln6
where a.fincatcode = b.fincatcode and b.parentcode = c.parentcode and a.fincatcode like 'IS%'
and c.accountcode *= bln1.account_id and c.accountcode *= bln2.account_id and c.accountcode *= bln3.account_id
and c.accountcode *= bln4.account_id and c.accountcode *= bln5.account_id and c.accountcode *= bln6.account_id
) x
group by fincatcode
order by fincatcode
