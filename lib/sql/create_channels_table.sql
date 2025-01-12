CREATE TABLE IF NOT EXISTS "lichat-channels"(
       "id" INT GENERATED ALWAYS AS IDENTITY,
       "name" VARCHAR(32) NOT NULL,
       "registrant" INT NOT NULL,
       "lifetime" INT NOT NULL,
       "expiry" INT NOT NULL,
       PRIMARY KEY("id"),
       UNIQUE("name")
);

