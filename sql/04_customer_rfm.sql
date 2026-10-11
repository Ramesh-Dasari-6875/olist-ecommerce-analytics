SELECT COUNT(*) AS customers,
       COUNT(*) FILTER (WHERE orders_count > 1) AS repeat_customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE orders_count > 1) / COUNT(*), 1) AS repeat_pct
FROM (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS orders_count
    FROM orders o
    JOIN customers c USING (customer_id)
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1
) x;

-- B
WITH customer_orders AS (
    SELECT c.customer_unique_id, o.order_id,
           o.order_purchase_timestamp,
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
           COUNT(*)                                 AS frequency,
           ROUND(SUM(order_value), 2)               AS monetary
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
GROUP BY segment
ORDER BY pct_revenue DESC;