CREATE TABLE IF NOT EXISTS "lichat-history"(
       "id" VARCHAR(32) NOT NULL,
       "from" VARCHAR(32) NOT NULL,
       "bridge" VARCHAR(32),
       "clock" BIGINT NOT NULL,
       "channel" INT NOT NULL,
       "text" TEXT NOT NULL,
       "rich" TEXT,
       "markup" VARCHAR(16),
       CONSTRAINT "channel" FOREIGN KEY("channel") REFERENCES "lichat-history-channels"("id") ON DELETE CASCADE
);

