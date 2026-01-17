# Cloud run deployment

## Prerequisites Checklist
```sh
gcloud version
gcloud auth list
gcloud config list

```

## Enable Required GCP Services
```sh
# Run once per project:
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  iam.googleapis.com
```

## Create Artifact Registry (Docker Repo)
```sh
# Why?
# Artifact Registry = private Docker Hub inside GCP
# Create repo:
gcloud artifacts repositories create fastapi-repo \
  --repository-format=docker \
  --location=asia-south1 \
  --description="FastAPI Docker images"

# Verify:
gcloud artifacts repositories list
```

## Create a Dedicated Deployment Service Account
```sh
# Why not use your personal account?
# Because:
# Auditable
# Secure
# Industry standard
# Required for CI/CD later
# Create Service Account:
gcloud iam service-accounts create fastapi-deployer \
  --display-name "FastAPI Cloud Run Deployer"

# Service account email:
fastapi-deployer@PROJECT_ID.iam.gserviceaccount.com
```

## Assign IAM Roles (CRITICAL)
| Task              | Role                            |
| ----------------- | ------------------------------- |
| Push image        | `roles/artifactregistry.writer` |
| Deploy Cloud Run  | `roles/run.admin`               |
| Act as runtime SA | `roles/iam.serviceAccountUser`  |

```sh
# Assign roles:
PROJECT_ID=$(gcloud config get-value project)

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:fastapi-deployer@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:fastapi-deployer@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:fastapi-deployer@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"
```

## Allow YOU to Impersonate This Service Account
```sh
# Why?
# You don’t create keys.
# You temporarily impersonate.
# Grant impersonation permission:

gcloud iam service-accounts add-iam-policy-binding \
  fastapi-deployer@$PROJECT_ID.iam.gserviceaccount.com \
  --member="user:YOUR_EMAIL@gmail.com" \
  --role="roles/iam.serviceAccountTokenCreator"

```

## Configure Docker Authentication (IMPERSONATED)
```sh
gcloud auth configure-docker asia-south1-docker.pkg.dev \
  --impersonate-service-account=fastapi-deployer@$PROJECT_ID.iam.gserviceaccount.com

# Now Docker pushes as the service account
```

## Build Docker Image (Locally)
```sh
docker build -t fastapi-app .
```

## Tag Image for Artifact Registry
```sh
# Format:
LOCATION-docker.pkg.dev/PROJECT_ID/REPO/IMAGE:TAG

docker tag fastapi-app \
asia-south1-docker.pkg.dev/$PROJECT_ID/fastapi-repo/fastapi-app:v1

```

## Push Image (IMPERSONATED)
```sh
docker push asia-south1-docker.pkg.dev/$PROJECT_ID/fastapi-repo/fastapi-app:v1
```

## Deploy to Cloud Run (IMPERSONATED)
```sh
gcloud run deploy fastapi-service \
  --image=asia-south1-docker.pkg.dev/$PROJECT_ID/fastapi-repo/fastapi-app:v1 \
  --region=asia-south1 \
  --platform=managed \
  --allow-unauthenticated \
  --port=8080 \
  --impersonate-service-account=fastapi-deployer@$PROJECT_ID.iam.gserviceaccount.com

```

## Test Deployment
```sh
gcloud run services list
```


# 🔐 Security Best Practices (Industry)
✔ DO

- Use service account impersonation
- Use separate deployer SA
- Push only to Artifact Registry
- Restrict IAM roles

❌ DON’T

- Create service account keys
- Use Owner role
- Push images to Docker Hub for prod
