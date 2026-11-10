-- ============================================================
-- SECTION 1: ORDER OVERVIEW
-- 1.1 Overall order population
-- ============================================================

SELECT
    COUNT(*) AS total_orders,

    COUNT(DISTINCT o.customer_id)
        AS distinct_customer_records,

    COUNT(DISTINCT c.customer_unique_id)
        AS distinct_customers,

    MIN(o.order_purchase_timestamp)
        AS first_purchase_timestamp,

    MAX(o.order_purchase_timestamp)
        AS last_purchase_timestamp

FROM staging.orders o

LEFT JOIN staging.customers c
    ON o.customer_id = c.customer_id;

-- ============================================================
-- 1.2 Order status distribution
-- ============================================================

WITH status_summary AS (
    SELECT
        order_status,
        COUNT(*) AS total_orders

    FROM staging.orders

    GROUP BY order_status
)

SELECT
    order_status,
    total_orders,

    ROUND(
        100.0 * total_orders /
        SUM(total_orders) OVER (),
        2
    ) AS percentage_of_orders

FROM status_summary

ORDER BY total_orders DESC;

-- ============================================================
-- 1.3 Monthly order volume
-- ============================================================

SELECT
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )::DATE AS purchase_month,

    COUNT(*) AS total_orders,

    COUNT(DISTINCT c.customer_unique_id)
        AS distinct_customers,

    COUNT(*) FILTER (
        WHERE o.order_status = 'delivered'
    ) AS delivered_orders

FROM staging.orders o

LEFT JOIN staging.customers c
    ON o.customer_id = c.customer_id

GROUP BY
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )::DATE

ORDER BY purchase_month;

-- ============================================================
-- SECTION 2: TRANSACTION ANALYSIS
-- 2.1 Overall transaction summary
-- ============================================================

SELECT
    COUNT(*) AS total_orders,

    COUNT(payment_total) AS orders_with_payment,

    COUNT(item_and_freight_total) AS orders_with_items,

    ROUND(
        SUM(payment_total)::NUMERIC,
        2
    ) AS total_payment_value,

    ROUND(
        SUM(item_and_freight_total)::NUMERIC,
        2
    ) AS total_item_and_freight_value,

    ROUND(
        AVG(payment_total)::NUMERIC,
        2
    ) AS average_payment_per_order,

    ROUND(
        AVG(item_and_freight_total)::NUMERIC,
        2
    ) AS average_item_and_freight_per_order

FROM staging.order_reconciliation;

-- ============================================================
-- 2.2 Payment method distribution
-- ============================================================

SELECT
    payment_type,

    COUNT(*) AS total_payment_records,

    COUNT(DISTINCT order_id) AS distinct_orders,

    ROUND(
        SUM(payment_value)::NUMERIC,
        2
    ) AS total_payment_value,

    ROUND(
        100.0 * SUM(payment_value) /
        SUM(SUM(payment_value)) OVER (),
        2
    ) AS percentage_of_payment_value

FROM staging.order_payments

GROUP BY payment_type

ORDER BY total_payment_value DESC;

-- ============================================================
-- 2.3 Order payment value distribution
-- One row per order
-- ============================================================

SELECT
    COUNT(payment_total) AS orders_with_payment,

    ROUND(
        MIN(payment_total)::NUMERIC,
        2
    ) AS minimum_order_value,

    ROUND(
        AVG(payment_total)::NUMERIC,
        2
    ) AS average_order_value,

    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY payment_total)::NUMERIC,
        2
    ) AS median_order_value,

    ROUND(
        PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY payment_total)::NUMERIC,
        2
    ) AS third_quartile_order_value,

    ROUND(
        MAX(payment_total)::NUMERIC,
        2
    ) AS maximum_order_value

FROM staging.order_reconciliation

WHERE payment_total IS NOT NULL;

-- ============================================================
-- SECTION 3: CUSTOMER ANALYSIS
-- 3.1 Customer purchasing frequency
-- ============================================================

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(o.order_id) AS total_orders

    FROM staging.customers c

    JOIN staging.orders o
        ON c.customer_id = o.customer_id

    GROUP BY c.customer_unique_id
)

