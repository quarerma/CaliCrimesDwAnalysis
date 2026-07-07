"""Stream the Chicago Crimes CSV into orm.crimes using Postgres COPY.

The DB is cleaned (TRUNCATE) before each load so the script is safe to
re-run, then rows are read lazily, cleaned (date parsing, dropping the
redundant Location column, empty -> NULL) and pushed straight into
orm.crimes in batches. Progress is printed per batch.
"""

import csv
import io
import os
import sys
import time
from datetime import datetime

import psycopg2

from db.config import CSV_PATH, DB_SCHEMA, psycopg2_dsn

csv.field_size_limit(10 * 1024 * 1024)

CHUNK_ROWS = 100_000
CLEAN = os.getenv("LOAD_CLEAN", "true").lower() not in ("false", "0", "no")

# Target columns in COPY order (the redundant CSV `Location` column is dropped).
TARGET_COLUMNS = [
    "id",
    "case_number",
    "crime_date",
    "block",
    "iucr",
    "primary_type",
    "description",
    "location_description",
    "arrest",
    "domestic",
    "beat",
    "district",
    "ward",
    "community_area",
    "fbi_code",
    "x_coordinate",
    "y_coordinate",
    "year",
    "updated_on",
    "latitude",
    "longitude",
]
COLS = ", ".join(TARGET_COLUMNS)

SRC_INDEX = list(range(21))
DATE_COLS = {2, 18} 


def parse_dt(value: str) -> str:
    """`MM/DD/YYYY HH:MM:SS AM/PM` -> ISO. Empty -> empty (NULL)."""
    value = value.strip()
    if not value:
        return ""
    return datetime.strptime(value, "%m/%d/%Y %I:%M:%S %p").isoformat(sep=" ")


def clean_row(row: list[str]) -> list[str]:
    out = []
    for idx in SRC_INDEX:
        val = row[idx] if idx < len(row) else ""
        if idx in DATE_COLS:
            val = parse_dt(val)
        out.append(val)
    return out


def chunks(reader):
    """Yield (csv_text, row_count) buffers of up to CHUNK_ROWS rows."""
    buf = io.StringIO()
    writer = csv.writer(buf)
    n = 0
    for row in reader:
        writer.writerow(clean_row(row))
        n += 1
        if n >= CHUNK_ROWS:
            yield buf.getvalue(), n
            buf.seek(0)
            buf.truncate(0)
            n = 0
    if n:
        yield buf.getvalue(), n


def main() -> None:
    copy_sql = (
        f'COPY "{DB_SCHEMA}".crimes ({COLS}) FROM STDIN WITH (FORMAT csv)'
    )

    conn = psycopg2.connect(psycopg2_dsn())
    conn.autocommit = False
    total = 0
    batch_no = 0
    start = time.time()

    try:
        with conn.cursor() as cur:
            if CLEAN:
                print(f'Cleaning "{DB_SCHEMA}".crimes (TRUNCATE)...', flush=True)
                cur.execute(f'TRUNCATE "{DB_SCHEMA}".crimes')

            with open(CSV_PATH, newline="", encoding="utf-8") as fh:
                reader = csv.reader(fh)
                header = next(reader)
                if len(header) != 22:
                    sys.exit(f"Unexpected header width {len(header)}: {header}")

                for chunk, rows in chunks(reader):
                    cur.copy_expert(copy_sql, io.StringIO(chunk))
                    batch_no += 1
                    total += rows
                    rate = total / max(time.time() - start, 1e-9)
                    print(
                        f"  batch {batch_no:>3} | +{rows:>6,} rows | "
                        f"{total:>10,} total | {rate:,.0f} rows/s",
                        flush=True,
                    )
            conn.commit()

            cur.execute(f'SELECT count(*) FROM "{DB_SCHEMA}".crimes')
            table_total = cur.fetchone()[0]
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    elapsed = time.time() - start
    print("\n==================== LOAD COMPLETE ====================")
    print(f"  Batches:             {batch_no:>12,}")
    print(f"  Rows loaded:         {total:>12,}")
    print(f"  Table row count now: {table_total:>12,}")
    print(f"  Elapsed:             {elapsed:>10.1f}s ({total/elapsed:,.0f} rows/s)")
    print("=======================================================")


if __name__ == "__main__":
    main()
