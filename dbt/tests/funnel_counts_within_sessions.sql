-- Fails if any open-funnel count exceeds the session count for its row, or if
-- any closed-funnel step exceeds the step before it.
select * from {{ ref('fct_daily_sessions') }}
where greatest(view_item_sessions, add_to_cart_sessions, begin_checkout_sessions,
               add_shipping_sessions, add_payment_sessions, purchase_sessions, engaged_sessions) > sessions
   or funnel_view_item > sessions
   or funnel_add_to_cart > funnel_view_item
   or funnel_begin_checkout > funnel_add_to_cart
   or funnel_add_shipping > funnel_begin_checkout
   or funnel_add_payment > funnel_add_shipping
   or funnel_purchase > funnel_add_payment
   or cart_purchase_sessions > least(add_to_cart_sessions, purchase_sessions)
