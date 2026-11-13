-- Daily session and funnel counts by segment. All measures are additive, so
-- Tableau can compute any rate (conversion, cart abandonment, step drop-off)
-- for any combination of filters.
--
-- Two kinds of funnel count:
--   *_sessions   open funnel: sessions that reached the step at all. GA4 does not
--                force steps into order, so a later step can exceed an earlier one.
--   funnel_*     closed funnel: sessions that reached the step and every earlier
--                one, so each step is a subset of the last. Use these for drop-off.
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
    countif(reached_add_to_cart and reached_purchase) as cart_purchase_sessions,
    countif(reached_view_item)                 as funnel_view_item,
    countif(reached_view_item and reached_add_to_cart) as funnel_add_to_cart,
    countif(reached_view_item and reached_add_to_cart and reached_begin_checkout) as funnel_begin_checkout,
    countif(reached_view_item and reached_add_to_cart and reached_begin_checkout
            and reached_add_shipping)          as funnel_add_shipping,
    countif(reached_view_item and reached_add_to_cart and reached_begin_checkout
            and reached_add_shipping and reached_add_payment) as funnel_add_payment,
    countif(reached_view_item and reached_add_to_cart and reached_begin_checkout
            and reached_add_shipping and reached_add_payment and reached_purchase) as funnel_purchase,
    sum(orders)                                as orders,
    sum(revenue_usd)                           as revenue_usd
from {{ ref('int_sessions') }}
group by 1, 2, 3, 4, 5, 6
