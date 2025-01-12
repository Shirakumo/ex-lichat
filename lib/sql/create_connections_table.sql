CREATE TABLE IF NOT EXISTS "lichat-connections"(
       "id" INT GENERATED ALWAYS AS IDENTITY,
       "ip" VARCHAR(39) NOT NULL,
       "ssl" BOOLEAN NOT NULL,
       "user" INT NOT NULL,
       "last-update" BIGINT NOT NULL,
       "started-on" BIGINT NOT NULL,
       PRIMARY KEY("id"),
       CONSTRAINT "user" FOREIGN KEY("user") REFERENCES "lichat-users"("id") ON DELETE CASCADE
);
