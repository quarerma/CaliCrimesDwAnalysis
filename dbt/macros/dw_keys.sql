-- Surrogate-key macros.
--
-- Hash keys must be computed IDENTICALLY in the dimension that defines them and
-- in every fact that references them -- that is what lets a fact resolve its FK
-- without joining the dimension. Written out by hand in two files, the two copies
-- WILL eventually drift: change a delimiter, a column order or a coalesce default
-- in one and not the other, and every FK silently stops matching. The
-- relationships tests would catch it, but only after the fact.
--
-- Defining each key once here makes that class of bug unrepresentable.

{# Composite key over the administrative geography.
   The '|' delimiter is load-bearing: without it ('12','3') and ('1','23') both
   flatten to '123' and collide. coalesce is load-bearing too: in SQL
   anything || NULL is NULL, so one missing ward would null out the whole key. #}
{% macro location_key(beat, district, ward, community_area) %}
    md5(
        coalesce({{ beat }}, '')                   || '|' ||
        coalesce({{ district }}, '')               || '|' ||
        coalesce({{ ward }}::text, '')             || '|' ||
        coalesce({{ community_area }}::text, '')
    )
{% endmacro %}


{# Location type. NULL location_description routes to the unknown member rather
   than producing a NULL FK, so facts still reconcile to fct_crimes. #}
{% macro location_type_key(location_description) %}
    coalesce(md5({{ location_description }}), md5('__UNKNOWN__'))
{% endmacro %}
