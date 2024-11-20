# Copyright 2024 Google LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     https://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "project" {
  project_id = var.project_id
}

module "apis" {
  source  = "./terraform-modules/apis"
  project = data.google_project.project
}


module "iam" {
  source     = "./terraform-modules/iam"
  project    = data.google_project.project
  depends_on = [module.apis]
}

module "storage" {
  source  = "./terraform-modules/storage"
  project = data.google_project.project
  region  = var.region
  depends_on = [
    module.apis, module.iam
  ]
}


module "artifact_registry" {
  source  = "./terraform-modules/artifact_registry"
  project = data.google_project.project
  depends_on = [
    module.apis, module.iam
  ]
}

module "persistent_resource" {
  source                   = "./terraform-modules/persistent_resource"
  project                  = data.google_project.project
  persistent_resource_name = var.persistent_resource_id
  gcp_region               = var.region
  depends_on = [
    module.apis, module.iam
  ]
}

module "bigquery" {
  source  = "./terraform-modules/bigquery"
  project = data.google_project.project
  depends_on = [
    module.apis, module.iam
  ]
}

module "pubsub" {
  source     = "./terraform-modules/pubsub"
  project    = data.google_project.project
  topic_name = data.google_project.project.project_id
  depends_on = [
    module.apis, module.iam
  ]
}


module "vertex_ai_endpoint_prod" {
  source        = "./terraform-modules/vertex_ai_endpoint"
  project       = data.google_project.project
  gcp_region    = var.region
  endpoint_name = "production"
  depends_on    = [module.apis, module.iam]
}

# This module sets up Colab.
module "colab" {
  source     = "./terraform-modules/colab-enterprise"
  project    = data.google_project.project
  region     = var.region
  depends_on = [module.apis, module.iam]
}

module "tensorboard" {
  source     = "./terraform-modules/tensorboard"
  depends_on = [module.apis, module.iam]
}

locals {
  bq_sample_training_data_uri  = "bq://${data.google_project.project.project_id}.${module.bigquery.dataset.dataset_id}.uploaded_csv_sample"
  gcs_sample_training_data_uri = "${module.upload_sample.uploaded_prefix}/sample.csv"
  model_checkpoint_dir         = "${module.storage.bucket.url}/model_checkpoints"
  image_cloud_build            = "${module.artifact_registry.repo_cloud_build_uri}/img"
  image_training               = "${module.artifact_registry.repo_ml_uri}/training"
  notebook_gcs_uri             = "${module.storage.bucket.url}/continuous_training.ipynb"
  pipeline_template_path       = "https://${module.artifact_registry.repo_kfp_uri}/pipeline/latest"
  pipeline_substitutions = {
    _REGION                         = var.region
    _ARTIFACT_REGISTRY_REPO_KFP_URI = module.artifact_registry.repo_kfp_uri
    _RUNNER_SERVICE_ACCOUNT_EMAIL   = module.iam.runner_service_account.email
    _PIPELINE_ROOT                  = module.storage.bucket.url
    _MACHINE_TYPE                   = "n1-standard-4"
    _PERSISTENT_RESOURCE_NAME       = module.persistent_resource.uri
    _TRAINING_CONTAINER_IMAGE_URI   = local.image_training
    _PREDICTION_CONTAINER_IMAGE_URI = var.prediction_container_image_uri
    _PRODUCTION_ENDPOINT_ID         = module.vertex_ai_endpoint_prod.endpoint.id
    _CLOUD_BUILD_IMAGE              = local.image_cloud_build
    _TENSORBOARD                    = module.tensorboard.tensorboard.name
    _BQ_SAMPLE_TRAINING_DATA_URI    = local.bq_sample_training_data_uri
    _MODEL_CHECKPOINT_DIR           = local.model_checkpoint_dir
  }
  build_configs = [
    {
      name      = "cloud_build"
      directory = "../containers/cloud_build_image"
      substitutions = {
        _IMAGE_NAME = local.image_cloud_build
      }
    },
    {
      name      = "training"
      directory = "../containers/training"
      substitutions = {
        _IMAGE_NAME                   = local.image_training
        _RUNNER_SERVICE_ACCOUNT_EMAIL = module.iam.runner_service_account.email
        _BUCKET                       = module.storage.bucket.name
        _REGION                       = var.region
        _PERSISTENT_RESOURCE_ID       = module.persistent_resource.id
        _CLOUD_BUILD_IMAGE            = local.image_cloud_build
        _TENSORBOARD                  = module.tensorboard.tensorboard.name
        _BQ_SAMPLE_TRAINING_DATA_URI  = local.bq_sample_training_data_uri
        _MODEL_CHECKPOINT_DIR         = local.model_checkpoint_dir
      }
    },
    {
      name          = "pipeline"
      directory     = "../pipeline"
      substitutions = local.pipeline_substitutions
    },
    {
      name      = "notebook"
      directory = "../notebook"
      substitutions = merge(
        local.pipeline_substitutions,
        {
          _NOTEBOOK_GCS_URI             = local.notebook_gcs_uri
          _BUCKET                       = module.storage.bucket.name
          _PROJECT_ID                   = data.google_project.project.project_id
          _PROJECT_NUMBER               = data.google_project.project.number
          _PIPELINE_TEMPLATE_PATH       = local.pipeline_template_path
          _TRIGGER_BUCKET               = module.storage.bucket_trigger.name
          _GCS_SAMPLE_TRAINING_DATA_URI = local.gcs_sample_training_data_uri
        }
      )
    }
  ]
  build_configs_map = { for config in local.build_configs : config.name => config }
}
module "cloud_build_local_cloud_build_image" {
  source                                       = "./terraform-modules/cloud_build_local"
  project                                      = data.google_project.project
  region                                       = var.region
  builder_service_account                      = module.iam.builder_service_account
  source_dir_relative_to_main_terraform_module = local.build_configs_map["cloud_build"].directory
  substitutions                                = local.build_configs_map["cloud_build"].substitutions
  depends_on                                   = [module.apis, module.iam, module.storage]
}

