-- name: create_connections_table
CREATE TABLE IF NOT EXISTS "lichat-connections"(
  "id" INT GENERATED ALWAYS AS IDENTITY,
  "ip" VARCHAR(39) NOT NULL,
  "ssl" BOOLEAN NOT NULL,
  "user" INT,
  "last-update" BIGINT NOT NULL,
  "started-on" BIGINT NOT NULL,
  PRIMARY KEY("id"),
  CONSTRAINT "user" FOREIGN KEY("user") REFERENCES "lichat-users"("id") ON DELETE CASCADE
);

-- name: create_connections_ip_index
CREATE INDEX IF NOT EXISTS "lichat-connections.ip" ON "lichat-connections"("ip");

-- name: create_connections_user_index
CREATE INDEX IF NOT EXISTS "lichat-connections.user" ON "lichat-connections"("user");

-- name: create_connection
INSERT INTO "lichat-connections"("ip", "ssl", "user", "last-update", "started-on")
VALUES(:ip,
       :ssl,
       CASE :user WHEN NULL THEN NULL
       ELSE (SELECT "id" FROM "lichat-users" WHERE "name" = :user)
       END,
       :last_update,
       :started_on)
       RETURNING ("id");

-- name: delete_connection
DELETE FROM "lichat-connections" 
 WHERE "id" = :id;

-- name: associate_connection
UPDATE "lichat-connections"
   SET "user" = (SELECT "id" FROM "lichat-users" WHERE "name" = :user)
 WHERE "id" = :id;

-- name: update_connection
UPDATE "lichat-connections"
   SET "last-update" = :last_update
 WHERE "id" = :id;

-- name: ip_connections
SELECT * FROM "lichat-connections"
 WHERE "ip" = :ip
 ORDER BY "started-on" DESC;

-- name: user_connections
SELECT * FROM "lichat-connections"
 WHERE "user" IN (SELECT "id" FROM (:find_user))
 ORDER BY "started-on" DESC;

-- name: clear_connections
TRUNCATE TABLE "lichat-connections";
