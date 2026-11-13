-- Daily item-level funnel: how often each product is viewed, added to cart and bought.
-- Purchases come from de-duplicated orders; views and adds from events.
--
-- The same product can carry different categories on different events (a view
-- logged under "New", the purchase under "Apparel"). Each product is given one
-- category, the known one it appears under most often, so its views and sales
-- land on the same row.
with item_events as (
    select e.event_date, e.event_name, it.item_name, {{ item_category('it.item_category') }} as item_category
    from {{ ref('stg_events') }} e, unnest(e.items) as it
    where e.event_name in ('view_item', 'add_to_cart')
      and it.item_name is not null and it.item_name != '(not set)'
),

purchase_items as (
    select o.order_date as event_date, o.transaction_id, it.item_name,
           {{ item_category('it.item_category') }} as item_category,
           it.quantity, it.item_revenue_in_usd
    from {{ ref('int_orders') }} o, unnest(o.items) as it
    where it.item_name is not null and it.item_name != '(not set)'
),

category_counts as (
    select item_name, item_category, count(*) as n
    from (select item_name, item_category from item_events
          union all
          select item_name, item_category from purchase_items)
    group by 1, 2
),

product_category as (
    select item_name,
           array_agg(item_category order by item_category = 'Unknown', n desc, item_category limit 1)[offset(0)] as item_category
    from category_counts
    group by 1
),

interactions as (
    select event_date, item_name,
           countif(event_name = 'view_item')   as item_views,
           countif(event_name = 'add_to_cart') as add_to_carts
    from item_events
    group by 1, 2
),

purchases as (
    select event_date, item_name,
           count(distinct transaction_id)  as orders_with_item,
           sum(quantity)                   as units_sold,
           sum(item_revenue_in_usd)        as item_revenue_usd
    from purchase_items
    group by 1, 2
)

select
    coalesce(i.event_date, p.event_date)     as event_date,
    coalesce(i.item_name, p.item_name)       as item_name,
    pc.item_category,
    coalesce(i.item_views, 0)                as item_views,
    coalesce(i.add_to_carts, 0)              as add_to_carts,
    coalesce(p.orders_with_item, 0)          as orders_with_item,
    coalesce(p.units_sold, 0)                as units_sold,
    coalesce(p.item_revenue_usd, 0)          as item_revenue_usd
from interactions i
full outer join purchases p
  on i.event_date = p.event_date and i.item_name = p.item_name
left join product_category pc
  on pc.item_name = coalesce(i.item_name, p.item_name)
