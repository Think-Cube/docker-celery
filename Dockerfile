FROM python:3.14-alpine3.24@sha256:5862d971d1f0ae26b258cefa4e893556b1d3aba81bd2ff30888704ad378bab67

LABEL org.opencontainers.image.title="celery" \
      org.opencontainers.image.description="Celery worker with the Redis transport in a non-root image" \
      org.opencontainers.image.vendor="Think-Cube" \
      org.opencontainers.image.authors="contact@thinkcube.dev" \
      org.opencontainers.image.licenses="MIT"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# The upgrade is what lets the weekly rebuild pick up security patches
# while the base image stays pinned by digest.
RUN apk upgrade --no-cache

COPY requirements.txt /tmp/requirements.txt

RUN pip install --no-cache-dir --root-user-action=ignore --only-binary=:all: --require-hashes \
        -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

RUN addgroup -S -g 10001 celery && \
    adduser -S -D -H -u 10001 -G celery celery

WORKDIR /app

USER 10001:10001

CMD ["celery", "-A", "tasks", "worker", "--loglevel=info"]
