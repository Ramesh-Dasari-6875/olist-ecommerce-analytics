-- A. Payment method mix
SELECT p.payment_type,
       COUNT(DISTINCT p.order_id)    AS orders,
       ROUND(100.0 * COUNT(DISTINCT p.order_id) / SUM(COUNT(DISTINCT p.order_id)) OVER (), 1) AS pct_orders,
       ROUND(SUM(p.payment_value), 2) AS total_value,
       ROUND(AVG(p.payment_value), 2) AS avg_payment
FROM order_payments p
JOIN orders o USING (order_id)
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY 1
ORDER BY orders DESC;

-- B. Credit card installments vs. payment size
SELECT CASE WHEN payment_installments = 1 THEN '1. Single payment'
            WHEN payment_installments <= 3 THEN '2. 2-3 installments'
            WHEN payment_installments <= 6 THEN '3. 4-6 installments'
            ELSE '4. 7+ installments' END AS installment_bucket,
       COUNT(*)                          AS payments,
       ROUND(AVG(payment_value), 2)      AS avg_payment_value
FROM order_payments p
JOIN orders o USING (order_id)
WHERE p.payment_type = 'credit_card'
  AND o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY 1
ORDER BY 1;

## Key Findings: Payments

- Credit cards account for 75.3% of orders and about 78% of payment value; boleto (bank slip) is second at 19.5%.
- About 67% of credit card payments use installments, and 16% use 7 or more.
- Average payment grows with installments: R$96 (single) to R$332 (7+ installments).
- Recommendation: keep flexible installment options on high-priced items, and keep boleto for customers without cards, since it covers about one in five orders.
- Note: an order can have several payment rows (e.g. voucher plus card).