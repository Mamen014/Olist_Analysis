-- ============================================================
-- BA-01 Customer purchase frequency and value contribution
-- ============================================================

WITH customer_value AS (
    SELECT
        c.customer_unique_id,

        COUNT(DISTINCT o.order_id) AS delivered_orders,

        SUM(oi.price) AS merchandise_value,

        SUM(oi.freight_value) AS freight_value

    FROM staging.orders o

    JOIN staging.customers c
        ON o.customer_id = c.customer_id

    JOIN staging.order_items oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY c.customer_unique_id
),

customer_segments AS (
    SELECT
        customer_unique_id,
        delivered_orders,
        merchandise_value,
        freight_value,

        CASE
            WHEN delivered_orders = 1 THEN 'One-time'
            WHEN delivered_orders = 2 THEN '2 orders'
            ELSE '3+ orders'
        END AS customer_segment

    FROM customer_value
)

SELECT
    customer_segment,

    COUNT(*) AS customers,

    SUM(delivered_orders) AS delivered_orders,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_percentage,

    ROUND(
        100.0 * SUM(delivered_orders)
        / SUM(SUM(delivered_orders)) OVER (),
        2
    ) AS order_percentage,

    ROUND(
        SUM(merchandise_value)::NUMERIC,
        2
    ) AS merchandise_value,

    ROUND(
        100.0 * SUM(merchandise_value)
        / SUM(SUM(merchandise_value)) OVER (),
        2
    ) AS merchandise_value_percentage,

    ROUND(
        (SUM(merchandise_value) / COUNT(*))::NUMERIC,
        2
    ) AS avg_merchandise_per_customer,

    ROUND(
        (SUM(merchandise_value) / SUM(delivered_orders))::NUMERIC,
        2
    ) AS avg_merchandise_per_order,

    ROUND(
        100.0 * SUM(freight_value)
        / NULLIF(SUM(merchandise_value), 0),
        2
    ) AS freight_to_merchandise_percentage

FROM customer_segments

GROUP BY customer_segment

ORDER BY
    CASE customer_segment
        WHEN 'One-time' THEN 1
        WHEN '2 orders' THEN 2
        ELSE 3
    END;

-- ============================================================
-- BA-02 Product category commercial performance
-- ============================================================
WITH category_performance AS (
    SELECT
        COALESCE(
            p.product_category_name_for_analysis,
            'Uncategorized'
        ) AS product_category,

        COUNT(*) AS delivered_item_lines,

        COUNT(DISTINCT oi.order_id) AS delivered_orders,

        COUNT(DISTINCT oi.product_id) AS distinct_products,

        SUM(oi.price) AS merchandise_value,

        SUM(oi.freight_value) AS freight_value,

        AVG(oi.price) AS average_item_price

    FROM staging.orders o

    JOIN staging.order_items oi
        ON o.order_id = oi.order_id

    JOIN staging.products p
        ON oi.product_id = p.product_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        COALESCE(
            p.product_category_name_for_analysis,
            'Uncategorized'
        )
)

SELECT
    product_category,

    delivered_orders,

    delivered_item_lines,

    distinct_products,

    ROUND(
        merchandise_value::NUMERIC,
        2
    ) AS merchandise_value,

    ROUND(
        100.0 * merchandise_value
        / SUM(merchandise_value) OVER (),
        2
    ) AS merchandise_value_share,

    ROUND(
        average_item_price::NUMERIC,
        2
    ) AS average_item_price,

    ROUND(
        freight_value::NUMERIC,
        2
    ) AS freight_value,

    ROUND(
        100.0 * freight_value
        / NULLIF(merchandise_value, 0),
        2
    ) AS freight_to_merchandise_percentage

FROM category_performance

ORDER BY merchandise_value DESC;

-- ============================================================
-- BA-03 Seller commercial contribution by state
-- ============================================================
WITH seller_activity AS (
    SELECT
        s.seller_id,
        s.seller_state,

        COUNT(*) AS delivered_order_item_lines,

        SUM(oi.price) AS merchandise_value,

        SUM(oi.freight_value) AS freight_value

    FROM staging.sellers s

    JOIN staging.order_items oi
        ON s.seller_id = oi.seller_id

    JOIN staging.orders o
        ON oi.order_id = o.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY
        s.seller_id,
        s.seller_state
),

