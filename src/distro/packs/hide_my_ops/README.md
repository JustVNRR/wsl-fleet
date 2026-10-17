# hide_my_ops

[← Back to the README](../../../../README.md#optional-tooling-packs)

Project targets: Docker, GitHub PRs.

Make targets for your projects: build and run the Docker image locally, create a GitHub pull request from the current branch, list the open ones.

Nothing is installed - the tools they call, Docker and the GitHub CLI, are already there.

**Type:** hidden - never offered; it arrives with the packs that require it.

## Required by

oh_my_cloud, oh_my_py.

## gmake

| Target | What it does |
| :--- | :--- |
| `docker_build_local` | Build the Docker image locally for testing |
| `docker_run_local` | Run the local Docker container on port 8080 |
| `gh_pr_create` | Push the current branch and create a non-interactive PR |
| `gh_pr_ls` | List open PRs in the repository |
| `gh_pr_toreview` | Add the 'toreview' label to the PR of the current branch |
| `gh_pr_wip` | Remove the 'toreview' label from the PR |

```sh
gmake docker_build_local
gmake gh_pr_create
```

## Environment

Project (`.env.project`) - `gmake env_project_enable` copies the block into the
project's `.env`, filling only what is missing:

| Variable | What it means |
| :--- | :--- |
| `PACKAGE_NAME` | the application package (`my-package`) |
| `DOCKER_BASE_IMAGE` | the image the Dockerfile starts from |
| `DOCKER_LOCAL_IMAGE` | the local image's name - refused in a shared `.env.global` |

```sh
PACKAGE_NAME=my-package
DOCKER_BASE_IMAGE=python:3.10.6-slim
DOCKER_LOCAL_IMAGE=my_project-image
```

## Cheatsheets

Offered by `fcheat` (Alt+Z) beside every installed pack's:

| Sheet | What it covers |
| :--- | :--- |
| `devops` | the project targets: Docker images and the GitHub pull requests, from a project's root |
| `docker` | docker: images, containers, compose, debugging, cleanup - shown while `docker` is installed |
