-- name: create_history_table
CREATE TABLE IF NOT EXISTS "lichat-history"(
  "id" VARCHAR(32) NOT NULL,
  "user" INT NOT NULL,
  "bridge" VARCHAR(32),
  "clock" BIGINT NOT NULL,
  "channel" INT NOT NULL,
  "text" TEXT NOT NULL,
  "rich" TEXT,
  "markup" VARCHAR(16),
  CONSTRAINT "channel" FOREIGN KEY("channel") REFERENCES "lichat-channels"("id") ON DELETE CASCADE,
  CONSTRAINT "user" FOREIGN KEY("user") REFERENCES "lichat-users"("id") ON DELETE CASCADE
);

-- name: create_history_text_index
CREATE INDEX IF NOT EXISTS "lichat-history.text" ON "lichat-history"("text");

-- name: create_history_user_index
CREATE INDEX IF NOT EXISTS "lichat-history.user" ON "lichat-history"("user");

-- name: create_history_channel_index
CREATE INDEX IF NOT EXISTS "lichat-history.channel" ON "lichat-history"("channel");

-- name: history_record
INSERT INTO "lichat-history"("id", "user", "bridge", "clock", "channel", "text", "rich", "markup")
VALUES (:id,
        (SELECT "id" FROM "lichat-users" WHERE "name" = :from),
        :bridge,
        :clock,
        (SELECT "id" FROM "lichat-channels" WHERE "name" = :channel),
        :text,
        :rich,
        :markup)
       RETURNING ("id");

-- name: history_clear
DELETE FROM "lichat-history" AS H
WHERE "channel" IN (SELECT "id" FROM (:find_channel))

-- name: history_backlog
SELECT * FROM (
  SELECT H.*, U."name" AS "from"
    FROM "lichat-history" AS H
         LEFT JOIN "lichat-channels" AS C ON C."id" = H."channel"
         LEFT JOIN "lichat-users" AS U ON U."id" = H."user"
   WHERE C."name" = :channel
     AND :since <= H."clock"
   ORDER BY H."clock" DESC
   LIMIT :limit
) AS B ORDER BY B."clock" ASC;

-- name: history_search
SELECT H.*, U."name" AS "from"
  FROM "lichat-history" AS H
       LEFT JOIN "lichat-channels" AS C ON C."id" = H."channel"
       LEFT JOIN "lichat-users" AS U ON U."id" = H."user"
 WHERE C."name" = :channel
   AND (:from::text IS NULL OR U."name" ~ :from)
   AND (:time_max::int IS NULL OR H."clock" <= :time_max)
   AND (:time_min::int IS NULL OR H."clock" >= :time_min)
   AND (:text::text IS NULL OR H."text" ~ :text)
 ORDER BY H."clock" ASC
 LIMIT :limit
OFFSET :offset;
