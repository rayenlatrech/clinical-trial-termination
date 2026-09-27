# Predicting clinical trial termination

> Status: 🚧 work in progress (week 1: data exploration)

Can we tell early, using only what a trial's public registration says, whether it will stop before it finishes?

## Problem statement

**Question.** Using only information publicly available on ClinicalTrials.gov in **December 2018**, predict which trials that had not yet finished recruiting will end up **terminated or withdrawn** rather than **completed**.

**Why it matters.** Trials that stop early waste funding and expose patients to research that produces no answer. Sponsors and CROs spend a lot of effort deciding whether a trial is likely to recruit and finish. A model that flags high-risk trials at registration time could support that decision.

**Design ("time machine").** Two monthly snapshots of the AACT database:
- **Dec 2018 snapshot → features.** Everything the model sees comes from this snapshot, so it only knows what was knowable at the time.
- **Sep 2026 snapshot → outcome.** The same trials (matched on `nct_id`), about 8 years later.

**Population.**
- Interventional trials
- with status *Not yet recruiting* or *Recruiting* in the Dec 2018 snapshot.

**Outcome (from the Sep 2026 snapshot).**
- Positive (1): *Terminated* or *Withdrawn*
- Negative (0): *Completed*

**Excluded, then counted and reported (not dropped silently):**
- trials still ongoing in 2026 (recruiting, active, enrolling by invitation, not yet recruiting)
- *Suspended* and *Unknown status* trials
- trials that can't be found in the 2026 snapshot

**Evaluation.**
- Time-based split: train on trials registered earlier, test on the most recently registered ones. No random split.
- Metrics: PR-AUC (the positive class is the minority), ROC-AUC, and calibration.

**Baselines to beat.**
1. Predict the majority class for every trial.
2. Logistic regression on trial phase and sponsor type only.

### Open decisions
- [ ] **Withdrawn vs Terminated:** one class, or separate? (Withdrawn means it stopped before enrolling anyone; Terminated means it stopped after starting.)
- [ ] **Unknown status:** excluding these may bias the results, because abandoned trials often end up as "unknown". Check how many there are before deciding.
- [ ] **The exact registration date** used to split training and test data.

## Data

[AACT](https://aact.ctti-clinicaltrials.org/) (Aggregate Analysis of ClinicalTrials.gov), from the Clinical Trials Transformation Initiative. Monthly PostgreSQL snapshots:

| Snapshot | Studies |
|---|---|
| Dec 2018 | 291,109 |
| Sep 2026 | 604,561 |

The data isn't included in this repo because it's too large. See **Setup** to rebuild it locally. Data issues found along the way are recorded in [`docs/data_quality_log.md`](docs/data_quality_log.md).

## Repository structure

```
sql/              SQL queries (exploration, cohort, features)
notebooks/        exploration and modelling notebooks
src/              reusable Python code
reports/figures/  saved plots
docs/             data-quality log and notes
```

## Setup

1. Install PostgreSQL (version 14 or newer).
2. From AACT, download the **Dec 2018** and **Sep 2026** PostgreSQL dump snapshots.
3. Restore both into one database, then rename each schema:
   ```
   createdb -U postgres aact
   pg_restore -U postgres -d aact --no-owner --no-privileges <2018 dump>
   psql -U postgres -d aact -c "ALTER SCHEMA ctgov RENAME TO snap_2018_12;"
   pg_restore -U postgres -d aact --no-owner --no-privileges <2026 dump>
   psql -U postgres -d aact -c "ALTER SCHEMA ctgov RENAME TO snap_2026_09;"
   ```
4. Create the Python environment (Python 3.12+):
   ```
   python -m venv .venv
   .venv\Scripts\activate          # Windows  (macOS/Linux: source .venv/bin/activate)
   pip install -r requirements.txt
   ```
5. Copy `.env.example` to `.env` and fill in your database password.

## Roadmap
- [ ] Week 1: explore both snapshots; table of how 2018 statuses ended up in 2026
- [ ] Week 2: cohort and label, features, leakage check, baselines
- [ ] Week 3: gradient boosting, time-based evaluation, error analysis, write-up
