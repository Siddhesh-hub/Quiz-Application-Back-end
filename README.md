```markdown
# Quiz Application Backend (Spring Boot) — Dockerized

A beginner-friendly, interview-ready Docker setup for a Java 17 + Spring Boot REST API with a PostgreSQL database.

This documentation covers:
- Why Docker is useful (pros)
- Step-by-step containerization approach (beginner to advanced)
- How to run locally with Docker Compose
- How to run in a more production-like mode (hardening)
- How to build, tag, and push images to Docker Hub
- Best practices and troubleshooting

---

## What is this project?

This is a Spring Boot REST API that uses:
- Spring Web (REST endpoints)
- Spring Data JPA (ORM/database access)
- PostgreSQL (database)

Key runtime settings:
- API port: 8081
- PostgreSQL port: 5432 (internal container port; optionally exposed on host for local tooling)

Important Docker networking concept:
- When the API runs inside a container, `localhost` refers to the container itself.
- In Docker Compose, the API should connect to the DB using the service name `db`, e.g. `jdbc:postgresql://db:5432/questiondb`.

---

## Why Docker? (Pros)

Docker helps you:
1. Standardize environments: reduces “works on my machine” issues by running the app in the same environment everywhere.
2. Improve onboarding: new developers can run the stack with one command rather than installing Java/Maven/Postgres locally.
3. Increase reproducibility: versioned image tags let you deploy and roll back to exact artifacts.
4. Encourage separation of concerns: API and DB run as separate services with clean interfaces.
5. Match production patterns: healthchecks, minimal runtime images, non-root containers, and environment-based configuration.

---

## Repository structure (Docker-related)

You should have (or will create) these files in the backend folder:
- `Dockerfile` — builds a runnable Spring Boot JAR using multi-stage build
- `.dockerignore` — keeps build context small and prevents secrets/leaked files in builds
- `docker-compose.yml` — local stack (API + DB) with environment variables
- `docker-compose.prod.yml` — production-like hardening overrides
- `.env` — local environment variables (do not commit)

---

## Prerequisites

- Docker Desktop installed and running
- (Optional) Git
- (Optional) Postman/Insomnia/curl for testing endpoints

---

## Local run (recommended): Docker Compose

### 1) Create `.env` file

Create a `.env` file next to `docker-compose.yml`:

```env
POSTGRES_DB=questiondb
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password
SPRING_DATASOURCE_URL=jdbc:postgresql://db:5432/questiondb
```

Why `.env`?
- Keeps config out of images (12-factor approach)
- Makes it easy to change values without editing code
- Helps avoid committing secrets into your repository

Important: add `.env` to `.gitignore` so it isn’t pushed to GitHub.

### 2) Start the stack

From the backend folder (where `docker-compose.yml` is located):

```bash
docker compose up --build
```

What this does:
- Builds the API image using your Dockerfile
- Starts Postgres container
- Starts API container
- Creates a default internal network so `api` can reach `db` by hostname

### 3) Verify

Open:
- `http://localhost:8081`

Then test a real endpoint, for example:
- `http://localhost:8081/api/questions/getAllQuestion`

A 404 at `/` can be normal if no root route exists; the key is that the server is reachable and endpoints respond.

### 4) Stop the stack

```bash
docker compose down
```

If you run with persistent volumes, the DB data remains. If you want to delete DB data too:

```bash
docker compose down -v
```

---

## Beginner learning mode: Run without Compose (manual containers)

This is useful if you want to learn Docker networking and volumes step-by-step.

### 1) Build the API image

From the backend folder:

```bash
docker build -t quiz-api:local .
```

### 2) Create a Docker network

```bash
docker network create quiz-net
```

Why?
- Puts containers on a shared network
- Enables DNS resolution by container name
- Makes container-to-container connections simple and repeatable

### 3) Create a persistent volume for Postgres

```bash
docker volume create quiz_pg_data
```

Why?
- Without a volume, Postgres data lives only inside the container filesystem and is lost when the container is removed.
- A named volume keeps DB data across restarts.

### 4) Run Postgres (Postgres 18+ recommended mount)

Postgres 18+ images recommend mounting at `/var/lib/postgresql` (not `/var/lib/postgresql/data`) for upgrade compatibility.

```bash
docker run --name quiz-db --rm --network quiz-net \
  -v quiz_pg_data:/var/lib/postgresql \
  -e POSTGRES_DB=questiondb \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=password \
  postgres:18
```

Wait until logs show the database is ready to accept connections.

### 5) Run the API and connect to the DB

In a new terminal:

```bash
docker run --name quiz-api --rm --network quiz-net -p 8081:8081 \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://quiz-db:5432/questiondb \
  -e SPRING_DATASOURCE_USERNAME=postgres \
  -e SPRING_DATASOURCE_PASSWORD=password \
  quiz-api:local
```

