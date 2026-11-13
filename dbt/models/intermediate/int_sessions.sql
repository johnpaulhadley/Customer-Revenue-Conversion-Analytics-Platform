-- One row per session, with funnel-step flags, channel and the session's orders.
{{ config(partition_by={'field': 'session_date', 'data_type': 'date'}, cluster_by=['channel']) }}

with events as (
    select * from {{ ref('stg_events') }}
    where ga_session_id is not null
),

sessions as (
    select
        session_key,
        any_value(user_pseudo_id)                                     as user_pseudo_id,
        min(event_date)                                               as session_date,
        min(event_ts)                                                 as session_start_ts,
        min(ga_session_number)                                        as ga_session_number,
        any_value(device_category)                                    as device_category,
        any_value(country)                                            as country,
        any_value(first_user_source)                                  as first_user_source,
        any_value(first_user_medium)                                  as first_user_medium,
        -- Session-level source: the first event in the session that carries one.
        array_agg(event_source ignore nulls order by event_ts limit 1)[safe_offset(0)] as session_source,
        array_agg(event_medium ignore nulls order by event_ts limit 1)[safe_offset(0)] as session_medium,
        count(*)                                                      as events,
        countif(event_name = 'page_view')                             as page_views,
        logical_or(is_engaged_event)                                  as is_engaged,
        coalesce(sum(engagement_time_msec), 0) / 1000                 as engagement_seconds,
        logical_or(event_name = 'view_item')                          as reached_view_item,
        logical_or(event_name = 'add_to_cart')                        as reached_add_to_cart,
        logical_or(event_name = 'begin_checkout')                     as reached_begin_checkout,
        logical_or(event_name = 'add_shipping_info')                  as reached_add_shipping,
        logical_or(event_name = 'add_payment_info')                   as reached_add_payment,
        logical_or(event_name = 'purchase')                           as reached_purchase
    from events
    group by session_key
),

orders as (
    select session_key, count(*) as orders, sum(revenue_usd) as revenue_usd
    from {{ ref('int_orders') }}
    group by session_key
)

select
    s.*,
    s.ga_session_number = 1                                              as is_new_user,
    {{ channel_group('s.first_user_source', 's.first_user_medium') }}   as first_user_channel,
    {{ channel_group('s.session_source', 's.session_medium') }}         as session_channel,
    -- Reporting channel: the session's own source and medium. About a quarter of
    -- sessions carry neither (none of them include a purchase); they are kept
    -- as 'Not recorded' rather than given the visitor's first-touch channel,
    -- which would pull down the conversion rate of whichever channel they joined.
    case
        when s.session_source is null and s.session_medium is null then 'Not recorded'
        else {{ channel_group('s.session_source', 's.session_medium') }}
    end                                                                  as channel,
    case when s.country in ('United States', 'India', 'Canada', 'United Kingdom') then s.country
         else 'Rest of world' end                                        as country_group,
    coalesce(o.orders, 0)                                                as orders,
    coalesce(o.revenue_usd, 0)                                           as revenue_usd
from sessions s
left join orders o using (session_key)
