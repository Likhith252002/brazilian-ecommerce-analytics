"""
load_data.py
Brazilian E-Commerce Analytics Platform

Creates the ecommerce_db database (if it does not exist), applies schema.sql,
and bulk-loads all 9 Olist CSVs into PostgreSQL using COPY for maximum speed.

Requirements:
    pip install psycopg2-binary

Usage:
    python load_data.py
"""

import os
import sys
import psycopg2
from psycopg2 import sql
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

# ---------------------------------------------------------------------------
# Connection settings
# ---------------------------------------------------------------------------
HOST     = "localhost"
PORT     = 5432
USER     = "postgres"
PASSWORD = "Tampa@33613"
DB_NAME  = "ecommerce_db"

# Folder that contains this script and the CSV files
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SCHEMA   = os.path.join(BASE_DIR, "schema.sql")

# ---------------------------------------------------------------------------
# CSV → table mapping (order matters: parents before children)
# ---------------------------------------------------------------------------
LOAD_ORDER = [
    ("product_category_name_translation.csv", "product_category_name_translation"),
    ("olist_geolocation_dataset.csv",          "geolocation"),
    ("olist_customers_dataset.csv",            "customers"),
    ("olist_sellers_dataset.csv",              "sellers"),
    ("olist_products_dataset.csv",             "products"),
    ("olist_orders_dataset.csv",               "orders"),
    ("olist_order_items_dataset.csv",          "order_items"),
    ("olist_order_payments_dataset.csv",       "order_payments"),
    ("olist_order_reviews_dataset.csv",        "order_reviews"),
]


def create_database() -> None:
    """Create ecommerce_db if it does not already exist."""
    conn = psycopg2.connect(host=HOST, port=PORT, user=USER,
                            password=PASSWORD, dbname="postgres")
    conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
    cur = conn.cursor()
    cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (DB_NAME,))
    if cur.fetchone():
        print(f"Database '{DB_NAME}' already exists — skipping creation.")
    else:
        cur.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(DB_NAME)))
        print(f"Database '{DB_NAME}' created.")
    cur.close()
    conn.close()


def get_conn() -> psycopg2.extensions.connection:
    return psycopg2.connect(host=HOST, port=PORT, user=USER,
                            password=PASSWORD, dbname=DB_NAME)


def apply_schema(conn) -> None:
    """Run schema.sql against ecommerce_db."""
    with open(SCHEMA, "r", encoding="utf-8") as f:
        ddl = f.read()
    with conn.cursor() as cur:
        cur.execute(ddl)
    conn.commit()
    print("Schema applied.")


def load_csv(conn, filename: str, table: str) -> None:
    """Bulk-load a CSV into *table* using PostgreSQL COPY.

    For tables with a known PK duplicate issue in the raw data (order_reviews),
    data is staged into a temporary table first and deduplicated on insert.
    """
    filepath = os.path.join(BASE_DIR, filename)
    if not os.path.exists(filepath):
        print(f"  [WARN] File not found, skipping: {filepath}")
        return

    with open(filepath, "r", encoding="utf-8-sig") as f, conn.cursor() as cur:
        if table == "order_reviews":
            # Stage into a temp table then insert distinct rows, keeping the
            # first occurrence of each review_id (raw data contains duplicates).
            cur.execute(
                "CREATE TEMP TABLE order_reviews_stage "
                "(LIKE order_reviews) ON COMMIT DROP"
            )
            cur.copy_expert(
                "COPY order_reviews_stage FROM STDIN "
                "WITH (FORMAT CSV, HEADER TRUE, NULL '')",
                f,
            )
            cur.execute(
                """
                INSERT INTO order_reviews
                SELECT DISTINCT ON (review_id) *
                FROM   order_reviews_stage
                ORDER  BY review_id
                ON CONFLICT (review_id) DO NOTHING
                """
            )
        else:
            cur.copy_expert(
                f"COPY {table} FROM STDIN "
                f"WITH (FORMAT CSV, HEADER TRUE, NULL '')",
                f,
            )
    conn.commit()


def main() -> None:
    print("=== Brazilian E-Commerce Data Loader ===\n")

    # 1. Create database
    create_database()

    # 2. Connect to ecommerce_db and apply schema
    conn = get_conn()
    apply_schema(conn)

    # 3. Load CSVs
    print("\nLoading CSVs …")
    for filename, table in LOAD_ORDER:
        print(f"  Loading {filename} → {table} … ", end="", flush=True)
        try:
            load_csv(conn, filename, table)
            # Quick row count
            with conn.cursor() as cur:
                cur.execute(f"SELECT COUNT(*) FROM {table}")
                count = cur.fetchone()[0]
            print(f"done  ({count:,} rows)")
        except Exception as exc:
            conn.rollback()
            print(f"ERROR: {exc}")
            sys.exit(1)

    conn.close()
    print("\nAll data loaded successfully.")


if __name__ == "__main__":
    main()
