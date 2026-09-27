-- Tables in 2018 that were REMOVED in 2026
SELECT 
    table_name,
    'Only in 2018' AS change_type
FROM 
    information_schema.tables
WHERE 
    table_schema = 'snap_2018_12'
    AND table_name NOT IN (
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'snap_2026_09'
    )

UNION ALL

-- Tables that are NEW in 2026
SELECT 
    table_name,
    'Added in 2026 (New Table)' AS change_type
FROM 
    information_schema.tables
WHERE 
    table_schema = 'snap_2026_09'
    AND table_name NOT IN (
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'snap_2018_12'
    )

ORDER BY 
    change_type, 
    table_name;