CREATE TABLE IF NOT EXISTS "lichat-ip-log"(
       "id" INT GENERATED ALWAYS AS IDENTITY,
       "ip" VARCHAR(39) NOT NULL,
       "clock" BIGINT NOT NULL,
       "action" INT NOT NULL,
       "from" VARCHAR(32),
       "target" VARCHAR(39),
       PRIMARY KEY("id")
);
