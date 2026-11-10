-- =========================================================
-- 1. DATASET PROFILING
-- =========================================================

-- 1.1 Row counts

SELECT 'customers' AS table_name, COUNT(*) AS total_rows
FROM raw.customers

UNION ALL
SELECT 'orders', COUNT(*) FROM raw.orders

UNION ALL
SELECT 'order_items', COUNT(*) FROM raw.order_items

UNION ALL
SELECT 'order_payments', COUNT(*) FROM raw.order_payments

UNION ALL
SELECT 'order_reviews', COUNT(*) FROM raw.order_reviews

UNION ALL
SELECT 'products', COUNT(*) FROM raw.products

UNION ALL
SELECT 'sellers', COUNT(*) FROM raw.sellers

UNION ALL
SELECT 'geolocation', COUNT(*) FROM raw.geolocation

UNION ALL
SELECT 'category_name_translation',
       COUNT(*) FROM raw.category_name_translation

ORDER BY table_name;

-- 1.2. Categorical distribution

-- Order status distribution
SELECT
    order_status,
    COUNT(*) AS total_orders
FROM raw.orders
GROUP BY order_status
ORDER BY total_orders DESC;


-- Payment type distribution
SELECT
    payment_type,
    COUNT(*) AS total_records
FROM raw.order_payments
GROUP BY payment_type
ORDER BY total_records DESC;


-- Customer state distribution
SELECT
    customer_state,
    COUNT(*) AS total_customers
FROM raw.customers
GROUP BY customer_state
ORDER BY total_customers DESC;


-- Seller state distribution
SELECT
    seller_state,
    COUNT(*) AS total_sellers
FROM raw.sellers
GROUP BY seller_state
ORDER BY total_sellers DESC;

-- =========================================================
-- 2. COMPLETENESS ASSESSMENT
-- =========================================================

-- 2.1 NULL value assessment

SELECT
    'customers' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE customer_id IS NULL
           OR customer_unique_id IS NULL
           OR customer_zipcode_prefix IS NULL
           OR customer_city IS NULL
           OR customer_state IS NULL
    ) AS rows_with_missing_values
FROM raw.customers
UNION ALL
SELECT
    'orders',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE order_id IS NULL
           OR customer_id IS NULL
           OR order_status IS NULL
           OR order_purchase_timestamp IS NULL
           OR order_approved_at IS NULL
           OR order_delivered_carrier_date IS NULL
           OR order_delivered_customer_date IS NULL
           OR order_estimated_delivery_date IS NULL
    )
FROM raw.orders
UNION ALL
SELECT
    'order_items',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE order_id IS NULL
           OR order_item_id IS NULL
           OR product_id IS NULL
           OR seller_id IS NULL
           OR shipping_limit_date IS NULL
           OR price IS NULL
           OR freight_value IS NULL
    )
FROM raw.order_items
UNION ALL
SELECT
    'order_payments',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE order_id IS NULL
           OR payment_sequential IS NULL
           OR payment_type IS NULL
           OR payment_installments IS NULL
           OR payment_value IS NULL
    )
FROM raw.order_payments
UNION ALL
SELECT
    'order_reviews',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE review_id IS NULL
           OR order_id IS NULL
           OR review_score IS NULL
           OR review_creation_date IS NULL
           OR review_answer_timestamp IS NULL
    )
FROM raw.order_reviews
UNION ALL
SELECT
    'products',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE product_id IS NULL
           OR product_category_name IS NULL
           OR product_name_lenght IS NULL
           OR product_description_lenght IS NULL
           OR product_photos_qty IS NULL
           OR product_weight_g IS NULL
           OR product_length_cm IS NULL
           OR product_height_cm IS NULL
           OR product_width_cm IS NULL
    )
FROM raw.products
UNION ALL
SELECT
    'sellers',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE seller_id IS NULL
           OR seller_zipcode_prefix IS NULL
           OR seller_city IS NULL
           OR seller_state IS NULL
    )
FROM raw.sellers
UNION ALL
SELECT
    'geolocation',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE geolocation_zip_code_prefix IS NULL
           OR geolocation_lat IS NULL
           OR geolocation_lng IS NULL
           OR geolocation_city IS NULL
           OR geolocation_state IS NULL
    )
