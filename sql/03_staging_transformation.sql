-- ============================================================
-- 03_STAGING_TRANSFORMATIONS.SQL
-- Purpose: Prepare source records for analytical use.
-- Source: raw schema
-- Target: staging schema
-- ============================================================


-- ============================================================
-- SECTION 1: CREATE STAGING SCHEMA
-- ============================================================

CREATE SCHEMA IF NOT EXISTS staging;


-- ============================================================
-- SECTION 2: PREPARE ORDERS
-- Source: raw.orders
-- Grain: One row per order
-- ============================================================

CREATE OR REPLACE VIEW staging.orders AS

SELECT
    o.*,

    -- DQ-012: Missing order lifecycle timestamps

    (o.order_approved_at IS NULL)
        AS is_missing_approval_timestamp,

    (o.order_delivered_carrier_date IS NULL)
        AS is_missing_carrier_timestamp,

    (o.order_delivered_customer_date IS NULL)
        AS is_missing_customer_delivery_timestamp,

    (
        o.order_approved_at IS NULL
        OR o.order_delivered_carrier_date IS NULL
        OR o.order_delivered_customer_date IS NULL
    ) AS has_missing_lifecycle_timestamp,


    -- DQ-003: Carrier handoff before approval

    (
        o.order_approved_at IS NOT NULL
        AND o.order_delivered_carrier_date IS NOT NULL
        AND o.order_delivered_carrier_date < o.order_approved_at
    ) AS is_carrier_before_approval,


    -- DQ-004: Customer delivery before carrier handoff

    (
        o.order_delivered_carrier_date IS NOT NULL
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_delivered_customer_date < o.order_delivered_carrier_date
    ) AS is_customer_delivery_before_carrier_handoff,


    -- DQ-006: Delivered orders without customer delivery timestamp

    (
        o.order_status = 'delivered'
        AND o.order_delivered_customer_date IS NULL
    ) AS is_delivered_without_customer_timestamp,


    -- DQ-006: Delivered orders with incomplete timelines

    (
        o.order_status = 'delivered'
        AND (
            o.order_approved_at IS NULL
            OR o.order_delivered_carrier_date IS NULL
            OR o.order_delivered_customer_date IS NULL
        )
    ) AS is_delivered_with_incomplete_timeline,


    -- DQ-006: Canceled orders with delivery timestamps

    (
        o.order_status = 'canceled'
        AND (
            o.order_delivered_carrier_date IS NOT NULL
            OR o.order_delivered_customer_date IS NOT NULL
        )
    ) AS is_canceled_with_delivery_timestamp

FROM raw.orders o;

-- ============================================================
-- SECTION 3: PREPARE PRODUCTS
-- Source: raw.products
-- Reference: raw.category_name_translation
-- Grain: One row per product
-- ============================================================

CREATE OR REPLACE VIEW staging.products AS

SELECT
    p.*,

    -- DQ-008: Preserve original category and provide
    -- an English translation fallback for analysis.

    t.product_category_name_english,

    COALESCE(
        t.product_category_name_english,
        p.product_category_name
    ) AS product_category_name_for_analysis,


    -- DQ-007: Individual attribute completeness flags

    (p.product_category_name IS NULL)
        AS is_missing_category,

    (p.product_name_lenght IS NULL)
        AS is_missing_name_length,

    (p.product_description_lenght IS NULL)
        AS is_missing_description_length,

    (p.product_photos_qty IS NULL)
        AS is_missing_photo_count,

    (p.product_weight_g IS NULL)
        AS is_missing_weight,

    (p.product_length_cm IS NULL)
        AS is_missing_length,

    (p.product_height_cm IS NULL)
        AS is_missing_height,

    (p.product_width_cm IS NULL)
        AS is_missing_width,


    -- DQ-007: Overall completeness flags

    (
        p.product_category_name IS NULL
        OR p.product_name_lenght IS NULL
        OR p.product_description_lenght IS NULL
        OR p.product_photos_qty IS NULL
        OR p.product_weight_g IS NULL
        OR p.product_length_cm IS NULL
        OR p.product_height_cm IS NULL
        OR p.product_width_cm IS NULL
    ) AS has_missing_product_attributes,

    (
        p.product_category_name IS NULL
        AND p.product_name_lenght IS NULL
        AND p.product_description_lenght IS NULL
        AND p.product_photos_qty IS NULL
        AND p.product_weight_g IS NULL
        AND p.product_length_cm IS NULL
        AND p.product_height_cm IS NULL
        AND p.product_width_cm IS NULL
    ) AS is_fully_incomplete_product,


    -- DQ-008: Category translation completeness

    (
        p.product_category_name IS NOT NULL
        AND t.product_category_name IS NULL
    ) AS is_category_translation_missing

