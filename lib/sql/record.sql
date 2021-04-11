INSERT INTO "lichat-history"("id", "from", "bridge", "clock", "channel", "text", "rich", "markup")
VALUES (:id,
        :from,
        :bridge,
        :clock,
        (SELECT "id" FROM "lichat-history-channels" WHERE "name" = :channel),
        :text,
        :rich,
        :markup);
