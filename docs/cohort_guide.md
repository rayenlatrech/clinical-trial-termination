# Guide to `analysis.cohort`

A reference for the project's main table: what each column and value means, and which rows to use for what.

---

## 1. The big picture

```
aact (database)
├── snap_2018_12   raw registry as it was in Dec 2018   ← features come from here
├── snap_2026_09   raw registry as it is in Sep 2026    ← outcomes come from here
└── analysis       the project's clean layer
      └── cohort   ONE ROW PER TRIAL  ← start here
```

`analysis.cohort` is a **view**: a saved query that behaves like a table. It contains every trial in the cohort (47,210 rows), including the excluded ones, so they can still be counted.

**Who is in the cohort?** Interventional trials that were *recruiting* or *not yet recruiting* in December 2018.

---

## 2. Columns

| Column | Type | What it means |
|---|---|---|
| `nct_id` | text | The trial's unique ID on ClinicalTrials.gov, e.g. `NCT01234567`. The same in both snapshots, which is how a trial is followed from 2018 to 2026. |
| `status_2018` | text | The trial's status in Dec 2018. Always `RECRUITING` or `NOT_YET_RECRUITING` (the cohort definition). **Known in 2018, so it can be used as a feature.** |
| `status_2026` | text | The trial's status in Sep 2026. **This is the outcome, never a feature.** NULL if the trial isn't in the 2026 snapshot. |
| `bucket` | text | A readable group based on `status_2026`, e.g. `label 1: terminated` or `excluded: unknown status`. Useful for counting and reporting. |
| `label` | 0 / 1 / NULL | **The target for the model.** 1 = stopped early, 0 = completed, NULL = not used in the main analysis. |
| `label_sensitivity` | 0 / 1 / NULL | Same as `label`, but `UNKNOWN` trials count as 1. Only used for the sensitivity check. |
| `registration_date` | date | When the trial was first submitted to the registry. |
| `registration_year` | int | The year of `registration_date`. |
| `split` | text | Which part of the data the trial belongs to: `train` (registered ≤ 2016), `valid` (2017) or `test` (2018). |

---

## 3. What the statuses mean

These are ClinicalTrials.gov's official statuses, in their 2026 spelling. (2018 wrote them in title case, e.g. `Active, not recruiting`.)

**Trial finished or stopped (these become the label):**

| Status | Meaning | In this project |
|---|---|---|
| `COMPLETED` | Ended normally, as planned. | **label 0** |
| `TERMINATED` | Stopped early after enrolling participants, and won't restart. | **label 1** |
| `WITHDRAWN` | Stopped **before enrolling anyone**. | **label 1** |

**Still going, or paused (excluded):**

| Status | Meaning |
|---|---|
| `NOT_YET_RECRUITING` | Hasn't started recruiting yet. |
| `RECRUITING` | Currently recruiting participants. |
| `ENROLLING_BY_INVITATION` | Recruiting, but only from a pre-selected group. |
| `ACTIVE_NOT_RECRUITING` | Running (participants still being treated or followed), but no longer recruiting. |
| `SUSPENDED` | Paused; may restart. |

**Status not known (excluded from the main analysis, used in the sensitivity check):**

| Status | Meaning |
|---|---|
| `UNKNOWN` | The sponsor stopped updating the record: its expected end date passed and the status wasn't confirmed for 2+ years. Many of these trials were probably abandoned, but we can't tell. |

**Expanded access (excluded as "other"):** `AVAILABLE`, `NO_LONGER_AVAILABLE`, `TEMPORARILY_NOT_AVAILABLE`, `APPROVED_FOR_MARKETING`, `WITHHELD`. These describe access to an experimental drug outside a trial, not a trial's progress. Only about 10 cohort trials have them.

---

## 4. The buckets

| `bucket` | Trials | `label` | `label_sensitivity` |
|---|---|---|---|
| `label 0: completed` | 25,420 | 0 | 0 |
| `label 1: terminated` | 4,846 | 1 | 1 |
| `label 1: withdrawn` | 1,637 | 1 | 1 |
| `excluded: unknown status` | 11,326 | NULL | **1** |
| `excluded: still ongoing` | ~3,700 | NULL | NULL |
| `excluded: other` | ~10 | NULL | NULL |
| `excluded: suspended` | 207 | NULL | NULL |
| `excluded: not found in 2026` | 63 | NULL | NULL |

---

## 5. Which rows to use for what

| Task | Rows |
|---|---|
| Counting and describing the whole cohort | all 47,210 rows |
| **Training and evaluating the model** | rows where `label` is **not NULL** (31,903) |
| Training | `label` not NULL **and** `split = 'train'` (11,776) |
| Tuning / choosing between models | `label` not NULL **and** `split = 'valid'` (9,157) |
| Final result (use **once**, at the very end) | `label` not NULL **and** `split = 'test'` (10,970) |
| Sensitivity check | rows where `label_sensitivity` is not NULL, same splits |
| Robustness check | the rows above, restricted to `status_2018 = 'RECRUITING'` |

---

## 6. Rules that protect the results

1. **Features come only from `snap_2018_12`.** Anything from 2026 is the answer, not a clue.
2. **`status_2026`, `bucket`, `label` and `label_sensitivity` are never features.** They *are* the outcome.
3. **Don't look at the test set** until the model is final. Every decision you make after looking at it quietly overfits to it.
4. **With about 20% positives, a random guess scores a PR-AUC of about 0.20.** Compare every result against that, not against 0.

---

## 7. Other terms you'll meet

| Term | Meaning |
|---|---|
| **Interventional** trial | Participants receive a treatment (a drug, device, procedure…) assigned by the study. The opposite is *observational*, where researchers only watch. |
| **Phase** | The drug-development stage: Phase 1 (safety, small), Phase 2 (does it work?), Phase 3 (large confirmation), Phase 4 (after approval). Some trials are "N/A" (e.g. device or behavioural studies). |
| **Sponsor** | The organisation responsible for the trial: industry, NIH/government, or other (universities, hospitals). |
| **Facility / site** | A hospital or clinic where the trial runs. |
| **Enrolment** | The number of participants. In 2018 it's the *target*; the 2026 value may be the *actual* number, so only the 2018 value is safe to use. |
