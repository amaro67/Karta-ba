
UPDATE Events
SET CoverImageUrl = CASE 

    WHEN CAST(Id AS BIGINT) % 2 = 0 THEN '/images/event1.jpg'
    ELSE '/images/event2.jpg'
END
WHERE CoverImageUrl LIKE 'https://example.com/images/event%.jpg'
   OR CoverImageUrl LIKE 'http://example.com/images/event%.jpg';

SELECT Id, Title, CoverImageUrl 
FROM Events 
WHERE CoverImageUrl IS NOT NULL
ORDER BY CreatedAt DESC;
