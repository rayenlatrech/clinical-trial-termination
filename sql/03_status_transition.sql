-- 03_status_transition.sql
-- Goal: take the Dec 2018 cohort (interventional trials that were not yet
-- recruiting or recruiting) and see what status each one has in Sep 2026.
-- This gives the cohort size, the class balance, and how many trials need excluding.
--
-- Spelling: 2018 uses values like 'Not yet recruiting', while the 2026 format
-- (after the 2024 overhaul) may use 'NOT_YET_RECRUITING'. To compare them, every
-- status is normalized: upper case, commas removed, spaces turned into underscores.
--   'Active, not recruiting' -> 'ACTIVE_NOT_RECRUITING'

-- Part A: the full transition table (2018 status x 2026 status)
WITH cohort AS (
    SELECT
        nct_id,
        UPPER(REPLACE(REPLACE(overall_status, ',', ''), ' ', '_')) AS status_2018
    FROM snap_2018_12.studies
    WHERE UPPER(study_type) = 'INTERVENTIONAL'
      AND UPPER(REPLACE(REPLACE(overall_status, ',', ''), ' ', '_'))
          IN ('RECRUITING', 'NOT_YET_RECRUITING')
),
outcome AS (
    SELECT
        nct_id,
        UPPER(REPLACE(REPLACE(overall_status, ',', ''), ' ', '_')) AS status_2026
    FROM snap_2026_09.studies
)
SELECT
    c.status_2018,
    -- LEFT JOIN keeps cohort trials that have no row in 2026; their status is NULL
    COALESCE(o.status_2026, '(NOT FOUND IN 2026)') AS status_2026,
    COUNT(*) AS n_trials,
    -- share within each 2018 status (each 2018 status adds up to 100%)
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY c.status_2018), 1)
        AS pct_of_2018_status
FROM cohort c
LEFT JOIN outcome o USING (nct_id)
GROUP BY c.status_2018, COALESCE(o.status_2026, '(NOT FOUND IN 2026)')
ORDER BY c.status_2018, n_trials DESC;


-- Part B: the same cohort, grouped into the buckets the label needs
-- (this is where the README's open decisions get their numbers)
WITH cohort AS (
    SELECT nct_id
    FROM snap_2018_12.studies
    WHERE UPPER(study_type) = 'INTERVENTIONAL'
      AND UPPER(REPLACE(REPLACE(overall_status, ',', ''), ' ', '_'))
          IN ('RECRUITING', 'NOT_YET_RECRUITING')
),
outcome AS (
    SELECT
        nct_id,
        UPPER(REPLACE(REPLACE(overall_status, ',', ''), ' ', '_')) AS status_2026
    FROM snap_2026_09.studies
),
labelled AS (
    SELECT
        c.nct_id,
        o.status_2026,
        CASE
            WHEN o.status_2026 IS NULL                     THEN 'excluded: not found in 2026'
            WHEN o.status_2026 = 'COMPLETED'               THEN 'label 0: completed'
            WHEN o.status_2026 = 'TERMINATED'              THEN 'label 1: terminated'
            WHEN o.status_2026 = 'WITHDRAWN'               THEN 'label 1: withdrawn'
            WHEN o.status_2026 LIKE 'UNKNOWN%'             THEN 'excluded: unknown status'
            WHEN o.status_2026 = 'SUSPENDED'               THEN 'excluded: suspended'
            WHEN o.status_2026 IN ('RECRUITING', 'NOT_YET_RECRUITING',
                                   'ACTIVE_NOT_RECRUITING', 'ENROLLING_BY_INVITATION')
                                                           THEN 'excluded: still ongoing'
            ELSE                                                'excluded: other'   -- expanded-access statuses
        END AS bucket
    FROM cohort c
    LEFT JOIN outcome o USING (nct_id)
)
SELECT
    bucket,
    COUNT(*) AS n_trials,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_cohort
FROM labelled
GROUP BY bucket
ORDER BY bucket;
