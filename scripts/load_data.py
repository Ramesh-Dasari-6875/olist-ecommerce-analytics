"""Load the 9 Olist CSV files into PostgreSQL. Safe to re-run."""
from getpass import getpass
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

RAW = Path(__file__).resolve().parent.parent / "data" / "raw"

# (csv file, table name, columns to parse as dates), in load order
FILES = [
    ("olist_customers_dataset.csv", "customers", []),
    ("olist_sellers_dataset.csv", "sellers", []),
    ("olist_products_dataset.csv", "products", []),
    ("product_category_name_translation.csv", "category_translation", []),
    ("olist_orders_dataset.csv", "orders", [
        "order_purchase_timestamp", "order_approved_at",
        "order_delivered_carrier_date", "order_delivered_customer_date",
        "order_estimated_delivery_date"]),
    ("olist_order_items_dataset.csv", "order_items", ["shipping_limit_date"]),
    ("olist_order_payments_dataset.csv", "order_payments", []),
    ("olist_order_reviews_dataset.csv", "order_reviews",
     ["review_creation_date", "review_answer_timestamp"]),
    ("olist_geolocation_dataset.csv", "geolocation", []),
]

password = getpass("PostgreSQL password for user 'postgres': ")
engine = create_engine(URL.create(
    "postgresql+psycopg2", username="postgres", password=password,
    host="localhost", port=5432, database="olist"))

with engine.begin() as conn:
    conn.execute(text(
        "TRUNCATE order_reviews, order_payments, order_items, orders, "
        "customers, sellers, products, geolocation, category_translation"))

for csv_name, table, date_cols in FILES:
    df = pd.read_csv(RAW / csv_name, parse_dates=date_cols,
                     dtype={"customer_zip_code_prefix": str,
                            "seller_zip_code_prefix": str,
                            "geolocation_zip_code_prefix": str})
    df.to_sql(table, engine, if_exists="append", index=False,
              chunksize=10_000, method="multi")
    print(f"Loaded {len(df):>9,} rows into {table}")

print("Done.")
