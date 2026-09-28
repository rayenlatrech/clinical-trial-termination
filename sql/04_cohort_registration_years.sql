-- 04_cohort_registration_years.sql
-- Goal: when were the cohort's trials registered? This is needed to pick the
-- date that splits the training data from the test data (open decision 3).
-- Only trials that get a label (completed, terminated, withdrawn) are counted,
-- because only those are used for training and testing.

WITH cohort AS (
    SELECT nct_id, study_first_submitted_date
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
    EXTRACT(YEAR FROM c.study_first_submitted_date)::int AS registration_year,
    COUNT(*)                                             AS n_labelled,
    -- the share of positives (terminated or withdrawn) per year, as a %
    ROUND(100.0 * AVG(CASE WHEN o.status_2026 IN ('TERMINATED', 'WITHDRAWN')
                           THEN 1 ELSE 0 END), 1)        AS pct_stopped_early
FROM cohort c
JOIN outcome o USING (nct_id)          -- inner join: trials without a 2026 row are dropped
WHERE o.status_2026 IN ('COMPLETED', 'TERMINATED', 'WITHDRAWN')
GROUP BY registration_year
ORDER BY registration_year;
