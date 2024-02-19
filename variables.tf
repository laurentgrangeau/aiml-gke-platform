variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
}

variable "region" {
  default     = "europe-west1"
  description = "The region for clusters"
  type        = string
}

variable "zones" {
  default     = []
  description = "Cluster nodes will be created in each of the following zones. These zones need to be in the region specified by the 'region' variable."
  type        = list(string)
}
