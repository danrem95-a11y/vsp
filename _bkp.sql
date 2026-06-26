SELECT * INTO gl_journal_fa_rebase_backup FROM gl_journal
WHERE voucher IN ('1012601MEMO0026','1012602MEMO0020','1012603MEMO0016','1012604MEMO0018');
COMMIT;
SELECT count(*) backup_rows, CAST(sum(debet) AS numeric(18,2)) total_dr FROM gl_journal_fa_rebase_backup;
