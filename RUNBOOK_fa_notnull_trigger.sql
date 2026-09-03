-- =====================================================================
-- FIX PERMANEN entry Aktiva manual (Master Aktiva Tetap) -- ASA9.
-- Dua bug dari satu akar: form entry tidak mengisi field TURUNAN, sehingga:
--   1) Save error "residual_value cannot be NULL" (kolom numerik NOT NULL dikirim NULL)
--   2) Penyusutan = 0 (beginning_period & akun kosong -> engine skip & tak bisa posting)
-- Trigger mengisi otomatis saat insert/update JIKA field kosong (tidak menimpa nilai
-- yang sudah ada -> aman untuk aset migrasi/rebuild). Reversible: DROP TRIGGER.
-- Jalankan di dbisql (32-bit, dba). Tutup dulu form Master Aktiva Tetap (lock DDL).
-- =====================================================================

-- (idempotent) hapus trigger lama bila ada
if exists(select 1 from systrigger where trigger_name='tr_fa_asset_defaults') then
   drop trigger tr_fa_asset_defaults
end if;

create trigger tr_fa_asset_defaults
before insert, update on FA_ASSET
referencing new as n
for each row
begin
  -- 1) kolom numerik NOT NULL: NULL -> 0  (perbaiki error Save)
  if n.residual_value      is null then set n.residual_value      = 0 end if;
  if n.acquisition_cost     is null then set n.acquisition_cost     = 0 end if;
  if n.useful_life_month    is null then set n.useful_life_month    = 0 end if;
  if n.accum_dep_beginning  is null then set n.accum_dep_beginning  = 0 end if;

  -- 2) sisa umur awal default = umur ekonomis (aset baru) bila 0/null
  if n.remaining_life_begin is null or n.remaining_life_begin = 0 then
     set n.remaining_life_begin = n.useful_life_month;
  end if;

  -- 3) NBV awal default = harga perolehan - residu bila 0/null
  if n.book_value_beginning is null or n.book_value_beginning = 0 then
     set n.book_value_beginning = n.acquisition_cost - n.residual_value;
  end if;

  -- 4) periode awal penyusutan = AWAL BULAN tgl perolehan bila kosong
  --    (beli di bulan ybs, awal/akhir bulan -> disusutkan bulan itu juga)
  if n.beginning_period is null and n.acquisition_date is not null then
     set n.beginning_period = dateadd(day, 1 - day(n.acquisition_date), date(n.acquisition_date));
  end if;

  -- 5) akun (aktiva/akumulasi/beban) dari kategori bila kosong
  if n.asset_account is null or n.asset_account = '' then
     set n.asset_account = (select asset_account from FA_CATEGORY
                            where site_id = n.site_id and category_code = n.category_code);
  end if;
  if n.accum_dep_account is null or n.accum_dep_account = '' then
     set n.accum_dep_account = (select accum_dep_account from FA_CATEGORY
                               where site_id = n.site_id and category_code = n.category_code);
  end if;
  if n.dep_expense_account is null or n.dep_expense_account = '' then
     set n.dep_expense_account = (select dep_expense_account from FA_CATEGORY
                                 where site_id = n.site_id and category_code = n.category_code);
  end if
end;

-- verifikasi trigger terpasang:
select trigger_name, trigger_time, event from systrigger where trigger_name='tr_fa_asset_defaults';
