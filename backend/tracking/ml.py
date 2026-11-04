from pathlib import Path

import joblib
import numpy as np

from sklearn.ensemble import IsolationForest

from .models import Telemetry


# Features used by the model
FEATURES = ["speed", "activity", "lat", "lon"]

# Save the trained model beside this Python file
MODEL_PATH = Path(__file__).with_name("isolation_forest.joblib")


def train_model():
    """
    Train one shared Isolation Forest model using
    existing telemetry readings from all trackers.
    """

    readings = Telemetry.objects.exclude(
        speed__isnull=True
    ).exclude(
        activity__isnull=True
    ).values_list(
        "speed", "activity", "lat", "lon"
    )

    X = np.asarray(list(readings), dtype=float)

    # Remove invalid values
    X = X[np.isfinite(X).all(axis=1)]

    if len(X) < 50:
        raise ValueError(
            f"Not enough training data: {len(X)} readings. "
            "At least 50 are required."
        )

    model = IsolationForest(
        n_estimators=200,
        contamination="auto",
        random_state=42,
        n_jobs=-1
    )

    model.fit(X)

    # Save the model and its metadata
    joblib.dump(
        {
            "model": model,
            "features": FEATURES,
            "trained_samples": len(X)
        },
        MODEL_PATH
    )

    return {
        "status": "success",
        "trained_samples": len(X),
        "model_path": str(MODEL_PATH)
    }


def detect_anomaly(speed, activity, lat, lon):
    """
    Analyse one telemetry reading using the trained model.
    """

    if not MODEL_PATH.exists():
        raise FileNotFoundError(
            "Model not found. Train the model first."
        )

    saved = joblib.load(MODEL_PATH)
    model = saved["model"]

    X = np.asarray(
        [[speed, activity, lat, lon]],
        dtype=float
    )

    if not np.isfinite(X).all():
        raise ValueError("Invalid telemetry values.")

    prediction = int(model.predict(X)[0])

    return {
        "is_anomaly": prediction == -1,
        "anomaly_score": float(model.score_samples(X)[0]),
        "decision_score": float(model.decision_function(X)[0])
    }