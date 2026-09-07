select a.fincatcode, b.parentcode, c.accountcode, c.debetcredit,
  isnull(bln1.debit,0) as b1d, isnull(bln2.debit,0) as b2d
from gl_cate a, gl_cate_detail b, gl_acc c,
(select account_id, sum(isnull(debet,0)) debit, sum(isnull(kredit,0)) credit from gl_journal where tgl between '2026-01-01' and '2026-01-31' group by account_id) bln1,
(select account_id, sum(isnull(debet,0)) debit, sum(isnull(kredit,0)) credit from gl_journal where tgl between '2026-02-01' and '2026-02-28' group by account_id) bln2
where a.fincatcode = b.fincatcode and b.parentcode = c.parentcode and a.fincatcode like 'IS%'
and c.accountcode *= bln1.account_id and c.accountcode *= bln2.account_id
