-- Dashboard views: each one feeds a Power BI visual.
-- Revenue excludes canceled and unavailable orders.

CREATE OR REPLACE VIEW v_kpis AS
WITH rev AS (
    SELECT COUNT(DISTINCT o.order_id) AS orders, SUM(oi.price) AS revenue
    FROM orders o JOIN order_items oi USING (order_id)
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
),
rep AS (
    SELECT 100.0 * COUNT(*) FILTER (WHERE n > 1) / COUNT(*) AS repeat_pct
    FROM (SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS n
          FROM orders o JOIN customers c USING (customer_id)
          WHERE o.order_status NOT IN ('canceled', 'unavailable')
          GROUP BY 1) x
),
del AS (
    SELECT 100.0 * COUNT(*) FILTER (WHERE order_delivered_customer_date > order_estimated_delivery_date)
           / COUNT(*) AS late_pct
    FROM orders
    WHERE order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL
),
rv AS (
    SELECT AVG(review_score) AS avg_review
    FROM (SELECT DISTINCT ON (order_id) order_id, review_score
          FROM order_reviews ORDER BY order_id, review_answer_timestamp DESC) l
)
SELECT ROUND(rev.revenue, 2)                AS total_revenue,
       rev.orders                           AS total_orders,
       ROUND(rev.revenue / rev.orders, 2)   AS avg_order_value,
       ROUND(rep.repeat_pct, 1)             AS repeat_customer_pct,
       ROUND(del.late_pct, 1)               AS late_delivery_pct,
       ROUND(rv.avg_review, 2)              AS avg_review_score
FROM rev, rep, del, rv;

CREATE OR REPLACE VIEW v_monthly_revenue AS
SELECT date_trunc('month', o.order_purchase_timestamp)::date AS month,
       COUNT(DISTINCT o.order_id)                            AS orders,
       ROUND(SUM(oi.price), 2)                               AS revenue,
       ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2)  AS avg_order_value
FROM orders o JOIN order_items oi USING (order_id)
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY 1;

CREATE OR REPLACE VIEW v_category_revenue AS
SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
       COUNT(DISTINCT oi.order_id) AS orders,
       ROUND(SUM(oi.price), 2)     AS revenue,
       ROUND(100 * SUM(oi.price) / SUM(SUM(oi.price)) OVER (), 1) AS pct_of_revenue
FROM order_items oi
JOIN orders o   USING (order_id)
JOIN products p USING (product_id)
LEFT JOIN category_translation t USING (product_category_name)
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY 1;

CREATE OR REPLACE VIEW v_state_revenue AS
SELECT c.customer_state,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.price), 2)    AS revenue,
       ROUND(100 * SUM(oi.price) / SUM(SUM(oi.price)) OVER (), 1) AS pct_of_revenue
FROM orders o
JOIN order_items oi USING (order_id)
JOIN customers c    USING (customer_id)
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY 1;

CREATE OR REPLACE VIEW v_rfm_segments AS
WITH customer_orders AS (
    SELECT c.customer_unique_id, o.order_id, o.order_purchase_timestamp,
           SUM(oi.price) AS order_value
    FROM orders o
    JOIN customers c    USING (customer_id)
    JOIN order_items oi USING (order_id)
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1, 2, 3
),
rfm AS (
    SELECT customer_unique_id,
           (SELECT MAX(order_purchase_timestamp)::date FROM orders)
             - MAX(order_purchase_timestamp)::date AS recency_days,
           COUNT(*) AS frequency,
           ROUND(SUM(order_value), 2) AS monetary
    FROM customer_orders
    GROUP BY 1
),
scored AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
           NTILE(5) OVER (ORDER BY monetary)          AS m_score,
           CASE WHEN frequency = 1 THEN 1
                WHEN frequency = 2 THEN 2 ELSE 3 END  AS f_score
    FROM rfm
),
segmented AS (
    SELECT *,
           CASE WHEN f_score >= 2 AND r_score >= 4 THEN 'Active repeat buyers'
                WHEN f_score >= 2                  THEN 'Lapsing repeat buyers'
                WHEN r_score >= 4 AND m_score >= 4 THEN 'New high-value'
                WHEN r_score >= 4                  THEN 'New customers'
                WHEN m_score >= 4                  THEN 'Lost high-value (one-time)'
                ELSE 'Lost low-value (one-time)' END AS segment
    FROM scored
)
SELECT segment,
       COUNT(*)                                             AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)   AS pct_customers,
       ROUND(AVG(monetary), 2)                              AS avg_spend,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_revenue
