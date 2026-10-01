-- 07_features_view.sql
-- Creates analysis.features: ONE ROW PER COHORT TRIAL with the label, the split and
-- every feature chosen in docs/feature_list.md. Run the CREATE part once, then the
-- checks at the bottom. After that, notebooks read it with:
--     SELECT * FROM analysis.features
--
-- Rules:
--   * Every feature comes from the Dec 2018 snapshot (snap_2018_12). Nothing from 2026
--     except the label, which comes from analysis.cohort.
--   * SQL only does fixed, rule-based cleaning (placeholders -> NULL, units -> years,
--     counting rows per trial). Anything LEARNED from the data (filling missing values
--     with a median, encoding categories, scaling) happens later in Python, using the
--     training set only, so no test information leaks in.
--   * Tables with many rows per trial are aggregated to one row per trial in their own
--     CTE first, then joined. Joining them directly would multiply rows.
--
-- Reference date: the 2018 snapshot was downloaded on 2018-11-30 (calculated_values.nlm_download_date).

DROP VIEW IF EXISTS analysis.features;

CREATE VIEW analysis.features AS
WITH
-- ---------------------------------------------------------------------------
-- Many-per-trial tables, each aggregated to one row per trial
-- ---------------------------------------------------------------------------
site_agg AS (
    -- every facility row is one site (country is never empty in this snapshot,
    -- and this count matched calculated_values.number_of_facilities for all trials)
    SELECT
        f.nct_id,
        COUNT(*)                                  AS n_sites,
        BOOL_OR(f.country = 'United States')      AS has_us_site
    FROM snap_2018_12.facilities f
    WHERE f.nct_id IN (SELECT nct_id FROM analysis.cohort)
    GROUP BY f.nct_id
),
country_agg AS (
    -- removed = TRUE means the country was listed earlier and later taken off the record
    SELECT
        co.nct_id,
        COUNT(*) FILTER (WHERE co.removed IS NOT TRUE)  AS n_countries,
        BOOL_OR(COALESCE(co.removed, FALSE))            AS had_country_removed
    FROM snap_2018_12.countries co
    WHERE co.nct_id IN (SELECT nct_id FROM analysis.cohort)
    GROUP BY co.nct_id
),
sponsor_agg AS (
    -- every cohort trial has exactly one lead sponsor (checked in notebook 02)
    SELECT
        sp.nct_id,
        MAX(sp.agency_class) FILTER (WHERE sp.lead_or_collaborator = 'lead')  AS lead_sponsor_class,
        COUNT(*) FILTER (WHERE sp.lead_or_collaborator = 'collaborator')      AS n_collaborators
    FROM snap_2018_12.sponsors sp
    WHERE sp.nct_id IN (SELECT nct_id FROM analysis.cohort)
    GROUP BY sp.nct_id
),
intervention_agg AS (
    -- a trial can combine several intervention types, so each type gets its own yes/no flag
    SELECT
        i.nct_id,
        COUNT(*)                                                   AS n_interventions,
        COUNT(DISTINCT i.intervention_type)                        AS n_intervention_types,
        BOOL_OR(i.intervention_type = 'Drug')                      AS is_drug,
        BOOL_OR(i.intervention_type = 'Device')                    AS is_device,
        BOOL_OR(i.intervention_type = 'Biological')                AS is_biological,
        BOOL_OR(i.intervention_type = 'Procedure')                 AS is_procedure,
        BOOL_OR(i.intervention_type = 'Behavioral')                AS is_behavioral,
        BOOL_OR(i.intervention_type = 'Radiation')                 AS is_radiation,
        BOOL_OR(i.intervention_type = 'Dietary Supplement')        AS is_dietary_supplement,
        -- 'Other' plus the rare types (Diagnostic Test, Combination Product, Genetic)
        BOOL_OR(i.intervention_type IN ('Other', 'Diagnostic Test',
                                        'Combination Product', 'Genetic')) AS is_other_intervention
    FROM snap_2018_12.interventions i
    WHERE i.nct_id IN (SELECT nct_id FROM analysis.cohort)
    GROUP BY i.nct_id
),
condition_agg AS (
    -- same keyword list as notebook 02 (matched 26% of trials; the checked sample was clean)
    SELECT
        cd.nct_id,
        COUNT(*)  AS n_conditions,
        BOOL_OR(cd.name ~* 'cancer|carcinoma|tumou?r|neoplasm|lymphoma|leuka?emia|melanoma|sarcoma|myeloma|glioma|glioblastoma|oncolog')
                  AS is_oncology
    FROM snap_2018_12.conditions cd
    WHERE cd.nct_id IN (SELECT nct_id FROM analysis.cohort)
    GROUP BY cd.nct_id
),

