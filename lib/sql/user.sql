-- name: create_users_table
CREATE TABLE IF NOT EXISTS "lichat-users"(
  "id" INT GENERATED ALWAYS AS IDENTITY,
  "name" VARCHAR(32),
  "registered" BOOLEAN NOT NULL,
  "created-on" BIGINT NOT NULL,
  "last-connected" BIGINT NOT NULL,
  PRIMARY KEY("id"),
  UNIQUE("name")
);

-- name: create_user
INSERT INTO "lichat-users"("name", "registered", "created-on", "last-connected")
VALUES(:name, :registered, :created_on, 0)
       ON CONFLICT("name") DO UPDATE 
       SET "created-on" = :created_on;

-- name: delete_user
DELETE FROM "lichat-users" 
 WHERE "name" = :name;

-- name: find_user
SELECT * FROM "lichat-users"
 WHERE "name" = :name;

-- name: list_users
SELECT * FROM "lichat-users"
 ORDER BY "name" ASC;

-- name: update_user
UPDATE "lichat-users"
   SET "last-connected" = :last_connected
 WHERE "name" = :name;
