-- Fails if int_orders holds a different number of orders than the daily
-- reconciliation counts, or if int_sessions is empty. Both reconcile to
-- staging independently, so an empty or partly lost table shows up here.
with checks as (
    select 'int_orders vs reconciliation' as check_name,
           (select count(*) from {{ ref('int_orders') }}) as actual,
           (select sum(orders) from {{ ref('int_purchase_reconciliation') }}) as expected
    union all
    select 'int_sessions has rows',
           least((select count(*) from {{ ref('int_sessions') }}), 1),
           1
)
select * from checks where actual != expected
