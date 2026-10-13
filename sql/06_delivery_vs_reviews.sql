
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


--review score by how many days late
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