"""Scoring shared by every model notebook."""
from sklearn.metrics import average_precision_score, brier_score_loss, roc_auc_score


def evaluate(y_true, y_prob, model_name):
    """Score predicted probabilities of 'stopped early' (label 1).

    y_true      the true labels (0 = completed, 1 = stopped early)
    y_prob      the predicted probability of label 1, i.e. model.predict_proba(X)[:, 1]
    model_name  a short name for the results table

    Returns a dict, so results from several models can be collected into one DataFrame.

    pr_auc   average precision: the main metric. A model that guesses randomly scores
             about the share of positives (~0.20 here), so compare against that, not 0.
    roc_auc  how well the model ranks stopped trials above completed ones
             (0.5 = random, 1.0 = perfect).
    brier    mean squared error of the probabilities (lower = better). It checks that the
             probabilities themselves are sensible, not just the ranking.
    """
    return {
        "model": model_name,
        "n_trials": len(y_true),
        "positive_rate": float(y_true.mean()),
        "pr_auc": average_precision_score(y_true, y_prob),
        "roc_auc": roc_auc_score(y_true, y_prob),
        "brier": brier_score_loss(y_true, y_prob),
    }