FROM raw.products p

LEFT JOIN raw.category_name_translation t
    ON p.product_category_name = t.product_category_name;

-- ============================================================
-- SECTION 4: PREPARE ORDER REVIEWS
-- Source: raw.order_reviews
-- Reference: raw.orders
-- Grain: One row per source review record
-- ============================================================

CREATE OR REPLACE VIEW staging.order_reviews AS

WITH review_records AS (
    SELECT
        r.*,

        -- DQ-001: Count occurrences of each identifier

        COUNT(*) OVER (
            PARTITION BY r.review_id
        ) AS review_id_occurrences,

        COUNT(*) OVER (
            PARTITION BY r.order_id
        ) AS order_id_occurrences

    FROM raw.order_reviews r
)

SELECT
    r.*,

    o.order_purchase_timestamp,


    -- DQ-001: Duplicate identifier flags

    (r.review_id_occurrences > 1)
        AS has_duplicate_review_id,

    (r.order_id_occurrences > 1)
        AS has_duplicate_order_id,


    -- DQ-005: Review created before purchase timestamp

    (
        r.review_creation_date IS NOT NULL
        AND o.order_purchase_timestamp IS NOT NULL
        AND r.review_creation_date < o.order_purchase_timestamp
    ) AS is_review_before_purchase_timestamp,


    -- DQ-005: Same-day timestamp difference

    (
        r.review_creation_date IS NOT NULL
        AND o.order_purchase_timestamp IS NOT NULL
        AND r.review_creation_date < o.order_purchase_timestamp
        AND r.review_creation_date::DATE =
            o.order_purchase_timestamp::DATE
    ) AS is_review_before_purchase_same_day,


    -- DQ-005: Review creation date precedes purchase date

    (
        r.review_creation_date IS NOT NULL
        AND o.order_purchase_timestamp IS NOT NULL
        AND r.review_creation_date::DATE <
            o.order_purchase_timestamp::DATE
    ) AS is_review_before_purchase_earlier_day

FROM review_records r

LEFT JOIN raw.orders o
    ON r.order_id = o.order_id;

-- ============================================================
-- SECTION 5: PREPARE ORDER PAYMENTS
-- Source: raw.order_payments
-- Grain: One row per payment record
-- ============================================================

CREATE OR REPLACE VIEW staging.order_payments AS

SELECT
    p.*,

    -- DQ-011: Zero payment installments

    (p.payment_installments = 0)
        AS has_zero_installments

FROM raw.order_payments p;

-- ============================================================
-- SECTION 6: PREPARE ORDER ITEMS
-- Source: raw.order_items
-- Grain: One row per order item
-- ============================================================

CREATE OR REPLACE VIEW staging.order_items AS

SELECT *
FROM raw.order_items;

-- ============================================================
-- SECTION 7: ORDER-LEVEL FINANCIAL RECONCILIATION
-- Sources: raw.orders, raw.order_items, raw.order_payments
-- Grain: One row per order
-- ============================================================

CREATE OR REPLACE VIEW staging.order_reconciliation AS

