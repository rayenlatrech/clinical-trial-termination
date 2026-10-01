"""The two final model pipelines, built exactly as in notebook 04."""
from lightgbm import LGBMClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline

from src.features import BINARY, CATEGORICAL, LOG_NUMERIC, NUMERIC
from src.preprocess import make_preprocessor, make_tree_preprocessor


def make_logreg(max_iter=2000):
    """Logistic regression on all features (the primary model)."""
    return Pipeline([
        ("prep", make_preprocessor(categorical=CATEGORICAL, log_numeric=LOG_NUMERIC,
                                   numeric=NUMERIC, binary=BINARY)),
        ("model", LogisticRegression(max_iter=max_iter)),
    ])


def make_lgbm(num_leaves=31, min_child_samples=20, n_estimators=300, learning_rate=0.05):
    """LightGBM with the same fixed settings as notebook 04's make_lgbm."""
    return Pipeline([
        ("prep", make_tree_preprocessor(CATEGORICAL)),
        ("model", LGBMClassifier(
            num_leaves=num_leaves,
            min_child_samples=min_child_samples,
            n_estimators=n_estimators,
            learning_rate=learning_rate,
            subsample=0.8, subsample_freq=1,
            colsample_bytree=0.8,
            random_state=42,
            verbose=-1,
        )),
    ])