FROM raw.geolocation
UNION ALL
SELECT
    'category_name_translation',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE product_category_name IS NULL
           OR product_category_name_english IS NULL
    )
FROM raw.category_name_translation;

-- 2.2 Empty and whitespace-only text values

SELECT 'customers.customer_city' AS field_name,
       COUNT(*) AS empty_values
FROM raw.customers
WHERE customer_city IS NOT NULL
  AND BTRIM(customer_city) = ''

UNION ALL

SELECT 'sellers.seller_city',
       COUNT(*)
FROM raw.sellers
WHERE seller_city IS NOT NULL
  AND BTRIM(seller_city) = ''

UNION ALL

SELECT 'products.product_category_name',
       COUNT(*)
FROM raw.products
WHERE product_category_name IS NOT NULL
  AND BTRIM(product_category_name) = ''

UNION ALL

SELECT 'order_payments.payment_type',
       COUNT(*)
FROM raw.order_payments
WHERE payment_type IS NOT NULL
  AND BTRIM(payment_type) = ''

UNION ALL

SELECT 'order_reviews.review_comment_title',
       COUNT(*)
FROM raw.order_reviews
WHERE review_comment_title IS NOT NULL
  AND BTRIM(review_comment_title) = ''

UNION ALL

SELECT 'order_reviews.review_comment_message',
       COUNT(*)
FROM raw.order_reviews
WHERE review_comment_message IS NOT NULL
  AND BTRIM(review_comment_message) = ''

UNION ALL

SELECT 'category_name_translation.product_category_name_english',
       COUNT(*)
FROM raw.category_name_translation
WHERE product_category_name_english IS NOT NULL
  AND BTRIM(product_category_name_english) = '';

-- 2.3 Incomplete product records

SELECT *
FROM raw.products
WHERE product_id IS NOT NULL
  AND product_category_name IS NULL
  AND product_name_lenght IS NULL
  AND product_description_lenght IS NULL
  AND product_photos_qty IS NULL
  AND product_weight_g IS NULL
  AND product_length_cm IS NULL
  AND product_height_cm IS NULL
  AND product_width_cm IS NULL;

-- =========================================================
-- 3. UNIQUENESS ASSESSMENT
-- =========================================================
-- 3.1. Check duplicate identifiers

-- Customers
SELECT customer_id, COUNT(*) AS occurrences
FROM raw.customers
GROUP BY customer_id
HAVING COUNT(*) > 1;


-- Orders
SELECT order_id, COUNT(*) AS occurrences
FROM raw.orders
GROUP BY order_id
HAVING COUNT(*) > 1;


-- Products
SELECT product_id, COUNT(*) AS occurrences
FROM raw.products
GROUP BY product_id
HAVING COUNT(*) > 1;


-- Sellers
SELECT seller_id, COUNT(*) AS occurrences
FROM raw.sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;


-- Reviews
SELECT review_id, COUNT(*) AS occurrences
FROM raw.order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1;

-- 3.2 Check composite identifiers

-- Order items
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS occurrences
FROM raw.order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;


-- Order payments
SELECT
    order_id,
    payment_sequential,
    COUNT(*) AS occurrences
FROM raw.order_payments
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1;


-- 3.3 Check category translation uniqueness
SELECT
    product_category_name,
    COUNT(*) AS occurrences
FROM raw.category_name_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1;


-- =========================================================
-- 4. VALIDITY ASSESSMENT
-- =========================================================
-- 4.1 Numerical validity

-- Review score
SELECT *
FROM raw.order_reviews
WHERE review_score NOT BETWEEN 1 AND 5
   OR review_score IS NULL;


-- Order item financial values
SELECT *
FROM raw.order_items
WHERE price < 0
   OR freight_value < 0;


-- Payment values
SELECT *
FROM raw.order_payments
WHERE payment_value < 0;


-- Product dimensions and measurements
SELECT *
FROM raw.products
WHERE product_weight_g < 0
   OR product_length_cm < 0
   OR product_height_cm < 0
   OR product_width_cm < 0
   OR product_photos_qty < 0;