-- ---------------------------------------------------------------------------
-- Eligibility-criteria complexity (the free-text inclusion/exclusion criteria).
-- Published work on trial termination found these among the strongest registry
-- signals (Elkin & Zhu 2021; a 2025 accrual-failure study in Scientific Reports).
-- ---------------------------------------------------------------------------
criteria_parts AS (
    SELECT
        el.nct_id,
        NULLIF(TRIM(el.criteria), '')                          AS criteria,
        -- where the exclusion part starts (0 if the text has no exclusion heading)
        POSITION('exclusion criteria' IN LOWER(el.criteria))   AS excl_pos
    FROM snap_2018_12.eligibilities el
    WHERE el.nct_id IN (SELECT nct_id FROM analysis.cohort)
),
criteria_stats AS (
    -- a criterion = a line starting with a bullet ('-', '*') or a number ('1.', '2)')
    SELECT
        nct_id,
        CASE WHEN criteria IS NULL THEN NULL
             ELSE ARRAY_LENGTH(REGEXP_SPLIT_TO_ARRAY(criteria, '\s+'), 1)
        END AS criteria_words,
        CASE WHEN criteria IS NULL THEN NULL
             ELSE (SELECT COUNT(*) FROM REGEXP_MATCHES(
                       CASE WHEN excl_pos > 0 THEN LEFT(criteria, excl_pos - 1) ELSE criteria END,
                       '(^|\n)[ \t]*(-|\*|[0-9]+[.)])[ \t]', 'g'))
        END AS n_inclusion_criteria,
        CASE WHEN criteria IS NULL THEN NULL
             WHEN excl_pos = 0 THEN 0
             ELSE (SELECT COUNT(*) FROM REGEXP_MATCHES(
                       SUBSTRING(criteria FROM excl_pos),
                       '(^|\n)[ \t]*(-|\*|[0-9]+[.)])[ \t]', 'g'))
        END AS n_exclusion_criteria
    FROM criteria_parts
),

-- ---------------------------------------------------------------------------
-- Age units: ' Years', 'Year', ' Months', ... -> one factor that converts to years
-- ---------------------------------------------------------------------------
age_units AS (
    SELECT
        cv.nct_id,
        cv.minimum_age_num,
        cv.maximum_age_num,
        -- trim the leading space, lower-case, drop a final 's' ('Years' -> 'year')
        REGEXP_REPLACE(LOWER(TRIM(cv.minimum_age_unit)), 's$', '') AS min_unit,
        REGEXP_REPLACE(LOWER(TRIM(cv.maximum_age_unit)), 's$', '') AS max_unit
    FROM snap_2018_12.calculated_values cv
    WHERE cv.nct_id IN (SELECT nct_id FROM analysis.cohort)
)

