-- Daily product table: purchases from de-duplicated orders, plus view and
-- add-to-cart counts from events.
--
-- Use the purchase columns for product analysis. In this sample, view_item and
-- add_to_cart events carry long item lists (about 36 and 44 products per
-- session that viewed or added to cart), so item_views and add_to_carts count
-- appearances in those lists rather than individual product actions.
--
-- Each product gets one merchandise group. Purchase events are used where the
-- product sold, since their categories are cleaner, and product types are
-- preferred over collections such as Sale or New.
with item_events as (
    select e.event_date, e.event_name, it.item_name, it.item_category
    from {{ ref('stg_events') }} e, unnest(e.items) as it
    where e.event_name in ('view_item', 'add_to_cart')
      and it.item_name is not null and it.item_name != '(not set)'
),

purchase_items as (
    select o.order_date as event_date, o.transaction_id, it.item_name, it.item_category,
           it.quantity, it.item_revenue_in_usd
    from {{ ref('int_orders') }} o, unnest(o.items) as it
    where it.item_name is not null and it.item_name != '(not set)'
),

group_counts as (
    select item_name, {{ merch_group('item_category') }} as merch_group, from_purchase, count(*) as n
    from (select item_name, item_category, false as from_purchase from item_events
          union all
          select item_name, item_category, true from purchase_items)
    group by 1, 2, 3
),

product_group as (
    select item_name,
           array_agg(merch_group order by
                         merch_group in ('Unknown', 'Other'),
                         starts_with(merch_group, 'Collection'),
                         from_purchase desc,
                         n desc,
                         merch_group
                     limit 1)[offset(0)] as merch_group
    from group_counts
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
    pg.merch_group                           as item_category,
    coalesce(i.item_views, 0)                as item_views,
    coalesce(i.add_to_carts, 0)              as add_to_carts,
    coalesce(p.orders_with_item, 0)          as orders_with_item,
    coalesce(p.units_sold, 0)                as units_sold,
    coalesce(p.item_revenue_usd, 0)          as item_revenue_usd
from interactions i
full outer join purchases p
  on i.event_date = p.event_date and i.item_name = p.item_name
left join product_group pg
  on pg.item_name = coalesce(i.item_name, p.item_name)
