-- One row per GA4 event, flattened to the fields the analysis needs.
--
-- Partitioned by event_date and loaded incrementally. Each run reads only the
-- daily source tables it needs: the date window is resolved at compile time so
-- BigQuery can skip the other daily tables entirely (a subquery in the
-- _table_suffix filter would scan every day).
--
-- Reloaded days replace their partitions through BigQuery copy jobs rather than
-- a MERGE statement. Copy jobs are free and are not DML, so incremental runs
-- also work in the BigQuery sandbox.
{{ config(
    materialized='incremental',
    incremental_strategy='insert_overwrite',
    partition_by={'field': 'event_date', 'data_type': 'date', 'granularity': 'day', 'copy_partitions': true},
    cluster_by=['event_name', 'user_pseudo_id'],
    on_schema_change='append_new_columns'
) }}

{%- set start = var('start_date') -%}
{%- set end = var('end_date') -%}
{%- if var('backfill_start') and var('backfill_end') -%}
    {%- set start = var('backfill_start') -%}
    {%- set end = var('backfill_end') -%}
{%- elif is_incremental() and execute -%}
    {%- set latest = run_query(
        "select format_date('%Y-%m-%d', date_sub(max(event_date), interval "
        ~ var('lookback_days') ~ " day)) from " ~ this
    ).columns[0].values()[0] -%}
    {%- if latest -%}{%- set start = latest -%}{%- endif -%}
{%- endif %}

select
    parse_date('%Y%m%d', event_date)                                   as event_date,
    timestamp_micros(event_timestamp)                                  as event_ts,
    event_name,
    user_pseudo_id,
    {{ ga4_param('ga_session_id', 'int_value') }}                      as ga_session_id,
    concat(user_pseudo_id, '-', cast({{ ga4_param('ga_session_id', 'int_value') }} as string)) as session_key,
    {{ ga4_param('ga_session_number', 'int_value') }}                  as ga_session_number,
    coalesce({{ ga4_param('session_engaged') }},
             cast({{ ga4_param('session_engaged', 'int_value') }} as string)) = '1' as is_engaged_event,
    {{ ga4_param('engagement_time_msec', 'int_value') }}               as engagement_time_msec,
    {{ ga4_param('page_location') }}                                   as page_location,
    {{ ga4_param('source') }}                                          as event_source,
    {{ ga4_param('medium') }}                                          as event_medium,
    {{ ga4_param('campaign') }}                                        as event_campaign,
    traffic_source.source                                              as first_user_source,
    traffic_source.medium                                              as first_user_medium,
    traffic_source.name                                                as first_user_campaign,
    device.category                                                    as device_category,
    device.operating_system                                            as operating_system,
    geo.country                                                        as country,
    ecommerce.transaction_id                                           as transaction_id,
    ecommerce.purchase_revenue_in_usd                                  as purchase_revenue_usd,
    ecommerce.total_item_quantity                                      as total_item_quantity,
    -- Items are only kept on the events the product analysis uses.
    if(event_name in ('view_item', 'add_to_cart', 'begin_checkout', 'purchase'),
       array(select as struct
                 it.item_id, it.item_name, it.item_category,
                 it.price_in_usd, it.quantity, it.item_revenue_in_usd
             from unnest(items) as it),
       []) as items
from {{ source('ga4', 'events') }}
where _table_suffix between '{{ start | replace("-", "") }}' and '{{ end | replace("-", "") }}'
