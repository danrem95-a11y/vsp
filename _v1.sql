SELECT account_code, account_type, register_amt, gl_amt, delta, post_cutoff_amt, residual_unexpl
FROM v_fa_recon_gl WHERE site_id='101' ORDER BY account_type, account_code;
