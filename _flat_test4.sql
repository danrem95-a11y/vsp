select a.fincatcode, b.parentcode, c.accountcode,
  (isnull(bln1.debit,0)-isnull(bln1.credit,0)) * if(c.debetcredit='D',1,-1) as net
from gl_cate a, gl_cate_detail b, gl_acc c,
(select account_id, sum(isnull(debet,0)) debit, sum(isnull(kredit,0)) credit from gl_journal where tgl between '2026-01-01' and '2026-01-31' group by account_id) bln1
where a.fincatcode = b.fincatcode and b.parentcode = c.parentcode and a.fincatcode like 'IS%'
and c.accountcode *= bln1.account_id
