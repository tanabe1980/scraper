FROM mcr.microsoft.com/playwright/python:v1.55.0-noble

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /workspace/dl_app

# Override dependencies for local docker execution.
COPY dl_app/docker/src/requirements.txt /tmp/requirements.txt
RUN if [ -f /tmp/requirements.txt ]; then pip install -r /tmp/requirements.txt; fi

CMD ["bash", "-lc", "sleep infinity"]
