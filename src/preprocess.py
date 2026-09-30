"""Preprocessing shared by every model notebook.

All the steps that LEARN something from the data (medians, scaling, the list of
categories) live in one ColumnTransformer. Put inside a Pipeline with a model,
.fit() learns them from the training data only, and the same fitted steps are then
reused on validation and test data. That's what keeps test information out of training.
"""
import numpy as np
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import FunctionTransformer, OneHotEncoder, StandardScaler


def make_preprocessor(categorical=(), log_numeric=(), numeric=(), binary=()):
    """Build the ColumnTransformer for the given column lists.

    categorical  text columns -> fill missing with "missing", then one-hot encode
    log_numeric  skewed, non-negative sizes and counts -> median fill, log(1 + x), scale
    numeric      other numbers (can be negative) -> median fill, scale
    binary       0/1 flags -> fill missing with the most frequent value, keep as 0/1

    Pass only the lists you need (e.g. just `categorical` for a small baseline).
    """
    branches = []
    if categorical:
        branches.append(("cat", Pipeline([
            ("impute", SimpleImputer(strategy="constant", fill_value="missing")),
            # ignore categories that appear in validation/test but not in train
            ("onehot", OneHotEncoder(handle_unknown="ignore", sparse_output=False)),
        ]), list(categorical)))
    if log_numeric:
        branches.append(("log_num", Pipeline([
            ("impute", SimpleImputer(strategy="median")),
            # log1p shrinks huge values (e.g. 2,000,000 participants) so they don't dominate
            ("log", FunctionTransformer(np.log1p, feature_names_out="one-to-one")),
            ("scale", StandardScaler()),
        ]), list(log_numeric)))
    if numeric:
        branches.append(("num", Pipeline([
            ("impute", SimpleImputer(strategy="median")),
            ("scale", StandardScaler()),
        ]), list(numeric)))
    if binary:
        branches.append(("bin", SimpleImputer(strategy="most_frequent"), list(binary)))
    return ColumnTransformer(branches, verbose_feature_names_out=False)
