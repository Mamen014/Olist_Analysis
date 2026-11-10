# Metric Dictionary

## 1. Purpose and conventions

This dictionary defines the principal metrics used in the SQL analysis and Power BI report. It clarifies the population, grain, calculation, and interpretation boundaries so that similar-sounding measures are not confused.

Unless stated otherwise:

- **Delivered-only** means `order_status = 'delivered'`.
- **Eligible delivered orders** also satisfy the delivery timestamp and chronology conditions described below.
- Merchandise value is based on order-item `price` and excludes freight.
- Freight value is the recorded order-item freight charge, not the actual cost of logistics.
- Monetary values are in Brazilian real (R$).

## 2. Order and delivery metrics

| Metric | Definition / calculation | Grain and population | Interpretation |
|---|---|---|---|
| Total Orders | Count of `order_id` | Order grain; all statuses | Number of orders in the selected period |
| Delivered Orders | Count of orders with `order_status = 'delivered'` | Order grain | Includes delivered orders even if a required delivery timestamp is missing |
| Eligible Delivered Orders | Delivered orders with purchase, actual-delivery, and estimated-delivery timestamps present, and actual delivery >= purchase | Order grain | Denominator for delivery-performance metrics |
| On-Time Orders | Eligible delivered orders with actual customer delivery <= estimated delivery | Order grain | Includes delivery exactly on the estimate date/time as on time |
| Late Orders | Eligible delivered orders with actual customer delivery > estimated delivery | Order grain | Complement of on-time orders within the eligible population |
| On-Time Delivery % | On-Time Orders / Eligible Delivered Orders | Eligible delivered-order population | Share delivered on or before estimate |
| Late Delivery % | Late Orders / Eligible Delivered Orders | Eligible delivered-order population | Share delivered after estimate |
| Delivery Days | Actual customer delivery timestamp minus purchase timestamp, expressed in days | Eligible delivered order | Measures purchase-to-delivery speed, not schedule adherence |
| Average Delivery Days | Average `delivery_days` | Eligible delivered orders | Average purchase-to-customer-delivery duration |
| Delivery Deviation Days | Actual customer delivery timestamp minus estimated delivery timestamp, in days | Eligible delivered order | Negative = early; zero = on estimate; positive = late |
| Average Days Late | Average positive `late_days` among late eligible delivered orders | Late eligible delivered orders only | Severity among late orders, not average across all orders |

An order is not delivery-eligible solely because its status is delivered. The required timestamps and chronology must also be valid under the project definition. The overall EDA has 96,478 delivered orders and 96,470 eligible delivered orders.

## 3. Commercial metrics

| Metric | Definition / calculation | Grain and population | Interpretation |
|---|---|---|---|
| Merchandise Value | Sum of order-item `price` | Item-line grain; selected statuses | Item value excluding freight |
| Delivered Merchandise Value | Sum of item `price` for delivered orders | Delivered item lines | Not net revenue, profit, or contribution margin |
| Freight Value | Sum of recorded order-item `freight_value` | Item-line grain; selected statuses | Transaction-level freight charge |
| Delivered Freight Value | Sum of item freight for delivered orders | Delivered item lines | Not actual logistics expense |
| Item-and-Freight Value | Merchandise value + recorded freight value | Item-line or order aggregate | Combined transaction amount for comparison |
| Freight-to-Merchandise % | Freight value / Merchandise value | Same selected population and grouping for numerator and denominator | Freight intensity indicator; not margin or cost ratio |
| Average Delivered Item Price | Delivered merchandise value / delivered item-line count | Delivered item lines | Average price per purchased item line, not per order |
| Delivered Orders (Item Context) | Distinct count of `order_id` in delivered order-item rows | Order-item fact filtered by the relevant dimensions | Use for category/seller visuals so product and seller filters apply correctly |
| Active Sellers | Distinct sellers with at least one delivered item line | Delivered order-item population | Activity during the historical analysis period, not current active status |
| Merchandise Value Share | Group merchandise value / total merchandise value in the applicable comparison context | Same delivered item population | Share of delivered merchandise value |
| Seller Contribution Share | Merchandise value of selected top-N sellers / total merchandise value | Seller ranking and filter context as defined by the DAX measure | Cumulative seller concentration; ranking basis must remain consistent |

