SELECT * FROM "lichat-history-channels" as A
LEFT JOIN "lichat-history" ON A."id" = "channel" 
WHERE A."name" = :channel
  AND (:from::text IS NULL OR "from" ~ :from)
  AND (:time_max::int IS NULL OR "clock" <= :time_max)
  AND (:time_min::int IS NULL OR "clock" >= :time_min)
  AND (:text::text IS NULL OR "text" ~ :text)
ORDER BY "clock" ASC
LIMIT :limit
OFFSET :offset;
