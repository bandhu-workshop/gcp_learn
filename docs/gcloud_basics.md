# gcloud basic commands

## One time install
```sh
# install verify
gcloud version
# login - human user
gcloud auth login
# List accounts
gcloud auth list
# Set default project
gcloud config set project PROJECT_ID
# Check config
gcloud config list
# Enable required APIs (do once per project)
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  iam.googleapis.com \
  storage.googleapis.com
```

## Project & Billing (Cost Safety First)
```sh
# List projects
gcloud projects list
# Describe project
gcloud projects describe PROJECT_ID
# Check billing account
gcloud beta billing projects describe PROJECT_ID
# Disable billing (nuclear option)
gcloud beta billing projects unlink PROJECT_ID
```

## Service Accounts (Very Important)
```sh
# List service accounts
gcloud iam service-accounts list
# Create service account
gcloud iam service-accounts create cloudrun-deployer \
  --display-name="Cloud Run Deployer"

# Grant roles
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:cloudrun-deployer@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:cloudrun-deployer@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.admin"

# Allow impersonation (VERY COMMON)
gcloud iam service-accounts add-iam-policy-binding \
  cloudrun-deployer@PROJECT_ID.iam.gserviceaccount.com \
  --member="user:YOUR_EMAIL@gmail.com" \
  --role="roles/iam.serviceAccountTokenCreator"

# Use impersonation locally
gcloud config set auth/impersonate_service_account \
  cloudrun-deployer@PROJECT_ID.iam.gserviceaccount.com

# Disable later:
gcloud config unset auth/impersonate_service_account
```

## Artifact Registry (Docker Images)

```sh
# List repositories
gcloud artifacts repositories list
# Create Docker repo
gcloud artifacts repositories create fastapi-repo \
  --repository-format=docker \
  --location=asia-south1 \
  --description="FastAPI images"

# Configure Docker auth
gcloud auth configure-docker asia-south1-docker.pkg.dev

# Build image (Cloud Build)
gcloud builds submit \
  --tag asia-south1-docker.pkg.dev/PROJECT_ID/fastapi-repo/app:latest

# List images
gcloud artifacts docker images list \
  asia-south1-docker.pkg.dev/PROJECT_ID/fastapi-repo

# Delete image (cost safe)
gcloud artifacts docker images delete \
  asia-south1-docker.pkg.dev/PROJECT_ID/fastapi-repo/app:latest

# Delete repository (recommended)
gcloud artifacts repositories delete fastapi-repo \
  --location=asia-south1
```

## Cloud Run (Most Used)
```sh
# Deploy service
gcloud run deploy fastapi-service \
  --image asia-south1-docker.pkg.dev/PROJECT_ID/fastapi-repo/app:latest \
  --region asia-south1 \
  --platform managed \
  --allow-unauthenticated

# List services
gcloud run services list --region asia-south1

# Describe service
gcloud run services describe fastapi-service \
  --region asia-south1

# Update env vars
gcloud run services update fastapi-service \
  --set-env-vars ENV=dev,DEBUG=true \
  --region asia-south1

# View logs
gcloud logs read \
  "resource.type=cloud_run_revision" \
  --limit=50

# DELETE Cloud Run service (VERY IMPORTANT)
gcloud run services delete fastapi-service \
  --region asia-south1
```

## Cloud Storage Buckets
```sh
# List buckets
gcloud storage buckets list
# Create bucket
gcloud storage buckets create gs://my-fastapi-bucket \
  --location=asia-south1

# Upload file
gcloud storage cp file.txt gs://my-fastapi-bucket/

# List bucket contents
gcloud storage ls gs://my-fastapi-bucket/

# Delete bucket (must be empty)
gcloud storage rm -r gs://my-fastapi-bucket
```

## Cloud Build
```sh
# List builds
gcloud builds list
# Cancel build
gcloud builds cancel BUILD_ID
```

## Logs (Safe but Useful)
```sh
# Read logs
gcloud logs read \
  "resource.type=cloud_run_service" \
  --limit=100

# Delete logs (optional)
gcloud logging logs delete \
  projects/PROJECT_ID/logs/run.googleapis.com%2Fstdout
```

## IAM Auditing (Security + Cost)
```sh
# Who has access?
gcloud projects get-iam-policy PROJECT_ID
# List enabled services
gcloud services list
# Disable unused:
gcloud services disable vision.googleapis.com
```

## Cleanup Checklist (SAVE THIS)
```sh
# Delete Cloud Run
gcloud run services delete SERVICE_NAME --region REGION
# Delete Artifact Registry
gcloud artifacts repositories delete REPO --location REGION
# Delete Buckets
gcloud storage rm -r gs://BUCKET
# Remove impersonation
gcloud config unset auth/impersonate_service_account
# (Optional) Disable billing
gcloud beta billing projects unlink PROJECT_ID
```


