# Data quality log

Record every oddity the moment you find it. This becomes the "Data" section of the README.

| Date | Snapshot | Table.column | What I found | Why it matters | Decision |
|---|---|---|---|---|---|
| 2026-09-27 | both | information_schema.tables | Compared table lists between the two snapshots. 0 tables exist only in 2018; 21 exist only in 2026 (the `all_*` convenience tables, the `search_*` / `categories` tables, `retractions`, `provided_documents`, `reported_event_totals`). | Features must come from the 2018 snapshot, so any table that didn't exist in Dec 2018 can't be a feature source. | Use only tables present in `snap_2018_12`. The 21 new tables are out of scope. Table names are unchanged, but columns still need checking (see 01b). |