SELECT
    COUNT(*) AS total_unique_customers,

    COUNT(*) FILTER (
        WHERE total_orders = 1
    ) AS single_order_customers,

    COUNT(*) FILTER (
        WHERE total_orders > 1
    ) AS repeat_customers,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE total_orders > 1
        ) / COUNT(*),
        2
    ) AS repeat_customer_percentage,

    ROUND(
        AVG(total_orders),
        2
    ) AS average_orders_per_customer,

    MAX(total_orders) AS maximum_orders_by_customer

FROM customer_orders;

-- ============================================================
-- SECTION 4: PRODUCT ANALYSIS
-- 4.1 Product catalog distribution by category
-- ============================================================

SELECT
    COALESCE(
        product_category_name_for_analysis,
        'Uncategorized'
    ) AS product_category,

    COUNT(*) AS total_products,

    COUNT(*) FILTER (
        WHERE is_missing_category
    ) AS products_missing_category,

    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_products

FROM staging.products

GROUP BY
    COALESCE(
        product_category_name_for_analysis,
        'Uncategorized'
    )

ORDER BY total_products DESC;

-- ============================================================
-- 4.2 Delivered transaction performance by category
-- ============================================================

SELECT
    COALESCE(
        p.product_category_name_for_analysis,
        'Uncategorized'
    ) AS product_category,

    COUNT(*) AS delivered_order_item_lines,

    COUNT(DISTINCT oi.product_id)
        AS distinct_products,

    COUNT(DISTINCT oi.order_id)
        AS delivered_orders,

    ROUND(
        SUM(oi.price)::NUMERIC,
        2
    ) AS merchandise_value,

    ROUND(
        SUM(oi.freight_value)::NUMERIC,
        2
    ) AS freight_value,

    ROUND(
        AVG(oi.price)::NUMERIC,
        2
    ) AS average_item_price

FROM staging.order_items oi

JOIN staging.orders o
    ON oi.order_id = o.order_id

JOIN staging.products p
    ON oi.product_id = p.product_id

WHERE o.order_status = 'delivered'

GROUP BY
    COALESCE(
        p.product_category_name_for_analysis,
        'Uncategorized'
    )

ORDER BY merchandise_value DESC;

-- ============================================================
-- 4.3 Top 20 products by delivered order-item activity
-- ============================================================

SELECT
    oi.product_id,

    COALESCE(
        p.product_category_name_for_analysis,
        'Uncategorized'
    ) AS product_category,

    COUNT(*) AS delivered_order_item_lines,

    COUNT(DISTINCT oi.order_id)
        AS distinct_orders,

    ROUND(
        SUM(oi.price)::NUMERIC,
        2
    ) AS merchandise_value,

    ROUND(
        AVG(oi.price)::NUMERIC,
        2
    ) AS average_item_price

FROM staging.order_items oi

JOIN staging.orders o
    ON oi.order_id = o.order_id

JOIN staging.products p
    ON oi.product_id = p.product_id

WHERE o.order_status = 'delivered'

GROUP BY
    oi.product_id,
    p.product_category_name_for_analysis

ORDER BY
    delivered_order_item_lines DESC,
    merchandise_value DESC

LIMIT 20;

-- ============================================================
-- SECTION 5: SELLER ANALYSIS
-- 5.1 Seller geographic distribution
-- ============================================================

SELECT
    seller_state,

    COUNT(*) AS total_sellers,

    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_sellers

FROM staging.sellers

GROUP BY seller_state

ORDER BY total_sellers DESC;

-- ============================================================
-- 5.2 Seller transaction activity
-- ============================================================

SELECT
    oi.seller_id,

    s.seller_state,

    COUNT(*) AS delivered_order_item_lines,

    COUNT(DISTINCT oi.order_id)
        AS delivered_orders,

    COUNT(DISTINCT oi.product_id)
        AS distinct_products,

    ROUND(
        SUM(oi.price)::NUMERIC,
        2
    ) AS merchandise_value,

    ROUND(
        SUM(oi.freight_value)::NUMERIC,
        2
    ) AS freight_value

FROM staging.order_items oi

JOIN staging.orders o
    ON oi.order_id = o.order_id