-- 4.2 Positive identifier and sequence checks
-- Order item sequence
SELECT *
FROM raw.order_items
WHERE order_item_id <= 0;


-- Payment sequence
SELECT *
FROM raw.order_payments
WHERE payment_sequential <= 0;


-- Payment installments
SELECT *
FROM raw.order_payments
WHERE payment_installments <= 0;


-- 4.3 Categorical domain checks
-- Order statuses
SELECT DISTINCT order_status
FROM raw.orders
ORDER BY order_status;


-- Payment types
SELECT DISTINCT payment_type
FROM raw.order_payments
ORDER BY payment_type;


-- Customer states
SELECT DISTINCT customer_state
FROM raw.customers
ORDER BY customer_state;


-- Seller states
SELECT DISTINCT seller_state
FROM raw.sellers
ORDER BY seller_state;

-- 4.4 Geographic validity
-- Geographic coordinate ranges
SELECT *
FROM raw.geolocation
WHERE geolocation_lat NOT BETWEEN -90 AND 90
   OR geolocation_lng NOT BETWEEN -180 AND 180;

-- 4.5 Postal code format
-- Customer postal prefixes
SELECT *
FROM raw.customers
WHERE customer_zipcode_prefix !~ '^[0-9]{5}$'
   OR customer_zipcode_prefix IS NULL;


-- Seller postal prefixes
SELECT *
FROM raw.sellers
WHERE seller_zipcode_prefix !~ '^[0-9]{5}$'
   OR seller_zipcode_prefix IS NULL;


-- Geolocation postal prefixes
SELECT *
FROM raw.geolocation
WHERE geolocation_zip_code_prefix !~ '^[0-9]{5}$'
   OR geolocation_zip_code_prefix IS NULL;


-- =========================================================
-- 5. REFERENTIAL INTEGRITY ASSESSMENT
-- =========================================================
-- 5.1 Orders referencing customers
SELECT
    o.order_id,
    o.customer_id
FROM raw.orders o
LEFT JOIN raw.customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;   

-- 5.2 Order items referencing orders
SELECT
    oi.order_id
FROM raw.order_items oi
LEFT JOIN raw.orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 5.5 Payments referencing orders
SELECT
    op.order_id
FROM raw.order_payments op
LEFT JOIN raw.orders o
    ON op.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 5.6 Reviews referencing orders
SELECT
    r.review_id,
    r.order_id
FROM raw.order_reviews r
LEFT JOIN raw.orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 5.7 Product categories missing from the translation table
SELECT DISTINCT
    p.product_category_name
FROM raw.products p
LEFT JOIN raw.category_name_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL;

-- Customer postal prefixes without geolocation matches
SELECT DISTINCT
    c.customer_zipcode_prefix
FROM raw.customers c
LEFT JOIN raw.geolocation g
    ON c.customer_zipcode_prefix = g.geolocation_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL;


-- Seller postal prefixes without geolocation matches
SELECT DISTINCT
    s.seller_zipcode_prefix
FROM raw.sellers s
LEFT JOIN raw.geolocation g
    ON s.seller_zipcode_prefix = g.geolocation_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL;

-- =========================================================
-- 6. CONSISTENCY ASSESSMENT
-- =========================================================

-- Delivered orders without customer delivery date
SELECT
    order_id,
    order_status,
    order_delivered_customer_date
FROM raw.orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;


-- Orders with delivery dates but a non-delivered status
SELECT
    order_id,
    order_status,
    order_delivered_carrier_date,
    order_delivered_customer_date
FROM raw.orders
WHERE order_status <> 'delivered'
  AND (
      order_delivered_carrier_date IS NOT NULL
      OR order_delivered_customer_date IS NOT NULL
  );


-- 6.2 Compare order payment totals with item and freight totals

WITH item_totals AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS item_and_freight_total
    FROM raw.order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM raw.order_payments
    GROUP BY order_id
)
SELECT
    COALESCE(i.order_id, p.order_id) AS order_id,
    i.item_and_freight_total,
    p.payment_total,
    p.payment_total - i.item_and_freight_total AS difference
FROM item_totals i
FULL OUTER JOIN payment_totals p
    ON i.order_id = p.order_id