state_performance AS (
    SELECT
        s.seller_state,

        COUNT(*) AS registered_sellers,

        COUNT(sa.seller_id) AS active_sellers,

        COALESCE(
            SUM(sa.delivered_order_item_lines),
            0
        ) AS delivered_order_item_lines,

        COALESCE(
            SUM(sa.merchandise_value),
            0
        ) AS merchandise_value,

        COALESCE(
            SUM(sa.freight_value),
            0
        ) AS freight_value

    FROM staging.sellers s

    LEFT JOIN seller_activity sa
        ON s.seller_id = sa.seller_id

    GROUP BY s.seller_state
)

SELECT
    seller_state,

    registered_sellers,

    active_sellers,

    ROUND(
        100.0 * active_sellers
        / registered_sellers,
        2
    ) AS active_seller_percentage,

    delivered_order_item_lines,

    ROUND(
        merchandise_value::NUMERIC,
        2
    ) AS merchandise_value,

    ROUND(
        100.0 * merchandise_value
        / NULLIF(
            SUM(merchandise_value) OVER (),
            0
        ),
        2
    ) AS merchandise_value_share,

    ROUND(
        (
            merchandise_value
            / NULLIF(active_sellers, 0)
        )::NUMERIC,
        2
    ) AS avg_merchandise_per_active_seller,

    ROUND(
        (
            100.0 * freight_value
            / NULLIF(merchandise_value, 0)
        )::NUMERIC,
        2
    ) AS freight_to_merchandise_percentage

FROM state_performance

ORDER BY merchandise_value DESC;

-- ============================================================
-- BA-04 Customer-state operational performance
-- ============================================================
WITH order_review_summary AS (
    SELECT
        order_id,

        CASE
            WHEN COUNT(DISTINCT review_score) = 1
            THEN MIN(review_score)
        END AS review_score

    FROM staging.order_reviews
    GROUP BY order_id
),

delivery_data AS (
    SELECT
        o.order_id,
        c.customer_state,
        r.review_score,

        EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_purchase_timestamp
            )
        ) / 86400.0 AS delivery_days,

        EXTRACT(
            EPOCH FROM (
                o.order_delivered_customer_date
                - o.order_estimated_delivery_date
            )
        ) / 86400.0 AS delay_days

    FROM staging.orders o

    JOIN staging.customers c
        ON o.customer_id = c.customer_id

    LEFT JOIN order_review_summary r
        ON o.order_id = r.order_id

    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
      AND o.order_delivered_customer_date
          >= o.order_purchase_timestamp
)

SELECT
    customer_state,

    COUNT(*) AS eligible_delivered_orders,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS order_volume_share,

    ROUND(
        AVG(delivery_days)::NUMERIC,
        2
    ) AS avg_delivery_days,

    COUNT(*) FILTER (
        WHERE delay_days > 0
    ) AS late_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE delay_days > 0
        ) / COUNT(*),
        2
    ) AS late_delivery_percentage,

    ROUND(
        AVG(delay_days) FILTER (
            WHERE delay_days > 0
        )::NUMERIC,
        2
    ) AS avg_days_late,

    COUNT(*) FILTER (
        WHERE review_score IS NOT NULL
    ) AS reviewed_delivered_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE review_score IS NOT NULL
        ) / COUNT(*),
        2
    ) AS review_coverage_percentage,

    COUNT(*) FILTER (
        WHERE review_score IN (1, 2)
    ) AS low_rating_orders,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE review_score IN (1, 2)
        ) / NULLIF(
            COUNT(*) FILTER (
                WHERE review_score IS NOT NULL
            ),
            0
        ),
        2
    ) AS low_rating_percentage

FROM delivery_data

GROUP BY customer_state

HAVING COUNT(*) >= 100

ORDER BY eligible_delivered_orders DESC;