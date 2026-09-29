# Feature list

Every candidate feature, where it comes from, and whether it was **known in December 2018**. Features may only come from the `snap_2018_12` schema. Anything from 2026 is the outcome.

Status: ✅ explored · ⏳ not explored yet
Last updated: 29 Sep 2026 (after notebook 02, Section 2)

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

## 3. Many-per-trial features ⏳ (notebook 02, Section 3)

| Candidate feature | Group | Source | Known in Dec 2018? | Decision |
|---|---|---|---|---|
| number of sites | Sites | `facilities` (count per trial) | ⏳ check | ⏳ |
| has a US site | Sites | `facilities.country` | ⏳ | ⏳ |
| number of countries | Sites | `countries` (check the `removed` column) | ⏳ | ⏳ |
| lead sponsor type | Sponsor | `sponsors.agency_class` where lead | ⏳ | ⏳ |
| number of collaborators | Sponsor | `sponsors` (collaborator rows) | ⏳ | ⏳ |
| intervention type(s) | Intervention | `interventions.intervention_type` | ⏳ | ⏳ |
| number of interventions | Intervention | `interventions` (count) | ⏳ | ⏳ |
| number of conditions | Disease area | `conditions` (count) | ⏳ | ⏳ |
| oncology yes/no | Disease area | `conditions.name` keywords | ⏳ | ⏳ |

---

## 4. `calculated_values` ⏳ (notebook 02, Section 4)

Each column still needs a decision: does it describe the trial as of 2018, or the future?

---

## Never allowed as features
`status_2026`, `bucket`, `label`, `label_sensitivity` (they are the outcome), `why_stopped`, any "actual" dates or counts, and anything from `snap_2026_09`.