WHERE i.order_id IS NULL
   OR p.order_id IS NULL
   OR ABS(p.payment_total - i.item_and_freight_total) > 0.01
ORDER BY ABS(
    COALESCE(p.payment_total, 0)
    - COALESCE(i.item_and_freight_total, 0)
) DESC;


-- 6.3 Customer and seller geographic consistency
-- Customer postal prefix associated with multiple states
SELECT
    customer_zipcode_prefix,
    COUNT(DISTINCT customer_state) AS distinct_states
FROM raw.customers
GROUP BY customer_zipcode_prefix
HAVING COUNT(DISTINCT customer_state) > 1;


-- Seller postal prefix associated with multiple states
SELECT
    seller_zipcode_prefix,
    COUNT(DISTINCT seller_state) AS distinct_states
FROM raw.sellers
GROUP BY seller_zipcode_prefix
HAVING COUNT(DISTINCT seller_state) > 1;


-- =========================================================
-- 7. TEMPORAL INTEGRITY ASSESSMENT
-- =========================================================
-- 7.1 Approval before purchase

SELECT
    order_id,
    order_purchase_timestamp,
    order_approved_at,
    order_approved_at - order_purchase_timestamp AS time_difference
FROM raw.orders
WHERE order_approved_at < order_purchase_timestamp;

-- 7.2 Carrier handoff before approval
SELECT
    order_id,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_carrier_date - order_approved_at AS time_difference
FROM raw.orders
WHERE order_delivered_carrier_date < order_approved_at;

-- 7.3 Customer delivery before carrier handoff
SELECT
    order_id,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_delivered_customer_date - order_delivered_carrier_date AS time_difference
FROM raw.orders
WHERE order_delivered_customer_date < order_delivered_carrier_date;

-- 7.4 Customer delivery before purchase
SELECT
    order_id,
    order_purchase_timestamp,
    order_delivered_customer_date,
    order_delivered_customer_date - order_purchase_timestamp AS time_difference
FROM raw.orders
WHERE order_delivered_customer_date < order_purchase_timestamp;

-- 7.5 Review response before review creation
SELECT
    review_id,
    order_id,
    review_creation_date,
    review_answer_timestamp,
    review_answer_timestamp - review_creation_date AS time_difference
FROM raw.order_reviews
WHERE review_answer_timestamp < review_creation_date;

-- 7.6 Review creation before order purchase
SELECT
    r.review_id,
    r.order_id,
    o.order_purchase_timestamp,
    r.review_creation_date
FROM raw.order_reviews r
JOIN raw.orders o
    ON r.order_id = o.order_id
WHERE r.review_creation_date < o.order_purchase_timestamp;

-- ============================================================
-- FINAL STAGING VALIDATION: RECORD COUNTS AND GRAIN
-- ============================================================
-- Execute after staging_transformation.sql

SELECT
    'customers' AS table_name,
    COUNT(*) AS staging_records,
    COUNT(DISTINCT customer_id) AS distinct_keys
FROM staging.customers

UNION ALL

SELECT
    'orders',
    COUNT(*),
    COUNT(DISTINCT order_id)
FROM staging.orders

UNION ALL

SELECT
    'order_items',
    COUNT(*),
    COUNT(DISTINCT (order_id, order_item_id))
FROM staging.order_items

UNION ALL

SELECT
    'order_payments',
    COUNT(*),
    COUNT(DISTINCT (order_id, payment_sequential))
FROM staging.order_payments

UNION ALL

SELECT
    'order_reviews',
    COUNT(*),
    NULL::bigint
FROM staging.order_reviews

UNION ALL

SELECT
    'products',
    COUNT(*),
    COUNT(DISTINCT product_id)
FROM staging.products

UNION ALL

SELECT
    'sellers',
    COUNT(*),
    COUNT(DISTINCT seller_id)
FROM staging.sellers

UNION ALL

SELECT
    'geolocation',
    COUNT(*),
    NULL::bigint
FROM staging.geolocation

UNION ALL

SELECT
    'category_name_translation',
    COUNT(*),
    COUNT(DISTINCT product_category_name)
FROM staging.category_name_translation

ORDER BY table_name;