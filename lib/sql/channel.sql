-- name: create_channels_table
CREATE TABLE IF NOT EXISTS "lichat-channels"(
  "id" INT GENERATED ALWAYS AS IDENTITY,
  "name" VARCHAR(32) NOT NULL,
  "registrant" INT NOT NULL,
  "lifetime" INT NOT NULL,
  "expiry" INT NOT NULL,
  PRIMARY KEY("id"),
  UNIQUE("name")
);

-- name: create_channel_members_table
CREATE TABLE IF NOT EXISTS "lichat-channel-members"(
  "channel" INT NOT NULL,
  "user" INT NOT NULL,
  PRIMARY KEY("channel", "user"),
  CONSTRAINT "channel" FOREIGN KEY("channel") REFERENCES "lichat-channels"("id") ON DELETE CASCADE,
  CONSTRAINT "user" FOREIGN KEY("user") REFERENCES "lichat-users"("id") ON DELETE CASCADE,
);

-- name: create_channel
INSERT INTO "lichat-channels"("name", "registrant", "lifetime", "expiry")
VALUES(:channel, :registrant, :lifetime, :expiry);

-- name: delete_channel
DELETE FROM "lichat-channels" 
 WHERE "name" = :channel;

-- name: find_channel
SELECT * FROM "lichat-channels"
 WHERE "name" = :channel;

-- name: list_channels
SELECT * FROM "lichat-channels"
 ORDER BY "name" ASC;

-- name: list_channel_members
SELECT U.*
  FROM "lichat-users" AS U
       LEFT JOIN "lichat-channel-members" AS M ON M."user" = U."id"
 WHERE M."channel" IN (SELECT "id" FROM "lichat-channels" WHERE "name" = :channel)
 ORDER BY "name" ASC;

-- name: join_channel
INSERT INTO "lichat-channel-members"("channel", "user")
SELECT C."id", U."id" FROM "lichat-channels" AS C, "lichat-users" AS U
 WHERE C."name" = :channel
   AND U."name" = :user;

-- name: leave_channel
DELETE FROM "lichat-channel-members"
 WHERE "channel" IN (SELECT "id" FROM "lichat-channels" WHERE "name" = :channel)
   AND "user" IN (SELECT "id" FROM "lichat-users" WHERE "name" = :user);
