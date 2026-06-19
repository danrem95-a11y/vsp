SELECT AccountCode,
  CAST(AmountDebet AS numeric(20,2)) dr,
  CAST(AmountCredit AS numeric(20,2)) cr,
  CAST(AmountCredit-AmountDebet AS numeric(20,2)) saldo_kredit
FROM gl_balance
WHERE Period='2026-01-01' AND site_id='101'
  AND AccountCode IN ('151-001','151-100','153-001','154-001','155-001',
                      '158-001','158-101','158-201','158-301')
ORDER BY AccountCode;
