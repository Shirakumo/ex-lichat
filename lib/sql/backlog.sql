SELECT * FROM (
       SELECT * FROM "lichat-history-channels" as A
       LEFT JOIN "lichat-history" ON A."id" = "channel" 
       WHERE "name" = :channel
       ORDER BY "clock" DESC
       LIMIT :limit
) AS B ORDER BY B."clock" ASC;
