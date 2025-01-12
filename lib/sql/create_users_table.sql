CREATE TABLE IF NOT EXISTS "lichat-users"(
       "id" INT GENERATED ALWAYS AS IDENTITY,
       "name" VARCHAR(32),
       "registered" BOOLEAN NOT NULL,
       PRIMARY KEY("id"),
       UNIQUE("name")
);
