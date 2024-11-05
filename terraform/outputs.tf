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

output "artifact_registry_repo_kfp_uri" {
  value = module.artifact_registry.repo_kfp_uri
}

output "bq_dataset" {
  value = module.bigquery.dataset.dataset_id
}

output "bq_sample_training_data_uri" {
  value = local.bq_sample_training_data_uri
}

output "builder_service_account_email" {
  value = module.iam.builder_service_account.email
}

output "bucket_name" {
  value = module.storage.bucket.name
}

output "colab_url" {
  value = module.colab.colab_url
}

output "gcs_sample_training_data_uri" {
  value = local.gcs_sample_training_data_uri
}

output "model_checkpoint_dir" {
  value = local.model_checkpoint_dir
}

output "notebook_gcs_uri" {
  value = local.notebook_gcs_uri
}

output "pipeline_template_path" {
  value = local.pipeline_template_path
}

output "persistent_resource_name" {
  value = module.persistent_resource.uri
}

output "prediction_container_image_uri" {
  value = var.prediction_container_image_uri
}

output "production_endpoint_id" {
  value = module.vertex_ai_endpoint_prod.endpoint.id
}

output "project_id" {
  value = data.google_project.project.project_id
}

output "project_number" {
  value = data.google_project.project.number
}

output "region" {
  value = var.region
}

output "runner_service_account_email" {
  value = module.iam.runner_service_account.email
}

output "tensorboard" {
  value = module.tensorboard.tensorboard.name
}

output "training_container_image_uri" {
  value = local.image_training
}

output "training_machine_type" {
  value = var.training_machine_type
}

output "trigger_bucket" {
  value = module.storage.bucket_trigger.name
}

output "trigger_pipeline_pubsub_topic" {
  value = module.pubsub.topic.id
}