select asset_code,
  cast(acquisition_date as date) acq_date,
  cast(acquisition_cost as numeric(18,2)) cost,
  cast(residual_value as numeric(18,2)) residu,
  useful_life_month,
  cast(accum_dep_beginning as numeric(18,2)) akum_awal,
  cast(book_value_beginning as numeric(18,2)) nbv_awal,
  remaining_life_begin,
  cast(beginning_period as date) begin_period,
  asset_account, accum_dep_account, dep_expense_account
from FA_ASSET
where site_id='101' and asset_code in ('PKT-0180','PKT-0179','PKT-0178')
order by asset_code
