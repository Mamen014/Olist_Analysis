/*
===============================================================================
Olist E-Commerce Analysis
06_reporting_layer.sql

Purpose
-------
Create Power BI-ready reporting views in the analytics schema.

Prerequisites
-------------
- Database: olist_analysis
- Raw and staging layers have already been created and validated.
- Execute this script after 03_staging_transformations.sql.

Design principles
-----------------
1. Keep raw data unchanged; reporting objects read from staging.
2. Declare the grain of each fact view explicitly.
3. Aggregate one-to-many child tables before joining them to fact_orders.
4. Keep order items and payment records in separate fact views so measures
   from those tables are not multiplied by joins.
5. Keep all source orders and transaction rows; apply business filters in
   report measures or visuals.
6. A review score is exposed at order grain only when all non-NULL scores
   associated with that order agree. Conflicting-score orders remain visible
   and are flagged; their order-level review_score is NULL.

Reporting objects
-----------------
Dimensions:
  analytics.dim_date       One row per calendar date in the purchase period.
  analytics.dim_customer   One row per customer_id.
  analytics.dim_product    One row per product_id.
  analytics.dim_seller     One row per seller_id.

Facts:
  analytics.fact_orders          One row per order_id.
  analytics.fact_order_items     One row per order_id + order_item_id.
  analytics.fact_order_payments  One row per order_id + payment_sequential.

Important metric definitions
-----------------------------
- merchandise_value: sum of order-item price; excludes freight.
- freight_value: sum of recorded order-item freight charges.
- item_and_freight_value: merchandise_value + freight_value.
- payment_value: sum of payment records for an order.
- delivery_days: purchase-to-customer-delivery duration in days, only for
  orders eligible under the delivery conditions documented below.
- delivery_deviation_days: actual customer delivery minus estimated delivery;
  positive values are late, zero is on estimate, negative is early.
- review_score: one unambiguous score per order, or NULL when scores conflict
  or no non-NULL score exists.

Power BI relationship guidance
------------------------------
Use one-to-many, single-direction relationships from dimensions to facts:
  dim_date.date_key       -> each fact's purchase_date_key
  dim_customer.customer_id -> each fact's customer_id
  dim_product.product_id  -> fact_order_items.product_id
  dim_seller.seller_id    -> fact_order_items.seller_id

Use fact_orders for order-level KPIs, delivery performance, and the
order-level review score. Use fact_order_items for product/category/seller
performance. Use fact_order_payments for payment-method and installment
analysis. Do not join these fact views together in a way that multiplies rows.

The date relationship is based on purchase date. For analysis by approval,
carrier handoff, or delivery date, use additional role-playing date dimensions
or inactive relationships in the Power BI model.
===============================================================================
*/

BEGIN;

CREATE SCHEMA IF NOT EXISTS analytics;

/* ---------------------------------------------------------------------------
   1. DIMENSIONS
   --------------------------------------------------------------------------- */

-- One row per purchase calendar date.
CREATE OR REPLACE VIEW analytics.dim_date AS
WITH date_bounds AS (
    SELECT
        MIN(order_purchase_timestamp::date) AS min_date,
        MAX(order_purchase_timestamp::date) AS max_date
    FROM staging.orders
    WHERE order_purchase_timestamp IS NOT NULL
),
calendar AS (
    SELECT generated_timestamp::date AS date_key
    FROM date_bounds b
    CROSS JOIN LATERAL generate_series(
        b.min_date::timestamp,
        b.max_date::timestamp,
        INTERVAL '1 day'
    ) AS gs(generated_timestamp)
)
SELECT
    date_key,
    EXTRACT(YEAR FROM date_key)::INTEGER AS calendar_year,
    EXTRACT(QUARTER FROM date_key)::INTEGER AS calendar_quarter,
    EXTRACT(MONTH FROM date_key)::INTEGER AS month_number,
    (EXTRACT(YEAR FROM date_key)::INTEGER * 100
        + EXTRACT(MONTH FROM date_key)::INTEGER) AS year_month_sort,
    TO_CHAR(date_key, 'YYYY-MM') AS year_month,
    TO_CHAR(date_key, 'Mon') AS month_short_name,
    EXTRACT(WEEK FROM date_key)::INTEGER AS week_number,
    EXTRACT(ISODOW FROM date_key)::INTEGER AS iso_day_of_week,
    TO_CHAR(date_key, 'Dy') AS day_short_name,
    EXTRACT(DAY FROM date_key)::INTEGER AS day_of_month,
    (EXTRACT(ISODOW FROM date_key) IN (6, 7)) AS is_weekend
