# docker-celery

Container image for running [Celery](https://docs.celeryq.dev/) workers with the Redis transport. Bring your own `tasks.py`.

Images are built for `linux/amd64` and `linux/arm64`, run as a non-root user and ship with an SBOM, build provenance and a keyless signature.

## Images

Images are published to GitHub Container Registry as `ghcr.io/think-cube/celery`.

| Tag | Meaning | Changes? |
|---|---|---|
| `1.0.0` | Exact release | Never |
| `1.0`, `1`, `latest` | Newest matching release | With each release |
| `edge` | Newest build of `main` | With each merge and weekly rebuild |
| `edge-YYYYMMDD` | Weekly rebuild of `main` with current OS patches | Never |
| `sha-<commit>` | Build of one `main` commit | Never |

For production, pin by digest: `ghcr.io/think-cube/celery:1.0.0@sha256:...`.

## Usage

Put your tasks in `tasks.py`:

```python
import os

from celery import Celery

app = Celery(
    "tasks",
    broker=os.environ.get("CELERY_BROKER_URL", "redis://redis:6379/0"),
    backend=os.environ.get("CELERY_RESULT_BACKEND", "redis://redis:6379/1"),
)


@app.task
def add(x, y):
    return x + y
```

Start Redis and a worker on a shared network:

```bash
docker network create celery
docker run -d --name redis --network celery redis:8-alpine
docker run -d --name worker --network celery \
  -v "$PWD:/app:ro" \
  ghcr.io/think-cube/celery:1
```

The worker runs `celery -A tasks worker --loglevel=info` in `/app`. Override the command to start something else, for example `celery -A tasks beat`. The image runs as UID/GID `10001`, so mounted files must be readable by that user.

For production, build your own image on top of this one and copy your code in, instead of mounting it:

```dockerfile
FROM ghcr.io/think-cube/celery:1.0.0@sha256:...
COPY --chown=10001:10001 . /app
```

## What is in the image

- Celery with the Redis transport (`celery[redis]`). RabbitMQ (AMQP) works as well, since Celery always includes it.
- Python on Alpine Linux, in the versions named on the `FROM` line of the `Dockerfile`
- Python packages pinned with hashes in `requirements.txt`, generated from `requirements.in`

Python moves to a new minor version only once Celery declares support for it.

## Verify an image

Check the signature:

```bash
cosign verify ghcr.io/think-cube/celery:1.0.0 \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github\.com/Think-Cube/workflows/\.github/workflows/container-image\.yml@refs/tags/v.+$'
```

Read the SBOM and provenance:

```bash
docker buildx imagetools inspect ghcr.io/think-cube/celery:1.0.0 --format '{{ json .SBOM }}'
docker buildx imagetools inspect ghcr.io/think-cube/celery:1.0.0 --format '{{ json .Provenance }}'
```

## Build and test locally

```bash
docker build -t celery:local .
bash tests/smoke.sh celery:local
```

The smoke test starts Redis and a worker, sends a task and checks the result.

To change a Python dependency, edit `requirements.in` and regenerate the lock file:

```bash
pip-compile --generate-hashes --output-file=requirements.txt requirements.in
```

## Support

Only the newest release receives fixes. `main` is rebuilt every week, and images with fixable critical vulnerabilities are not published. Report security issues through [GitHub private vulnerability reporting](https://github.com/Think-Cube/docker-celery/security/advisories/new).

## License

This project is licensed under the [MIT License](LICENSE).

## Contribution

Feel free to contribute by opening issues or pull requests. Your feedback and improvements are highly appreciated!
