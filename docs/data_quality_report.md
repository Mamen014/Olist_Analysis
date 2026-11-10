# Data Quality Assessment Report

## 1. Executive Summary

This report presents the data quality assessment, issue investigation, approved treatment decisions, staging implementation, and verification results for the Brazilian E-Commerce Public Dataset by Olist.

The assessment evaluated nine source tables across six data quality dimensions: completeness, uniqueness, validity, referential integrity, consistency, and temporal integrity. Twelve data quality issues (DQ-001 to DQ-012) were identified and dispositioned.

The identified issues include incomplete product attributes, non-unique review identifiers, order-level review multiplicity, payment reconciliation differences, incomplete geographic reference coverage, zero payment installments, and inconsistent order timestamps. The approved approach preserves source records and applies transparent, analysis-specific treatment in staging rather than modifying or deleting raw data.

The staging transformations have been implemented and verified. The resulting staging objects were subsequently used for exploratory analysis. This does not mean that every source record is error-free or suitable for every analytical purpose. Some limitations remain and must be considered when defining metrics and interpreting results.

**Overall assessment status:** Initial assessment, issue investigation and disposition, staging implementation, and staging verification are complete for the 12 documented issues. Exploratory analysis and business analysis have been completed. A separate `analytics` reporting layer has also been implemented and validated for the documented reporting grains and control totals. The dataset should not be described as fully clean or universally analytics-ready.

---

## 2. Dataset Overview

The assessment covers nine tables imported into the `raw` schema.

| Table | Total Records |
|---|---:|
| `customers` | 99,441 |
| `orders` | 99,441 |
| `order_items` | 112,650 |
| `order_payments` | 103,886 |
| `order_reviews` | 99,224 |
| `products` | 32,951 |
| `sellers` | 3,095 |
| `geolocation` | 1,000,163 |
| `category_name_translation` | 71 |
| **Total** | **1,550,922** |

The dataset contains approximately 1.55 million records across nine tables covering customer, order, transaction, product, seller, review, and geographic information. These counts describe the source tables in the `raw` schema; staging transformations do not overwrite those records.

---

## 3. Assessment Methodology

The assessment was performed using SQL-based profiling, validation checks, and cross-table comparisons. The workflow followed these activities:

1. Detect and quantify potential quality issues in the raw data.
2. Investigate affected records and related entities to understand their scope and context.
3. Assess the impact on possible analytical activities.
4. Decide whether records should be retained, flagged, transformed, or excluded from a specific metric.
5. Implement approved treatments in the staging layer without modifying the raw source.
6. Verify the staged outputs against the original findings and intended treatment.

Six data quality dimensions were evaluated.

### 3.1 Completeness

Evaluated missing, empty, and whitespace-only values. Checks included NULL values across source tables, empty review text, incomplete product attributes, and order records with missing lifecycle timestamps.

### 3.2 Uniqueness

Evaluated whether identifiers and composite identifiers uniquely identify records. Checks included duplicate identifiers in customer, order, product, seller, and review tables; duplicate composite identifiers in order items and payments; and duplicate category translation entries.

### 3.3 Validity

Evaluated whether values comply with expected numerical, categorical, geographic, and formatting constraints. Checks included review score ranges, financial values, product dimensions, payment installments and transaction sequences, order statuses, payment types, state codes, geographic coordinates, and postal-prefix formats.

### 3.4 Referential Integrity

Evaluated relationships between transactional tables and reference tables. Checks included orders referencing customers; order items referencing orders, products, and sellers; payments and reviews referencing orders; product categories referencing the translation table; and customer and seller postal prefixes matching geolocation records.

### 3.5 Consistency

Evaluated logical consistency between related records and attributes. Checks included order status and delivery information, payment totals compared with order-item and freight totals, and geographic relationships between postal prefixes and state information.

### 3.6 Temporal Integrity

Evaluated chronological relationships between transaction timestamps. Checks included order approval versus purchase, carrier handoff versus approval, customer delivery versus carrier handoff and purchase, review response versus review creation, review creation versus purchase, and actual delivery versus estimated delivery.

