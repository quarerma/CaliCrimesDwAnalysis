## Iniciar Projeto

```bash
docker compose up -d                       # start oltp_database
python -m venv .venv && ./.venv/bin/pip install -r requirements.txt
source .venv/bin/activate
python create_schema.py
python load_data.py
```

## URLs

PgAdmin: localhost:5050
OLTP: localhost:5433
