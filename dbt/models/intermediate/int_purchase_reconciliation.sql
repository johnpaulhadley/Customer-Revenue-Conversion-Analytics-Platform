-- Daily split of raw purchase-event revenue into: counted orders, duplicate
-- events for orders already counted, and purchases with no usable transaction ID.
with purchases as (
    select
        event_date,
        transaction_id,
        purchase_revenue_usd,
        case
            when transaction_id is null or transaction_id = '(not set)' then 'unidentified'
            when row_number() over (partition by transaction_id order by event_ts, session_key) = 1 then 'order'
            else 'duplicate'
        end as purchase_type
    from {{ ref('stg_events') }}
    where event_name = 'purchase'
)

select
    event_date,
    count(*)                                                              as purchase_events,
    coalesce(sum(purchase_revenue_usd), 0)                                as raw_purchase_revenue_usd,
    countif(purchase_type = 'order')                                      as orders,
    coalesce(sum(if(purchase_type = 'order', purchase_revenue_usd, 0)), 0)        as order_revenue_usd,
    countif(purchase_type = 'duplicate')                                  as duplicate_events,
    coalesce(sum(if(purchase_type = 'duplicate', purchase_revenue_usd, 0)), 0)    as duplicate_revenue_usd,
    countif(purchase_type = 'unidentified')                               as unidentified_events,
    coalesce(sum(if(purchase_type = 'unidentified', purchase_revenue_usd, 0)), 0) as unidentified_revenue_usd
from purchases
group by event_date
