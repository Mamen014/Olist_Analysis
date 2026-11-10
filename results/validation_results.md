# Reporting Layer Validation Results

## 1. Purpose

This document records the validation performed after creating the PostgreSQL `analytics` reporting views in `sql/06_reporting_layer.sql`. It complements the data quality assessment: the data quality report concerns source and staging issues, while this document checks whether the reporting views preserve their intended grain, references, and key totals.

The validation was performed in PostgreSQL against the `olist_analysis` database after the reporting views were created. The Power BI default-period results were also reconciled against the SQL analysis benchmarks.

## 2. Source-to-reporting row counts

| Source / staging object | Reporting object | Source rows | Reporting rows | Result |
|---|---|---:|---:|---|
| `staging.orders` | `analytics.fact_orders` | 99,441 | 99,441 | Pass |
| `staging.order_items` | `analytics.fact_order_items` | 112,650 | 112,650 | Pass |
| `staging.order_payments` | `analytics.fact_order_payments` | 103,886 | 103,886 | Pass |
| `staging.customers` | `analytics.dim_customer` | 99,441 | 99,441 | Pass |
| `staging.products` | `analytics.dim_product` | 32,951 | 32,951 | Pass |
| `staging.sellers` | `analytics.dim_seller` | 3,095 | 3,095 | Pass |

`analytics.dim_date` is a generated calendar dimension and is not expected to have a one-to-one source-table row count.

## 3. Fact grain and uniqueness

The reporting facts were checked against their intended keys:

| Fact view | Intended key / grain | Duplicate excess rows |
|---|---|---:|
| `analytics.fact_orders` | `order_id` | 0 |
| `analytics.fact_order_items` | (`order_id`, `order_item_id`) represented by `order_item_key` | 0 |
| `analytics.fact_order_payments` | (`order_id`, `payment_sequential`) represented by `payment_record_key` | 0 |

The row counts equal the distinct count of each fact's declared key. This supports the intended reporting grain and reduces the risk of fan-out introduced by the view definitions.

## 4. Financial-total preservation

The reporting fact totals were compared with the corresponding staging source totals. These figures cover **all order statuses**, not delivered orders only.

| Measure | All-status total |
|---|---:|
| Merchandise value | R$13,591,643.70 |
| Recorded freight value | R$2,251,909.54 |
| Payment value | R$16,008,872.12 |

The order-item and payment totals were preserved in their separate fact views. This separation is intentional: joining item lines directly to payment records can multiply values where an order has multiple items and multiple payment records.

## 5. Order and review population checks

| Validation measure | Result |
|---|---:|
| Total orders | 99,441 |
| Delivered orders | 96,478 |
| Eligible delivered orders | 96,470 |
| On-time orders | 88,644 |
| Late orders | 7,826 |
| Orders with conflicting review scores | 202 |
| Orders with an unambiguous review score | 98,471 |
| Orders with review records but no non-NULL score and no conflict | 0 |

The delivery population uses the reporting-layer eligibility rule: delivered status, purchase timestamp, actual customer-delivery timestamp, and estimated-delivery timestamp must be present, and actual delivery must not precede purchase. Eight delivered orders are excluded because the required delivery conditions are not met.

Review scores are exposed at order grain only when the non-NULL review scores for that order agree. The 202 conflicting-score orders remain present in `fact_orders` but have a NULL `review_score` and a conflict flag.

## 6. Dimension-reference integrity

The Power BI dimension-to-fact relationships were validated against the reporting data. The eight expected dimension-to-fact references returned zero unmatched rows:

- `dim_date` to `fact_orders`;
- `dim_date` to `fact_order_items`;
- `dim_date` to `fact_order_payments`;
- `dim_customer` to `fact_orders`;
- `dim_customer` to `fact_order_items`;
- `dim_customer` to `fact_order_payments`;
- `dim_product` to `fact_order_items`;
- `dim_seller` to `fact_order_items`.

The model uses one-to-many, single-direction relationships from dimensions to facts. There are no fact-to-fact relationships.

## 7. Power BI reconciliation benchmarks

With the full reporting period selected and report slicers cleared, these key report measures should match the SQL baseline:

| Measure | Expected value |
|---|---:|
| Total Orders | 99,441 |
| Delivered Orders | 96,478 |
| Eligible Delivered Orders | 96,470 |
| On-Time Orders | 88,644 |
| Late Orders | 7,826 |
| On-Time Delivery % | 91.89% |
| Average Delivery Days | 12.56 |
| Delivered Merchandise Value | R$13,221,498.11 |
| Delivered Freight Value | R$2,198,275.64 |
| Customers with Delivered Purchases | 93,358 |
| Repeat Customers | 2,801 |
| Repeat Customer % | 3.00% |
| Repeat Customer Merchandise Value Share % | 5.51% |

Additional business-analysis controls:

- Top 10 / 50 / 100 seller merchandise-value contribution: 13.27% / 33.20% / 45.52%.
- Top 10 product categories' share of delivered merchandise value: 62.43%.
- Top six seller states' share of delivered merchandise value: 94.75%.
- São Paulo seller-state share of delivered merchandise value: 64.36%.
- March 2018 on-time delivery rate: 78.64%.

## 8. Interpretation and validation boundary

A passing row-count or key check confirms only the specific property tested. It does not prove that the underlying source data is free from all quality issues, that the metrics are accounting measures, or that every record is suitable for every business question.

All-status reporting totals and delivered-only business metrics have different populations. They should not be compared without applying consistent filters. Delivery and review measures must use their documented eligibility rules.

The Power BI validation is tied to the report model and DAX definitions used for this project. If the SQL views, relationships, or DAX measures change, rerun the relevant checks and update this document.
