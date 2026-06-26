SELECT account_id, AmountDebet-AmountCredit saldo FROM gl_balance WHERE Period='2026-01-01' AND account_id IN ('151-100','158-001','155-001','158-301');
