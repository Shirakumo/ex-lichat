-- name: create_ip_log_table
CREATE TABLE IF NOT EXISTS "lichat-ip-log"(
  "id" INT GENERATED ALWAYS AS IDENTITY,
  "ip" VARCHAR(39) NOT NULL,
  "clock" BIGINT NOT NULL,
  "action" INT NOT NULL,
  "user" INT,
  "target" VARCHAR(39),
  PRIMARY KEY("id"),
  CONSTRAINT "user" FOREIGN KEY("user") REFERENCES "lichat-users"("id") ON DELETE SET NULL
);

-- name: create_ip_log_ip_index
CREATE INDEX IF NOT EXISTS "lichat-ip-log.ip" ON "lichat-ip-log"("ip");

-- name: create_ip_log_user_index
CREATE INDEX IF NOT EXISTS "lichat-ip-log.user" ON "lichat-ip-log"("user");

-- name: create_ip_log_action_index
CREATE INDEX IF NOT EXISTS "lichat-ip-log.action" ON "lichat-ip-log"("action");

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
