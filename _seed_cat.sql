DELETE FROM FA_CATEGORY WHERE site_id='101';
INSERT INTO FA_CATEGORY (site_id,category_code,category_name,asset_account,accum_dep_account,dep_expense_account,useful_life_month,residual_percent,depreciable_yn) VALUES ('101','BGN','Bangunan','151-100','158-001','412-066',120,0,'Y');
INSERT INTO FA_CATEGORY (site_id,category_code,category_name,asset_account,accum_dep_account,dep_expense_account,useful_life_month,residual_percent,depreciable_yn) VALUES ('101','KDR','Kendaraan','155-001','158-301','412-066',96,0,'Y');
INSERT INTO FA_CATEGORY (site_id,category_code,category_name,asset_account,accum_dep_account,dep_expense_account,useful_life_month,residual_percent,depreciable_yn) VALUES ('101','PKT','Peralatan Kantor','153-001','158-101','412-066',48,0,'Y');
INSERT INTO FA_CATEGORY (site_id,category_code,category_name,asset_account,accum_dep_account,dep_expense_account,useful_life_month,residual_percent,depreciable_yn) VALUES ('101','PBK','Peralatan Bengkel','154-001','158-201','412-066',96,0,'Y');
INSERT INTO FA_CATEGORY (site_id,category_code,category_name,asset_account,accum_dep_account,dep_expense_account,useful_life_month,residual_percent,depreciable_yn) VALUES ('101','TNH','Tanah','151-001',NULL,NULL,0,0,'N');
COMMIT;
