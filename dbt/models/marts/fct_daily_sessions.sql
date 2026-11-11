-- Daily session and funnel counts by segment. All measures are additive, so
-- Tableau can compute any rate (conversion, cart abandonment, step drop-off)
-- for any combination of filters.
select
    session_date,
    channel,
    first_user_channel,
    device_category,
    if(is_new_user, 'New', 'Returning')        as user_type,
    country_group,
    count(*)                                   as sessions,
    countif(is_engaged)                        as engaged_sessions,
    countif(reached_view_item)                 as view_item_sessions,
    countif(reached_add_to_cart)               as add_to_cart_sessions,
    countif(reached_begin_checkout)            as begin_checkout_sessions,
    countif(reached_add_shipping)              as add_shipping_sessions,
    countif(reached_add_payment)               as add_payment_sessions,
    countif(reached_purchase)                  as purchase_sessions,
    sum(orders)                                as orders,
    sum(revenue_usd)                           as revenue_usd
from {{ ref('int_sessions') }}
group by 1, 2, 3, 4, 5, 6
