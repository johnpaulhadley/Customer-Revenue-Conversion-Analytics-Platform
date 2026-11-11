-- One row per user, with order value and a simple RFM-style segment for buyers.
-- The data covers only three months, so segments use order count and days since
-- the last order rather than quintiles of frequency (most buyers order once).
with users as (
    select
        user_pseudo_id,
        min(session_date)                        as first_seen_date,
        array_agg(first_user_channel order by session_start_ts limit 1)[offset(0)] as first_user_channel,
        array_agg(device_category order by session_start_ts limit 1)[offset(0)]    as first_device_category,
        count(*)                                 as sessions
    from {{ ref('int_sessions') }}
    group by 1
),

buyers as (
    select
        user_pseudo_id,
        count(*)                                 as orders,
        sum(revenue_usd)                         as revenue_usd,
        min(order_date)                          as first_order_date,
        max(order_date)                          as last_order_date
    from {{ ref('int_orders') }}
    group by 1
)

select
    u.*,
    coalesce(b.orders, 0)                                              as orders,
    coalesce(b.revenue_usd, 0)                                         as revenue_usd,
    b.first_order_date,
    b.last_order_date,
    date_diff(date '{{ var("end_date") }}', b.last_order_date, day)    as days_since_last_order,
    coalesce(b.orders, 0) > 1                                          as is_repeat_buyer,
    if(b.user_pseudo_id is null, null,
       ntile(5) over (partition by b.user_pseudo_id is not null order by b.revenue_usd)) as monetary_score,
    case
        when b.user_pseudo_id is null then 'Non-buyer'
        when b.orders > 1 and date_diff(date '{{ var("end_date") }}', b.last_order_date, day) <= 30 then 'Repeat, recent'
        when b.orders > 1 then 'Repeat, lapsing'
        when date_diff(date '{{ var("end_date") }}', b.last_order_date, day) <= 30 then 'One-time, recent'
        else 'One-time, lapsed'
    end                                                                as customer_segment
from users u
left join buyers b using (user_pseudo_id)