WITH item_totals AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS item_and_freight_total
    FROM staging.order_items
    GROUP BY order_id
),

payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM staging.order_payments
    GROUP BY order_id
)

SELECT
    o.order_id,
    o.order_status,

    i.item_and_freight_total,
    p.payment_total,

    p.payment_total - i.item_and_freight_total AS difference,

    -- DQ-002: Reconciliation classification

    CASE
        WHEN i.order_id IS NULL
            THEN 'Payment without order items'

        WHEN p.order_id IS NULL
            THEN 'Order items without payment'

        WHEN ABS(p.payment_total - i.item_and_freight_total) <= 0.01
            THEN 'Matched'

        WHEN p.payment_total > i.item_and_freight_total
            THEN 'Payment exceeds item total'

        ELSE 'Item total exceeds payment'
    END AS reconciliation_status,

    -- Individual reconciliation flags

    (i.order_id IS NULL)
        AS is_missing_order_items,

    (p.order_id IS NULL)
        AS is_missing_payment,

    (
        i.order_id IS NOT NULL
        AND p.order_id IS NOT NULL
        AND ABS(p.payment_total - i.item_and_freight_total) > 0.01
    ) AS has_reconciliation_difference

FROM raw.orders o

LEFT JOIN item_totals i
    ON o.order_id = i.order_id

LEFT JOIN payment_totals p
    ON o.order_id = p.order_id;

-- ============================================================
-- SECTION 7: PREPARE REFERENCE TABLES
-- ============================================================

-- Geolocation
-- Grain: One row per source geolocation record

CREATE OR REPLACE VIEW staging.geolocation AS

SELECT *
FROM raw.geolocation;


-- Product category translation
-- Grain: One row per source translation record

CREATE OR REPLACE VIEW staging.category_name_translation AS

SELECT *
FROM raw.category_name_translation;

-- ============================================================
-- SECTION 8: PREPARE CUSTOMERS
-- Source: raw.customers
-- Reference: staging.geolocation
-- Grain: One row per customer
-- ============================================================

CREATE OR REPLACE VIEW staging.customers AS

SELECT
    c.*,

    EXISTS (
        SELECT 1
        FROM raw.geolocation g
        WHERE g.geolocation_zip_code_prefix =
              c.customer_zipcode_prefix
    ) AS has_geolocation_match,

    NOT EXISTS (
        SELECT 1
        FROM raw.geolocation g
        WHERE g.geolocation_zip_code_prefix =
              c.customer_zipcode_prefix
    ) AS is_geolocation_unmatched

FROM raw.customers c;

-- ============================================================
-- SECTION 9: PREPARE SELLERS
-- Source: raw.sellers
-- Reference: staging.geolocation
-- Grain: One row per seller
-- ============================================================

CREATE OR REPLACE VIEW staging.sellers AS

WITH seller_prefix_states AS (
    SELECT
        seller_zipcode_prefix,
        COUNT(DISTINCT seller_state) AS distinct_states

    FROM raw.sellers

    GROUP BY seller_zipcode_prefix
)

SELECT
    s.*,

    -- DQ-009: Geolocation coverage

    EXISTS (
        SELECT 1
        FROM raw.geolocation g
        WHERE g.geolocation_zip_code_prefix =
              s.seller_zipcode_prefix
    ) AS has_geolocation_match,

    NOT EXISTS (
        SELECT 1
        FROM raw.geolocation g
        WHERE g.geolocation_zip_code_prefix =
              s.seller_zipcode_prefix
    ) AS is_geolocation_unmatched,

    -- DQ-010: Multiple seller states per postal prefix

    ps.distinct_states AS postal_prefix_distinct_states,

    (ps.distinct_states > 1)
        AS has_ambiguous_postal_prefix_state

FROM raw.sellers s

LEFT JOIN seller_prefix_states ps
    ON ps.seller_zipcode_prefix = s.seller_zipcode_prefix;