---

## 4. Assessment Results

### 4.1 Completeness

The consolidated completeness checks identified records containing at least one missing value in two tables.

| Table | Total Records | Records with Missing Values |
|---|---:|---:|
| `products` | 32,951 | 611 |
| `orders` | 99,441 | 2,980 |

No rows containing NULL values were detected by the consolidated checks in the remaining seven tables. Additional observations included two empty or whitespace-only review comment titles and nine empty or whitespace-only review comment messages.

Product attribute completeness was assessed as follows:

| Product Attribute | Missing Records |
|---|---:|
| Product category | 610 |
| Product name length | 610 |
| Product description length | 610 |
| Product photo count | 610 |
| Product weight | 2 |
| Product length | 2 |
| Product height | 2 |
| Product width | 2 |
| **Products with at least one missing attribute** | **611** |

One product record contains only its identifier, with all eight descriptive attributes missing. It is referenced by 17 order-item records across 15 distinct orders and one seller. Its transactional relationships were preserved.

The order completeness assessment identified 2,980 records with at least one missing timestamp or other checked field. Most missing values are associated with order lifecycle stages where later milestones have not occurred. Twenty-three delivered orders had at least one missing timeline timestamp; this includes eight delivered orders without a customer delivery timestamp. These counts overlap at the column level and should not be added together.

**Assessment and implementation outcome:** Missing values were retained. Staging applies completeness and lifecycle-related flags so records can be used or excluded according to the requirements of an individual analysis. The 610 products without a category are represented as `Uncategorized` in category analysis; the original raw category values remain unchanged.

### 4.2 Uniqueness

No duplicate identifiers were detected for `customers`, `orders`, `products`, or `sellers`. No duplicate composite identifiers were detected for `order_items (order_id, order_item_id)` or `order_payments (order_id, payment_sequential)`. No duplicate category names were detected in the translation table.

Repeated identifiers were found in `order_reviews`.

| Measurement | Result |
|---|---:|
| Total review records | 99,224 |
| Duplicate `review_id` groups | 789 |
| Records in duplicate `review_id` groups | 1,603 |
| Excess records beyond one per ID | 814 |
| Maximum occurrences of one `review_id` | 3 |
| Distinct `order_id` values | 98,673 |
| Duplicate `order_id` groups | 547 |
| Excess records beyond one per order | 551 |
| Maximum occurrences of one `order_id` | 3 |

The 789 duplicated `review_id` groups were associated with multiple orders. All orders within each group belonged to the same `customer_unique_id`, and the duplicated groups contained identical values across the five review attributes examined: score, comment title, comment message, creation date, and answer timestamp. No missing customer mappings were detected. Therefore, `review_id` is not a safe unique key for joining review records to orders.

A later order-level review investigation refined the understanding of repeated `order_id` values:

| Review Records per Order | Orders | Orders with Multiple Scores |
|---:|---:|---:|
| 1 | 98,126 | 0 |
| 2 | 543 | 200 |
| 3 | 4 | 2 |
| **Total** | **98,673** | **202** |

Of the 547 orders with multiple review records, 345 had consistent scores and 202 had conflicting scores. No order had a repeated `review_id` within its own review records. This finding is distinct from the reuse of the same review ID across different orders.

**Assessment and implementation outcome:** Raw review records were retained. The staging review table includes occurrence counts and flags for reused review IDs and repeated order IDs. Order-level score analysis uses `order_id` as the order association and requires an explicit rule for multiple records. In the exploratory analysis, orders with one unambiguous score were retained; the 202 orders with conflicting scores were excluded from score-based comparisons.

### 4.3 Validity

The following checks returned no detected exceptions under the defined validation rules:

- Review scores outside the expected range of 1–5.
- Negative order-item prices or freight values.
- Negative payment values.
- Negative product measurements.
- Invalid order-item sequence values.
- Invalid payment sequence values.
- Geographic coordinates outside the specified boundaries.
- Postal prefixes failing the specified format checks.

