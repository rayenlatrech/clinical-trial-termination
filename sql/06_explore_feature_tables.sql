-- studies
SELECT 'studies' AS table_name, COUNT(*) AS total_rows, COUNT(DISTINCT nct_id) AS distinct_trials 
FROM snap_2018_12.studies;

-- designs 
SELECT 'designs' AS table_name, count(*) AS total_rows, count(DISTINCT nct_id) AS distinct_trials
FROM  snap_2018_12.designs;

--eligibilities
SELECT 'eligibilities' AS table_name, COUNT(*) AS total_rows, COUNT(DISTINCT nct_id) AS distinct_trials 
FROM snap_2018_12.eligibilities;

--facilities
SELECT 'facilities' AS table_name, COUNT(*) AS total_rows, COUNT(DISTINCT nct_id) AS distinct_trials 
FROM snap_2018_12.facilities;

--countries
SELECT 'countries' AS table_name, COUNT(*) AS total_rows, COUNT(DISTINCT nct_id) AS distinct_trials 
FROM snap_2018_12.countries;

--sponsors
SELECT 'sponsors' AS table_name, COUNT(*) AS total_rows, COUNT(DISTINCT nct_id) AS distinct_trials 
FROM snap_2018_12.sponsors;

--conditions
SELECT 'conditions' AS table_name, COUNT(*) AS total_rows, COUNT(DISTINCT nct_id) AS distinct_trials 
FROM snap_2018_12.conditions;

--interventions
SELECT 'interventions' AS table_name, COUNT(*) AS total_rows, COUNT(DISTINCT nct_id) AS distinct_trials 
FROM snap_2018_12.interventions;

-- cohort on studies
SELECT count(*) as total_rows
from analysis.cohort ac
left join snap_2018_12.studies s18 on ac.nct_id=s18.nct_id;


-- on designs   
SELECT count(*) as total_rows
from analysis.cohort ac
left join snap_2018_12.designs ds on ds.nct_id=ac.nct_id;

-- on eligibilities 
SELECT count(*) as total_rows
from analysis.cohort ac
left join snap_2018_12.eligibilities el on el.nct_id=ac.nct_id;

-- columns cohort on studies
SELECT *
from analysis.cohort ac
left join snap_2018_12.studies s18 on ac.nct_id=s18.nct_id
limit 10;

-- on designs   
SELECT *
from analysis.cohort ac
left join snap_2018_12.designs ds on ds.nct_id=ac.nct_id
limit 10;

-- on eligibilities 
SELECT *
from analysis.cohort ac
left join snap_2018_12.eligibilities el on el.nct_id=ac.nct_id
limit 10;

--column distributions
SELECT 
    -- enrollment
    MIN(s.enrollment) AS min_enrollment,
    ROUND(AVG(s.enrollment), 1) AS avg_enrollment,
    MAX(s.enrollment) AS max_enrollment,
    COUNT(*) FILTER (WHERE s.enrollment IS NULL) AS null_enrollment,

    -- number_of_arms
    MIN(s.number_of_arms) AS min_arms,
    ROUND(AVG(s.number_of_arms), 1) AS avg_arms,
    MAX(s.number_of_arms) AS max_arms,
    COUNT(*) FILTER (WHERE s.number_of_arms IS NULL) AS null_arms
FROM analysis.cohort ac
LEFT JOIN snap_2018_12.studies s ON ac.nct_id = s.nct_id;