FROM calendar;

-- One row per customer record (customer_id), not per unique person
-- (customer_unique_id). Multiple customer_id records may represent the same
-- customer_unique_id in the source dataset.
CREATE OR REPLACE VIEW analytics.dim_customer AS
SELECT
    customer_id,
    customer_unique_id,
    customer_zipcode_prefix,
    customer_city,
    customer_state
FROM staging.customers;

-- One row per product. The analysis category field contains the approved
-- analysis label/fallback prepared in staging, including 'Uncategorized'.
CREATE OR REPLACE VIEW analytics.dim_product AS
SELECT
    product_id,
    product_category_name_for_analysis AS product_category
FROM staging.products;

-- One row per seller. Seller state comes from the seller master record.
CREATE OR REPLACE VIEW analytics.dim_seller AS
SELECT
    seller_id,
    seller_zipcode_prefix,
    seller_city,
    seller_state
FROM staging.sellers;

/* ---------------------------------------------------------------------------
   2. FACT: ORDERS
   Grain: one row per order_id.

   Child tables are aggregated independently before joining. This prevents
   multiple order items, payment records, or review records from multiplying
   one another and inflating order-level amounts.
   --------------------------------------------------------------------------- */

CREATE OR REPLACE VIEW analytics.fact_orders AS
WITH item_aggregation AS (
    SELECT
        order_id,
        COUNT(*) AS order_item_line_count,
        COUNT(DISTINCT product_id) AS distinct_product_count,
        COUNT(DISTINCT seller_id) AS distinct_seller_count,
        SUM(price) AS merchandise_value,
        SUM(freight_value) AS freight_value,
        SUM(price + freight_value) AS item_and_freight_value
    FROM staging.order_items
    GROUP BY order_id
),
payment_aggregation AS (
    SELECT
        order_id,
        COUNT(*) AS payment_record_count,
        COUNT(DISTINCT payment_type) AS distinct_payment_type_count,
        STRING_AGG(DISTINCT payment_type, ', ' ORDER BY payment_type)
            AS payment_types,
        SUM(payment_value) AS payment_value
    FROM staging.order_payments
    GROUP BY order_id
),
review_aggregation AS (
    SELECT
        order_id,
        COUNT(*) AS review_record_count,
        COUNT(DISTINCT review_id) AS distinct_review_id_count,
        COUNT(DISTINCT review_score) AS distinct_review_score_count,
        CASE
            WHEN COUNT(DISTINCT review_score) = 1
            THEN MIN(review_score)
            ELSE NULL
        END AS review_score,
        BOOL_OR(has_duplicate_review_id) AS has_reused_review_id,
        BOOL_OR(has_duplicate_order_id) AS has_multiple_review_records_for_order,
        BOOL_OR(is_review_before_purchase_earlier_day)
            AS has_review_earlier_than_purchase_date
    FROM staging.order_reviews
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_purchase_timestamp::date AS purchase_date_key,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    -- Order-level item aggregates. NULL monetary totals mean no matching
    -- item rows; line counts are set to zero for convenient counting.
    COALESCE(i.order_item_line_count, 0) AS order_item_line_count,
    COALESCE(i.distinct_product_count, 0) AS distinct_product_count,
    COALESCE(i.distinct_seller_count, 0) AS distinct_seller_count,
    i.merchandise_value,
    i.freight_value,
    i.item_and_freight_value,
    (i.order_id IS NOT NULL) AS has_order_items,

    -- Order-level payment aggregates. NULL payment_value means no matching
    -- payment rows; it is not silently converted to a zero-value payment.
    COALESCE(p.payment_record_count, 0) AS payment_record_count,
    COALESCE(p.distinct_payment_type_count, 0)
        AS distinct_payment_type_count,
    p.payment_types,
    p.payment_value,
    (p.order_id IS NOT NULL) AS has_payment_records,

    -- Review fields are already aggregated to one row per order.
    COALESCE(r.review_record_count, 0) AS review_record_count,
    COALESCE(r.distinct_review_id_count, 0) AS distinct_review_id_count,
    COALESCE(r.distinct_review_score_count, 0)
        AS distinct_review_score_count,
    r.review_score,
    (r.order_id IS NOT NULL) AS has_review_records,
    COALESCE(r.distinct_review_score_count > 1, FALSE)
        AS has_conflicting_review_scores,
    COALESCE(r.has_reused_review_id, FALSE) AS has_reused_review_id,
    COALESCE(r.has_multiple_review_records_for_order, FALSE)
        AS has_multiple_review_records_for_order,
    COALESCE(r.has_review_earlier_than_purchase_date, FALSE)
        AS has_review_earlier_than_purchase_date,

    -- The delivery population matches the EDA eligibility conditions:
    -- delivered status, all three required timestamps present, and actual
    -- customer delivery not earlier than purchase.
    (
        o.order_status = 'delivered'
        AND o.order_purchase_timestamp IS NOT NULL
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
        AND o.order_delivered_customer_date >= o.order_purchase_timestamp
    ) AS is_delivery_eligible,

    CASE
        WHEN o.order_status = 'delivered'
         AND o.order_purchase_timestamp IS NOT NULL
         AND o.order_delivered_customer_date IS NOT NULL
         AND o.order_estimated_delivery_date IS NOT NULL
         AND o.order_delivered_customer_date >= o.order_purchase_timestamp
        THEN EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_purchase_timestamp
            )
        ) / 86400.0
        ELSE NULL
    END AS delivery_days,

    CASE
        WHEN o.order_status = 'delivered'
         AND o.order_purchase_timestamp IS NOT NULL
         AND o.order_delivered_customer_date IS NOT NULL
         AND o.order_estimated_delivery_date IS NOT NULL
         AND o.order_delivered_customer_date >= o.order_purchase_timestamp
        THEN EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_estimated_delivery_date
            )
        ) / 86400.0
        ELSE NULL
    END AS delivery_deviation_days,

    CASE
        WHEN o.order_status = 'delivered'
         AND o.order_purchase_timestamp IS NOT NULL
         AND o.order_delivered_customer_date IS NOT NULL
         AND o.order_estimated_delivery_date IS NOT NULL
         AND o.order_delivered_customer_date >= o.order_purchase_timestamp
        THEN o.order_delivered_customer_date
             <= o.order_estimated_delivery_date
        ELSE NULL
    END AS is_on_time_delivery,

    CASE
        WHEN o.order_status = 'delivered'
         AND o.order_purchase_timestamp IS NOT NULL
         AND o.order_delivered_customer_date IS NOT NULL
         AND o.order_estimated_delivery_date IS NOT NULL
         AND o.order_delivered_customer_date >= o.order_purchase_timestamp
         AND o.order_delivered_customer_date > o.order_estimated_delivery_date
        THEN EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_estimated_delivery_date
            )
        ) / 86400.0
        ELSE NULL
    END AS late_days,

    -- Preserve temporal anomalies as flags rather than correcting timestamps.
    (
        o.order_approved_at IS NOT NULL
        AND o.order_delivered_carrier_date IS NOT NULL
        AND o.order_delivered_carrier_date < o.order_approved_at
    ) AS has_carrier_before_approval,

    (
        o.order_delivered_carrier_date IS NOT NULL
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_delivered_customer_date < o.order_delivered_carrier_date
    ) AS has_customer_delivery_before_carrier,

    (
        o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NULL
    ) AS is_delivered_missing_customer_date,

    -- Reconciliation status uses the same 0.01 tolerance as the DQ assessment.
    CASE
        WHEN COALESCE(i.order_item_line_count, 0) = 0
         AND COALESCE(p.payment_record_count, 0) = 0
            THEN 'No payment or items'
        WHEN COALESCE(p.payment_record_count, 0) = 0
            THEN 'Items without payment'
        WHEN COALESCE(i.order_item_line_count, 0) = 0
            THEN 'Payment without items'
        WHEN ABS(p.payment_value - i.item_and_freight_value) <= 0.01
            THEN 'Matched'
        WHEN p.payment_value > i.item_and_freight_value + 0.01
            THEN 'Payment exceeds items and freight'
        WHEN i.item_and_freight_value > p.payment_value + 0.01
            THEN 'Items and freight exceed payment'
        ELSE 'Unclassified'
    END AS payment_item_reconciliation_status,

    CASE
        WHEN i.order_id IS NOT NULL AND p.order_id IS NOT NULL
        THEN p.payment_value - i.item_and_freight_value
        ELSE NULL
    END AS payment_minus_item_and_freight_value