module "cloud_build_local_training" {
  source                                       = "./terraform-modules/cloud_build_local"
  project                                      = data.google_project.project
  region                                       = var.region
  builder_service_account                      = module.iam.builder_service_account
  source_dir_relative_to_main_terraform_module = local.build_configs_map["training"].directory
  substitutions                                = local.build_configs_map["training"].substitutions
  depends_on                                   = [module.apis, module.iam, module.storage, module.cloud_build_local_cloud_build_image, module.listen_to_data_ingestion, module.persistent_resource, module.bigquery]
}

module "cloud_build_local_pipeline" {
  source                                       = "./terraform-modules/cloud_build_local"
  project                                      = data.google_project.project
  region                                       = var.region
  builder_service_account                      = module.iam.builder_service_account
  source_dir_relative_to_main_terraform_module = local.build_configs_map["pipeline"].directory
  substitutions                                = local.build_configs_map["pipeline"].substitutions
  depends_on                                   = [module.apis, module.iam, module.storage, module.cloud_build_local_training]
}

module "cloud_build_local_notebook" {
  source                                       = "./terraform-modules/cloud_build_local"
  project                                      = data.google_project.project
  region                                       = var.region
  builder_service_account                      = module.iam.builder_service_account
  source_dir_relative_to_main_terraform_module = local.build_configs_map["notebook"].directory
  substitutions                                = local.build_configs_map["notebook"].substitutions
  depends_on                                   = [module.apis, module.iam, module.cloud_build_local_cloud_build_image]
}

module "listen_to_pubsub" {
  source                         = "./terraform-modules/function_pubsub"
  project                        = data.google_project.project
  source_code_upload_bucket_name = module.storage.bucket.name
  pubsub_topic_id                = module.pubsub.topic.id
  builder_service_account        = module.iam.builder_service_account
  runner_service_account         = module.iam.runner_service_account
  gcp_region                     = var.region
  source_dir                     = "../functions/submit_pipeline"
  function_name                  = "submit_pipeline"
  memory                         = "512M"
  depends_on                     = [module.apis, module.iam, module.cloud_build_local_pipeline]
}

module "listen_to_data_ingestion" {
  source                         = "./terraform-modules/function_storage"
  project                        = data.google_project.project
  source_code_upload_bucket_name = module.storage.bucket.name
  trigger_bucket_name            = module.storage.bucket_trigger.name
  builder_service_account        = module.iam.builder_service_account
  runner_service_account         = module.iam.runner_service_account
  gcp_region                     = var.region
  source_dir                     = "../functions/storage_trigger"
  function_name                  = "storage_trigger"
  memory                         = "512M"
  environment_variables = {
    ARTIFACT_REGISTRY_REPO_KFP_URI = local.pipeline_template_path
    PERSISTENT_RESOURCE_NAME       = module.persistent_resource.uri
    PIPELINE_ROOT                  = module.storage.bucket.url
    PRODUCTION_ENDPOINT_ID         = module.vertex_ai_endpoint_prod.endpoint.id
    PREDICTION_CONTAINER_IMAGE_URI = var.prediction_container_image_uri
    PROJECT_ID                     = data.google_project.project.project_id
    MACHINE_TYPE                   = "n1-standard-4"
    REGION                         = var.region
    RUNNER_SERVICE_ACCOUNT_EMAIL   = module.iam.runner_service_account.email
    TENSORBOARD                    = module.tensorboard.tensorboard.name
    TRIGGER_PIPELINE_PUBSUB_TOPIC  = module.pubsub.topic.id
    TRAINING_CONTAINER_IMAGE_URI   = "${local.image_training}:latest"
    BQ_DATASET                     = module.bigquery.dataset.dataset_id
    MODEL_CHECKPOINT_DIR           = local.model_checkpoint_dir
  }
  depends_on = [
    module.apis,
    module.iam,
    module.persistent_resource,
    module.cloud_build_local_cloud_build_image
  ]
}

module "upload" {
  source         = "./terraform-modules/storage_upload"
  bucket         = module.storage.bucket_trigger
  data_directory = "../data"
  depends_on     = [module.apis, module.iam, module.listen_to_data_ingestion, module.bigquery]
}

module "upload_sample" {
  source         = "./terraform-modules/storage_upload"
  bucket         = module.storage.bucket
  data_directory = "../data"
  bucket_prefix  = "data"
  depends_on     = [module.apis, module.iam]
}
