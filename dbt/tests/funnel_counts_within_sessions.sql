-- Fails if any funnel count exceeds the session count for its row.
select * from {{ ref('fct_daily_sessions') }}
where greatest(view_item_sessions, add_to_cart_sessions, begin_checkout_sessions,
               add_shipping_sessions, add_payment_sessions, purchase_sessions, engaged_sessions) > sessions
