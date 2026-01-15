# Simple FastAPI deployment to Google Cloud Run

## What we are building:

- A FastAPI service
- Containerized using Docker
- Deployed on Google Cloud Run
- Image stored in Artifact Registry
- Access controlled via Service Accounts
- CI/CD using GitHub Actions
- Infra managed using Terraform
- Secrets via Secret Manager
- Database later via Cloud SQL (Postgres) + migrations

This mirrors how companies deploy Python APIs on GCP.

## Docker commands

Build an drun the dokcer

```sh
# build the docker image
docker build -t fastapi-uv -f Dockerfile .
# run the docker container
docker run --rm -d -p 8080:8080 --name fastapi-uv fastapi-uv
```

test the local docker container

```sh
curl http://localhost:8080
# or
open http://localhost:8080/docs

```
