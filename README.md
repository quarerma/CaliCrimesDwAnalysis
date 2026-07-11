# CaliCrimes DW Analysis

Chicago Crimes (2001–present) turned into a Postgres data warehouse with **dbt**
and reported on with **Power BI**.

```
CSV  ──load_data.py──►  orm.crimes (OLTP)  ──dbt──►  dw_marts (star schema)  ──►  Power BI
```

## 1. Load the OLTP database

```bash
docker compose up -d                       # start oltp_database (+ pgadmin)
python -m venv .venv && ./.venv/bin/pip install -r requirements.txt
source .venv/bin/activate
python create_schema.py
python load_data.py
```

## 2. Build the warehouse with dbt

The dbt project lives in `dbt/`. Its `profiles.yml` defaults to the same
connection as `.env`, so no extra config is needed.

```bash
cd dbt
dbt debug   --profiles-dir .   # test the connection
dbt build   --profiles-dir .   # build models + run tests
dbt docs generate --profiles-dir . && dbt docs serve --profiles-dir .   # browse docs
```

Models (`dbt/models/`):

| Layer   | Model            | Schema       | Grain                |
|---------|------------------|--------------|----------------------|
| staging | `stg_crimes`     | `dw_staging` | one crime (cleaned)  |
| marts   | `dim_date`       | `dw_marts`   | one calendar day     |
| marts   | `dim_crime_type` | `dw_marts`   | one IUCR code        |
| marts   | `dim_location`   | `dw_marts`   | one location combo   |
| marts   | `fct_crimes`     | `dw_marts`   | one reported crime   |

Column descriptions & tests live in the `schema.yml` files
(`dbt/models/staging/*.yml`, `dbt/models/marts/schema.yml`) — edit the
`description:` fields there to document columns; they flow into `dbt docs`.

## 3. Power BI (Desktop + Report Builder)

Power BI Desktop and Report Builder are **Windows-only** Microsoft apps — no
native Linux build exists. To run them on this Linux host, use the bundled
Windows-in-Docker VM (requires `/dev/kvm`, already present here):

```bash
docker compose -f docker-compose.powerbi.yml up -d
# open http://localhost:8006  (Windows installs itself on first boot)
```

Inside Windows, download & install:
- Power BI Desktop: https://www.microsoft.com/download/details.aspx?id=58494
- Report Builder:   https://www.microsoft.com/download/details.aspx?id=104976

Then connect Power BI to the DW (see the header of
`docker-compose.powerbi.yml` for exact steps): PostgreSQL, server
`20.20.20.1:5433`, database `oltp`, schema `dw_marts`, user/pass `oltp`/`oltp`.

## URLs

| Service   | URL / Port          | Credentials        |
|-----------|---------------------|--------------------|
| OLTP      | `localhost:5433`    | `oltp` / `oltp`    |
| PgAdmin   | `localhost:5050`    | `admin@oltp.com` / `admin` |
| Power BI  | `localhost:8006`    | `poweruser` / `poweruser`  |