-- ---------------------------------------------------------------------------
-- One row per cohort trial
-- ---------------------------------------------------------------------------
SELECT
    -- identifiers, label and split (from analysis.cohort)
    c.nct_id,
    c.label,
    c.label_sensitivity,
    c.split,
    c.registration_date,
    c.registration_year,

    -- 2018 status
    c.status_2018,

    -- trial design
    s.phase,
    s.number_of_arms,
    CASE
        WHEN s.has_dmc::text IN ('true', 't', 'Yes', 'yes')  THEN 'yes'
        WHEN s.has_dmc::text IN ('false', 'f', 'No', 'no')   THEN 'no'
        ELSE 'unknown'
    END                                                       AS has_dmc,
    CASE
        WHEN d.allocation IS NOT NULL                              THEN d.allocation
        WHEN d.intervention_model = 'Single Group Assignment'      THEN 'Single group'
        ELSE 'Unknown'
    END                                                       AS allocation,
    COALESCE(d.masking, 'Unknown')                            AS masking,
    COALESCE(d.primary_purpose, 'Unknown')                    AS primary_purpose,
    COALESCE(d.intervention_model, 'Unknown')                 AS intervention_model,

    -- planned size (enrolment in 2018 is the TARGET: 'Anticipated' for every trial)
    CASE WHEN s.enrollment >= 99999999 THEN NULL ELSE s.enrollment END   AS enrollment_target,

    -- planned timing (planned dates as of 2018; far-future placeholders such as 2099 -> NULL)
    CASE
        WHEN s.start_date IS NULL OR s.primary_completion_date IS NULL   THEN NULL
        WHEN s.primary_completion_date > DATE '2050-12-31'               THEN NULL
        WHEN s.primary_completion_date < s.start_date                    THEN NULL
        ELSE ROUND((s.primary_completion_date - s.start_date) / 30.44, 1)
    END                                                       AS planned_duration_months,
    -- negative = the trial was registered after it had already started
    ROUND((s.start_date - c.registration_date) / 30.44, 1)    AS months_registration_to_start,
    -- still recruiting in Nov 2018 although the planned completion date had passed
    CASE
        WHEN s.primary_completion_date IS NULL THEN NULL
        ELSE (s.primary_completion_date < DATE '2018-11-30')::int
    END                                                       AS overdue_2018,

    -- population
    e.gender,
    CASE NULLIF(TRIM(e.healthy_volunteers), '')
        WHEN 'Accepts Healthy Volunteers' THEN 1
        WHEN 'No'                         THEN 0
    END                                                       AS accepts_healthy_volunteers,
    ROUND(a.minimum_age_num * CASE a.min_unit
        WHEN 'year'   THEN 1.0
        WHEN 'month'  THEN 1.0 / 12
        WHEN 'week'   THEN 7.0 / 365.25
        WHEN 'day'    THEN 1.0 / 365.25
        WHEN 'hour'   THEN 1.0 / (24 * 365.25)
        WHEN 'minute' THEN 1.0 / (1440 * 365.25)
    END, 3)                                                   AS min_age_years,
    ROUND(a.maximum_age_num * CASE a.max_unit
        WHEN 'year'   THEN 1.0
        WHEN 'month'  THEN 1.0 / 12
        WHEN 'week'   THEN 7.0 / 365.25
        WHEN 'day'    THEN 1.0 / 365.25
        WHEN 'hour'   THEN 1.0 / (24 * 365.25)
        WHEN 'minute' THEN 1.0 / (1440 * 365.25)
    END, 3)                                                   AS max_age_years,
    (a.minimum_age_num IS NULL)::int                          AS no_min_age,
    (a.maximum_age_num IS NULL)::int                          AS no_max_age,
    cs.criteria_words,
    cs.n_inclusion_criteria,
    cs.n_exclusion_criteria,

    -- sites and countries (no rows in the table -> 0)
    COALESCE(sa.n_sites, 0)                                   AS n_sites,
    (COALESCE(sa.n_sites, 0) = 0)::int                        AS no_sites_listed,
    (COALESCE(sa.n_sites, 0) = 1)::int                        AS single_site,
    COALESCE(sa.has_us_site, FALSE)::int                      AS has_us_site,
    COALESCE(ca.n_countries, 0)                               AS n_countries,
    COALESCE(ca.had_country_removed, FALSE)::int              AS had_country_removed,

    -- sponsor
    spa.lead_sponsor_class,
    COALESCE(spa.n_collaborators, 0)                          AS n_collaborators,

    -- interventions
    COALESCE(ia.n_interventions, 0)                           AS n_interventions,
    COALESCE(ia.n_intervention_types, 0)                      AS n_intervention_types,
    COALESCE(ia.is_drug, FALSE)::int                          AS is_drug,
    COALESCE(ia.is_device, FALSE)::int                        AS is_device,
    COALESCE(ia.is_biological, FALSE)::int                    AS is_biological,
    COALESCE(ia.is_procedure, FALSE)::int                     AS is_procedure,
    COALESCE(ia.is_behavioral, FALSE)::int                    AS is_behavioral,
    COALESCE(ia.is_radiation, FALSE)::int                     AS is_radiation,
    COALESCE(ia.is_dietary_supplement, FALSE)::int            AS is_dietary_supplement,
    COALESCE(ia.is_other_intervention, FALSE)::int            AS is_other_intervention,

    -- disease area
    COALESCE(cda.n_conditions, 0)                             AS n_conditions,
    COALESCE(cda.is_oncology, FALSE)::int                     AS is_oncology