Key concept:
- Inside the API container, `localhost` is the API container itself.
- Use `quiz-db` as host because that is the DB container name on the same network.

---

## Production-like run (hardening with Compose override)

A production-style setup typically:
- avoids exposing the DB port publicly
- drops unnecessary Linux capabilities
- enforces no-new-privileges
- uses read-only filesystem where possible
- uses restart policies
- uses healthchecks and “wait for readiness” patterns

Run with the production override file:

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up --build
```

Stop:

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml down
```

Note:
- “Production-like” here focuses on container hardening and safer defaults. Real production also needs TLS, observability, secrets manager, migrations, CI/CD, etc.

---

## How Dockerfile containerization works (steps and reasoning)

### Step 1: Use multi-stage build
- Build stage: Maven + JDK to compile/package
- Runtime stage: JRE only to run the JAR

Reason:
- Smaller runtime image
- Fewer tools shipped to production
- Faster pulls and lower attack surface

### Step 2: Optimize caching
Copy `pom.xml` first and download dependencies before copying source code.

Reason:
- Maven dependencies rarely change compared to source files
- Docker can cache dependency layers so rebuilds after code changes are much faster

### Step 3: Run as a non-root user (runtime)
Reason:
- Reduces security risk if the app is compromised
- Common production requirement and a good interview talking point

---

## Using the image (run commands)

### Run image with env vars (without Compose)
You still need a reachable Postgres instance.

```bash
docker run --rm -p 8081:8081 \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://<DB_HOST>:5432/questiondb \
  -e SPRING_DATASOURCE_USERNAME=postgres \
  -e SPRING_DATASOURCE_PASSWORD=password \
  yourdockerhub/quiz-backend:0.1.0
```

If your DB is another container on the same Docker network, use its container/service name as `<DB_HOST>`.

---

## Pushing the image to Docker Hub (efficient + best practices)

### 1) Login

```bash
docker login
```

### 2) Build with versioned + latest tags

```bash
docker build -t yourdockerhub/quiz-backend:0.1.0 -t yourdockerhub/quiz-backend:latest .
```

Reason:
- Version tag gives reproducibility and rollback ability
- `latest` is convenient but not safe for deployments

### 3) Push

```bash
docker push yourdockerhub/quiz-backend:0.1.0
docker push yourdockerhub/quiz-backend:latest
```

### (Optional, interview-ready) Multi-arch with Buildx

```bash
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 \
  -t yourdockerhub/quiz-backend:0.1.0 \
  -t yourdockerhub/quiz-backend:latest \
  --push .
```

Reason:
- Works on Intel/AMD and Apple Silicon
- Shows understanding of real-world deployment targets

---

## Best practices (interview notes)

1. Multi-stage builds: keep runtime images small and minimal.
2. Layer caching: copy dependency descriptors first; rebuild faster.
3. Do not bake secrets into images: use env vars, `.env`, secret managers.
4. Avoid exposing DB ports in production: DB should be internal-only.
5. Healthchecks and readiness: start order is not readiness; healthchecks reduce flaky startup.
6. Pin versions: avoid floating tags for critical base images in production for reproducibility.
7. Least privilege: non-root users, drop capabilities, no-new-privileges, read-only FS.
8. Observability: logs, metrics, tracing matter in real production deployments.
9. Database migrations: prefer Flyway/Liquibase instead of relying on runtime schema auto-update.
10. CI/CD: build, test, scan, sign, and push images through pipelines.

---

## Troubleshooting

### API fails to connect to DB
Symptom: connection refused / cannot connect.
Common cause: using `localhost` inside a container.

Fix:
- Compose: use `jdbc:postgresql://db:5432/questiondb`
- Manual network: use `jdbc:postgresql://quiz-db:5432/questiondb`

### Port already in use
If `8081` is taken:
- Map a different host port, e.g. `8082:8081` and access `http://localhost:8082`.

If `5432` is taken and you publish DB port locally:
- Map `5433:5432` and connect from host tools via `localhost:5433`.

### View logs
Compose:
```bash
docker compose logs -f
```

Manual:
```bash
docker logs quiz-api
docker logs quiz-db
```

### Reset everything (careful)
Stop and delete containers + volumes (deletes DB data):
```bash
docker compose down -v
```

---

## Common Docker commands

List running containers:
```bash
docker ps
```

List images:
```bash
docker images
```

Compose status:
```bash
docker compose ps
```

Stop and remove container:
```bash
docker stop <name>
docker rm <name>
```

Remove a volume (deletes DB data):
```bash
docker volume rm quiz_pg_data
```

---

## Notes / Next improvements
For a real production deployment, consider adding:
- Spring Boot Actuator (`/actuator/health`) for API healthchecks
- Flyway/Liquibase migrations
- A reverse proxy (TLS termination)
- Proper secret management (Docker secrets, Vault, cloud secret managers)
- CI pipeline for build + tests + security scanning + push to registry
```