The all-status reporting-layer validation totals are different from delivered-only commercial metrics. Do not compare them without applying the same order-status filter.

## 4. Customer metrics

| Metric | Definition / calculation | Grain and population | Interpretation |
|---|---|---|---|
| Customer Records | Count of `customer_id` | Customer-record grain | Not the number of unique people |
| Distinct Customers | Distinct count of `customer_unique_id` | Unique-person identifier | Preferred measure for unique customer counts |
| Customers with Delivered Purchases | Distinct `customer_unique_id` associated with at least one delivered order | Unique-person grain; delivered orders | 93,358 in the full-period baseline |
| Delivered Orders per Customer | Distinct delivered `order_id` per `customer_unique_id` | Unique-person grain | Used to classify purchase frequency |
| Repeat Customer | Customer with at least two distinct delivered orders in the analysis period | Unique-person grain | Period-based repeat behavior, not a formal retention or lifetime-value measure |
| Repeat Customer Share | Repeat customers / customers with delivered purchases | Unique-person grain | 3.00% in the full-period baseline |
| Repeat Customer Merchandise Value | Delivered merchandise value attributable to customers with at least two delivered orders | Unique-person / order-item value aggregated consistently | 5.51% of delivered merchandise value in the full-period baseline |
| Average Merchandise per Customer | Delivered merchandise value / customers with delivered purchases | Delivered customer population | Cumulative value over the observed period; not customer lifetime value |

Customer segmentation is dynamic within the selected report period. A customer can have more orders over their full lifetime than appear in the dataset or selected year. State-level distinct-customer counts may overlap if a `customer_unique_id` is linked to customer records in more than one state.

## 5. Product, seller, and review metrics

| Metric | Definition / calculation | Grain and population | Interpretation |
|---|---|---|---|
| Category Merchandise Value | Sum of delivered item prices grouped by product category | Delivered item lines | Uses the analysis category field; missing categories are grouped as `Uncategorized` |
| Category Share | Category delivered merchandise value / total delivered merchandise value | Delivered item lines | Contribution to delivered merchandise value |
| Seller Merchandise Value | Sum of delivered item prices grouped by seller | Delivered item lines | Seller contribution, not seller profit or commission |
| Seller State Merchandise Value | Delivered merchandise value grouped by seller master state | Delivered item lines | Seller location, not customer delivery destination |
| Average Merchandise per Active Seller | State merchandise value / active sellers in the state | Seller state | Can be skewed by a small number of sellers |
| Review Score | One score per order only when all non-NULL scores for that order agree | Order grain | Conflicting-score orders have a NULL reporting score |
| Reviewed Delivered Orders | Eligible delivered orders with a non-NULL unambiguous review score | Order grain | Excludes orders with conflicting or absent usable scores |
| Low-Rating Orders | Eligible delivered orders with review score 1 or 2 | Order grain | Low-rating definition used in the project |
| Low-Rating % | Low-rating orders / reviewed eligible delivered orders | Unambiguous reviewed eligible delivered orders | Denominator excludes orders without an unambiguous score |

## 6. Baseline values for full-period validation

| Metric | Expected baseline |
|---|---:|
| Total orders | 99,441 |
| Delivered orders | 96,478 |
| Eligible delivered orders | 96,470 |
| On-time orders | 88,644 |
| Late orders | 7,826 |
| On-time delivery rate | 91.89% |
| Average delivery days | 12.56 |
| Delivered merchandise value | R$13,221,498.11 |
| Delivered freight value | R$2,198,275.64 |
| Customers with delivered purchases | 93,358 |
| Repeat customers | 2,801 |
| Repeat customer share | 3.00% |
| Repeat merchandise value share | 5.51% |

These are default full-period values. Report slicers change the selected population and therefore change the results.