FROM analysis.cohort c
LEFT JOIN snap_2018_12.studies        s   ON s.nct_id   = c.nct_id
LEFT JOIN snap_2018_12.designs        d   ON d.nct_id   = c.nct_id
LEFT JOIN snap_2018_12.eligibilities  e   ON e.nct_id   = c.nct_id
LEFT JOIN age_units                   a   ON a.nct_id   = c.nct_id
LEFT JOIN criteria_stats              cs  ON cs.nct_id  = c.nct_id
LEFT JOIN site_agg                    sa  ON sa.nct_id  = c.nct_id
LEFT JOIN country_agg                 ca  ON ca.nct_id  = c.nct_id
LEFT JOIN sponsor_agg                 spa ON spa.nct_id = c.nct_id
LEFT JOIN intervention_agg            ia  ON ia.nct_id  = c.nct_id
LEFT JOIN condition_agg               cda ON cda.nct_id = c.nct_id;


-- ---------------------------------------------------------------------------
-- Checks: run each one after creating the view.
-- Expected values come from notebooks 01 and 02.
-- ---------------------------------------------------------------------------

-- 1) One row per trial: expect n_rows = n_trials = 47,210
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT nct_id) AS n_trials
FROM analysis.features;

-- 2) Label and split unchanged: expect train 11,776 / valid 9,157 / test 10,970, about 20% positive
SELECT split, COUNT(*) AS n_labelled, ROUND(100.0 * AVG(label), 1) AS pct_stopped_early
FROM analysis.features
WHERE label IS NOT NULL
GROUP BY split
ORDER BY split;

-- 3) Spot checks against notebook 02:
--    no sites ~11%, oncology ~26%, has US site ~39%, a country removed ~1.1%, lead Industry ~16.5%
SELECT
    ROUND(100.0 * AVG(no_sites_listed), 1)                              AS pct_no_sites,
    ROUND(100.0 * AVG(is_oncology), 1)                                  AS pct_oncology,
    ROUND(100.0 * AVG(has_us_site), 1)                                  AS pct_us_site,
    ROUND(100.0 * AVG(had_country_removed), 1)                          AS pct_country_removed,
    ROUND(100.0 * AVG((lead_sponsor_class = 'Industry')::int), 1)       AS pct_industry_lead,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY n_sites)                AS median_sites
FROM analysis.features;

-- 4) Missing values in the columns that can be NULL (expect small numbers, except where noted)
SELECT
    COUNT(*) FILTER (WHERE enrollment_target IS NULL)          AS null_enrollment,        -- ~22 (20 missing + 2 placeholders)
    COUNT(*) FILTER (WHERE planned_duration_months IS NULL)    AS null_planned_duration,
    COUNT(*) FILTER (WHERE min_age_years IS NULL)              AS null_min_age,           -- ~2,468 (no minimum age)
    COUNT(*) FILTER (WHERE max_age_years IS NULL)              AS null_max_age,           -- ~22,098 (no maximum age)
    COUNT(*) FILTER (WHERE accepts_healthy_volunteers IS NULL) AS null_healthy_volunteers, -- ~15
    COUNT(*) FILTER (WHERE lead_sponsor_class IS NULL)         AS null_lead_sponsor       -- expect 0
FROM analysis.features;

-- 5) Age conversion sanity check: every value should be between 0 and ~120 years
SELECT MIN(min_age_years), MAX(min_age_years), MIN(max_age_years), MAX(max_age_years)
FROM analysis.features;

-- 6) Eligibility-criteria features: typical trials list a handful of inclusion and
--    exclusion criteria and a few hundred words; NULL only when the text is missing
SELECT
    COUNT(*) FILTER (WHERE criteria_words IS NULL)                         AS null_criteria,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY criteria_words)            AS median_words,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY n_inclusion_criteria)      AS median_inclusion,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY n_exclusion_criteria)      AS median_exclusion,
    ROUND(100.0 * AVG((n_inclusion_criteria = 0)::int), 1)                 AS pct_no_inclusion_bullets
FROM analysis.features;

