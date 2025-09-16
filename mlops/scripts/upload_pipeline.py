import argparse
from kfp.client import Client

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", required=True)
    parser.add_argument("--pipeline-file", required=True)
    args = parser.parse_args()

    client = Client(host=args.host)

    pipeline = client.upload_pipeline(
        pipeline_package_path=args.pipeline_file,
        pipeline_name="Iris Pipeline"
    )
    print(f"✅ Pipeline uploaded: {pipeline.id}")