FROM staging.orders o
LEFT JOIN item_aggregation i
    ON o.order_id = i.order_id
LEFT JOIN payment_aggregation p
    ON o.order_id = p.order_id
LEFT JOIN review_aggregation r
    ON o.order_id = r.order_id;

/* ---------------------------------------------------------------------------
   3. FACT: ORDER ITEMS
   Grain: one row per order_id + order_item_id.
   Use for product/category and seller performance. Keep all order statuses;
   filter to delivered orders in the relevant Power BI measures/visuals.
   --------------------------------------------------------------------------- */

CREATE OR REPLACE VIEW analytics.fact_order_items AS
SELECT
    oi.order_id,
    oi.order_item_id,
    oi.order_id || '-' || oi.order_item_id::text AS order_item_key,
    o.customer_id,
    oi.product_id,
    oi.seller_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_purchase_timestamp::date AS purchase_date_key,
    oi.shipping_limit_date,
    oi.price AS merchandise_value,
    oi.freight_value,
    oi.price + oi.freight_value AS item_and_freight_value
FROM staging.order_items oi
JOIN staging.orders o
    ON oi.order_id = o.order_id;

/* ---------------------------------------------------------------------------
   4. FACT: ORDER PAYMENTS
   Grain: one row per order_id + payment_sequential.
   Use for payment-type, installment, and payment-record analysis. This fact
   remains separate from fact_order_items to avoid item/payment fan-out.
   --------------------------------------------------------------------------- */

