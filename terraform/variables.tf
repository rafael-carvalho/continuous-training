variable "project_id" {
  type        = string
  description = "GCP project id"
}

variable "persistent_resource_id" {
  type        = string
  description = "Id for the persistent cluster"
  default     = "my-cluster"
}

variable "prediction_container_image_uri" {
  type        = string
  description = "Prediction Container Image URI"
  default     = "us-docker.pkg.dev/vertex-ai/prediction/xgboost-cpu.1-7:latest"
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "us-central1"
}

variable "training_machine_type" {
  type        = string
  default     = "n1-standard-4"
  description = "Machine type to be used to perform custom training"
}