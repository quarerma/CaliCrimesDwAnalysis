# CaliCrimes DW Analysis

## 1. Run the Docker Compose stack

```bash
docker compose up -d
```

This starts the PostgreSQL database and pgAdmin.

- Database: http://localhost:5433
  - Host: localhost
  - Port: 5433
  - Database: oltp
  - User: oltp
  - Password: oltp
- pgAdmin: http://localhost:5050
  - Email: admin@oltp.com
  - Password: admin

> Put the source CSV file in the project root, next to [README.md](README.md) and rename it to [export.csv](export.csv), before running the loader.

## 2. Run the scripts in this order

```bash
python create_schema.py
python load_data.py
python run_dbt_build.py
```

## 3. URLs

| Service  | URL / Port       | Credentials                |
| -------- | ---------------- | -------------------------- |
| OLTP     | `localhost:5433` | `oltp` / `oltp`            |
| PgAdmin  | `localhost:5050` | `admin@oltp.com` / `admin` |
| Power BI | `localhost:8006` | `poweruser` / `poweruser`  |
