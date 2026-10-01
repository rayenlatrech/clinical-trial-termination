# Feature list

Every candidate feature, where it comes from, and whether it was **known in December 2018**. Features may only come from the `snap_2018_12` schema. Anything from 2026 is the outcome.

Status: ✅ explored · ⏳ not explored yet
Last updated: 30 Sep 2026 (eligibility-criteria features added after the literature review)

---

## 1. Table shapes (`sql/06_explore_feature_tables.sql`)

| Table (2018) | Shape | How it's used |
|---|---|---|
| `studies` | 1 row per trial | join directly |
| `designs` | 1 row per trial | join directly |
| `eligibilities` | 1 row per trial | join directly |
| `facilities` | many rows per trial | aggregate to one row per trial first |
| `countries` | many rows per trial | aggregate first |
| `sponsors` | many rows per trial | aggregate first |
| `conditions` | many rows per trial | aggregate first |
| `interventions` | many rows per trial | aggregate first |

Joining the cohort to the three one-per-trial tables keeps **47,210 rows**, so no rows are multiplied.

---

## 2. One-per-trial features ✅

Missing % is measured on the 47,210 cohort trials.

| Feature | Group | Source | Missing | What the values look like | Known in Dec 2018? | Decision |
|---|---|---|---|---|---|---|
| `status_2018` | 2018 status | `analysis.cohort` | 0% | RECRUITING / NOT_YET_RECRUITING | ✅ It defines the cohort | **Keep** |
| `phase` | Design | `studies.phase` | 0% | 8 values; "N/A" is 51% (non-drug trials) | ✅ Registered design | **Keep**; "N/A" is its own category |
| `enrollment` | Size | `studies.enrollment` | 0.04% | median 80; placeholder 99,999,999; values up to 2M | ✅ It's the *target* ("Anticipated" for everyone) | **Keep**: placeholder → missing, log scale |
| `enrollment_type` | Size | `studies.enrollment_type` | 0.05% | "Anticipated" for everyone | ✅ | **Drop**: no variation (but it confirms the enrolment column is safe) |
| planned duration | Timing | `studies.primary_completion_date − start_date` | ~0.04% | placeholder dates (e.g. 2099) | ✅ These were the planned dates as of 2018 | **Derive** in pandas; far-future dates → missing |
| `number_of_arms` | Design | `studies.number_of_arms` | 0.7% | 1–31, median 2 | ✅ | **Keep** |
| `has_dmc` | Design | `studies.has_dmc` | 11.9% | yes / no | ✅ | **Keep**; missing is its own category |
| `allocation` | Design | `designs.allocation` | 27.4% | Randomized / Non-Randomized; missing = single group (97.7%) | ✅ | **Keep**; missing → "single group" |
| `masking` | Design | `designs.masking` | 0.2% | Open label … Quadruple | ✅ | **Keep** |
| `primary_purpose` | Design | `designs.primary_purpose` | 0.3% | 9 values; Treatment is 65% | ✅ | **Keep**; group the rare values |
| `intervention_model` | Design | `designs.intervention_model` | 0.1% | 5 values | ✅ | **Keep** |
| `gender` | Population | `eligibilities.gender` | 0% | All / Female / Male | ✅ | **Keep** |
| `minimum_age` | Population | `eligibilities.minimum_age` | 0% (5.2% "N/A" = no minimum) | text, units Minutes–Years | ✅ | **Keep**: parse to years + "no minimum" flag |
| `maximum_age` | Population | `eligibilities.maximum_age` | 0% (46.8% "N/A" = no maximum) | text, units Minutes–Years | ✅ | **Keep**: parse to years + "no maximum" flag |
| `healthy_volunteers` | Population | `eligibilities.healthy_volunteers` | 15 empty strings | Yes / No | ✅ | **Keep**; "" → missing |

**Idea to test later:** some trials were still recruiting in Dec 2018 even though their planned completion date had already passed. An "overdue in 2018" flag would be legitimately known at the time, and it may be a strong signal.

---

## 3. Many-per-trial features ✅

Each table is aggregated to one row per trial (a trial with no rows gets 0).

| Feature | Group | Source | What the data shows | Known in Dec 2018? | Decision |
|---|---|---|---|---|---|
| `n_sites` | Sites | count of `facilities` rows | median 1, mean 6.3, max 1,457; some trials have 0 | ✅ Sites listed in the 2018 record | **Keep**, log scale |
| `has_us_site` | Sites | `facilities.country` = United States | the US is in 18,544 trials (39%) | ✅ | **Keep** |
| `single_site` | Sites | `n_sites` = 1 | the median trial is single-site | ✅ | **Keep** (or let the model use `n_sites`) |
| `n_countries` | Sites | `countries` excluding `removed` | median 1, max 49; matches `facilities` for 100% of trials | ✅ | **Keep** |
| `had_country_removed` | Sites | `countries.removed` = True | 519 trials (1.1%) | ✅ The removal had already happened by Dec 2018 | **Keep**: a possible "trouble" signal, but rare |
| `lead_sponsor_class` | Sponsor | `sponsors.agency_class` where lead | exactly 1 lead per trial; Other 81.1%, Industry 16.5%, NIH 1.3%, U.S. Fed 1.1% | ✅ | **Keep**; consider merging NIH and U.S. Fed (both small) |
| `n_collaborators` | Sponsor | count of collaborator rows | median 0, max 68 | ✅ | **Keep** |
| `n_interventions` | Intervention | count of `interventions` rows | min 1, median 2, max 35 | ✅ | **Keep** |
| intervention type flags | Intervention | one yes/no per type (`is_drug`, `is_device`, …) | a trial can combine types; Drug 43.9%, Other 20.4%, Device 15.8%, Behavioral 12.4%, Procedure 12.0%, Biological 7.1% | ✅ | **Keep** the main types; group the rare ones |
| `n_conditions` | Disease area | count of `conditions` rows | min 1, median 1, max 90 | ✅ | **Keep** |
| `is_oncology` | Disease area | cancer keywords in `conditions.name` | 26.0% of trials; a sample showed only genuine cancers | ✅ | **Keep** |

