import kfp
from kfp import dsl


def preprocess_op():
    return dsl.ContainerOp(
        name="Preprocess",
        image="891713918387.dkr.ecr.us-east-1.amazonaws.com/kubeflow-prod-preprocess:latest",
        arguments=["--output_path", "/data"],
        file_outputs={
            "output": "/data/iris_preprocessed.pkl"
        }
    )


def train_op(input_path):
    return dsl.ContainerOp(
        name="Train",
        image="891713918387.dkr.ecr.us-east-1.amazonaws.com/kubeflow-prod-train:latest",
        arguments=["--input_path", input_path, "--output_path", "/model"],
        file_outputs={
            "model": "/model/model.pkl"
        }
    )


def evaluate_op(model_path, input_path):
    return dsl.ContainerOp(
        name="Evaluate",
        image="891713918387.dkr.ecr.us-east-1.amazonaws.com/kubeflow-prod-evaluate:latest",
        arguments=["--model_path", model_path, "--input_path",
                   input_path, "--metrics_path", "/metrics.txt"],
        file_outputs={
            "metrics": "/metrics.txt"
        }
    )


@dsl.pipeline(
    name="Iris Training Pipeline",
    description="An example pipeline with preprocess, train, evaluate"
)
def iris_pipeline():
    preprocess = preprocess_op()
    train = train_op(preprocess.outputs["output"])
    evaluate = evaluate_op(
        train.outputs["model"], preprocess.outputs["output"])


if __name__ == "__main__":
    kfp.compiler.Compiler().compile(iris_pipeline, "pipelines/rag_pipeline.yaml")