Two credit-card payment records were identified with zero installments.

| Payment Type | Installments | Affected Records |
|---|---:|---:|
| Credit card | 0 | 2 |

The observed categorical values included eight order statuses, five payment types, and the Brazilian state codes represented in the customer and seller tables. Infrequent categorical values, including `not_defined` payment types, were retained rather than automatically classified as invalid.

**Assessment and implementation outcome:** The two zero-installment records were retained and flagged for installment-related analysis. General transaction analysis can retain these payment records; installment metrics must apply an explicit treatment to the flagged values.

### 4.4 Referential Integrity

The following core transactional relationships returned no unmatched records:

- Orders referencing customers.
- Order items referencing orders.
- Order items referencing products.
- Order items referencing sellers.
- Payments referencing orders.
- Reviews referencing orders.

Incomplete reference coverage was identified in product categories and geographic information.

**Product category translations**

Two categories present in the products table were absent from the English translation table:

- `portateis_cozinha_e_preparadores_de_alimentos`
- `pc_gamer`

The original category names were retained and used as a fallback where an English translation was unavailable. The translation source was not modified and no translation was invented.

**Geographic coverage**

The geographic checks produced the following measures, which use different counting grains:

| Relationship / Measure | Result |
|---|---:|
| Distinct customer postal prefixes without a geolocation match (prefix-level check) | 157 |
| Customer records without a geolocation match (optimized row-level verification) | 278 |
| Seller records without a geolocation match (optimized verification) | 7 |
| Seller postal prefixes found ambiguous in the seller-specific verification | 1 |
| Postal prefixes associated with multiple states in the geolocation reference | 17 |

The customer figures of 157 and 278 are not interchangeable: the former is a distinct-prefix count, while the latter is a row-level count of affected customer records. Similarly, the 17 multiple-state prefixes describe ambiguity in the geolocation reference; the optimized seller-specific check found one ambiguous postal prefix among the seller population. No customer postal prefixes associated with multiple states were detected.

**Assessment and implementation outcome:** Customer and seller records were retained. Staging geographic checks were verified against the customer and seller populations. Geographic analysis must account for unmatched records. Seller-level state analysis uses the state recorded in the seller master rather than inferring a seller's state from an ambiguous postal prefix. Original category names provide a fallback when English translations are unavailable.

### 4.5 Consistency

Two major areas of inconsistency were identified.

#### A. Payment and Order-Item Reconciliation

Payment totals were compared with the aggregated sum of order-item prices and freight values at the order level. A tolerance of 0.01 was applied.

| Reconciliation Result | Orders |
|---|---:|
| Matched | 98,362 |
| Payment without order items | 775 |
| Order items without payment | 1 |
| Payment exceeds item total | 264 |
| Item total exceeds payment | 39 |
| **Total orders assessed** | **99,441** |

The 775 orders with payment records but no corresponding order items were concentrated in unavailable (603), canceled (164), created (5), invoiced (2), and shipped (1) orders. Of the 264 orders where payment exceeded the item and freight total, 260 were delivered, two were canceled, and two were shipped. All 39 orders where item and freight totals exceeded payment were delivered. One additional delivered order had order items but no corresponding payment record.

The staging reconciliation object was implemented and verified. Its summary covered 99,441 orders, with payment records present for 99,440 orders and order items present for 98,666 orders. The aggregated payment value was R$16,008,872.12 and the aggregated item-plus-freight value was R$15,843,553.24. These overall totals have different underlying order populations and must not be interpreted as a direct accounting revenue discrepancy or as evidence that every order should reconcile. Per-order reconciliation classifications remain the appropriate basis for investigating differences.

**Treatment:** All transaction records are retained. Payment totals and item-plus-freight totals remain separate measures, with per-order reconciliation differences visible for financial analysis. The causes of individual monetary differences have not been established.

#### B. Order Status and Delivery Information

The initial checks identified delivered orders without customer delivery timestamps and non-delivered orders with delivery information.

