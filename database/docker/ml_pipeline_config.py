#!/usr/bin/env python3
"""
ML Pipeline Configuration for Claude Learning System
Implements continuous training and model management
"""

import json
import os
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional


class ModelType(Enum):
    AGENT_SELECTOR = "agent_selector"
    PERFORMANCE_PREDICTOR = "performance_predictor"
    TASK_CLASSIFIER = "task_classifier"
    ANOMALY_DETECTOR = "anomaly_detector"
    EMBEDDING_GENERATOR = "embedding_generator"


class TrainingSchedule(Enum):
    CONTINUOUS = "continuous"
    HOURLY = "hourly"
    DAILY = "daily"
    WEEKLY = "weekly"
    ON_DEMAND = "on_demand"


@dataclass
class ModelConfig:
    """Configuration for individual ML models"""

    name: str
    type: ModelType
    algorithm: str
    hyperparameters: Dict[str, Any] = field(default_factory=dict)
    features: List[str] = field(default_factory=list)
    target: str = ""
    version: str = "1.0.0"
    training_schedule: TrainingSchedule = TrainingSchedule.DAILY
    min_training_samples: int = 100
    max_training_samples: int = 10000
    validation_split: float = 0.2
    test_split: float = 0.1
    metrics: List[str] = field(
        default_factory=lambda: ["accuracy", "precision", "recall", "f1"]
    )
    threshold_metrics: Dict[str, float] = field(default_factory=dict)


@dataclass
class PipelineConfig:
    """Main ML pipeline configuration"""

    name: str = "Claude Learning Pipeline"
    version: str = "3.1.0"
    models: List[ModelConfig] = field(default_factory=list)
    preprocessing_steps: List[str] = field(default_factory=list)
    feature_engineering: Dict[str, Any] = field(default_factory=dict)
    data_sources: List[str] = field(default_factory=list)
    output_path: str = "/app/data/models"
    log_path: str = "/app/logs/ml_pipeline"
    checkpoint_interval: int = 100
    enable_distributed: bool = False
    enable_gpu: bool = False
    enable_monitoring: bool = True
    alert_thresholds: Dict[str, float] = field(default_factory=dict)


