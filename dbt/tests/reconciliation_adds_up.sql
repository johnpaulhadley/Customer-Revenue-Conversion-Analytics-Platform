-- Fails if counted orders, duplicates and unidentified purchases do not add up
-- to raw purchase revenue on any day.
select * from {{ ref('int_purchase_reconciliation') }}
where abs(raw_purchase_revenue_usd
          - order_revenue_usd - duplicate_revenue_usd - unidentified_revenue_usd) > 0.01