## 4. `calculated_values` ✅

A pre-computed AACT table (16 columns in the 2018 snapshot). Mostly duplicates of what we built ourselves, plus a few *results* columns that must not be used.

| Column | Missing | Verdict | Why |
|---|---|---|---|
| `number_of_facilities` | 11.0% | duplicate of `n_sites` | Matches our count for all 47,210 trials; NaN = 0 sites |
| `has_us_facility` | 11.0% | duplicate of `has_us_site` | Agrees except for 9 trials |
| `has_single_facility` | 0% | duplicate of `single_site` | |
| `minimum_age_num` / `_unit`, `maximum_age_num` / `_unit` | 5.2% / 46.8% | ✅ **use as the source for ages** | Already split into number + unit; units still need cleaning (leading space, singular/plural) and converting to years |
| `registered_in_calendar_year` | 0% | redundant | Same as `registration_year` (which defines the split) |
| `nlm_download_date` | 0% | ❌ not a feature | The snapshot date, identical for all trials |
| `actual_duration` | 99.1% | ❌ **leakage** | Only known after a trial ends |
| `were_results_reported`, `months_to_report_results` | 0% / 100% | ❌ **leakage** | Results information |
| `number_of_sae_subjects`, `number_of_nsae_subjects` | 100% | ❌ **leakage** (empty anyway) | Adverse events from results |

**Leakage check result:** 288 labelled trials already had an `actual_duration` in the 2018 snapshot, and only **6.9%** of them later stopped early, against **20.4%** for the rest. The column is clearly related to the outcome, which confirms it must stay out. `were_results_reported` was True for a single trial.

**New feature from this section:** `no_sites_listed` (about 11% of the cohort had no sites registered in Dec 2018).

## 5. Final feature set: `analysis.features` (`sql/07_features_view.sql`)

One row per cohort trial (47,210). **41 features** since 30 Sep: 9 categorical, 9 log-numeric, 6 numeric, 17 binary. SQL applies only **fixed rules** (placeholders → NULL, units → years, counts per trial). Anything *learned* from the data (imputing, encoding, scaling) happens later in Python, on the training set only.

| Group | Columns |
|---|---|
| Keys, label, split | `nct_id`, `label`, `label_sensitivity`, `split`, `registration_date`, `registration_year` |
| 2018 status | `status_2018` |
| Design | `phase`, `number_of_arms`, `has_dmc` (yes/no/unknown), `allocation` (NULL + single group → "Single group"), `masking`, `primary_purpose`, `intervention_model` |
| Size and timing | `enrollment_target` (99,999,999 → NULL), `planned_duration_months` (dates after 2050 → NULL), `months_registration_to_start` (negative = registered after starting), `overdue_2018` (planned completion before 2018-11-30) |
| Population | `gender`, `accepts_healthy_volunteers` ('' → NULL), `min_age_years`, `max_age_years`, `no_min_age`, `no_max_age` |
| Sites and countries | `n_sites`, `no_sites_listed`, `single_site`, `has_us_site`, `n_countries` (removed excluded), `had_country_removed` |
| Sponsor | `lead_sponsor_class`, `n_collaborators` |
| Interventions | `n_interventions`, `n_intervention_types`, `is_drug`, `is_device`, `is_biological`, `is_procedure`, `is_behavioral`, `is_radiation`, `is_dietary_supplement`, `is_other_intervention` |
| Disease area | `n_conditions`, `is_oncology` |
| Eligibility criteria (added 30 Sep) | `criteria_words`, `n_inclusion_criteria`, `n_exclusion_criteria` (log-transformed for linear models) |

Not features: `nct_id`, `label`, `label_sensitivity`, `split`, `registration_date` (identifiers, target and split). `registration_year` is only used for the split.

### Why the eligibility-criteria features were added (30 Sep 2026)
A review of published work on predicting trial termination from ClinicalTrials.gov found **eligibility-criteria complexity** (word counts, number of criteria) among the most important registry features (Elkin & Zhu, *Scientific Reports* 2021; a 2025 accrual-failure study in *Scientific Reports*). The criteria text is part of the 2018 registration record, so it's known in Dec 2018. The features were added **before any test-set scoring**, and notebook 04 was re-run with them.

## Never allowed as features
`status_2026`, `bucket`, `label`, `label_sensitivity` (they are the outcome), `why_stopped`, `actual_duration`, `were_results_reported`, `months_to_report_results`, adverse-event counts, any "actual" dates or counts, and anything from `snap_2026_09`.
