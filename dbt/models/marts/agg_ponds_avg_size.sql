{{ config(materialized='table') }}

select
  avg(size)        as avg_size,
  count(*)         as pond_count
from {{ ref('stg_ponds') }}
