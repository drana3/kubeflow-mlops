import argparse
from kfp.client import Client

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", required=True)
    parser.add_argument("--pipeline-file", required=True)
    parser.add_argument("--params", default="{}")
    args = parser.parse_args()

    client = Client(host=args.host)

    experiment = client.create_experiment("Iris Experiment")
    run = client.run_pipeline(
        experiment_id=experiment.id,
        job_name="iris-run",
        pipeline_package_path=args.pipeline_file,
        params=eval(args.params)
    )
    print(f"✅ Pipeline run started: {run.id}")
