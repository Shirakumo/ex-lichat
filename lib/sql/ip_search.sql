SELECT * FROM "lichat-ip-log"
WHERE (:ip::text IS NULL OR "ip" ~ :ip)
  AND (:from::text IS NULL OR "from" ~ :from)
  AND (:action::int IS NULL OR "action" ~ :action)
ORDER BY "clock" DESC
LIMIT :limit
OFFSET :offset;
