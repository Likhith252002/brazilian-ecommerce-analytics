-- Brazilian E-Commerce Analytics Platform
-- PostgreSQL Schema

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS order_reviews CASCADE;
DROP TABLE IF EXISTS order_payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS sellers CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS geolocation CASCADE;
DROP TABLE IF EXISTS product_category_name_translation CASCADE;

-- Product category translations
CREATE TABLE product_category_name_translation (
    product_category_name         VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100) NOT NULL
);

-- Geolocation
CREATE TABLE geolocation (
    geolocation_zip_code_prefix   CHAR(5)       NOT NULL,
    geolocation_lat               NUMERIC(18,14) NOT NULL,
    geolocation_lng               NUMERIC(18,14) NOT NULL,
    geolocation_city              VARCHAR(100)   NOT NULL,
    geolocation_state             CHAR(2)        NOT NULL
);

-- Customers
CREATE TABLE customers (
    customer_id              VARCHAR(32) PRIMARY KEY,
    customer_unique_id       VARCHAR(32) NOT NULL,
    customer_zip_code_prefix CHAR(5)     NOT NULL,
    customer_city            VARCHAR(100) NOT NULL,
    customer_state           CHAR(2)      NOT NULL
);

-- Sellers
CREATE TABLE sellers (
    seller_id              VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix CHAR(5)      NOT NULL,
    seller_city            VARCHAR(100) NOT NULL,
    seller_state           CHAR(2)      NOT NULL
);

-- Products
CREATE TABLE products (
    product_id                   VARCHAR(32)  PRIMARY KEY,
    product_category_name        VARCHAR(100),
    product_name_lenght          SMALLINT,
    product_description_lenght   INT,
    product_photos_qty           SMALLINT,
    product_weight_g             INT,
    product_length_cm            SMALLINT,
    product_height_cm            SMALLINT,
    product_width_cm             SMALLINT
);

-- Orders
CREATE TABLE orders (
    order_id                      VARCHAR(32) PRIMARY KEY,
    customer_id                   VARCHAR(32) NOT NULL,
    order_status                  VARCHAR(20) NOT NULL,
    order_purchase_timestamp      TIMESTAMP,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
);

-- Order items
CREATE TABLE order_items (
    order_id             VARCHAR(32) NOT NULL,
    order_item_id        SMALLINT    NOT NULL,
    product_id           VARCHAR(32) NOT NULL,
    seller_id            VARCHAR(32) NOT NULL,
    shipping_limit_date  TIMESTAMP,
    price                NUMERIC(10,2) NOT NULL,
    freight_value        NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id),
    FOREIGN KEY (order_id)    REFERENCES orders   (order_id),
    FOREIGN KEY (product_id)  REFERENCES products (product_id),
    FOREIGN KEY (seller_id)   REFERENCES sellers  (seller_id)
);

-- Order payments
CREATE TABLE order_payments (
    order_id              VARCHAR(32)   NOT NULL,
    payment_sequential    SMALLINT      NOT NULL,
    payment_type          VARCHAR(30)   NOT NULL,
    payment_installments  SMALLINT      NOT NULL,
    payment_value         NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential),
    FOREIGN KEY (order_id) REFERENCES orders (order_id)
);

-- Order reviews
CREATE TABLE order_reviews (
    review_id                VARCHAR(32) PRIMARY KEY,
    order_id                 VARCHAR(32) NOT NULL,
    review_score             SMALLINT    NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title     TEXT,
    review_comment_message   TEXT,
    review_creation_date     TIMESTAMP,
    review_answer_timestamp  TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders (order_id)
);

-- Indexes for common join / filter columns
CREATE INDEX idx_orders_customer_id        ON orders      (customer_id);
CREATE INDEX idx_orders_purchase_timestamp ON orders      (order_purchase_timestamp);
CREATE INDEX idx_order_items_product_id    ON order_items (product_id);
CREATE INDEX idx_order_items_seller_id     ON order_items (seller_id);
CREATE INDEX idx_order_payments_order_id   ON order_payments (order_id);
CREATE INDEX idx_order_reviews_order_id    ON order_reviews  (order_id);
CREATE INDEX idx_geolocation_zip           ON geolocation (geolocation_zip_code_prefix);
