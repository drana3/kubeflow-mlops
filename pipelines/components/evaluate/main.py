import argparse
import joblib
import numpy as np
from sklearn.metrics import accuracy_score


def evaluate(model_path: str, input_path: str, metrics_path: str):
    # Load model & data
    model = joblib.load(model_path)
    df = joblib.load(input_path)

    X = df.drop(columns=["target"])
    y = df["target"]

    # Predict & compute accuracy
    preds = model.predict(X)
    acc = accuracy_score(y, preds)

    # Save metrics
    with open(metrics_path, "w") as f:
        f.write(f"accuracy: {acc}\n")

    print(f"✅ Evaluation done - Accuracy: {acc}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_path", type=str, required=True)
    parser.add_argument("--input_path", type=str, required=True)
    parser.add_argument("--metrics_path", type=str, required=True)
    args = parser.parse_args()

    evaluate(args.model_path, args.input_path, args.metrics_path)
