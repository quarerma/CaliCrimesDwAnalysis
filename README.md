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

### Dimensions (10)

| Model | Grain | Rows |
|---|---|---|
| `dim_date` | one calendar day | 9,311 |
| `dim_month` ▽ | one month | 306 |
| `dim_time_of_day` | one minute of the day | 1,440 |
| `dim_hour` ▽ | one hour | 24 |
| `dim_crime_type` | one IUCR code | 418 |
| `dim_crime_category` ▽ | one primary_type | 33 |
| `dim_location` | one admin geography combo | 2,446 |
| `dim_location_type` | one kind of place | 219 |
| `dim_block` | one city block | 65,968 |
| `dim_community_area` | one community area | 79 |

▽ = shrunken conformed dimension (rollup of a base dimension).

### Facts (6)

| Model | Kimball type | Grain | Rows |
|---|---|---|---|
| `fct_crimes` | Transaction | one reported crime | 8,587,983 |
| `fct_monthly_crime_types` | Periodic snapshot | month × crime type | 75,552 |
| `fct_crime_types_cumulative` | Cumulative snapshot | month × crime type (dense) | 127,908 |
| `fct_monthly_area_crimes` | Periodic snapshot | month × area × category | 382,043 |
| `fct_hourly_crime_profile` | Aggregate (profile) | hour × weekday × type | 48,403 |
| `fct_block_location_profile` | Aggregate (profile) | block × location type | 632,399 |

Every derived fact is built **from `fct_crimes`**, never from staging, and a test
in `dbt/tests/` reconciles each one back to the atomic fact. `dbt build` runs
**91 tests**.

Column documentation lives in the model `.sql` headers, next to the code it
describes; `schema.yml` carries model descriptions and the data tests.

## Documentação dimensional

| Documento | Conteúdo |
|---|---|
| [`docs/01-modelagem-dimensional.md`](docs/01-modelagem-dimensional.md) | Processos de negócio, granularidades, dimensões, fatos, aditividade, métricas-armadilha |
| [`docs/02-diagrama-estrela.md`](docs/02-diagrama-estrela.md) | Diagramas do modelo estrela + linhagem (DAG) |
| [`docs/03-matriz-barramento.md`](docs/03-matriz-barramento.md) | Matriz de barramento e dimensões conformadas |

## 3. Power BI (Desktop + Report Builder)

Power BI Desktop and Report Builder are **Windows-only** Microsoft apps — no
native Linux build exists.

The simplest path is to run Power BI Desktop on a **real Windows machine** and
point it at this Postgres over the LAN (use `hostname -I` on the host to get the
IP, port `5433`, database `oltp`, schema `dw_marts`, user/pass `oltp`/`oltp`).

A bundled Windows-in-Docker VM (`docker-compose.powerbi.yml`) also exists, but it
needs **~30 GB of free disk** for the Windows install plus a ~6 GB ISO download.
Check `df -h /` before starting it — if `/` is tight, the install will die
partway through:

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
