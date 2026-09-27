# Data quality log

Record every oddity the moment you find it. This becomes the "Data" section of the README.

| Date | Snapshot | Table.column | What I found | Why it matters | Decision |
|---|---|---|---|---|---|
| 2026-09-27 | both | information_schema.tables | Compared table lists between the two snapshots. 0 tables exist only in 2018; 21 exist only in 2026 (the `all_*` convenience tables, the `search_*` / `categories` tables, `retractions`, `provided_documents`, `reported_event_totals`). | Features must come from the 2018 snapshot, so any table that didn't exist in Dec 2018 can't be a feature source. | Use only tables present in `snap_2018_12`. The 21 new tables are out of scope. Table names are unchanged, but columns still need checking (see 01b). |
| 2026-09-27 | both | studies (all columns) | Compared the columns of `studies` between snapshots. 0 columns exist only in 2018; 7 exist only in 2026: `baseline_type_units_analyzed`, `delayed_posting`, `expanded_access_nctid`, `expanded_access_status_for_nctid`, `fdaaa801_violation`, `patient_registry`, `source_class`. | No renames or drops, so no column mapping is needed. The new columns didn't exist in Dec 2018, and `fdaaa801_violation` / `delayed_posting` describe what happened after registration, so they would leak the outcome anyway. | Use only columns present in `snap_2018_12.studies`. Take sponsor type from the `sponsors` table instead of `source_class`. Column names match, but value spellings still need checking (query 02). |
