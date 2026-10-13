FROM python:3.11-slim AS build

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . /app

# Expose port (if any)
EXPOSE 8080

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV LEANS_WORKER_REGISTRY_PATH=/mnt/data1/time-2026/09-september/18/lean-worker
ENV LEANS_WORKER_REGISTRY_JSON=/mnt/data1/time-2026/09-september/18/lean-worker/contexts/registry/registry.json
ENV PIP_NO_CACHE_DIR=1

# Run the application
CMD ["python3", "minimal/lean_worker_registry.lean", "--mode=prod"]