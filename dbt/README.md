Welcome to your new dbt project!

### Using the starter project

Try running the following commands:
- dbt run
- dbt test


### Resources:
- Learn more about dbt [in the docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [chat](https://community.getdbt.com/) on Slack for live discussions and support
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices

### Run with Docker

This project includes a Docker setup for running dbt against a local Postgres
started from `db-destination/docker-compose.yml` (port `5435`).

1) Start Postgres (from repo root):
   - `docker compose -f db-destination/docker-compose.yml up -d`

2) Build and start dbt container (from `maxmar_analytics/`):
   - `docker compose build`
   - `docker compose up -d`

3) Execute dbt commands inside the container:
   - `docker exec -it dbt-maxmar-analytics dbt debug`
   - `docker exec -it dbt-maxmar-analytics dbt run`
   - `docker exec -it dbt-maxmar-analytics dbt test`

Connection settings are controlled via environment variables and default to:

- `DB_HOST=host.docker.internal`
- `DB_PORT=5435`
- `DB_NAME=analytics`
- `DB_USER=postgres`
- `DB_PASSWORD=postgres`
- `DBT_SCHEMA=public`

To change them, pass env vars to compose, e.g.:

- `DBT_SCHEMA=maxmar` -> `docker compose --env-file .env up -d`

You can also override the included `profiles/profiles.yml` by bind-mounting your
own at `/root/.dbt/profiles.yml` in the `docker-compose.yml`.


