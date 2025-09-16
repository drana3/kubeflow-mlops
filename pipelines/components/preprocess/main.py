import argparse
import pandas as pd
from sklearn.datasets import load_iris
import joblib
import os


def preprocess(output_path: str):
    # Load dataset
    iris = load_iris(as_frame=True)
    df = iris.frame

    # Normalize numeric features
    features = df.drop(columns=["target"])
    normalized = (features - features.mean()) / features.std()
    df_normalized = pd.concat([normalized, df["target"]], axis=1)

    # Save preprocessed dataset
    os.makedirs(output_path, exist_ok=True)
    output_file = os.path.join(output_path, "iris_preprocessed.pkl")
    joblib.dump(df_normalized, output_file)

    print(f"✅ Preprocessed dataset saved at: {output_file}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output_path", type=str, required=True)
    args = parser.parse_args()

    preprocess(args.output_path)
