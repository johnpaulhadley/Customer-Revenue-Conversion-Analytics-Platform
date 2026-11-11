-- Daily item-level funnel: how often each product is viewed, added to cart and bought.
-- Purchases come from de-duplicated orders; views and adds from events.
with interactions as (
    select
        e.event_date,
        it.item_name,
        {{ item_category('it.item_category') }}                 as item_category,
        countif(e.event_name = 'view_item')                    as item_views,
        countif(e.event_name = 'add_to_cart')                  as add_to_carts
    from {{ ref('stg_events') }} e, unnest(e.items) as it
    where e.event_name in ('view_item', 'add_to_cart')
      and it.item_name is not null and it.item_name != '(not set)'
    group by 1, 2, 3
),

purchases as (
    select
        o.order_date                                            as event_date,
        it.item_name,
        {{ item_category('it.item_category') }}                 as item_category,
        count(distinct o.transaction_id)                        as orders_with_item,
        sum(it.quantity)                                        as units_sold,
        sum(it.item_revenue_in_usd)                             as item_revenue_usd
    from {{ ref('int_orders') }} o, unnest(o.items) as it
    where it.item_name is not null and it.item_name != '(not set)'
    group by 1, 2, 3
)

select
    coalesce(i.event_date, p.event_date)           as event_date,
    coalesce(i.item_name, p.item_name)             as item_name,
    coalesce(i.item_category, p.item_category)     as item_category,
    coalesce(i.item_views, 0)                      as item_views,
    coalesce(i.add_to_carts, 0)                    as add_to_carts,
    coalesce(p.orders_with_item, 0)                as orders_with_item,
    coalesce(p.units_sold, 0)                      as units_sold,
    coalesce(p.item_revenue_usd, 0)                as item_revenue_usd
from interactions i
full outer join purchases p
  on i.event_date = p.event_date and i.item_name = p.item_name and i.item_category = p.item_category
