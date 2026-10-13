{#-
  Maps a session's source and medium onto a simplified version of GA4's
  default channel groups. The public sample dataset is obfuscated, so values
  like '<Other>' and '(data deleted)' land in 'Unassigned'.
-#}
{% macro channel_group(source, medium) -%}
    case
        when {{ source }} = '(direct)' and {{ medium }} in ('(none)', '(not set)') then 'Direct'
        when {{ medium }} = 'organic' then 'Organic Search'
        when regexp_contains({{ medium }}, r'^(cpc|ppc|paid.*)$') then 'Paid Search'
        when {{ medium }} in ('display', 'cpm', 'banner') then 'Display'
        when {{ medium }} in ('social', 'social-network', 'social-media', 'sm') then 'Organic Social'
        when {{ medium }} in ('email', 'e-mail', 'e_mail') then 'Email'
        when {{ medium }} = 'affiliate' then 'Affiliates'
        when {{ medium }} = 'referral' then 'Referral'
        else 'Unassigned'
    end
{%- endmacro %}
