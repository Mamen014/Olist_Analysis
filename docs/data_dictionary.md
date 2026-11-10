# Data Dictionary

## 1. Purpose

This document describes the source tables, their main identifiers, and the fields most relevant to the analysis. It is a practical project data dictionary, not a replacement for the complete source CSV schemas. The raw CSV headers should remain unchanged when loading the dataset.

The project uses three database layers:

- `raw`: source tables loaded from the Olist CSV files without analytical transformation.
- `staging`: prepared tables with explicit quality flags and approved analysis-specific transformations.
- `analytics`: reporting views consumed by Power BI.

## 2. Source tables

| Source CSV | Raw table | Main grain / identifier | Analytical purpose |
|---|---|---|---|
| `olist_customers_dataset.csv` | `raw.customers` | One customer record per `customer_id` | Customer location and unique-person mapping |
| `olist_orders_dataset.csv` | `raw.orders` | One order per `order_id` | Order status and lifecycle timestamps |
| `olist_order_items_dataset.csv` | `raw.order_items` | One order item per (`order_id`, `order_item_id`) | Product, seller, item price, and freight |
| `olist_order_payments_dataset.csv` | `raw.order_payments` | One payment record per (`order_id`, `payment_sequential`) | Payment method, installments, and payment value |
| `olist_order_reviews_dataset.csv` | `raw.order_reviews` | One review record as supplied; neither `review_id` nor `order_id` is unique in this dataset | Review scores, review text, and review timestamps |
| `olist_products_dataset.csv` | `raw.products` | One product per `product_id` | Product attributes and category |
| `olist_sellers_dataset.csv` | `raw.sellers` | One seller per `seller_id` | Seller location and seller analysis |
| `olist_geolocation_dataset.csv` | `raw.geolocation` | Multiple geolocation records may exist for a postal prefix | Postal-prefix geographic reference |
| `product_category_name_translation.csv` | `raw.category_name_translation` | One source category translation entry | Portuguese-to-English category labels |

## 3. Important source fields

### 3.1 Customers

| Field | Meaning | Notes |
|---|---|---|
| `customer_id` | Customer record identifier | Key for the order-to-customer relationship |
| `customer_unique_id` | Identifier used to associate customer records with an underlying unique customer | Use this for distinct-person and repeat-customer analysis |
| `customer_zipcode_prefix` | Customer postal-code prefix | Preserve the source spelling; do not rename silently |
| `customer_city` | Customer city | Source geographic attribute |
| `customer_state` | Customer state abbreviation | Customer geography, not seller geography |

### 3.2 Orders

| Field | Meaning |
|---|---|
| `order_id` | Order identifier |
| `customer_id` | Customer record associated with the order |
| `order_status` | Recorded order lifecycle status |
| `order_purchase_timestamp` | Purchase timestamp |
| `order_approved_at` | Payment/order approval timestamp |
| `order_delivered_carrier_date` | Carrier handoff timestamp |
| `order_delivered_customer_date` | Customer delivery timestamp |
| `order_estimated_delivery_date` | Estimated customer delivery timestamp |

### 3.3 Order items

| Field | Meaning |
|---|---|
| `order_id` | Parent order |
| `order_item_id` | Item sequence within an order |
| `product_id` | Product reference |
| `seller_id` | Seller reference |
| `shipping_limit_date` | Seller shipping-limit timestamp |
| `price` | Recorded item price; used as merchandise value |
| `freight_value` | Recorded freight charge associated with the item |

### 3.4 Payments

| Field | Meaning |
|---|---|
| `order_id` | Parent order |
| `payment_sequential` | Payment record sequence within an order |
| `payment_type` | Payment method category |
| `payment_installments` | Recorded number of installments |
| `payment_value` | Recorded payment amount |

### 3.5 Reviews

| Field | Meaning | Notes |
|---|---|---|
| `review_id` | Review identifier | Reused across different orders in the source; not a safe unique join key |
| `order_id` | Associated order | An order can have multiple review records |
| `review_score` | Score from 1 to 5 | Multiple records for one order can have conflicting scores |
| `review_comment_title` | Review title | Can be empty or missing |
| `review_comment_message` | Review text | Can be empty or missing |
| `review_creation_date` | Review creation timestamp | Used in temporal checks |
| `review_answer_timestamp` | Review response timestamp | Used in temporal checks |

### 3.6 Products

| Field | Meaning |
|---|---|
| `product_id` | Product identifier |
| `product_category_name` | Source product category |
| `product_name_lenght` | Source product-name length field; spelling is retained as supplied |
| `product_description_lenght` | Source product-description length field; spelling is retained as supplied |
| `product_photos_qty` | Number of product photos |
| `product_weight_g` | Product weight in grams |
| `product_length_cm` | Product length in centimeters |
| `product_height_cm` | Product height in centimeters |
| `product_width_cm` | Product width in centimeters |

The two `lenght` field names are source spellings. Do not silently change them in the raw table. The staging/reporting layer can expose clearer aliases if deliberately implemented and documented.

### 3.7 Sellers

| Field | Meaning |
|---|---|
| `seller_id` | Seller identifier |
| `seller_zipcode_prefix` | Seller postal-code prefix |
| `seller_city` | Seller city |
| `seller_state` | Seller state abbreviation |

### 3.8 Geolocation and category translation

Common geolocation fields include `geolocation_zip_code_prefix`, `geolocation_lat`, `geolocation_lng`, `geolocation_city`, and `geolocation_state`. Multiple coordinate records may be associated with a postal prefix; do not assume this table is unique by prefix.

The translation table contains `product_category_name` and `product_category_name_english`. Two source categories were not present in the translation table and are retained using the source category as fallback.

## 4. Important grain distinctions

- `customer_id` identifies a customer record; `customer_unique_id` is used for distinct-person analysis.
- `order_id` identifies an order.
- `order_item_id` is only unique within its order; use the composite (`order_id`, `order_item_id`) as the order-item grain.
- `payment_sequential` is only unique within its order; use (`order_id`, `payment_sequential`) as the payment-record grain.
- `review_id` is not unique across the source review records, and an order can have multiple review records.
- `product_id` and `seller_id` identify products and sellers, respectively.

Always state the grain when reporting row counts, customer counts, orders, item lines, payment records, or review scores.