FROM segmented
GROUP BY segment;

CREATE OR REPLACE VIEW v_cohort_retention AS
WITH orders_clean AS (
    SELECT c.customer_unique_id,
           date_trunc('month', o.order_purchase_timestamp)::date AS order_month
    FROM orders o JOIN customers c USING (customer_id)
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
),
first_order AS (
    SELECT customer_unique_id, MIN(order_month) AS cohort_month
    FROM orders_clean GROUP BY 1
),
activity AS (
    SELECT DISTINCT f.cohort_month, f.customer_unique_id,
           (EXTRACT(YEAR FROM age(oc.order_month, f.cohort_month)) * 12
            + EXTRACT(MONTH FROM age(oc.order_month, f.cohort_month)))::int AS month_number
    FROM orders_clean oc JOIN first_order f USING (customer_unique_id)
)
SELECT cohort_month,
       COUNT(*) FILTER (WHERE month_number = 0) AS cohort_size,
       ROUND(100.0 * COUNT(*) FILTER (WHERE month_number = 1) / COUNT(*) FILTER (WHERE month_number = 0), 2) AS m1_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE month_number = 2) / COUNT(*) FILTER (WHERE month_number = 0), 2) AS m2_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE month_number = 3) / COUNT(*) FILTER (WHERE month_number = 0), 2) AS m3_pct
FROM activity
WHERE cohort_month BETWEEN '2017-01-01' AND '2018-05-01'
GROUP BY 1;

CREATE OR REPLACE VIEW v_late_vs_ontime AS
WITH latest_review AS (
    SELECT DISTINCT ON (order_id) order_id, review_score
    FROM order_reviews ORDER BY order_id, review_answer_timestamp DESC
)
SELECT CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 'Late' ELSE 'On time' END AS delivery_status,
       COUNT(*)                        AS orders,
       ROUND(AVG(r.review_score), 2)   AS avg_review_score,
       ROUND(100.0 * COUNT(*) FILTER (WHERE r.review_score <= 2) / COUNT(*), 1) AS pct_bad_reviews
FROM orders o JOIN latest_review r USING (order_id)
WHERE o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
GROUP BY 1;

CREATE OR REPLACE VIEW v_review_by_delay AS
WITH latest_review AS (
    SELECT DISTINCT ON (order_id) order_id, review_score
    FROM order_reviews ORDER BY order_id, review_answer_timestamp DESC
),
delivered AS (
    SELECT order_id,
           (order_delivered_customer_date::date - order_estimated_delivery_date::date) AS d
    FROM orders
    WHERE order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL
)
SELECT CASE WHEN d <= 0 THEN '1. On time or early'
            WHEN d <= 3 THEN '2. 1-3 days late'
            WHEN d <= 7 THEN '3. 4-7 days late'
            ELSE '4. 8+ days late' END AS bucket,
       COUNT(*)                      AS orders,
       ROUND(AVG(review_score), 2)   AS avg_review_score
FROM delivered JOIN latest_review USING (order_id)
GROUP BY 1;

CREATE OR REPLACE VIEW v_delivery_by_state AS
WITH latest_review AS (
    SELECT DISTINCT ON (order_id) order_id, review_score
    FROM order_reviews ORDER BY order_id, review_answer_timestamp DESC
)
SELECT c.customer_state,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.order_delivered_customer_date > o.order_estimated_delivery_date) / COUNT(*), 1) AS pct_late,
       ROUND(AVG(o.order_delivered_customer_date::date - o.order_purchase_timestamp::date), 1) AS avg_delivery_days,
       ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM orders o
JOIN customers c USING (customer_id)
JOIN latest_review r USING (order_id)
WHERE o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
GROUP BY 1
HAVING COUNT(*) >= 500;