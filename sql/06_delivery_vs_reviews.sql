
-- A. Late vs on-time

WITH latest_review AS (
    SELECT DISTINCT ON (order_id) order_id, review_score
    FROM order_reviews
    ORDER BY order_id, review_answer_timestamp DESC
),
delivered AS (
    SELECT o.order_id,
           CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
                THEN 'Late' ELSE 'On time' END AS delivery_status,
           EXTRACT(DAY FROM o.order_delivered_customer_date - o.order_estimated_delivery_date) AS days_vs_estimate
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT d.delivery_status,
       COUNT(*)                                   AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_orders,
       ROUND(AVG(r.review_score), 2)              AS avg_review_score,
       ROUND(100.0 * COUNT(*) FILTER (WHERE r.review_score <= 2) / COUNT(*), 1) AS pct_bad_reviews
FROM delivered d
JOIN latest_review r USING (order_id)
GROUP BY 1
ORDER BY 1;


-- B. review score by how many days late
WITH latest_review AS (
    SELECT DISTINCT ON (order_id) order_id, review_score
    FROM order_reviews
    ORDER BY order_id, review_answer_timestamp DESC
),
delivered AS (
    SELECT o.order_id,
           (o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date) AS days_vs_estimate
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT CASE WHEN days_vs_estimate <= 0 THEN '1. On time or early'
            WHEN days_vs_estimate <= 3 THEN '2. 1-3 days late'
            WHEN days_vs_estimate <= 7 THEN '3. 4-7 days late'
            ELSE '4. 8+ days late' END AS bucket,
       COUNT(*)                          AS orders,
       ROUND(AVG(r.review_score), 2)     AS avg_review_score
FROM delivered d
JOIN latest_review r USING (order_id)
GROUP BY 1
ORDER BY 1;

-- C. Late delivery rate and review score by customer state (states with 500+ orders)
WITH latest_review AS (
    SELECT DISTINCT ON (order_id) order_id, review_score
    FROM order_reviews
    ORDER BY order_id, review_answer_timestamp DESC
)
SELECT c.customer_state,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE o.order_delivered_customer_date > o.order_estimated_delivery_date) / COUNT(*), 1) AS pct_late,
       ROUND(AVG(o.order_delivered_customer_date::date - o.order_purchase_timestamp::date), 1) AS avg_delivery_days,
       ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM orders o
JOIN customers c USING (customer_id)
JOIN latest_review r USING (order_id)
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY 1
HAVING COUNT(*) >= 500
ORDER BY pct_late DESC;

-- D. Sellers with the highest late rate (sellers with 50+ orders)
SELECT oi.seller_id,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(100.0 * COUNT(DISTINCT o.order_id) FILTER (WHERE o.order_delivered_customer_date > o.order_estimated_delivery_date) / COUNT(DISTINCT o.order_id), 1) AS pct_late
FROM orders o
JOIN order_items oi USING (order_id)
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY 1
HAVING COUNT(DISTINCT o.order_id) >= 50
ORDER BY pct_late DESC
LIMIT 10;