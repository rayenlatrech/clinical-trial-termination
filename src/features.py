"""The feature lists and the loading step, shared by the model notebooks (04 and 05).

The column groups match docs/feature_list.md (Section 5) and sql/07_features_view.sql.
41 features: 9 categorical, 9 log-numeric, 6 numeric, 17 binary.
"""
import pandas as pd
from sqlalchemy import text

from src.db import engine

# Columns that are NOT features: identifiers, the two labels, and the split
NON_FEATURES = [
    "nct_id", "label", "label_sensitivity", "split",
    "registration_date", "registration_year",
]

CATEGORICAL = [
    "status_2018", "phase", "has_dmc", "allocation", "masking",
    "primary_purpose", "intervention_model", "gender", "lead_sponsor_class",
]

# Skewed, non-negative sizes and counts: log-transformed for linear models
LOG_NUMERIC = [
    "enrollment_target", "n_sites", "n_countries",
    "n_collaborators", "n_interventions", "n_conditions",
    # eligibility-criteria complexity (added after the literature review, before any test scoring)
    "criteria_words", "n_inclusion_criteria", "n_exclusion_criteria",
]

# Other numbers (some can be negative): only scaled for linear models
NUMERIC = [
    "number_of_arms", "planned_duration_months", "months_registration_to_start",
    "min_age_years", "max_age_years", "n_intervention_types",
]

BINARY = [
    "overdue_2018", "accepts_healthy_volunteers", "no_min_age", "no_max_age",
    "no_sites_listed", "single_site", "has_us_site", "had_country_removed",
    "is_drug", "is_device", "is_biological", "is_procedure", "is_behavioral",
    "is_radiation", "is_dietary_supplement", "is_other_intervention", "is_oncology",
]

ALL_FEATURES = CATEGORICAL + LOG_NUMERIC + NUMERIC + BINARY
assert len(ALL_FEATURES) == 41


def load_features(label_column="label"):
    """Load analysis.features, keeping only the trials that have a value in `label_column`.

    label_column="label"              main analysis (unknown status excluded)
    label_column="label_sensitivity"  sensitivity check (unknown status counted as stopped)
    """
    with engine.connect() as conn:
        df = pd.read_sql(text("SELECT * FROM analysis.features"), conn)
    return df[df[label_column].notna()].reset_index(drop=True)


def split_xy(df, split, label_column="label"):
    """Return (X, y) for one split ('train', 'valid' or 'test')."""
    part = df[df["split"] == split]
    return part[ALL_FEATURES], part[label_column]
