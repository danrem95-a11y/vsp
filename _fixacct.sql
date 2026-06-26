UPDATE FA_ASSET a SET asset_account=(SELECT c.asset_account FROM FA_CATEGORY c WHERE c.site_id=a.site_id AND c.category_code=a.category_code),
                      accum_dep_account=(SELECT c.accum_dep_account FROM FA_CATEGORY c WHERE c.site_id=a.site_id AND c.category_code=a.category_code),
                      dep_expense_account=(SELECT c.dep_expense_account FROM FA_CATEGORY c WHERE c.site_id=a.site_id AND c.category_code=a.category_code)
WHERE a.site_id='101';
COMMIT;
