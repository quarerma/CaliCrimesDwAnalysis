import os

from dotenv import load_dotenv

load_dotenv()

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "oltp")
DB_USER = os.getenv("DB_USER", "oltp")
DB_PASSWORD = os.getenv("DB_PASSWORD", "oltp")
DB_SCHEMA = os.getenv("DB_SCHEMA", "orm")

CSV_PATH = os.getenv("CSV_PATH", "Crimes_-_2001_to_Present.csv")


def sqlalchemy_url() -> str:
    return (
        f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}"
        f"@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    )


def psycopg2_dsn() -> str:
    return (
        f"host={DB_HOST} port={DB_PORT} dbname={DB_NAME} "
        f"user={DB_USER} password={DB_PASSWORD}"
    )
