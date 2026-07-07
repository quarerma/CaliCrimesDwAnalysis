from sqlalchemy import create_engine, text

from db.config import DB_SCHEMA, sqlalchemy_url
from db.models import Base


def main() -> None:
    engine = create_engine(sqlalchemy_url())
    with engine.begin() as conn:
        conn.execute(text(f'CREATE SCHEMA IF NOT EXISTS "{DB_SCHEMA}"'))
    Base.metadata.create_all(engine)
    print(f'Schema "{DB_SCHEMA}" and table "{DB_SCHEMA}".crimes are ready.')


if __name__ == "__main__":
    main()
