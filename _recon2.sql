-- (B) GL JOURNAL: voucher FA101202601-06, per akun per voucher
SELECT voucher, account_id,
       CAST(SUM(debet) AS numeric(20,2)) AS dr,
       CAST(SUM(kredit) AS numeric(20,2)) AS cr, modul_id, MAX(posting) post
FROM gl_journal
WHERE site_id='101' AND voucher LIKE 'FA101202060%' OR (site_id='101' AND voucher LIKE 'FA10120260%')
GROUP BY voucher, account_id, modul_id ORDER BY voucher, account_id;