| Finding | Affected Orders | Assessment |
|---|---:|---|
| Shipped orders with carrier date but no customer delivery date | 1,107 | Consistent with orders in transit |
| Canceled orders with one or more delivery timestamps | 75 | Potential status-related inconsistency |
| Delivered orders without customer delivery date | 8 | Incomplete delivery information |
| Delivered orders with at least one missing timeline timestamp | 23 | Incomplete order timeline |

The 75 canceled orders included six with a customer delivery timestamp. The 23 delivered orders with incomplete timeline information included 14 missing approval timestamps, two missing carrier timestamps, and eight missing customer delivery timestamps. Column-level counts overlap.

**Assessment and implementation outcome:** Original statuses and timestamps were retained. Staging preserves lifecycle information and the identified data-quality conditions. The exploratory delivery analysis included only delivered orders with the purchase, actual delivery, and estimated delivery timestamps required by each metric. It excluded the eight delivered orders missing the customer delivery date. The 23 delivered orders with at least one missing timeline timestamp should not be treated as 23 additional missing delivery dates.

### 4.6 Temporal Integrity

The assessment identified the following timestamp inconsistencies:

| Finding | Affected Records |
|---|---:|
| Carrier handoff before order approval | 1,359 |
| Customer delivery before carrier handoff | 23 |
| Review creation before order purchase | 74 |

The 74 review creation-before-purchase associations were classified as follows:

| Finding | Records |
|---|---:|
| Review and purchase on the same calendar day | 10 |
| Review date earlier than purchase date | 64 |
| Review date more than seven days earlier | 40 |

The ten same-day cases may reflect the fact that review creation timestamps are recorded at midnight and do not provide reliable time-of-day precision. The 64 earlier-calendar-day associations remain anomalous. The investigation of reused review IDs provides context for some associations, but it does not establish the root cause of all affected records.

The following checks returned no detected exceptions:

- Order approval before purchase.
- Customer delivery before purchase.
- Review response before review creation.

Actual delivery after the estimated delivery date was retained as a business performance measure, not treated as an automatic data quality defect.

**Assessment and implementation outcome:** Original timestamps were preserved. Staging review data includes flags distinguishing review creation before purchase, same-calendar-day cases, and earlier-calendar-day cases. The staging review flags and their counts were verified. Delivery analyses use explicit timestamp eligibility conditions. The 23 carrier-to-customer sequence anomalies do not automatically invalidate purchase-to-customer delivery duration, but they must be excluded from analyses specifically measuring carrier-to-customer duration unless validated.

---

## 5. Summary of Identified Data Quality Issues

Twelve issues were identified and assigned treatment decisions. Their staging implementations and verification are complete for the documented treatments.

| Issue ID | Issue Description | Affected Records / Groups | Treatment | Status |
|---|---|---:|---|---|
| DQ-001 | Non-unique review and order identifiers; multiple review scores on some orders | 789 duplicate review ID groups; 547 duplicate order ID groups; 202 orders with conflicting scores | Retain records; add occurrence/quality flags; use order-level eligibility rules | Verified |
| DQ-002 | Payment and order-item reconciliation differences | 1,079 orders | Retain records; preserve separate financial measures and per-order reconciliation classifications | Verified |
| DQ-003 | Carrier handoff before approval | 1,359 orders | Retain and flag; exclude from affected processing-time calculations | Verified |
| DQ-004 | Customer delivery before carrier handoff | 23 orders | Retain and flag; exclude from affected carrier-to-customer duration calculations | Verified |
| DQ-005 | Review creation before order purchase | 74 associations | Retain; distinguish same-day cases and flag 64 earlier-calendar-day associations | Verified |
| DQ-006 | Order status and delivery information inconsistencies | 75 canceled orders; 8 delivered orders without customer delivery dates | Retain and flag; distinguish expected lifecycle conditions | Verified |
| DQ-007 | Missing product attributes | 611 products | Retain; apply completeness flags; preserve transactions | Verified |
| DQ-008 | Product categories missing from translation table | 2 categories | Retain original category as fallback | Verified |
| DQ-009 | Postal prefixes without geolocation matches | 157 distinct customer prefixes / 278 customer records; 7 seller records | Retain; identify unmatched geographic records | Verified |
| DQ-010 | Seller postal prefixes associated with multiple states | 17 geolocation prefixes; 1 ambiguous seller prefix in seller-specific check | Retain; use seller master state for seller-level analysis | Verified |
| DQ-011 | Zero payment installments | 2 payment records | Retain; flag for installment-related analysis | Verified |
| DQ-012 | Missing values in orders | 2,980 orders | Retain; apply status-aware completeness rules | Verified |

