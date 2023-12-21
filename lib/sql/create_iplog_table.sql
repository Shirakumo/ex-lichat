CREATE TABLE IF NOT EXISTS "lichat-ip-log"(
       "id" INT GENERATED ALWAYS AS IDENTITY,
       "ip" VARCHAR(39) NOT NULL,
       "clock" BIGINT NOT NULL,
       "action" INT NOT NULL,
       "from" VARCHAR(32),
       "target" VARCHAR(39),
       PRIMARY KEY("id")
);
CREATE INDEX IF NOT EXISTS "lichat-ip-log.ip" ON "lichat-ip-log" USING hash("ip");
CREATE INDEX IF NOT EXISTS "lichat-ip-log.from" ON "lichat-ip-log" USING hash("from");
CREATE INDEX IF NOT EXISTS "lichat-ip-log.action" ON "lichat-ip-log" USING hash("action");
CREATE INDEX IF NOT EXISTS "lichat-ip-log.clock" ON "lichat-ip-log" USING btree("clock") DESC;