JOIN staging.sellers s
    ON oi.seller_id = s.seller_id

WHERE o.order_status = 'delivered'

GROUP BY
    oi.seller_id,
    s.seller_state

ORDER BY merchandise_value DESC;

-- ============================================================
-- 5.3 Top 20 sellers by merchandise value
-- ============================================================

SELECT
    oi.seller_id,

    s.seller_state,

    COUNT(DISTINCT oi.order_id)
        AS delivered_orders,

    COUNT(*) AS delivered_order_item_lines,

    ROUND(
        SUM(oi.price)::NUMERIC,
        2
    ) AS merchandise_value,

    ROUND(
        AVG(oi.price)::NUMERIC,
        2
    ) AS average_item_price

FROM staging.order_items oi

JOIN staging.orders o
    ON oi.order_id = o.order_id

JOIN staging.sellers s
    ON oi.seller_id = s.seller_id

WHERE o.order_status = 'delivered'

GROUP BY
    oi.seller_id,
    s.seller_state

ORDER BY merchandise_value DESC

LIMIT 20;

-- ============================================================
-- 5.4 Seller contribution concentration
-- ============================================================

WITH seller_sales AS (
    SELECT
        oi.seller_id,

        SUM(oi.price) AS merchandise_value

    FROM staging.order_items oi

    JOIN staging.orders o
        ON oi.order_id = o.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY oi.seller_id
),

ranked_sellers AS (
    SELECT
        seller_id,
        merchandise_value,

        SUM(merchandise_value) OVER ()
            AS total_merchandise_value,

        ROW_NUMBER() OVER (
            ORDER BY merchandise_value DESC
        ) AS seller_rank

    FROM seller_sales
)

SELECT
    COUNT(*) AS active_sellers,

    ROUND(
        SUM(merchandise_value)::NUMERIC,
        2
    ) AS total_merchandise_value,

    ROUND(
        100.0 * SUM(merchandise_value)
            FILTER (WHERE seller_rank <= 10)
        / SUM(merchandise_value),
        2
    ) AS top_10_seller_contribution,

    ROUND(
        100.0 * SUM(merchandise_value)
            FILTER (WHERE seller_rank <= 50)
        / SUM(merchandise_value),
        2
    ) AS top_50_seller_contribution,

    ROUND(
        100.0 * SUM(merchandise_value)
            FILTER (WHERE seller_rank <= 100)
        / SUM(merchandise_value),
        2
    ) AS top_100_seller_contribution

FROM ranked_sellers;

-- ============================================================
-- SECTION 5: DELIVERY PERFORMANCE
-- 6.1 Overall delivery performance
-- ============================================================
SELECT
    COUNT(*) AS eligible_delivered_orders,

    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_purchase_timestamp
                )
            ) / 86400.0
        )::NUMERIC,
        2
    ) AS avg_delivery_days,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_purchase_timestamp
                )
            ) / 86400.0
        )::NUMERIC,
        2
    ) AS median_delivery_days,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date
              <= order_estimated_delivery_date
    ) AS on_time_orders,

    COUNT(*) FILTER (
        WHERE order_delivered_customer_date
              > order_estimated_delivery_date
    ) AS late_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE order_delivered_customer_date
                  <= order_estimated_delivery_date
        ) / COUNT(*),
        2
    ) AS on_time_delivery_percentage

FROM staging.orders
WHERE order_status = 'delivered'
  AND order_purchase_timestamp IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
  AND order_delivered_customer_date >= order_purchase_timestamp;

-- ============================================================
-- 6.2 Monthly delivery performance
-- ============================================================  
WITH eligible_orders AS (
    SELECT
        DATE_TRUNC(
            'month',
            order_purchase_timestamp
        )::DATE AS purchase_month,

        EXTRACT(
            EPOCH FROM (
                order_delivered_customer_date
                - order_purchase_timestamp
            )
        ) / 86400.0 AS delivery_days,

        order_delivered_customer_date
            <= order_estimated_delivery_date AS is_on_time

    FROM staging.orders
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date >= order_purchase_timestamp
)