class MLPipelineBuilder:
    """Builder for creating ML pipeline configurations"""

    @staticmethod
    def create_default_pipeline() -> PipelineConfig:
        """Create default ML pipeline configuration"""

        pipeline = PipelineConfig(
            preprocessing_steps=[
                "remove_duplicates",
                "handle_missing_values",
                "normalize_features",
                "encode_categorical",
                "generate_embeddings",
            ],
            feature_engineering={
                "time_features": ["hour", "day_of_week", "month"],
                "aggregations": ["mean", "std", "min", "max"],
                "window_sizes": [5, 10, 30],
                "interaction_features": True,
            },
            data_sources=[
                "postgresql://claude_auth",
                "api://learning_system",
                "file:///app/data/training",
            ],
            alert_thresholds={
                "model_accuracy": 0.8,
                "training_loss": 0.5,
                "prediction_latency": 100,
                "memory_usage": 0.9,
            },
        )

        pipeline.models = [
            ModelConfig(
                name="agent_selector_model",
                type=ModelType.AGENT_SELECTOR,
                algorithm="random_forest",
                hyperparameters={
                    "n_estimators": 100,
                    "max_depth": 10,
                    "min_samples_split": 5,
                    "min_samples_leaf": 2,
                    "max_features": "sqrt",
                    "bootstrap": True,
                    "oob_score": True,
                },
                features=[
                    "task_complexity",
                    "task_type_encoded",
                    "historical_success_rate",
                    "avg_execution_time",
                    "resource_requirements",
                    "agent_availability",
                ],
                target="selected_agent",
                training_schedule=TrainingSchedule.HOURLY,
                threshold_metrics={"accuracy": 0.85, "precision": 0.80, "recall": 0.80},
            ),
            ModelConfig(
                name="performance_predictor_model",
                type=ModelType.PERFORMANCE_PREDICTOR,
                algorithm="gradient_boosting",
                hyperparameters={
                    "n_estimators": 200,
                    "learning_rate": 0.1,
                    "max_depth": 5,
                    "subsample": 0.8,
                    "min_samples_split": 10,
                    "min_samples_leaf": 5,
                },
                features=[
                    "agent_id_encoded",
                    "task_complexity",
                    "historical_performance",
                    "system_load",
                    "time_features",
                    "recent_failures",
                ],
                target="execution_time",
                training_schedule=TrainingSchedule.DAILY,
                threshold_metrics={"mae": 5.0, "rmse": 10.0, "r2": 0.75},
            ),
            ModelConfig(
                name="task_classifier_model",
                type=ModelType.TASK_CLASSIFIER,
                algorithm="neural_network",
                hyperparameters={
                    "hidden_layers": [128, 64, 32],
                    "activation": "relu",
                    "dropout": 0.3,
                    "learning_rate": 0.001,
                    "batch_size": 32,
                    "epochs": 100,
                    "early_stopping_patience": 10,
                },
                features=[
                    "task_embedding",
                    "keyword_features",
                    "complexity_score",
                    "requirement_vector",
                ],
                target="task_category",
                training_schedule=TrainingSchedule.WEEKLY,
                threshold_metrics={"accuracy": 0.90, "f1": 0.85},
            ),
            ModelConfig(
                name="anomaly_detector_model",
                type=ModelType.ANOMALY_DETECTOR,
                algorithm="isolation_forest",
                hyperparameters={
                    "n_estimators": 100,
                    "contamination": 0.1,
                    "max_samples": "auto",
                    "random_state": 42,
                },
                features=[
                    "execution_time_zscore",
                    "error_rate",
                    "resource_usage",
                    "pattern_deviation",
                ],
                target="is_anomaly",
                training_schedule=TrainingSchedule.CONTINUOUS,
                threshold_metrics={"precision": 0.90, "recall": 0.70},
            ),
            ModelConfig(
                name="embedding_generator_model",
                type=ModelType.EMBEDDING_GENERATOR,
                algorithm="doc2vec",
                hyperparameters={
                    "vector_size": 256,
                    "window": 5,
                    "min_count": 2,
                    "epochs": 40,
                    "dm": 1,
                    "dbow_words": 1,
                },
                features=["task_description", "agent_capabilities", "context"],
                target="embedding_vector",
                training_schedule=TrainingSchedule.ON_DEMAND,
                min_training_samples=1000,
            ),
        ]

        return pipeline

    @staticmethod
    def save_config(config: PipelineConfig, path: str) -> None:
        """Save pipeline configuration to JSON file"""
        config_dict = {
            "name": config.name,
            "version": config.version,
            "models": [
                {
                    "name": m.name,
                    "type": m.type.value,
                    "algorithm": m.algorithm,
                    "hyperparameters": m.hyperparameters,
                    "features": m.features,
                    "target": m.target,
                    "version": m.version,
                    "training_schedule": m.training_schedule.value,
                    "min_training_samples": m.min_training_samples,
                    "max_training_samples": m.max_training_samples,
                    "validation_split": m.validation_split,
                    "test_split": m.test_split,
                    "metrics": m.metrics,
                    "threshold_metrics": m.threshold_metrics,
                }
                for m in config.models
            ],
            "preprocessing_steps": config.preprocessing_steps,
            "feature_engineering": config.feature_engineering,
            "data_sources": config.data_sources,
            "output_path": config.output_path,
            "log_path": config.log_path,
            "checkpoint_interval": config.checkpoint_interval,
            "enable_distributed": config.enable_distributed,
            "enable_gpu": config.enable_gpu,
            "enable_monitoring": config.enable_monitoring,
            "alert_thresholds": config.alert_thresholds,
        }

        Path(path).parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w") as f:
            json.dump(config_dict, f, indent=2)

    @staticmethod
    def load_config(path: str) -> PipelineConfig:
        """Load pipeline configuration from JSON file"""
        with open(path, "r") as f:
            config_dict = json.load(f)

        config = PipelineConfig(
            name=config_dict["name"],
            version=config_dict["version"],
            preprocessing_steps=config_dict["preprocessing_steps"],
            feature_engineering=config_dict["feature_engineering"],
            data_sources=config_dict["data_sources"],
            output_path=config_dict["output_path"],
            log_path=config_dict["log_path"],
            checkpoint_interval=config_dict["checkpoint_interval"],
            enable_distributed=config_dict["enable_distributed"],
            enable_gpu=config_dict["enable_gpu"],
            enable_monitoring=config_dict["enable_monitoring"],
            alert_thresholds=config_dict["alert_thresholds"],
        )

        config.models = [
            ModelConfig(
                name=m["name"],
                type=ModelType(m["type"]),
                algorithm=m["algorithm"],
                hyperparameters=m["hyperparameters"],
                features=m["features"],
                target=m["target"],
                version=m["version"],
                training_schedule=TrainingSchedule(m["training_schedule"]),
                min_training_samples=m["min_training_samples"],
                max_training_samples=m["max_training_samples"],
                validation_split=m["validation_split"],
                test_split=m["test_split"],
                metrics=m["metrics"],
                threshold_metrics=m["threshold_metrics"],
            )
            for m in config_dict["models"]
        ]

        return config


def create_ml_pipeline_config():
    """Create and save default ML pipeline configuration"""
    pipeline = MLPipelineBuilder.create_default_pipeline()

    config_path = os.environ.get("ML_CONFIG_PATH", "/app/config/ml_pipeline.json")
    MLPipelineBuilder.save_config(pipeline, config_path)

    print(f"ML Pipeline configuration saved to {config_path}")
    print(f"Pipeline version: {pipeline.version}")
    print(f"Number of models: {len(pipeline.models)}")
    print(f"Models configured:")
    for model in pipeline.models:
        print(f"  - {model.name} ({model.algorithm}): {model.training_schedule.value}")

    return pipeline


if __name__ == "__main__":
    create_ml_pipeline_config()
