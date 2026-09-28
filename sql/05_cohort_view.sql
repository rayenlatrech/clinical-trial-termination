-- 05_cohort_view.sql
-- Creates analysis.cohort: ONE ROW PER TRIAL in the cohort, with clean statuses,
-- the label and the train/valid/test split. Run this file once. After that, query
-- analysis.cohort like a normal table (from SQL or from pandas).
--
-- A view stores the query, not the data, so it always reflects the two snapshots.
-- Rerunning this file is safe (CREATE OR REPLACE).
--
-- Decisions encoded here (see README, "Decisions"):
--   * cohort   = interventional trials, RECRUITING or NOT_YET_RECRUITING in Dec 2018
--   * label 1  = TERMINATED or WITHDRAWN in Sep 2026;  label 0 = COMPLETED
--   * UNKNOWN, still-ongoing, suspended, other and not-found trials get label NULL
--     (excluded from the main analysis, but kept in the view so they can be counted)
--   * label_sensitivity treats UNKNOWN as 1 (for the sensitivity check)
--   * split by registration year: <=2016 train, 2017 valid, 2018 test

CREATE SCHEMA IF NOT EXISTS analysis;

CREATE OR REPLACE VIEW analysis.cohort AS
WITH s18 AS (
    -- the 2018 snapshot, with the status normalized to the 2026 spelling
    SELECT
        nct_id,
        UPPER(REPLACE(REPLACE(overall_status, ',', ''), ' ', '_')) AS status_2018,
        study_first_submitted_date                                 AS registration_date
    FROM snap_2018_12.studies
    WHERE UPPER(study_type) = 'INTERVENTIONAL'
),
s26 AS (
    SELECT
        nct_id,
        UPPER(REPLACE(REPLACE(overall_status, ',', ''), ' ', '_')) AS status_2026
    FROM snap_2026_09.studies
),
joined AS (
    SELECT
        s18.nct_id,
        s18.status_2018,
        s26.status_2026,                       -- NULL if the trial is missing in 2026
        s18.registration_date,
        EXTRACT(YEAR FROM s18.registration_date)::int AS registration_year
    FROM s18
    LEFT JOIN s26 USING (nct_id)
    WHERE s18.status_2018 IN ('RECRUITING', 'NOT_YET_RECRUITING')
),
bucketed AS (
    SELECT
        *,
        CASE
            WHEN status_2026 IS NULL        THEN 'excluded: not found in 2026'
            WHEN status_2026 = 'COMPLETED'  THEN 'label 0: completed'
            WHEN status_2026 = 'TERMINATED' THEN 'label 1: terminated'
            WHEN status_2026 = 'WITHDRAWN'  THEN 'label 1: withdrawn'
            WHEN status_2026 = 'UNKNOWN'    THEN 'excluded: unknown status'
            WHEN status_2026 = 'SUSPENDED'  THEN 'excluded: suspended'
            WHEN status_2026 IN ('RECRUITING', 'NOT_YET_RECRUITING',
                                 'ACTIVE_NOT_RECRUITING', 'ENROLLING_BY_INVITATION')
                                            THEN 'excluded: still ongoing'
            ELSE                                 'excluded: other'   -- e.g. expanded-access statuses
        END AS bucket
    FROM joined
)
SELECT
    nct_id,
    status_2018,
    status_2026,
    bucket,
    -- main label: NULL means "not used in the main analysis"
    CASE
        WHEN status_2026 = 'COMPLETED'                 THEN 0
        WHEN status_2026 IN ('TERMINATED', 'WITHDRAWN') THEN 1
    END AS label,
    -- sensitivity label: same, but UNKNOWN counts as stopped early
    CASE
        WHEN status_2026 = 'COMPLETED'                            THEN 0
        WHEN status_2026 IN ('TERMINATED', 'WITHDRAWN', 'UNKNOWN') THEN 1
    END AS label_sensitivity,
    registration_date,
    registration_year,
    CASE
        WHEN registration_year <= 2016 THEN 'train'
        WHEN registration_year =  2017 THEN 'valid'
        WHEN registration_year =  2018 THEN 'test'
    END AS split
FROM bucketed;


-- ---------------------------------------------------------------------------
-- Checks: run these after creating the view. Expected numbers are from queries 03/04.
-- ---------------------------------------------------------------------------

-- 1) Cohort size: expect 47,210 rows, and one row per trial (both numbers equal)
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT nct_id) AS n_trials
FROM analysis.cohort;

-- 2) Buckets: expect completed 25,420 / terminated 4,846 / withdrawn 1,637 /
--    unknown 11,326 / suspended 207 / not found 63; still ongoing + other = 3,711
SELECT bucket, COUNT(*) AS n_trials
FROM analysis.cohort
GROUP BY bucket
ORDER BY bucket;

-- 3) Split sizes and the share stopped early, labelled trials only
SELECT split, COUNT(*) AS n_labelled, ROUND(100.0 * AVG(label), 1) AS pct_stopped_early
FROM analysis.cohort
WHERE label IS NOT NULL
GROUP BY split
ORDER BY split;
