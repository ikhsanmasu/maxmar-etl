# Lightweight image with dbt + Postgres adapter
ARG DBT_VERSION=1.9.0
FROM ghcr.io/dbt-labs/dbt-postgres:${DBT_VERSION}

WORKDIR /usr/app

# Install project (copy only manifesting files first to leverage layer caching)
COPY dbt_project.yml ./
COPY models ./models
COPY macros ./macros
COPY analyses ./analyses
COPY seeds ./seeds
COPY snapshots ./snapshots

# Copy profiles (can be overridden by mounting a different file at /root/.dbt/profiles.yml)
COPY profiles/profiles.yml /root/.dbt/profiles.yml

# Default to running in the project directory
ENV DBT_PROFILES_DIR=/root/.dbt

# Install packages if packages.yml exists (dbt will no-op if absent)
RUN dbt --version \
 && (test -f packages.yml && dbt deps || true)

# Default entrypoint keeps container alive for interactive use.
# Override with e.g. `docker run ... dbt run` or via compose `command:`
CMD ["tail", "-f", "/dev/null"]