Detailed detection evidence, investigation results, analytical impacts, and treatment decisions are documented in the [Data Quality Issue Register](data_quality_issue_register.md).

---

## 6. Data Treatment Principles

The assessment and staging work follow these principles:

### 6.1 Preserve Raw Data

Original source records remain unchanged in the `raw` schema. Treatments are applied in staging and do not overwrite source values.

### 6.2 Do Not Assume Every Anomaly Is an Error

Missing values, repeated identifiers, and unusual timestamps are interpreted in context. An anomaly does not automatically justify correction or deletion.

### 6.3 Avoid Unsupported Corrections

Values are not inferred, replaced, or standardized without sufficient supporting evidence. Untranslated category names, for example, are retained rather than assigned invented translations.

### 6.4 Apply Analysis-Specific Treatment

A record may be suitable for one analytical purpose but unsuitable for another. A product with missing weight can remain in transaction analysis but should not be included in an analysis requiring product weight. An order without a customer delivery timestamp cannot be included in a delivery-duration calculation.

### 6.5 Preserve Transactional Relationships

Incomplete descriptive information does not cause otherwise valid transactional relationships to be discarded. The incomplete product referenced by order items remains represented in the staged transactional data.

### 6.6 Make Analytical Limitations Visible

Quality flags, explicit metric definitions, documented exclusions, and carefully defined analytical populations make limitations visible. They do not make the underlying source anomaly disappear.

### 6.7 Document and Verify Transformations

Approved treatments are implemented in the appropriate staging objects and checked against the original assessment findings. A treatment is described as verified only where the implemented result was tested.

---

## 7. Staging Implementation and Verification

The project uses separate data layers:

- **`raw`:** imported source data, preserved unchanged.
- **`staging`:** cleaned and enriched structures, quality flags, approved fallback logic, and reconciled measures used by the analysis.

The staging objects used in the work include `staging.customers`, `staging.sellers`, `staging.products`, `staging.orders`, `staging.order_items`, `staging.order_payments`, `staging.order_reconciliation`, and `staging.order_reviews`.

### 7.1 Verified Review Treatment

`staging.order_reviews` includes the following additional columns:

- `review_id_occurrences`
- `order_id_occurrences`
- `has_duplicate_review_id`
- `has_duplicate_order_id`
- `is_review_before_purchase_timestamp`
- `is_review_before_purchase_same_day`
- `is_review_before_purchase_earlier_day`

The staged review data preserves source rows while exposing identifier multiplicity and review/purchase date conditions for analysis. Subsequent EDA confirmed 98,673 distinct order IDs, including 547 orders with multiple review records. Of those, 202 had conflicting scores. The score-based analysis used 98,471 orders with an unambiguous score and excluded the 202 conflicting orders.

### 7.2 Verified Reconciliation Treatment

`staging.order_reconciliation` provides order-level payment and item-plus-freight totals and their reconciliation classification. Its verified summary covered 99,441 orders; payment records were present for 99,440 orders and order items for 98,666 orders. Per-order reconciliation categories matched the documented assessment: 98,362 matched, 775 payment without items, one order with items without payment, 264 payment greater than item-plus-freight value, and 39 item-plus-freight values greater than payment.

### 7.3 Verified Product and Category Treatment

