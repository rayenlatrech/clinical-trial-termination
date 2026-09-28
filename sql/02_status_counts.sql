-- 02_status_counts.sql
-- Goal: see how each snapshot spells overall_status and study_type, and how many
-- trials fall into each value. The cohort and the label are both defined by these
-- columns, so the spellings must be known before any filtering.

-- Part A: overall_status counts in each snapshot, stacked
SELECT
    'snap_2018_12'  AS snapshot,
    overall_status,
    COUNT(*)        AS n_trials,
    -- share of this snapshot's trials; the window function sums the counts
    -- of every row in the result, i.e. the total for this snapshot
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM snap_2018_12.studies
GROUP BY overall_status

UNION ALL

SELECT
    'snap_2026_09',
    overall_status,
    COUNT(*),
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)
FROM snap_2026_09.studies
GROUP BY overall_status

ORDER BY snapshot, n_trials DESC;


-- Part B: study_type counts in each snapshot
-- (the cohort is interventional trials only, so check how that value is spelled)
SELECT 'snap_2018_12' AS snapshot, study_type, COUNT(*) AS n_trials
FROM snap_2018_12.studies
GROUP BY study_type

UNION ALL

SELECT 'snap_2026_09', study_type, COUNT(*)
FROM snap_2026_09.studies
GROUP BY study_type

ORDER BY snapshot, n_trials DESC;
