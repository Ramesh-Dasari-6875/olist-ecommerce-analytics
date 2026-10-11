-- Monthly cohort retention
WITH orders_clean AS (
    SELECT c.customer_unique_id,
           date_trunc('month', o.order_purchase_timestamp)::date AS order_month
    FROM orders o
    JOIN customers c USING (customer_id)
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
),
first_order AS (
    SELECT customer_unique_id, MIN(order_month) AS cohort_month
    FROM orders_clean
    GROUP BY 1
),
activity AS (
    SELECT DISTINCT f.cohort_month, f.customer_unique_id,
           (EXTRACT(YEAR FROM age(oc.order_month, f.cohort_month)) * 12
            + EXTRACT(MONTH FROM age(oc.order_month, f.cohort_month)))::int AS month_number
    FROM orders_clean oc
    JOIN first_order f USING (customer_unique_id)
)
SELECT cohort_month,
       COUNT(*) FILTER (WHERE month_number = 0) AS cohort_size,
       ROUND(100.0 * COUNT(*) FILTER (WHERE month_number = 1) / COUNT(*) FILTER (WHERE month_number = 0), 2) AS m1_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE month_number = 2) / COUNT(*) FILTER (WHERE month_number = 0), 2) AS m2_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE month_number = 3) / COUNT(*) FILTER (WHERE month_number = 0), 2) AS m3_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE month_number = 6) / COUNT(*) FILTER (WHERE month_number = 0), 2) AS m6_pct
FROM activity
WHERE cohort_month BETWEEN '2017-01-01' AND '2018-08-01'
GROUP BY 1
ORDER BY 1;