-- =====================================================================
-- FITUR: Tarik Aktiva dari Pembelian  (backend) -- ASA9 / vspnew
-- Sumber : gl_journal baris DEBIT ke akun aktiva (FA_CATEGORY.asset_account)
--          151-100 BGN, 153-001 PKT, 154-001 PBK, 155-001 KDR, 151-001 TNH.
-- Setiap debit = 1 perolehan aktiva -> otomatis dibuat FA_ASSET.
-- Penanda "sudah ditarik" = FA_ASSET.source_ref = voucher||'#'||urut  (idempotent).
-- Trigger tr_fa_asset_defaults tetap jadi jaring pengaman.
-- Jalankan di dbisql (32-bit, dba), aplikasi FA ditutup.
-- =====================================================================

------------------------------------------------------------------ 0) BACKUP
if not exists(select 1 from systable where table_name='fa_bkp_asset_pull_pre') then
   execute immediate 'select * into fa_bkp_asset_pull_pre from FA_ASSET where site_id=''101''';
end if;
commit;

------------------------------------------------------- 1) KOLOM LINK source_ref
if not exists(select 1 from syscolumn c join systable t on t.table_id=c.table_id
              where t.table_name='FA_ASSET' and c.column_name='source_ref') then
   execute immediate 'alter table FA_ASSET add source_ref varchar(30) null';
end if;
commit;

------------------------------------------------ 2) BACKFILL aset 2026 yg sudah ada
-- Cocokkan aset existing (source_ref kosong) ke GL debit aktiva by akun+tgl+harga,
-- supaya tidak ketarik dobel (mis. PKT-0178/0179/0180).
update FA_ASSET a
set source_ref = (select first g.voucher || '#' || cast(g.urut as varchar)
                    from gl_journal g
                   where g.posting='P' and g.site_id=a.site_id and g.account_id=a.asset_account
                     and cast(g.tgl as date)=cast(a.acquisition_date as date)
                     and g.debet=a.acquisition_cost
                   order by g.voucher, g.urut)
where a.site_id='101' and (a.source_ref is null or a.source_ref='')
  and a.acquisition_date >= '2026-01-01'
  and exists(select 1 from gl_journal g
              where g.posting='P' and g.site_id=a.site_id and g.account_id=a.asset_account
                and cast(g.tgl as date)=cast(a.acquisition_date as date) and g.debet=a.acquisition_cost);
commit;

------------------------------- 3) PROC: tarik SATU baris (dipakai tombol Generate interaktif)
if exists(select 1 from sysprocedure where proc_name='sp_fa_pull_one') then drop procedure sp_fa_pull_one end if;
create procedure sp_fa_pull_one(in p_site varchar(4), in p_voucher varchar(50), in p_urut integer,
                                in p_category varchar(6), in p_name varchar(100), in p_useful integer)
begin
   declare v_num integer; declare v_code varchar(15);
   declare v_tgl date; declare v_cost numeric(18,2); declare v_rp numeric(6,2); declare v_resid numeric(18,2);
   declare v_aa varchar(15); declare v_ada varchar(15); declare v_dea varchar(15); declare v_ul integer;
   -- sudah ditarik? stop
   if exists(select 1 from FA_ASSET where site_id=p_site and source_ref=p_voucher||'#'||cast(p_urut as varchar)) then return end if;
   select cast(g.tgl as date), g.debet into v_tgl, v_cost
     from gl_journal g where g.site_id=p_site and g.voucher=p_voucher and g.urut=p_urut;
   select residual_percent, asset_account, accum_dep_account, dep_expense_account, useful_life_month
     into v_rp, v_aa, v_ada, v_dea, v_ul
     from FA_CATEGORY where site_id=p_site and category_code=p_category;
   if p_useful is not null and p_useful > 0 then set v_ul = p_useful end if;   -- override umur dari preview
   select isnull(max(cast(substring(asset_code, locate(asset_code,'-')+1) as integer)),0)+1 into v_num
     from FA_ASSET where site_id=p_site and category_code=p_category;
   set v_code  = p_category || '-' || right('0000' || cast(v_num as varchar), 4);
   set v_resid = round(v_cost * v_rp / 100, 0);
   insert into FA_ASSET(site_id,asset_code,asset_name,category_code,acquisition_date,
      acquisition_cost,residual_value,useful_life_month,accum_dep_beginning,
      book_value_beginning,remaining_life_begin,beginning_period,status,
      asset_account,accum_dep_account,dep_expense_account,source_ref)
   values(p_site,v_code,p_name,p_category,v_tgl,
      v_cost,v_resid,v_ul,0,
      v_cost-v_resid,v_ul,dateadd(day,1-day(v_tgl),v_tgl),'A',
      v_aa,v_ada,v_dea,p_voucher||'#'||cast(p_urut as varchar));
end;

--------------------------- 4) PROC: tarik SEMUA (bulk, utk uji / generate-all)
if exists(select 1 from sysprocedure where proc_name='sp_fa_pull_from_purchase') then drop procedure sp_fa_pull_from_purchase end if;
create procedure sp_fa_pull_from_purchase(in p_from date, in p_to date, in p_site varchar(4))
begin
   for lp as loopcur cursor for
      select g.voucher as c_vch, g.urut as c_urt, cast(g.tgl as date) as c_tgl,
             isnull(g.ket,'(tanpa nama)') as c_ket, cat.category_code as c_cat, cat.useful_life_month as c_ul
        from gl_journal g
        join FA_CATEGORY cat on cat.site_id=g.site_id and cat.asset_account=g.account_id
       where g.posting='P' and g.site_id=p_site and g.debet>0
         and cast(g.tgl as date) between p_from and p_to
         and not exists(select 1 from FA_ASSET a where a.site_id=p_site
                        and a.source_ref = g.voucher || '#' || cast(g.urut as varchar))
       order by cat.category_code, g.tgl, g.voucher, g.urut
   do
      call sp_fa_pull_one(p_site, c_vch, c_urt, c_cat, c_ket, c_ul);
   end for;
end;
commit;

-- =========================== PREVIEW (uji sebelum generate) =====================
-- Query yang dipakai grid preview dw_fa_purchase_preview (ganti tanggal sesuai kebutuhan):
select g.voucher, g.urut, cast(g.tgl as date) tgl, isnull(g.ket,'') nama_aset,
       cat.category_code golongan, cat.useful_life_month umur, cast(g.debet as numeric(18,2)) harga,
       g.voucher || '#' || cast(g.urut as varchar) source_ref
  from gl_journal g
  join FA_CATEGORY cat on cat.site_id=g.site_id and cat.asset_account=g.account_id
 where g.posting='P' and g.site_id='101' and g.debet>0
   and cast(g.tgl as date) between '2026-01-01' and '2026-07-31'
   and not exists(select 1 from FA_ASSET a where a.site_id=g.site_id
                  and a.source_ref = g.voucher || '#' || cast(g.urut as varchar))
 order by cat.category_code, g.tgl;

-- =========================== ROLLBACK (kalau perlu) =============================
-- delete from FA_ASSET where site_id='101' and source_ref is not null and asset_code not in (select asset_code from fa_bkp_asset_pull_pre);
-- update FA_ASSET set source_ref=null where site_id='101';  -- lepas link
-- drop procedure sp_fa_pull_one; drop procedure sp_fa_pull_from_purchase;
