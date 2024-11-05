# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import argparse
import numpy as np
import logging
import pandas as pd
import xgboost as xgb
from sklearn.metrics import accuracy_score  # Or any other relevant metric
from train import preprocess_data  # Import the preprocessing function


def load_predictor(model_dir: str) -> xgb.XGBClassifier:  # or xgb.XGBRegressor
    from google.cloud.aiplatform.prediction.xgboost.predictor import XgboostPredictor

    predictor = XgboostPredictor()
    predictor.load(model_dir)
    return predictor


def evaluate(model_dir: str, data_path: str) -> None:
    """Evaluates the model on the given data."""

    print("Starting evaluation...")
    print(f"Model directory: {model_dir}")
    print(f"Data path: {data_path}")
    from sklearn.datasets import load_iris

    if not data_path:
        print("Data path not provided... will create something")
        iris = load_iris()
        iris_df = pd.DataFrame(
            data=np.c_[iris["data"], iris["target"]],
            columns=iris["feature_names"] + ["target"],
        )
        iris_df.to_csv("iris.csv", index=False)

        data_path = "iris.csv"
        print(f"Will use {data_path}")

    print("Will load predictor")
    # Load the model
    predictor = load_predictor(model_dir)

    print("Will read data_path")
    try:
        # Load and preprocess the evaluation data
        df = pd.read_csv(data_path)  # use pandas for CSV
    except Exception as e:

        print(f"Error while reading {data_path}: {e}")

    X_eval, y_eval = preprocess_data(df)
    instances = {"instances": X_eval.values.tolist()}
    preprocessed = predictor.preprocess(instances)

    # Evaluate the model
    y_pred = predictor.predict(preprocessed)

    accuracy = accuracy_score(y_eval, y_pred)

    print(f"Evaluation complete. Accuracy: {accuracy}")
    return accuracy


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Evaluate an XGBoost model.")
    import os

    parser.add_argument(
        "--model_dir",
        type=str,
        required=True,
        help="Directory containing the saved model.",
    )
    parser.add_argument(
        "--data_path",
        type=str,
        required=True,
        help="Path to the evaluation data (CSV).",
    )
    args = parser.parse_args()

    evaluate(args.model_dir, args.data_path)
