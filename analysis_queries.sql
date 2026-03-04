-- ============================================================
-- Brazilian E-Commerce Analytics Platform
-- Business Analysis Queries
-- ============================================================

-- ---------------------------------------------------------------
-- Q1: Monthly Revenue Trends
-- Total revenue (items + freight) per month, with MoM % change.
-- ---------------------------------------------------------------
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
        ROUND(SUM(oi.price + oi.freight_value)::NUMERIC, 2) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1
)
SELECT
    TO_CHAR(month, 'YYYY-MM')                         AS month,
    revenue,
    LAG(revenue) OVER (ORDER BY month)                AS prev_month_revenue,
    ROUND(
        100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
              / NULLIF(LAG(revenue) OVER (ORDER BY month), 0),
        2
    )                                                  AS mom_pct_change
FROM monthly
ORDER BY month;


-- ---------------------------------------------------------------
-- Q2: Top Product Categories by Revenue
-- Revenue and order count per English category name.
-- ---------------------------------------------------------------
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name, 'Uncategorized') AS category,
    COUNT(DISTINCT oi.order_id)                                AS total_orders,
    ROUND(SUM(oi.price)::NUMERIC, 2)                          AS total_revenue,
    ROUND(AVG(oi.price)::NUMERIC, 2)                          AS avg_item_price
FROM order_items oi
JOIN orders     o  ON oi.order_id   = o.order_id
JOIN products   p  ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
       ON p.product_category_name = t.product_category_name
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY 1
ORDER BY total_revenue DESC
LIMIT 20;


-- ---------------------------------------------------------------
-- Q3: Average Delivery Time by State
-- Avg days from purchase to delivery for each customer state.
-- ---------------------------------------------------------------
SELECT
    c.customer_state,
    COUNT(o.order_id)                                          AS delivered_orders,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            o.order_delivered_customer_date - o.order_purchase_timestamp
        )) / 86400
    )::NUMERIC, 1)                                            AS avg_delivery_days,
    ROUND(AVG(
        EXTRACT(EPOCH FROM (
            o.order_estimated_delivery_date - o.order_delivered_customer_date
        )) / 86400
    )::NUMERIC, 1)                                            AS avg_days_early_vs_estimate
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_delivery_days;


-- ---------------------------------------------------------------
-- Q4: Payment Method Breakdown
-- Distribution of revenue and orders by payment type.
-- ---------------------------------------------------------------
SELECT
    payment_type,
    COUNT(DISTINCT order_id)              AS total_orders,
    ROUND(SUM(payment_value)::NUMERIC, 2) AS total_revenue,
    ROUND(AVG(payment_value)::NUMERIC, 2) AS avg_order_value,
    ROUND(AVG(payment_installments), 1)   AS avg_installments,
    ROUND(
        100.0 * COUNT(DISTINCT order_id)
              / SUM(COUNT(DISTINCT order_id)) OVER (),
        2
    )                                     AS pct_of_orders
FROM order_payments
GROUP BY payment_type
ORDER BY total_revenue DESC;


-- ---------------------------------------------------------------
-- Q5: Top 10 Sellers by Revenue
-- Identifies highest-earning sellers with order and product counts.
-- ---------------------------------------------------------------
SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT oi.order_id)                  AS total_orders,
    COUNT(DISTINCT oi.product_id)                AS unique_products,
    ROUND(SUM(oi.price)::NUMERIC, 2)             AS total_revenue,
    ROUND(AVG(r.review_score), 2)                AS avg_review_score
FROM order_items oi
JOIN sellers s ON oi.seller_id = s.seller_id
JOIN orders  o ON oi.order_id  = o.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY s.seller_id, s.seller_city, s.seller_state
ORDER BY total_revenue DESC
LIMIT 10;


-- ---------------------------------------------------------------
-- Q6: Average Review Score by Product Category
-- Satisfaction levels across categories, weighted by review count.
-- ---------------------------------------------------------------
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name, 'Uncategorized') AS category,
    COUNT(r.review_id)                  AS total_reviews,
    ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_review_score,
    SUM(CASE WHEN r.review_score = 5 THEN 1 ELSE 0 END) AS five_star_count,
    SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) AS low_score_count
FROM order_reviews r
JOIN orders      o  ON r.order_id    = o.order_id
JOIN order_items oi ON o.order_id    = oi.order_id
JOIN products    p  ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t
       ON p.product_category_name = t.product_category_name
WHERE r.review_score IS NOT NULL
GROUP BY 1
HAVING COUNT(r.review_id) >= 30          -- minimum sample for reliability
ORDER BY avg_review_score DESC;


-- ---------------------------------------------------------------
-- Q7: State-wise Order Volume
-- Total orders and revenue per Brazilian state.
-- ---------------------------------------------------------------
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id)                   AS total_orders,
    COUNT(DISTINCT c.customer_unique_id)         AS unique_customers,
    ROUND(SUM(oi.price + oi.freight_value)::NUMERIC, 2) AS total_revenue,
    ROUND(
        AVG(oi.price + oi.freight_value)::NUMERIC, 2
    )                                            AS avg_order_value
FROM orders    o
JOIN customers  c  ON o.customer_id  = c.customer_id
JOIN order_items oi ON o.order_id   = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_state
ORDER BY total_orders DESC;


-- ---------------------------------------------------------------
-- Q8: Repeat Customer Analysis
-- Segments customers by purchase frequency.
-- ---------------------------------------------------------------
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
)
SELECT
    CASE
        WHEN order_count = 1 THEN '1 – One-time buyer'
        WHEN order_count = 2 THEN '2 – Repeat (2 orders)'
        WHEN order_count BETWEEN 3 AND 5 THEN '3-5 – Loyal'
        ELSE '6+ – VIP'
    END                                       AS customer_segment,
    COUNT(*)                                  AS customer_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    )                                         AS pct_of_customers
FROM customer_orders
GROUP BY 1
ORDER BY MIN(order_count);


-- ---------------------------------------------------------------
-- Q9: Order Status Breakdown
-- Distribution of all orders across fulfillment statuses.
-- ---------------------------------------------------------------
SELECT
    order_status,
    COUNT(*)                                   AS order_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    )                                          AS pct_of_total
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


-- ---------------------------------------------------------------
-- Q10: Customer Lifetime Value (CLV)
-- Total spend, order frequency, and avg order value per unique customer,
-- ranked by lifetime value.
-- ---------------------------------------------------------------
WITH clv AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id)                        AS total_orders,
        ROUND(SUM(oi.price + oi.freight_value)::NUMERIC, 2) AS lifetime_value,
        ROUND(
            AVG(oi.price + oi.freight_value)::NUMERIC, 2
        )                                                 AS avg_order_value,
        MIN(o.order_purchase_timestamp)::DATE             AS first_order_date,
        MAX(o.order_purchase_timestamp)::DATE             AS last_order_date
    FROM customers   c
    JOIN orders      o  ON c.customer_id  = o.customer_id
    JOIN order_items oi ON o.order_id     = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
)
SELECT
    customer_unique_id,
    total_orders,
    lifetime_value,
    avg_order_value,
    first_order_date,
    last_order_date,
    (last_order_date - first_order_date)         AS customer_lifespan_days,
    NTILE(4) OVER (ORDER BY lifetime_value DESC) AS clv_quartile   -- 1 = top 25%
FROM clv
ORDER BY lifetime_value DESC
LIMIT 50;
