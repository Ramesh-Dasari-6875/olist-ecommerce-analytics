-- Revenue = item price, excluding canceled and unavailable orders

-- A. Monthly revenue trend
SELECT date_trunc('month', o.order_purchase_timestamp)::date AS month,
       COUNT(DISTINCT o.order_id)                            AS orders,
       ROUND(SUM(oi.price), 2)                               AS revenue,
       ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2)  AS avg_order_value
FROM orders o
JOIN order_items oi USING (order_id)
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY 1
ORDER BY 1;

-- B. Top 10 categories by revenue
SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
       COUNT(DISTINCT oi.order_id) AS orders,
       ROUND(SUM(oi.price), 2)     AS revenue
FROM order_items oi
JOIN orders o   USING (order_id)
JOIN products p USING (product_id)
LEFT JOIN category_translation t USING (product_category_name)
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY 1
ORDER BY revenue DESC
LIMIT 10;

-- C. Top 10 states by revenue (with share of total)
SELECT c.customer_state,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.price), 2)    AS revenue,
       ROUND(100 * SUM(oi.price) / SUM(SUM(oi.price)) OVER (), 1) AS pct_of_revenue
FROM orders o
JOIN order_items oi USING (order_id)
JOIN customers c    USING (customer_id)
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY 1
ORDER BY revenue DESC
LIMIT 10;

-- D. Category share of total revenue (top 10)
SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
       ROUND(SUM(oi.price), 2) AS revenue,
       ROUND(100 * SUM(oi.price) / SUM(SUM(oi.price)) OVER (), 1) AS pct_of_revenue
FROM order_items oi
JOIN orders o   USING (order_id)
JOIN products p USING (product_id)
LEFT JOIN category_translation t USING (product_category_name)
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY 1
ORDER BY revenue DESC
LIMIT 10;