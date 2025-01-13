-- name: create_ip_log_table
CREATE TABLE IF NOT EXISTS "lichat-ip-log"(
  "id" INT GENERATED ALWAYS AS IDENTITY,
  "ip" VARCHAR(39) NOT NULL,
  "clock" BIGINT NOT NULL,
  "action" INT NOT NULL,
  "from" VARCHAR(32),
  "target" VARCHAR(39),
  PRIMARY KEY("id")
);

-- name: ip_log
INSERT INTO "lichat-ip-log"("ip", "clock", "action", "from", "target")
VALUES (:ip,
        :clock,
        :action,
        :from,
        :target);

-- name: ip_search
SELECT * FROM "lichat-ip-log"
 WHERE (:ip::text IS NULL OR "ip" = :ip)
   AND (:from::text IS NULL OR "from" = :from)
   AND (:action::int IS NULL OR "action" = :action)
 ORDER BY "clock" DESC
 LIMIT :limit
OFFSET :offset;