SELECT
    TO_CHAR(purchase_month, 'YYYY-MM') AS purchase_month,

    COUNT(*) AS eligible_delivered_orders,

    ROUND(
        AVG(delivery_days)::NUMERIC,
        2
    ) AS avg_delivery_days,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY delivery_days
        )::NUMERIC,
        2
    ) AS median_delivery_days,

    COUNT(*) FILTER (
        WHERE is_on_time
    ) AS on_time_orders,

    COUNT(*) FILTER (
        WHERE NOT is_on_time
    ) AS late_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE is_on_time
        ) / COUNT(*),
        2
    ) AS on_time_delivery_percentage

FROM eligible_orders
GROUP BY purchase_month
ORDER BY purchase_month;

-- ============================================================
-- 6.3 Delivery performance by customer state
-- ============================================================ 
WITH eligible_orders AS (
    SELECT
        c.customer_state,

        EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_purchase_timestamp
            )
        ) / 86400.0 AS delivery_days,

        o.order_delivered_customer_date
            <= o.order_estimated_delivery_date AS is_on_time

    FROM staging.orders o
    JOIN staging.customers c
        ON o.customer_id = c.customer_id

    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
      AND o.order_delivered_customer_date >= o.order_purchase_timestamp
)

SELECT
    customer_state,

    COUNT(*) AS eligible_delivered_orders,

    ROUND(
        AVG(delivery_days)::NUMERIC,
        2
    ) AS avg_delivery_days,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY delivery_days
        )::NUMERIC,
        2
    ) AS median_delivery_days,

    COUNT(*) FILTER (
        WHERE is_on_time
    ) AS on_time_orders,

    COUNT(*) FILTER (
        WHERE NOT is_on_time
    ) AS late_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE is_on_time
        ) / COUNT(*),
        2
    ) AS on_time_delivery_percentage

FROM eligible_orders
GROUP BY customer_state
HAVING COUNT(*) >= 100
ORDER BY avg_delivery_days DESC;

-- ============================================================
-- 6.4 Delivery schedule deviation
-- ============================================================ 
WITH delivery_deviation AS (
    SELECT
        EXTRACT(
            EPOCH FROM (
                order_delivered_customer_date
                - order_estimated_delivery_date
            )
        ) / 86400.0 AS deviation_days

    FROM staging.orders
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date >= order_purchase_timestamp
)

SELECT
    COUNT(*) AS eligible_delivered_orders,

    COUNT(*) FILTER (
        WHERE deviation_days <= 0
    ) AS orders_delivered_on_or_before_estimate,

    COUNT(*) FILTER (
        WHERE deviation_days > 0
    ) AS late_orders,

    ROUND(
        AVG(deviation_days)::NUMERIC,
        2
    ) AS avg_schedule_deviation_days,

    ROUND(
        AVG(deviation_days) FILTER (
            WHERE deviation_days > 0
        )::NUMERIC,
        2
    ) AS avg_days_late,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY deviation_days
        ) FILTER (
            WHERE deviation_days > 0
        )::NUMERIC,
        2
    ) AS median_days_late,

    ROUND(
        PERCENTILE_CONT(0.9) WITHIN GROUP (
            ORDER BY deviation_days
        ) FILTER (
            WHERE deviation_days > 0
        )::NUMERIC,
        2
    ) AS p90_days_late

FROM delivery_deviation;

-- ============================================================
-- SECTION 5: REVIEW ANALYSIS
-- 7.1 Review score distribution
-- ============================================================
SELECT
    review_score,

    COUNT(*) AS review_records,

    COUNT(DISTINCT order_id) AS distinct_orders,

    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_review_records,

    COUNT(*) FILTER (
        WHERE has_duplicate_review_id
    ) AS records_with_reused_review_id,

    COUNT(*) FILTER (
        WHERE has_duplicate_order_id
    ) AS records_with_duplicate_order_id

FROM staging.order_reviews
GROUP BY review_score
ORDER BY review_score DESC;

-- ============================================================
-- 7.2 Review records per order
-- ============================================================
WITH order_review_summary AS (
    SELECT
        order_id,
        COUNT(*) AS review_records,
        COUNT(DISTINCT review_id) AS distinct_review_ids,
        COUNT(DISTINCT review_score) AS distinct_review_scores

    FROM staging.order_reviews
    GROUP BY order_id
)

