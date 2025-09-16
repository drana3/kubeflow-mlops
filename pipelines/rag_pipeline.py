import kfp
from kfp import dsl

# Preprocess component


@dsl.component(
    base_image="891713918387.dkr.ecr.us-east-1.amazonaws.com/kubeflow-prod-preprocess:latest"
)
def preprocess(output_path: str) -> str:
    return f"{output_path}/iris_preprocessed.pkl"


# Train component
@dsl.component(
    base_image="891713918387.dkr.ecr.us-east-1.amazonaws.com/kubeflow-prod-train:latest"
)
def train(input_path: str, output_path: str) -> str:
    return f"{output_path}/model.pkl"


# Evaluate component
@dsl.component(
    base_image="891713918387.dkr.ecr.us-east-1.amazonaws.com/kubeflow-prod-evaluate:latest"
)
def evaluate(model_path: str, input_path: str, metrics_path: str) -> str:
    return f"{metrics_path}/metrics.txt"


# Define pipeline
@dsl.pipeline(
    name="Iris Training Pipeline",
    description="An example pipeline with preprocess, train, evaluate"
)
def iris_pipeline(output_dir: str = "/data"):
    preprocess_task = preprocess(output_path=output_dir)
    train_task = train(
        input_path=preprocess_task.output,
        output_path=output_dir
    )
    evaluate_task = evaluate(
        model_path=train_task.output,
        input_path=preprocess_task.output,
        metrics_path=output_dir
    )


if __name__ == "__main__":
    kfp.compiler.Compiler().compile(
        pipeline_func=iris_pipeline,
        package_path="pipelines/rag_pipeline.yaml"
    )