CREATE OR REPLACE VIEW analytics.fact_order_payments AS
SELECT
    op.order_id,
    op.payment_sequential,
    op.order_id || '-' || op.payment_sequential::text AS payment_record_key,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_purchase_timestamp::date AS purchase_date_key,
    op.payment_type,
    op.payment_installments,
    op.payment_value
FROM staging.order_payments op
JOIN staging.orders o
    ON op.order_id = o.order_id;

COMMIT;

/* ---------------------------------------------------------------------------
   5. VALIDATION QUERIES
   Run after the views are created. Reporting row counts should match their
   source grains because the source relationships were validated in Stage 2.
   Investigate any non-zero row-count differences before connecting Power BI.
   --------------------------------------------------------------------------- */

-- 5.1 Source-to-reporting row-count comparison.
SELECT
    'orders' AS object_name,
    (SELECT COUNT(*) FROM staging.orders) AS source_rows,
    (SELECT COUNT(*) FROM analytics.fact_orders) AS reporting_rows
UNION ALL
SELECT
    'order_items',
    (SELECT COUNT(*) FROM staging.order_items),
    (SELECT COUNT(*) FROM analytics.fact_order_items)
UNION ALL
SELECT
    'order_payments',
    (SELECT COUNT(*) FROM staging.order_payments),
    (SELECT COUNT(*) FROM analytics.fact_order_payments)
