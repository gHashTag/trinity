# Trinity Cognitive Probes - Dockerfile
# Multi-stage build for reproducible evaluation environment

# Stage 1: Base image with Python
FROM python:3.11-slim AS base

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Stage 2: Development environment
FROM base AS development

WORKDIR /app

# Copy requirements first for caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install development dependencies
RUN pip install --no-cache-dir pytest pytest-cov black mypy

# Copy application code
COPY . .

# Create directories
RUN mkdir -p /app/data /app/output

# Set up entry point
ENTRYPOINT ["python", "-m", "eval.runner"]

# Stage 3: Production runtime
FROM base AS runtime

WORKDIR /app

# Copy only production dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create directories
RUN mkdir -p /app/data /app/output

# Default command
CMD ["python", "-m", "eval.runner", "--help"]

# Stage 4: Kaggle submission (minimal)
FROM base AS kaggle

WORKDIR /kaggle/working

# Install minimal runtime
COPY requirements.txt .
RUN pip install --no-cache-dir pandas numpy

# Copy evaluation code only
COPY eval/ ./eval/
COPY questions/ ./questions/

# Copy data files
COPY data/ ./data/

# Run script
COPY run_benchmark.py .

CMD ["python", "run_benchmark.py", "--dry-run"]

# Stage 5: Validation environment
FROM base AS validation

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY validate/ ./validate/
COPY data/ ./data/

ENTRYPOINT ["python", "-m", "validate"]

# Stage 6: Test environment
FROM base AS test

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt pytest pytest-cov

COPY tests/ ./tests/
COPY eval/ ./eval/
COPY questions/ ./questions/

ENTRYPOINT ["pytest", "tests/", "-v"]
