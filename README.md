# Brazilian E-Commerce Analytics Platform

An end-to-end data engineering and analytics project built on the [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (~100 k orders, 2016–2018). The project demonstrates a complete data pipeline — from raw CSVs to a normalized PostgreSQL data warehouse — with 10 production-ready business intelligence queries.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Storage | PostgreSQL 18 |
| Ingestion | Python 3 · psycopg2 |
| Analysis | SQL (window functions, CTEs) |
| Version control | Git / GitHub |

---

## Dataset

| File | Rows (approx.) | Description |
|---|---|---|
| olist_customers_dataset.csv | 99,441 | Customer profiles |
| olist_geolocation_dataset.csv | 1,000,163 | Zip-code lat/lng |
| olist_order_items_dataset.csv | 112,650 | Line items per order |
| olist_order_payments_dataset.csv | 103,886 | Payment transactions |
| olist_order_reviews_dataset.csv | 99,224 | Customer reviews |
| olist_orders_dataset.csv | 99,441 | Order header |
| olist_products_dataset.csv | 32,951 | Product catalogue |
| olist_sellers_dataset.csv | 3,095 | Seller profiles |
| product_category_name_translation.csv | 71 | PT → EN category map |

---

## Architecture

```
CSV Files (9)
     │
     ▼
load_data.py  ──► PostgreSQL (ecommerce_db)
     │                    │
     │            ┌───────┴──────────────────┐
     │            │  Normalized Schema        │
     │            │  (schema.sql)             │
     │            │                           │
     │            │  customers                │
     │            │  geolocation              │
     │            │  sellers                  │
     │            │  products ◄── category    │
     │            │  orders                   │
     │            │  order_items              │
     │            │  order_payments           │
     │            │  order_reviews            │
     │            └───────────────────────────┘
     │                    │
     ▼                    ▼
            analysis_queries.sql
            (10 BI queries)
```

**Design decisions:**
- Star-schema-style normalization with proper foreign keys for referential integrity.
- `COPY … FROM STDIN` for bulk loading — ~10× faster than row-by-row `INSERT`.
- Indexes on every foreign key and the primary timestamp column for fast analytical queries.

---

## How to Run

### Prerequisites

- PostgreSQL 15+ running locally on port 5432 (tested on PostgreSQL 18)
- Python 3.8+
- `psycopg2-binary` package

```bash
pip install psycopg2-binary
```

### Steps

1. **Clone the repository**

```bash
git clone https://github.com/Likhith252002/brazilian-ecommerce-analytics.git
cd brazilian-ecommerce-analytics
```

2. **Place the CSV files** in the project root (same directory as the scripts).

3. **Run the loader** — it will create the database, apply the schema, and load all data:

```bash
python load_data.py
```

Expected output:

```
=== Brazilian E-Commerce Data Loader ===

Database 'ecommerce_db' created.
Schema applied.

Loading CSVs …
  Loading product_category_name_translation.csv → product_category_name_translation … done  (71 rows)
  Loading olist_geolocation_dataset.csv → geolocation … done  (1,000,163 rows)
  ...
  Loading olist_order_reviews_dataset.csv → order_reviews … done  (99,224 rows)

All data loaded successfully.
```

4. **Run the analysis queries** in your preferred SQL client (psql, DBeaver, TablePlus, etc.):

```bash
psql -U postgres -d ecommerce_db -f analysis_queries.sql
```

---

## Key Business Insights

The following insights were derived from the 10 analysis queries:

### 1. Monthly Revenue Trends
Revenue grew significantly through 2017, peaking in November 2017 (Black Friday effect) with month-over-month spikes exceeding 20%. Growth plateaued in mid-2018.

### 2. Top Revenue Categories
**Health & Beauty**, **Watches & Gifts**, and **Bed/Bath/Table** consistently rank as the top 3 revenue-generating categories, together accounting for over 30% of total GMV.

### 3. Delivery Performance
Average delivery time across Brazil is ~12 days. States in the **North and Northeast regions** (AM, RR, AP) experience the longest delivery times (20+ days), while SP customers receive orders in ~8 days on average.

### 4. Payment Methods
**Credit card** is the dominant payment method (~74% of orders), with an average of 3.7 installments — reflecting Brazil's installment-payment culture. Boleto (bank slip) accounts for ~19%.

### 5. Top Sellers
The top 10 sellers by revenue are concentrated in São Paulo state and generate disproportionate GMV, suggesting a long-tail seller distribution typical of marketplace models.

### 6. Review Scores by Category
**Books** and **Home Appliances** categories score highest (avg ≥ 4.2). Categories related to electronics accessories and fashion tend to have the lowest scores, indicating potential quality or expectation-mismatch issues.

### 7. State-wise Order Volume
**SP (São Paulo)** accounts for ~42% of all orders, followed by **RJ** and **MG** — mirroring Brazil's population and GDP distribution.

### 8. Repeat Customer Rate
~97% of customers placed only a single order during the observation period, highlighting a significant opportunity for retention and loyalty programs.

### 9. Order Status Breakdown
~97% of orders reached "delivered" status. Cancellation rate is under 0.6%, and less than 1% remain in intermediate states.

### 10. Customer Lifetime Value
The top 25% of customers (CLV quartile 1) generate disproportionate revenue. Average CLV across all customers is ~R$160, with the top cohort averaging over R$400.

---

## Project Structure

```
.
├── schema.sql              # DDL — all 9 tables with FK constraints & indexes
├── load_data.py            # ETL — creates DB and bulk-loads CSVs via COPY
├── analysis_queries.sql    # 10 business intelligence SQL queries
├── README.md               # This file
└── *.csv                   # Raw Olist dataset files (not committed to git)
```

---

## Future Enhancements

- **dbt** models for a proper transformation layer
- **Apache Airflow** DAG for scheduled incremental loads
- **Metabase / Superset** dashboard for self-serve BI
- **Geospatial analysis** using PostGIS on the geolocation table
- **NLP sentiment analysis** on review comment text

---

## Data Source

Olist, "Brazilian E-Commerce Public Dataset by Olist", Kaggle, 2018.
[https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

Licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).
