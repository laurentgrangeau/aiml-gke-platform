resource "google_service_account" "default" {
  account_id   = "service-account-id"
  display_name = "Service Account"
}

resource "google_container_cluster" "primary" {
  provider = google-beta
  name     = "my-gke-cluster"
  location = var.region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  monitoring_config {
    managed_prometheus {
      enabled = true
    }
  }
}

resource "google_container_node_pool" "primary_node_pool" {
  name    = "primary-node-pool"
  cluster = google_container_cluster.primary.id
  node_count = 0

  autoscaling {
    min_node_count  = 0
    max_node_count  = 3
    location_policy = "ANY"
  }

  node_config {
    machine_type = "e2-standard-2"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

resource "google_container_node_pool" "a100_node_pool" {
  provider   = google-beta
  name       = "a100-node-pool"
  cluster    = google_container_cluster.primary.id
  node_count = 0

  queued_provisioning {
    enabled = true
  }

  autoscaling {
    min_node_count  = 0
    max_node_count  = 10
    location_policy = "ANY"
  }

  node_config {
    machine_type = "a2-highgpu-1g"

    reservation_affinity {
      consume_reservation_type = "NO_RESERVATION"
    }

    guest_accelerator {
      type  = "nvidia-tesla-a100"
      count = 1
      gpu_driver_installation_config {
        gpu_driver_version = "LATEST"
      }
    }

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

resource "google_gke_hub_membership" "membership" {
  membership_id = "my-membership"
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.primary.id}"
    }
  }
}

resource "google_gke_hub_feature" "feature" {
  name     = "configmanagement"
  location = "global"
}

resource "google_gke_hub_feature_membership" "name" {
  location   = "global"
  feature    = google_gke_hub_feature.feature.name
  membership = google_gke_hub_membership.membership.id

  configmanagement {
    version = "1.17.1"
    config_sync {
      git {
        sync_repo                 = "https://github.com/GoogleCloudPlatform/cloud-foundation-toolkit.git"
        sync_branch               = "master"
        policy_dir                = "config-management-samples/config-sync"
        secret_type               = "gcpserviceaccount"
        gcp_service_account_email = google_service_account.default.email
      }
    }
  }
}
