# Data Model and Reporting Architecture

## 1. Architecture overview

The project separates source preservation, data preparation, and BI reporting into three PostgreSQL schemas.

```text
Olist CSV files
     |
     v
raw schema  --------------------  Source records preserved
     |
     v
staging schema ----------------  Quality flags, approved transformations,
     |                            reconciliation and analysis-ready fields
     v
analytics schema --------------  Power BI reporting dimensions and facts
     |
     v
Power BI semantic model -------- DAX measures and report pages
```

The raw layer is not overwritten by staging or reporting transformations. The analytics layer is created by `sql/06_reporting_layer.sql` and reads from staging.

## 2. PostgreSQL reporting objects

The reporting layer contains four dimensions and three fact views.

### 2.1 Dimensions

| View | Grain | Main fields | Description |
|---|---|---|---|
| `analytics.dim_date` | One row per calendar date | `date_key`, `calendar_year`, `calendar_quarter`, `month_number`, `year_month`, `year_month_sort`, week/day attributes | Calendar dimension covering the purchase-date range |
| `analytics.dim_customer` | One row per `customer_id` | `customer_id`, `customer_unique_id`, `customer_zipcode_prefix`, `customer_city`, `customer_state` | Customer record and underlying unique-customer identifier |
| `analytics.dim_product` | One row per `product_id` | `product_id`, `product_category` | Product category field prepared for analysis; missing categories use the staging fallback |
| `analytics.dim_seller` | One row per `seller_id` | `seller_id`, `seller_zipcode_prefix`, `seller_city`, `seller_state` | Seller master attributes |

### 2.2 Fact views

| View | Grain | Main measures / attributes | Intended use |
|---|---|---|---|
| `analytics.fact_orders` | One row per `order_id` | Status, lifecycle timestamps, item/payment aggregates, review aggregation, delivery eligibility, delivery days, deviation, late days, reconciliation status | Order KPIs, customer purchase behavior, delivery and review analysis |
| `analytics.fact_order_items` | One row per (`order_id`, `order_item_id`) | `merchandise_value`, `freight_value`, `item_and_freight_value`, product, seller, status, customer, purchase date | Product/category and seller performance |
| `analytics.fact_order_payments` | One row per (`order_id`, `payment_sequential`) | `payment_type`, `payment_installments`, `payment_value`, order/customer/date attributes | Payment-method, installment, and payment-record analysis |

## 3. Fact-table design decisions

### 3.1 Keep facts at their natural grains

Order items and payments are separate facts because both can have multiple rows per order. Joining them directly at order level can multiply rows and overstate merchandise, freight, or payment totals.

The `fact_orders` view first aggregates item, payment, and review records independently by `order_id`, then joins those order-level aggregates to the order table. This preserves one row per order.

### 3.2 Merchandise and freight

- `merchandise_value` is the sum of item `price`; freight is excluded.
- `freight_value` is the sum of recorded item-level freight charges.
- `item_and_freight_value` is merchandise plus recorded freight.
- `payment_value` is independently aggregated from payment records.

These amounts should not be treated as interchangeable. Payment totals are not automatically accounting revenue, and recorded freight is not actual logistics cost.

### 3.3 Review aggregation

The reporting layer exposes an order-level review score only when all non-NULL review scores associated with that order agree. If the order has conflicting scores, `review_score` is NULL and `has_conflicting_review_scores` is true. This avoids silently selecting one conflicting score.

### 3.4 Delivery eligibility

An order is marked `is_delivery_eligible` when:

- `order_status = 'delivered'`;
- purchase timestamp is present;
- actual customer-delivery timestamp is present;
- estimated-delivery timestamp is present; and
- actual customer delivery is not earlier than purchase.

`delivery_days` measures purchase to actual customer delivery. `delivery_deviation_days` measures actual delivery minus estimated delivery. Positive deviation means late; zero means on estimate; negative means early. `late_days` is populated only for eligible orders delivered after the estimate.

## 4. Power BI relationships

Use one-to-many, single-direction relationships from dimensions to facts.

| One-side dimension | Many-side fact | Join columns |
|---|---|---|
| `Dim Date` | `Fact Orders` | `date_key` → `purchase_date_key` |
| `Dim Date` | `Fact Order Items` | `date_key` → `purchase_date_key` |
| `Dim Date` | `Fact Order Payments` | `date_key` → `purchase_date_key` |
| `Dim Customer` | `Fact Orders` | `customer_id` |
| `Dim Customer` | `Fact Order Items` | `customer_id` |
| `Dim Customer` | `Fact Order Payments` | `customer_id` |
| `Dim Product` | `Fact Order Items` | `product_id` |
| `Dim Seller` | `Fact Order Items` | `seller_id` |

Do not create fact-to-fact relationships. Product and seller dimensions filter order items, not order-level or payment facts directly. Measures that combine these grains must account for that model design.

The date relationships are based on purchase date. Analyses by approval, carrier-handoff, or delivery date would require role-playing date dimensions or additional inactive relationships; they are not implied by the current active relationships.

## 5. Customer identity and geography

`Dim Customer` is at `customer_id` grain, not unique-person grain. Multiple customer records can share one `customer_unique_id`. Distinct customer and repeat-purchase measures therefore use `customer_unique_id`, while relationships to facts use `customer_id`.

Customer state is the state on the customer record. If a unique customer is represented by records in multiple states, state-level distinct customer counts can overlap. Do not sum state distinct counts to obtain the global distinct-customer count.

Seller state comes from the seller master record. It describes seller location, not customer delivery destination.

## 6. Validation

The reporting layer was checked for source-to-view row-count preservation, fact grain uniqueness, financial-total preservation, review-score population, and dimension-reference integrity. See [`../results/validation_results.md`](../results/validation_results.md) and the validation queries at the end of `sql/06_reporting_layer.sql`.
