-- Fails if session-level revenue or orders in the mart differ from int_orders.
with mart as (select sum(orders) as orders, sum(revenue_usd) as revenue from {{ ref('fct_daily_sessions') }}),
src  as (select count(*) as orders, sum(revenue_usd) as revenue from {{ ref('int_orders') }}
         where session_key in (select session_key from {{ ref('int_sessions') }}))
select * from mart, src
where mart.orders != src.orders or abs(mart.revenue - src.revenue) > 0.01
