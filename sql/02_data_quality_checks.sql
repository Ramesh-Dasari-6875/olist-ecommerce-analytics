SELECT '01 total orders' AS check_name, COUNT(*)::text AS result FROM orders
UNION ALL SELECT '02 orders not delivered', COUNT(*)::text FROM orders WHERE order_status <> 'delivered'
UNION ALL SELECT '03 missing approved date', COUNT(*)::text FROM orders WHERE order_approved_at IS NULL
UNION ALL SELECT '04 missing delivery date (all statuses)', COUNT(*)::text FROM orders WHERE order_delivered_customer_date IS NULL
UNION ALL SELECT '05 delivered but no delivery date', COUNT(*)::text FROM orders WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL
UNION ALL SELECT '06 delivered before purchase', COUNT(*)::text FROM orders WHERE order_delivered_customer_date < order_purchase_timestamp
UNION ALL SELECT '07 duplicated review_ids', COUNT(*)::text FROM (SELECT review_id FROM order_reviews GROUP BY review_id HAVING COUNT(*) > 1) d
UNION ALL SELECT '08 orders with multiple reviews', COUNT(*)::text FROM (SELECT order_id FROM order_reviews GROUP BY order_id HAVING COUNT(*) > 1) d
UNION ALL SELECT '09 items without order', COUNT(*)::text FROM order_items oi WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.order_id = oi.order_id)
UNION ALL SELECT '10 items without product', COUNT(*)::text FROM order_items oi WHERE NOT EXISTS (SELECT 1 FROM products p WHERE p.product_id = oi.product_id)
UNION ALL SELECT '11 orders without items', COUNT(*)::text FROM orders o WHERE NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.order_id)
UNION ALL SELECT '12 products with no category', COUNT(*)::text FROM products WHERE product_category_name IS NULL
UNION ALL SELECT '13 categories without translation', COUNT(DISTINCT product_category_name)::text FROM products p WHERE product_category_name IS NOT NULL AND NOT EXISTS (SELECT 1 FROM category_translation t WHERE t.product_category_name = p.product_category_name)
UNION ALL SELECT '14 first order date', MIN(order_purchase_timestamp)::text FROM orders
UNION ALL SELECT '15 last order date', MAX(order_purchase_timestamp)::text FROM orders
ORDER BY check_name;