SELECT
    review_records,

    COUNT(*) AS orders,

    COUNT(*) FILTER (
        WHERE distinct_review_scores > 1
    ) AS orders_with_multiple_scores,

    COUNT(*) FILTER (
        WHERE distinct_review_ids < review_records
    ) AS orders_with_repeated_review_ids

FROM order_review_summary
GROUP BY review_records
ORDER BY review_records;

-- ============================================================
-- 7.3 Order-level review score distribution
-- ============================================================
WITH order_review_summary AS (
    SELECT
        order_id,
        COUNT(*) AS review_records,
        COUNT(DISTINCT review_score) AS distinct_review_scores,
        MIN(review_score) AS review_score

    FROM staging.order_reviews
    GROUP BY order_id
),

eligible_order_reviews AS (
    SELECT *
    FROM order_review_summary
    WHERE distinct_review_scores = 1
)

SELECT
    review_score,

    COUNT(*) AS distinct_orders,

    SUM(review_records) AS underlying_review_records,

    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_orders

FROM eligible_order_reviews
GROUP BY review_score
ORDER BY review_score DESC;

-- ============================================================
-- 7.4 Review score and delivery performance
-- ============================================================
WITH order_review_summary AS (
    SELECT
        order_id,
        COUNT(DISTINCT review_score) AS distinct_review_scores,
        MIN(review_score) AS review_score

    FROM staging.order_reviews
    GROUP BY order_id
),

eligible_order_reviews AS (
    SELECT
        order_id,
        review_score
    FROM order_review_summary
    WHERE distinct_review_scores = 1
),

delivery_data AS (
    SELECT
        o.order_id,
        r.review_score,

        EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_purchase_timestamp
            )
        ) / 86400.0 AS delivery_days,

        o.order_delivered_customer_date
            <= o.order_estimated_delivery_date AS is_on_time

    FROM staging.orders o
    JOIN eligible_order_reviews r
        ON o.order_id = r.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
      AND o.order_delivered_customer_date >= o.order_purchase_timestamp
)

SELECT
    review_score,

    COUNT(*) AS eligible_delivered_orders,

    ROUND(
        AVG(delivery_days)::NUMERIC,
        2
    ) AS avg_delivery_days,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY delivery_days
        )::NUMERIC,
        2
    ) AS median_delivery_days,

    COUNT(*) FILTER (
        WHERE is_on_time
    ) AS on_time_orders,

    COUNT(*) FILTER (
        WHERE NOT is_on_time
    ) AS late_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE is_on_time
        ) / COUNT(*),
        2
    ) AS on_time_delivery_percentage

FROM delivery_data
GROUP BY review_score
ORDER BY review_score DESC;

-- ============================================================
-- 7.5 Review scores by delivery status
-- ============================================================
WITH order_review_summary AS (
    SELECT
        order_id,
        COUNT(DISTINCT review_score) AS distinct_review_scores,
        MIN(review_score) AS review_score
    FROM staging.order_reviews
    GROUP BY order_id
),

eligible_order_reviews AS (
    SELECT
        order_id,
        review_score
    FROM order_review_summary
    WHERE distinct_review_scores = 1
),

delivery_data AS (
    SELECT
        o.order_id,
        r.review_score,

        CASE
            WHEN o.order_delivered_customer_date
                 <= o.order_estimated_delivery_date
            THEN 'On time'
            ELSE 'Late'
        END AS delivery_status

    FROM staging.orders o
    JOIN eligible_order_reviews r
        ON o.order_id = r.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
      AND o.order_delivered_customer_date >= o.order_purchase_timestamp
),

score_distribution AS (
    SELECT
        delivery_status,
        review_score,
        COUNT(*) AS orders
    FROM delivery_data
    GROUP BY delivery_status, review_score
)

SELECT
    delivery_status,
    review_score,
    orders,

    ROUND(
        100.0 * orders /
        SUM(orders) OVER (
            PARTITION BY delivery_status
        ),
        2
    ) AS percentage_within_delivery_status

FROM score_distribution
ORDER BY
    delivery_status,
    review_score DESC;