{# Pull one event parameter out of the GA4 event_params array. #}
{% macro ga4_param(key, value_type='string_value') -%}
    (select ep.value.{{ value_type }} from unnest(event_params) as ep where ep.key = '{{ key }}')
{%- endmacro %}