Product attribute incompleteness is retained and made visible in staging. Category analysis uses `Uncategorized` for products without a category, while untranslated source category values remain available as fallback values. The incomplete product referenced by 17 item lines across 15 orders remains available to transactional analysis.

### 7.4 Verified Geographic Treatment

Customer and seller staging populations were checked for record uniqueness and geolocation coverage:

| Staging Population | Rows | Distinct Records | Unmatched Geolocation Records |
|---|---:|---:|---:|
| Customers | 99,441 | 99,441 | 278 |
| Sellers | 3,095 | 3,095 | 7 |

The seller-specific geographic check also identified one ambiguous seller postal prefix. These are verification counts at the row/population level; they should not be substituted for the distinct-prefix counts reported in Section 4.4.

### 7.5 Verified Order and Payment Treatments

Staging retains order lifecycle timestamps and payment records while exposing the conditions required to apply status-aware completeness, timestamp eligibility, and payment validation rules. The documented exceptions were not corrected by inventing timestamps or payment values. Exploratory delivery metrics explicitly required a delivered status and valid purchase, actual delivery, and estimated delivery dates. The 96,470 eligible delivered orders in the overall delivery analysis exclude the eight delivered orders missing customer delivery dates.

### 7.6 Verification Boundary

The staging transformations and the checks described above were implemented and verified for their intended analytical use. EDA and business analysis were performed using the staging layer. A separate `analytics` schema was subsequently implemented through `sql/06_reporting_layer.sql`, with four dimensions and three fact views. Reporting-layer row counts, fact grains, financial totals, review populations, and dimension references were validated separately; see `results/validation_results.md`. This report remains focused on source-data quality and staging treatment. Passing reporting-layer checks does not establish that the underlying source is free of all quality issues or that every metric is suitable for every business use.

---

## 8. Remaining Limitations

The following limitations remain relevant after staging verification:

- The underlying reason for review ID reuse and the 202 orders with conflicting review scores has not been established.
- The root causes of payment and item-plus-freight reconciliation differences remain unknown.
- Timestamp anomalies may reflect source-system recording or association behavior that cannot be confirmed from the available dataset.
- Missing product attributes and missing order milestones remain missing; staging flags make them visible but do not recover the absent information.
- Geographic reference coverage remains incomplete, and some postal-prefix mappings are ambiguous.
- The two categories absent from the translation table remain untranslated; original category names are retained as fallback values.
- Delivery and review analyses use restricted populations defined by the fields required for each metric. Results should always be reported with those population definitions.
- The dataset covers historical activity from 2016–2018. Findings describe the supplied dataset period and should not be presented as Olist's current business performance.

A validation check returning no exceptions means that no records violated the specific rule tested. It does not prove that the dataset is free of every possible quality issue or that every record is factually correct.

---

## 9. Conclusion and Next Steps

The initial data quality assessment identified and dispositioned 12 issues across six data quality dimensions. The approved staging treatments have been implemented and verified for their intended use. Raw source data remains unchanged, records with incomplete or anomalous values are retained where possible, and quality limitations are made visible for analysis-specific handling.

The staged data supported the completed exploratory and business analyses. A separate analytics reporting layer was then created for Power BI consumption and validated at the documented fact grains. The project has progressed through the reporting and dashboard stage. The remaining work is portfolio packaging, reproducibility review, and maintenance of the documented metric assumptions.

**Final status:**

- Initial data quality assessment: Completed.
- Issue investigation and disposition: Completed for all 12 issues.
- Treatment documentation: Completed.
- Staging implementation: Completed.
- Staging verification: Completed for the documented treatments and intended EDA use.
- Exploratory analysis: Completed using staging data.
- Business analysis: Completed (four documented analyses).
- Analytics reporting layer: Implemented with four dimensions and three fact views.
- Reporting-layer validation: Completed for row counts, fact grains, financial totals, review populations, and dimension references.
- Power BI reporting: Completed with four report pages; default-period controls are documented in `results/validation_results.md`.

The dataset has undergone a structured data quality assessment and staging process. It should not be described as fully clean or universally analytics-ready.
