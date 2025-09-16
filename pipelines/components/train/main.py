import argparse
import joblib
import os
from sklearn.linear_model import LogisticRegression


def train(input_path: str, output_path: str):
    # Load preprocessed data
    df = joblib.load(input_path)

    X = df.drop(columns=["target"])
    y = df["target"]

    # Train logistic regression
    model = LogisticRegression(max_iter=200)
    model.fit(X, y)

    # Save model
    os.makedirs(output_path, exist_ok=True)
    model_path = os.path.join(output_path, "model.pkl")
    joblib.dump(model, model_path)

    print(f"✅ Model saved at: {model_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_path", type=str, required=True)
    parser.add_argument("--output_path", type=str, required=True)
    args = parser.parse_args()

    train(args.input_path, args.output_path)
