-- Data-quality mart: how raw purchase revenue splits into counted orders,
-- duplicates and unidentified purchases, by day.
select * from {{ ref('int_purchase_reconciliation') }}
