{# Missing, blank and '(not set)' categories all become 'Unknown'. #}
{% macro item_category(col) -%}
    coalesce(nullif(nullif(trim({{ col }}), ''), '(not set)'), 'Unknown')
{%- endmacro %}
