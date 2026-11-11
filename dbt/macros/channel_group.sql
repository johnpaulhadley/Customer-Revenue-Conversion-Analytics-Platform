{# Map source and medium to a channel. Obfuscated values become 'Unknown'. #}
{% macro channel_group(source, medium) -%}
    case
        when {{ medium }} is null or {{ medium }} in ('<Other>', '(data deleted)')
             or {{ source }} in ('<Other>', '(data deleted)') and {{ medium }} not in ('organic', 'cpc', 'referral')
            then 'Unknown'
        when {{ source }} = '(direct)' and {{ medium }} in ('(none)', '(not set)') then 'Direct'
        when {{ medium }} = 'organic' then 'Organic Search'
        when {{ medium }} in ('cpc', 'ppc', 'paidsearch') then 'Paid Search'
        when {{ medium }} = 'referral' then 'Referral'
        when {{ medium }} = 'email' then 'Email'
        else 'Other'
    end
{%- endmacro %}
