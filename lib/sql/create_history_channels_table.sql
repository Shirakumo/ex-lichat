CREATE TABLE IF NOT EXISTS "lichat-history-channels"(
       "id" INT GENERATED ALWAYS AS IDENTITY,
       "name" VARCHAR(32) NOT NULL,
       PRIMARY KEY("id"),
       UNIQUE("name")
);
CREATE INDEX IF NOT EXISTS "lichat-history-channels.name" ON "lichat-history-channels" USING hash("name");
