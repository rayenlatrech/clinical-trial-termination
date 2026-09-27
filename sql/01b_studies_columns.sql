SELECT 
    c18.column_name AS only_in_2018,
    c26.column_name AS only_in_2026
FROM 
    (
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_schema = 'snap_2018_12' 
          AND table_name = 'studies'
    ) c18
FULL OUTER JOIN 
    (
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_schema = 'snap_2026_09' 
          AND table_name = 'studies'
    ) c26
    ON c18.column_name = c26.column_name
WHERE 
    c18.column_name IS NULL   -- Added in 2026
    OR c26.column_name IS NULL -- Dropped after 2018
ORDER BY 
    COALESCE(c18.column_name, c26.column_name);