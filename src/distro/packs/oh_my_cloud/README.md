# oh_my_cloud: The Google Cloud CLI

[← Back to the README](../../../../README.md#optional-tooling-packs)

The Google Cloud CLI and the targets that drive it: projects, service accounts, buckets, BigQuery, Cloud Run, Artifact Registry, virtual machines.

The image carries no trace of Google - the install registers the repository and its key, and the removal takes both back.

**Type:** installable

## Requires

oh_my_shell, hide_my_ops.

## gmake

| Target | What it does |
| :--- | :--- |
| `gcp_auth_cli` | Authenticate the gcloud CLI (gcloud, bq) with your Google account |
| `gcp_auth_libs` | Authenticate the Python client libraries (application-default credentials) |
| `gcp_project_list` | List all GCP projects available to your account |
| `gcp_enable_compute` | Enable the Compute Engine API for the project |
| `gcp_enable_storage` | Enable the Cloud Storage API for the project |
| `gcp_enable_bigquery` | Enable the BigQuery API for the project |
| `gcp_enable_cloudrun` | Enable the Cloud Run API for the project |
| `gcp_enable_artifact_registry` | Enable the Artifact Registry API for the project |
| `gcp_enable_apis` | Enable every API the gmake modules use (the five above at once) |
| `iam_setup_service_account` | Create the Service Account and assign IAM roles |
| `vm_create` | Create the VM (run `iam_setup_service_account` first if it needs GCP API access) |
| `vm_connect` | Connect to the VM via SSH with agent forwarding |
| `vm_start` | Start the virtual machine (CPU billing resumes) |
| `vm_stop` | Stop the virtual machine (stops CPU billing) |
| `vm_delete` | Delete the virtual machine permanently |
| `vm_run_script` | Send and execute a shell script from the project on the VM |
| `gcs_list_buckets` | List all Cloud Storage buckets in the project |
| `gcs_create_bucket` | Create a new Cloud Storage bucket |
| `gcs_delete_bucket` | Delete the Cloud Storage bucket and all its contents |
| `bigquery_create_dataset` | Create the BigQuery dataset |
| `bigquery_create_table` | Create a new table in the dataset |
| `bigquery_show` | Show details of the project, dataset, or table |
| `bigquery_delete_table` | Delete a specific table |
| `bigquery_delete_dataset` | Delete the dataset and all its tables |
| `artifact_registry_create` | Create the Docker repository in Artifact Registry |
| `artifact_registry_role` | Grant yourself permission to push to Artifact Registry |
| `artifact_registry_auth` | Configure Docker to authenticate with Google Cloud |
| `artifact_registry_build` | Build the Docker image for production (linux/amd64) |
| `artifact_registry_push` | Push the production image to Artifact Registry |
| `cloudrun_deploy` | Deploy the container to Cloud Run (private unless `CLOUDRUN_PUBLIC=true`) |
| `cloudrun_list` | List all active Cloud Run services in the project |
| `cloudrun_url` | Retrieve the live URL of the deployed API |
| `cloudrun_logs` | Tail the real-time logs of the Cloud Run service |
| `cloudrun_delete` | Delete the Cloud Run service and take the API offline |

```sh
gmake gcp_auth_cli    # once per distro
gmake vm_create
gmake cloudrun_deploy
```

## Environment

Project (`.env.project`) - `gmake env_project_enable` copies the block into the
project's `.env`, filling only what is missing:

| Variable | What it means |
| :--- | :--- |
| `GCP_PROJECT` | the project id - most targets need it |
| `INSTANCE` | the VM's name |
| `MACHINE_TYPE` | the VM's machine type |
| `SA_NAME` | the service account the VM runs as |
| `VM_SCRIPT` | the script `vm_run_script` sends (path from the project root) |
| `BUCKET_NAME` | the storage bucket |
| `BQ_DATASET` | the BigQuery dataset |
| `TABLE_NAME` | a table, for the table-level targets |
| `GAR_IMAGE` | the image name in Artifact Registry |
| `ARTIFACTSREPO` | the Artifact Registry repository |
| `CLOUDRUN_PUBLIC` | `true` exposes a public URL - empty keeps the service private |
| `SERVICE_URL` | the deployed URL, filled by `cloudrun_url` |

Global (`.env.global`) - `gmake env_global_enable` copies the block into
`~/.config/zsh/gmake/.env.global`, filling only what is missing:

| Variable | What it means |
| :--- | :--- |
| `GCP_REGION` | the default region |
| `ZONE` | the default zone |
| `BQ_REGION` | where the datasets live (`EU`) - a dataset cannot be moved afterwards |
| `IMAGE_FAMILY`, `IMAGE_PROJECT` | the VM image (Ubuntu 22.04) |
| `CLOUDRUN_MEMORY` | the memory given to the Cloud Run service (`512Mi`) |

```sh
# the project's .env
GCP_PROJECT=my-project-id
INSTANCE=my-vm-instance
BUCKET_NAME=my-data-bucket

# the shared .env.global
GCP_REGION=europe-west1
ZONE=europe-west1-b
```

## Cheatsheets

Offered by `fcheat` (Alt+Z) beside every installed pack's:

| Sheet | What it covers |
| :--- | :--- |
| `gcp` | the raw `gcloud` setup, then the targets: auth, projects, APIs, service accounts, BigQuery, Cloud Run, Compute, Artifact Registry - shown while `gcloud` is installed |
