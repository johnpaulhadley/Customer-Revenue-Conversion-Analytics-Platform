-- One row per real order. A transaction ID sometimes appears on several purchase
-- events; the first event is kept. Purchases without a usable transaction ID
-- cannot be de-duplicated and are excluded here (see int_purchase_reconciliation).
{{ config(partition_by={'field': 'order_date', 'data_type': 'date'}) }}

select
    transaction_id,
    event_date                as order_date,
    event_ts                  as order_ts,
    user_pseudo_id,
    session_key,
    purchase_revenue_usd      as revenue_usd,
    total_item_quantity       as item_quantity,
    items
from {{ ref('stg_events') }}
where event_name = 'purchase'
  and transaction_id is not null
  and transaction_id != '(not set)'
qualify row_number() over (partition by transaction_id order by event_ts, session_key) = 1