UNION ALL
SELECT
    'customers',
    (SELECT COUNT(*) FROM staging.customers),
    (SELECT COUNT(*) FROM analytics.dim_customer)
UNION ALL
SELECT
    'products',
    (SELECT COUNT(*) FROM staging.products),
    (SELECT COUNT(*) FROM analytics.dim_product)
UNION ALL
SELECT
    'sellers',
    (SELECT COUNT(*) FROM staging.sellers),
    (SELECT COUNT(*) FROM analytics.dim_seller)
ORDER BY object_name;

-- 5.2 Grain/uniqueness checks: each difference should be zero.
SELECT
    'fact_orders' AS object_name,
    COUNT(*) AS row_count,
    COUNT(DISTINCT order_id) AS distinct_grain_keys,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_excess_rows
FROM analytics.fact_orders
UNION ALL
SELECT
    'fact_order_items',
    COUNT(*),
    COUNT(DISTINCT order_item_key),
    COUNT(*) - COUNT(DISTINCT order_item_key)
FROM analytics.fact_order_items
UNION ALL
SELECT
    'fact_order_payments',
    COUNT(*),
    COUNT(DISTINCT payment_record_key),
    COUNT(*) - COUNT(DISTINCT payment_record_key)
FROM analytics.fact_order_payments;

-- 5.3 Financial total reconciliation between source and reporting facts.
-- These totals cover all statuses, not only delivered orders.
SELECT
    'merchandise_value' AS measure_name,
    (SELECT SUM(price) FROM staging.order_items) AS source_total,
    (SELECT SUM(merchandise_value) FROM analytics.fact_order_items)
        AS reporting_total
UNION ALL
SELECT
    'freight_value',
    (SELECT SUM(freight_value) FROM staging.order_items),
    (SELECT SUM(freight_value) FROM analytics.fact_order_items)
UNION ALL
SELECT
    'payment_value',
    (SELECT SUM(payment_value) FROM staging.order_payments),
    (SELECT SUM(payment_value) FROM analytics.fact_order_payments);

-- 5.4 Key order-level population checks against the EDA definitions.
SELECT
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
    ) AS delivered_orders,
    COUNT(*) FILTER (
        WHERE is_delivery_eligible
    ) AS eligible_delivered_orders,
    COUNT(*) FILTER (
        WHERE is_on_time_delivery IS TRUE
    ) AS on_time_orders,
    COUNT(*) FILTER (
        WHERE is_on_time_delivery IS FALSE
    ) AS late_orders,
    COUNT(*) FILTER (
        WHERE has_conflicting_review_scores
    ) AS orders_with_conflicting_review_scores
FROM analytics.fact_orders;

-- 5.5 Review score eligibility check.
-- This should show one row per order with one unambiguous score; orders with
-- conflicting scores remain in fact_orders with review_score set to NULL.
SELECT
    COUNT(*) FILTER (
        WHERE review_score IS NOT NULL
    ) AS orders_with_unambiguous_review_score,
    COUNT(*) FILTER (
        WHERE has_conflicting_review_scores
    ) AS orders_with_conflicting_review_scores,
    COUNT(*) FILTER (
        WHERE has_review_records
          AND review_score IS NULL
          AND NOT has_conflicting_review_scores
    ) AS orders_with_reviews_but_no_nonnull_score
FROM analytics.fact_orders;
