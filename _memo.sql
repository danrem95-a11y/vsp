SELECT voucher, urut, account_id, CAST(debet AS numeric(16,2)) dr, CAST(kredit AS numeric(16,2)) kr, posting, modul_id, CAST(tgl AS date) tgl
FROM gl_journal WHERE voucher IN ('1012601MEMO0026','1012602MEMO0020','1012603MEMO0016','1012604MEMO0018')
ORDER BY voucher, urut;
