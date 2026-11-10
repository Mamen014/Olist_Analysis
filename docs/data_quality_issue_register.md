# Data Quality Issue Register

## 1. Purpose

This document records the data quality issues identified during the assessment of the Brazilian E-Commerce Public Dataset by Olist. It documents the detected concern, affected tables and columns, supporting evidence, investigation findings, analytical impact, approved treatment, and implementation/verification outcome.

The original records in the `raw` schema are preserved. Approved treatments are implemented in the staging layer without overwriting source values.

**Current status:** All 12 identified issues (DQ-001 to DQ-012) have been investigated and dispositioned. Their documented staging treatments have been implemented and verified for the intended exploratory analysis. The issue register incorporates additional findings from EDA, particularly the order-level review multiplicity investigation.

---

## 2. Issue Summary

| Issue ID | Issue Description | Affected Table(s) | Quality Dimension | Current Status |
|---|---|---|---|---|
| DQ-001 | Non-unique review and order identifiers; conflicting review scores on some orders | `order_reviews` | Uniqueness | Verified |
| DQ-002 | Payment and order-item reconciliation differences | `order_items`, `order_payments` | Consistency | Verified |
| DQ-003 | Carrier handoff before order approval | `orders` | Temporal integrity | Verified |
| DQ-004 | Customer delivery before carrier handoff | `orders` | Temporal integrity | Verified |
| DQ-005 | Review creation before order purchase | `order_reviews`, `orders` | Temporal integrity | Verified |
| DQ-006 | Order status and delivery information inconsistencies | `orders` | Consistency | Verified |
| DQ-007 | Missing product attributes | `products` | Completeness | Verified |
| DQ-008 | Product categories missing from translation table | `products`, `category_name_translation` | Referential integrity | Verified |
| DQ-009 | Postal prefixes without geolocation matches | `customers`, `sellers`, `geolocation` | Referential integrity | Verified |
| DQ-010 | Seller postal prefixes associated with multiple states | `sellers`, `geolocation` | Consistency | Verified |
| DQ-011 | Zero payment installments | `order_payments` | Validity | Verified |
| DQ-012 | Missing values in orders | `orders` | Completeness | Verified |

### Status Definitions

| Status | Meaning |
|---|---|
| Open | Issue identified but not yet investigated. |
| Investigating | Additional evidence is being collected. |
| Investigated | Available evidence has been reviewed. |
| Dispositioned | Investigation is sufficient and a treatment decision has been documented. |
| Implemented | Approved treatment has been applied to the appropriate data layer. |
| Verified | Implemented treatment has been tested against the intended outcome. |
| Closed | Issue lifecycle is complete, including any applicable downstream requirements. |

The 12 issues are marked **Verified** for their documented staging treatments and intended EDA use. This does not imply that the underlying source anomalies have been eliminated or that every future business metric is automatically validated.

---

# 3. Detailed Issue Records

## DQ-001 — Non-Unique Identifiers in Order Reviews

### Issue Information

| Attribute | Details |
|---|---|
| Issue ID | DQ-001 |
| Affected table | `raw.order_reviews`; implemented treatment in `staging.order_reviews` |
| Affected columns | `review_id`, `order_id` |
| Quality dimension | Uniqueness |
| Detection reference | `02_data_quality_assessment.sql`, Section 3.1.5 and subsequent investigation |
| Current status | Verified |

### Problem Description

The `review_id` and `order_id` columns contain repeated values in `order_reviews`. Neither column independently identifies every record uniquely.

### Initial Detection Results

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

### Investigation Results

Further investigation of duplicated `review_id` values established that:

- All 789 duplicated ID groups were associated with multiple orders.
- All orders within each group belonged to the same `customer_unique_id`.
- All duplicated groups contained identical values across the five review attributes examined: `review_score`, `review_comment_title`, `review_comment_message`, `review_creation_date`, and `review_answer_timestamp`.
- No duplicated ID groups were associated with multiple underlying customers.
- No missing customer mappings were identified.

The same review ID and identical review content could be associated with multiple orders belonging to one customer. The underlying reason for this behavior has not been established.

### Additional EDA Investigation: Multiple Review Records per Order

The later review analysis examined the grain of `order_reviews` by grouping records by `order_id`.

| Review Records per Order | Orders | Orders with Multiple Scores | Orders with Repeated Review IDs |
|---:|---:|---:|---:|
| 1 | 98,126 | 0 | 0 |
| 2 | 543 | 200 | 0 |
| 3 | 4 | 2 | 0 |
| **Total** | **98,673** | **202** | **0** |

Of the 547 orders with multiple review records:

- 345 orders had the same score across their records (343 two-record orders and two three-record orders).
- 202 orders had conflicting scores (200 two-record orders and two three-record orders).
- No order had a repeated `review_id` within its own review records.

This finding is distinct from the reuse of an identical `review_id` across different orders. The two patterns should not be conflated.

For the order-level review score distribution, 98,471 orders had one unambiguous score. The 202 orders with conflicting scores were excluded from score-based analysis. The 98,471 eligible orders contained 98,818 underlying review records.

### Analytical Impact

- Neither `review_id` nor `order_id` should be assumed to uniquely identify every review record.
- Counting distinct review IDs may produce different results from counting review records or distinct orders.
- Joins using either identifier require attention to the actual relationship and intended grain.
- Orders with multiple review records can have either consistent or conflicting scores.
- Review metrics must explicitly define how multiple records per order are handled.

### Treatment Decision

1. Retain all records in the raw dataset.
2. Do not remove records solely because their identifiers are repeated.
3. Record occurrence counts and duplicate flags in staging.
4. Use `order_id` for order-level review association, with an explicit aggregation or eligibility rule.
5. For score-based order analysis, retain an order when all associated records have the same score; exclude or separately report orders with conflicting scores.
6. Do not treat `review_id` alone as a safe unique key.

No changes were made to `raw.order_reviews`.

### Implementation and Verification

`staging.order_reviews` includes:

- `review_id_occurrences`
- `order_id_occurrences`
- `has_duplicate_review_id`
- `has_duplicate_order_id`

The staged occurrence and duplicate indicators were used in the subsequent review investigation. The review/purchase temporal flags are also present in this table and are documented under DQ-005.

| Activity | Status |
|---|---|
| Duplicate identifiers detected | Completed |
| Reused review IDs investigated | Completed |
| Multiple records per order investigated | Completed |
| Conflicting order-level scores quantified | Completed: 202 orders |
| Treatment documented | Completed |
| Raw data modified | No |
| Staging implementation | Completed |
| Staging verification | Completed |

**Final disposition:** Retain review records, expose identifier multiplicity in staging, and apply explicit order-level eligibility rules. **Status: Verified.**

---

## DQ-002 — Payment and Order-Item Reconciliation Differences

### Issue Information

| Attribute | Details |
|---|---|
| Issue ID | DQ-002 |
| Affected tables | `raw.order_items`, `raw.order_payments`; implemented treatment in staging reconciliation |
| Affected columns | `order_id`, `price`, `freight_value`, `payment_value` |
| Quality dimension | Consistency |
| Detection reference | `02_data_quality_assessment.sql`, Section 6.2 and subsequent investigation |
| Current status | Verified |

### Problem Description

The aggregated payment value for an order does not always match the sum of its order-item prices and freight charges. The comparison is performed at order level using a tolerance of 0.01.

### Detection Results

| Reconciliation Result | Orders |
|---|---:|
| Matched | 98,362 |
| Payment without order items | 775 |
| Order items without payment | 1 |
| Payment exceeds item total | 264 |
| Item total exceeds payment | 39 |
| **Total orders assessed** | **99,441** |

### Investigation Results

**Orders with payment records but no corresponding order items:**

| Order Status | Orders |
|---|---:|
| Unavailable | 603 |
| Canceled | 164 |
| Created | 5 |
| Invoiced | 2 |
| Shipped | 1 |
| **Total** | **775** |

**Orders where payment exceeds the item and freight total:**

| Order Status | Orders |
|---|---:|
| Delivered | 260 |
| Canceled | 2 |
| Shipped | 2 |
| **Total** | **264** |

**Orders where item and freight total exceeds payment:**

- 39 delivered orders were identified.

One additional delivered order had order-item records but no corresponding payment record. The concentration of missing counterparts in canceled and unavailable orders suggests that order lifecycle status is relevant to interpreting the findings. The underlying causes of the monetary differences have not been established.

### Analytical Impact

- Payment values and item-plus-freight values cannot be assumed to reconcile for every order.
- Financial analysis may produce different results depending on the source measure used.
- Missing counterpart records can affect order-level financial comparisons.
- Reconciliation exceptions should remain visible in financial analyses.
- Payment value should not automatically be described as accounting revenue or net sales.

### Treatment Decision

1. Retain all raw transaction records.
2. Do not alter payment values or item prices to force reconciliation.
3. Keep payment totals and item-plus-freight totals as separate measures.
4. Identify unmatched records and monetary differences when performing financial reconciliation.
5. Apply analysis-specific handling when a particular financial metric requires reconciled records.

### Implementation and Verification

The `staging.order_reconciliation` object was implemented and verified. Its summary covered 99,441 orders, with payment records present for 99,440 orders and order items present for 98,666 orders. Aggregated payment value was R$16,008,872.12; aggregated item-plus-freight value was R$15,843,553.24. These totals have different underlying order populations and are not a direct like-for-like reconciliation result.

| Activity | Status |
|---|---|
| Order-level aggregation performed | Completed |
| Reconciliation differences identified | Completed |
| Differences classified by reconciliation type | Completed |
| Findings compared against order status | Completed |
| Root cause of monetary differences established | No |
| Treatment documented | Completed |
| Raw data modified | No |
| Staging implementation | Completed |
| Staging verification | Completed |

**Final disposition:** Retain records, preserve separate financial measures, and use the verified per-order reconciliation classifications. **Status: Verified.**

---

## DQ-003 — Carrier Handoff Before Order Approval

### Issue Information

| Attribute | Details |
|---|---|
| Issue ID | DQ-003 |
| Affected table | `raw.orders`; implemented treatment in `staging.orders` |
| Affected columns | `order_approved_at`, `order_delivered_carrier_date` |
| Quality dimension | Temporal integrity |
| Detection reference | `02_data_quality_assessment.sql`, Section 7.2 |
| Current status | Verified |

### Problem Description

Some orders have a carrier handoff timestamp earlier than their approval timestamp. The expected chronological relationship is:

`order_approved_at <= order_delivered_carrier_date`

### Detection Results

| Measurement | Result |
|---|---:|
| Orders with carrier handoff before approval | 1,359 |

### Investigation Results

The identified records violate the expected chronological sequence of order approval and carrier handoff. The assessment did not establish the underlying reason for these inconsistencies.

### Analytical Impact

These records may distort order approval processing time, fulfillment preparation time, approval-to-carrier handoff duration, and operational performance comparisons.

### Treatment Decision

1. Retain all original order records and timestamps.
2. Flag records where carrier handoff precedes approval.
3. Exclude flagged records from approval-to-carrier duration calculations unless independently validated.
4. Do not automatically swap or modify timestamps.

### Implementation and Verification

The approved temporal treatment was implemented in staging and checked against the identified sequence condition. The original timestamps remain unchanged. Records flagged for this sequence must not be included in approval-to-carrier duration metrics without additional validation.

| Activity | Status |
|---|---|
| Temporal inconsistency detected and quantified | Completed: 1,359 orders |
| Analytical impact assessed | Completed |
| Treatment documented | Completed |
| Raw data modified | No |
| Staging implementation | Completed |
| Staging verification | Completed |

**Final disposition:** Retain records and flag invalid approval-to-carrier timestamp sequences. **Status: Verified.**

---

## DQ-004 — Customer Delivery Before Carrier Handoff

### Issue Information

| Attribute | Details |
|---|---|
| Issue ID | DQ-004 |
| Affected table | `raw.orders`; implemented treatment in `staging.orders` |
| Affected columns | `order_delivered_carrier_date`, `order_delivered_customer_date` |
| Quality dimension | Temporal integrity |
| Detection reference | `02_data_quality_assessment.sql`, Section 7.3 |
| Current status | Verified |

### Problem Description

Some orders have a customer delivery timestamp earlier than the carrier handoff timestamp. The expected chronological relationship is:

`order_delivered_carrier_date <= order_delivered_customer_date`

### Detection Results

| Measurement | Result |
|---|---:|
| Orders with customer delivery before carrier handoff | 23 |

### Investigation Results

Sample records showed negative time differences between carrier handoff and customer delivery. The underlying cause of these timestamp inconsistencies has not been established.

### Analytical Impact

These records may distort carrier-to-customer delivery duration and logistics performance measurements. They do not automatically invalidate every delivery metric: for example, purchase-to-customer delivery duration can still be calculated when the purchase and customer-delivery timestamps are valid.

### Treatment Decision

1. Retain all original order records and timestamps.
2. Flag records where customer delivery precedes carrier handoff.
3. Exclude affected records from carrier-to-customer delivery-duration calculations unless subsequently validated.
4. Do not automatically modify timestamps.

### Implementation and Verification

The approved temporal treatment was implemented in staging and checked against the identified sequence condition. The original timestamps remain unchanged. Delivery EDA used explicit purchase-to-customer delivery eligibility conditions; the carrier sequence issue is retained as a limitation for analyses specifically measuring the carrier-to-customer interval.

| Activity | Status |
|---|---|
| Temporal inconsistency detected and quantified | Completed: 23 orders |
| Analytical impact assessed | Completed |
| Treatment documented | Completed |
| Raw data modified | No |
| Staging implementation | Completed |
| Staging verification | Completed |

**Final disposition:** Retain records and flag invalid carrier-to-customer timestamp sequences. **Status: Verified.**

---

## DQ-005 — Review Creation Before Order Purchase

### Issue Information

| Attribute | Details |
|---|---|
| Issue ID | DQ-005 |
| Affected tables | `raw.order_reviews`, `raw.orders`; implemented treatment in `staging.order_reviews` |
| Affected columns | `review_creation_date`, `order_purchase_timestamp` |
| Quality dimension | Temporal integrity |
| Detection reference | `02_data_quality_assessment.sql`, Section 7.6 and subsequent investigation |
| Current status | Verified |

### Problem Description

Some review records have a review creation date earlier than the associated order purchase timestamp.

### Detection Results

| Finding | Records |
|---|---:|
| Total records identified | 74 |
| Same calendar day | 10 |
| Earlier calendar day | 64 |
| More than seven days earlier | 40 |

### Investigation Results

- **10 records:** Review creation and purchase occurred on the same calendar day, but the review timestamp was recorded at midnight. These are potentially explained by date-level rather than time-level precision.
- **64 records:** Review creation dates precede the associated order purchase dates by calendar date.
- **40 records:** Review creation dates precede the associated purchase dates by more than seven days.

The investigation of DQ-001 established that identical review content and an identical review ID can be associated with multiple orders from the same customer. This provides context for some earlier review-date associations, but the root cause has not been established for all affected records.

### Analytical Impact

- Order-to-review response time may be incorrect for affected associations.
- Review timing analysis may be distorted.
- Customer review behavior may be misinterpreted when review records are associated with later purchases.

### Treatment Decision

1. Retain all review records and original timestamps.
2. Do not modify review creation dates.
3. Treat same-calendar-day differences as date-precision cases rather than confirmed chronology errors.
4. Flag the 64 associations with earlier calendar dates.
5. Exclude or separately report these 64 associations when calculating order-to-review response time.
6. Preserve the original review information for general review-content analysis.

### Implementation and Verification

`staging.order_reviews` includes the following temporal flags:

- `is_review_before_purchase_timestamp`
- `is_review_before_purchase_same_day`
- `is_review_before_purchase_earlier_day`

The staged flags were checked against the original review/purchase date conditions. The 74 cases remain visible for analysis, with same-day and earlier-calendar-day cases distinguished.

| Activity | Status |
|---|---|
| Temporal inconsistency detected | Completed: 74 associations |
| Same-day and earlier-date cases classified | Completed |
| Analytical impact assessed | Completed |
| Treatment documented | Completed |
| Root cause established | No |
| Raw data modified | No |
| Staging implementation | Completed |
| Staging verification | Completed |

**Final disposition:** Retain records and flag the 64 earlier-calendar-day review-order associations; preserve same-day cases as date-precision warnings. **Status: Verified.**

---

## DQ-006 — Order Status and Delivery Information Inconsistencies

### Issue Information

| Attribute | Details |
|---|---|
| Issue ID | DQ-006 |
| Affected table | `raw.orders`; implemented treatment in `staging.orders` |
| Affected columns | `order_status`, `order_approved_at`, `order_delivered_carrier_date`, `order_delivered_customer_date` |
| Quality dimension | Consistency |
| Detection reference | `02_data_quality_assessment.sql`, Section 6.1 and subsequent investigation |
| Current status | Verified |

### Problem Description

Some order statuses do not appear consistent with the delivery information recorded for the corresponding orders. Initial checks identified delivered orders without a customer delivery timestamp and non-delivered orders with one or more delivery timestamps.

### Initial Detection Results

| Initial Finding | Orders |
|---|---:|
| Delivered without customer delivery date | 8 |
| Non-delivered orders with delivery timestamps | 1,182 |

### Investigation Results

The 1,182 non-delivered orders were classified by order status:

| Order Status | Orders | Interpretation |
|---|---:|---|
| Shipped | 1,107 | Carrier handoff recorded; customer delivery not yet recorded |
| Canceled | 75 | Orders have one or more delivery timestamps |
| **Total** | **1,182** | |

All 1,107 shipped orders had a carrier handoff timestamp but no customer delivery timestamp. This is consistent with an order still in transit and is not automatically considered a data quality defect.

The 75 canceled orders had one or more delivery timestamps. Six of these had a customer delivery timestamp.

Delivered orders with incomplete timeline information were further classified:

| Measurement | Records |
|---|---:|
| Delivered orders missing approval timestamp | 14 |
| Delivered orders missing carrier timestamp | 2 |
| Delivered orders missing customer delivery timestamp | 8 |
| Delivered orders with at least one missing timestamp | 23 |

The column-level missing counts overlap and should not be summed to determine the number of affected orders.

### Analytical Impact

- Status and delivery relationships may affect delivered-order counts.
- Missing customer delivery timestamps affect delivery-duration and on-time performance calculations.
- Canceled orders containing delivery information may affect cancellation analysis.
- Logistics calculations may be unreliable where required timestamps are unavailable or chronologically inconsistent.

### Treatment Decision

1. Retain all original orders, statuses, and timestamps.
2. Do not automatically change canceled orders to delivered or delivered orders to canceled.
3. Distinguish the 1,107 shipped orders with carrier timestamps and no customer delivery timestamps as expected lifecycle records.
4. Flag the 75 canceled orders containing delivery timestamps for status-related analysis.
5. Flag the eight delivered orders missing a customer delivery timestamp.
6. Preserve the broader finding of 23 delivered orders with at least one missing timeline timestamp; do not treat all 23 as missing customer delivery dates.
7. Apply analysis-specific exclusions when required delivery information is unavailable or inconsistent.

### Implementation and Verification

The status-aware completeness and delivery eligibility treatment was implemented in staging and checked against the documented lifecycle findings. The delivery EDA used delivered status and non-NULL purchase, actual customer-delivery, and estimated-delivery timestamps. The overall delivery analysis included 96,470 eligible orders; eight of the 96,478 delivered orders were excluded because they lacked customer delivery dates.

| Activity | Status |
|---|---|
| Status and delivery checks performed | Completed |
| Findings classified by order status | Completed |
| Expected shipped-order cases distinguished | Completed |
| Analytical impact assessed | Completed |
| Treatment documented | Completed |
| Raw data modified | No |
| Staging implementation | Completed |
| Staging verification | Completed |

**Final disposition:** Retain records, distinguish expected lifecycle missingness from potential status inconsistencies, and apply metric-specific eligibility rules. **Status: Verified.**

---

## DQ-007 — Missing Product Attributes

### Issue Information

| Attribute | Details |
|---|---|
| Issue ID | DQ-007 |
| Affected table | `raw.products`; implemented treatment in `staging.products` |
| Affected columns | `product_category_name`, `product_name_lenght`, `product_description_lenght`, `product_photos_qty`, `product_weight_g`, `product_length_cm`, `product_height_cm`, `product_width_cm` |
| Quality dimension | Completeness |
| Detection reference | `02_data_quality_assessment.sql`, Sections 2.1 and 2.3 |
| Current status | Verified |

### Problem Description

Some product records contain missing descriptive attributes and physical measurements.

### Detection Results

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
| Products with at least one missing attribute | 611 |
| Products with all eight attributes missing | 1 |

### Investigation Results

One product record was identified with only its `product_id` populated:

`5eb564652db742ff8f28759cd8d2652a`

This product has no values in any of the eight descriptive attributes. Further investigation established that it is referenced by 17 order-item records, 15 distinct orders, and one distinct seller. The product therefore has transactional relationships despite having no descriptive attributes.

### Analytical Impact

- Product-category analysis may be incomplete.
- Product description and catalog analysis may exclude incomplete products.
- Weight-based and dimension-based analysis may be affected by missing measurements.
- Transaction and order-level analysis can still include products with incomplete descriptive information.

### Treatment Decision

1. Retain all 611 affected product records.
2. Do not infer or populate missing attributes without supporting evidence.
3. Make attribute completeness visible in staging.
4. Retain incomplete products in transaction and order-level analysis.
5. Exclude products only from analyses that require specific missing attributes.
6. Preserve the incomplete product's order-item relationships.
7. Use `Uncategorized` for missing product categories in category analysis, without changing the raw category value.

### Implementation and Verification

Product completeness treatment was implemented in staging. Category EDA retained transactions associated with uncategorized products: 584 distinct products accounted for 1,537 delivered item lines across 1,392 delivered orders, with R$170,726.63 in merchandise value. This confirms that the category fallback did not remove those transactions from the category analysis.

| Activity | Status |
|---|---|
| Missing product attributes identified and quantified | Completed |
| Fully incomplete product investigated | Completed |
| Transactional relationships checked | Completed |
| Analytical impact assessed | Completed |
| Treatment documented | Completed |
| Raw data modified | No |
| Staging implementation | Completed |
| Staging verification | Completed |

**Final disposition:** Retain products, preserve transactional relationships, and expose incomplete descriptive attributes for analysis-specific treatment. **Status: Verified.**

---

## DQ-008 — Product Categories Missing from Translation Table

### Issue Information

| Attribute | Details |
|---|---|
| Issue ID | DQ-008 |
| Affected tables | `raw.products`, `raw.category_name_translation`; implemented treatment in `staging.products` |
| Affected columns | `product_category_name`, `product_category_name_english` |
| Quality dimension | Referential integrity |
| Detection reference | `02_data_quality_assessment.sql`, Section 5.7 |
| Current status | Verified |

### Problem Description

Some product category names found in the products table do not have matching entries in the English category translation table.

### Detection Results

Two unmatched categories were identified:

- `portateis_cozinha_e_preparadores_de_alimentos`
- `pc_gamer`

### Investigation Results

The categories exist in the product data but are absent from the translation table. The assessment did not establish why these translations are missing.

### Analytical Impact

- Products associated with these categories may receive NULL English category names after a left join.
- Category-level reports using only translated names may omit or misclassify these products.
- Inner joins against the translation table may unintentionally remove affected products.

### Treatment Decision

1. Retain both original category names.
2. Do not remove associated products.
3. Do not invent English translations.
4. Use the original `product_category_name` as a fallback when an English translation is unavailable.
5. Preserve the original translation table unchanged.

### Implementation and Verification

The category fallback was implemented in staging and used in category analysis. Missing categories are represented as `Uncategorized` where the source category itself is missing; untranslated but present source category names remain available as their original values. No source category or translation record was overwritten.

| Activity | Status |
|---|---|
| Unmatched categories identified | Completed: 2 categories |
| Analytical impact assessed | Completed |
| Treatment documented | Completed |
| Raw data modified | No |
| Staging implementation | Completed |
| Staging verification | Completed |

**Final disposition:** Retain original category names and use them as fallback values when English translations are unavailable. **Status: Verified.**

---

## DQ-009 — Postal Prefixes Without Geolocation Matches

### Issue Information

| Attribute | Details |
|---|---|
| Issue ID | DQ-009 |
| Affected tables | `raw.customers`, `raw.sellers`, `raw.geolocation`; geographic checks in staging |
| Affected columns | `customer_zipcode_prefix`, `seller_zipcode_prefix`, `geolocation_zip_code_prefix` |
| Quality dimension | Referential integrity |
| Detection reference | `02_data_quality_assessment.sql`, Section 5.8 and optimized staging verification |
| Current status | Verified |

### Problem Description

Some customer and seller postal prefixes do not have matching records in the geolocation table.

### Detection Results and Counting Grain

The original prefix-level checks reported 157 distinct customer postal prefixes and seven seller postal-prefix entries without geolocation matches. Optimized staging verification measured unmatched records at the entity-row level:

| Relationship / Measure | Result |
|---|---:|
| Distinct customer postal prefixes without geolocation matches (prefix-level check) | 157 |
| Customer records without a geolocation match (row-level verification) | 278 |
| Seller records without a geolocation match (optimized verification) | 7 |

The 157 and 278 customer measures use different counting grains and must not be conflated. The row-level customer verification covered 99,441 customer records, all distinct by customer record. The seller verification covered 3,095 seller records, all distinct by seller record.

### Investigation Results

The findings indicate incomplete geographic reference coverage. They do not independently establish that the customer or seller postal information is incorrect.

### Analytical Impact

- Geographic coordinates may be unavailable for affected customers and sellers.
- Geographic mapping and distance calculations may exclude these records.
- Geographic analysis based on available coordinates may not represent the full customer or seller population.

### Treatment Decision

1. Retain all customer and seller records.
2. Do not invent coordinates or geographic information.
3. Flag unmatched geolocation relationships when geographic analysis requires coordinates.
4. Exclude only affected records from analyses that specifically require geolocation matches.
5. Preserve the original geolocation dataset.

### Implementation and Verification

The customer and seller staging populations were verified for row counts, distinct entity records, and geolocation coverage.

| Staging Population | Rows | Distinct Records | Unmatched Geolocation Records |
|---|---:|---:|---:|
| Customers | 99,441 | 99,441 | 278 |
| Sellers | 3,095 | 3,095 | 7 |

| Activity | Status |
|---|---|
| Unmatched prefix records identified | Completed |
| Row-level unmatched records verified | Completed |
| Analytical impact assessed | Completed |
| Treatment documented | Completed |
| Raw data modified | No |
| Staging implementation | Completed |
| Staging verification | Completed |

**Final disposition:** Retain customer and seller records and flag missing geolocation references for analyses requiring geographic coordinates. **Status: Verified.**

---

## DQ-010 — Seller Postal Prefixes Associated with Multiple States

### Issue Information

| Attribute | Details |
|---|---|
| Issue ID | DQ-010 |
| Affected tables | `raw.sellers`, `raw.geolocation`; geographic checks in staging |
| Affected columns | `seller_zipcode_prefix`, `seller_state`, `geolocation_state` |
| Quality dimension | Consistency |
| Detection reference | `02_data_quality_assessment.sql`, Section 6.3.2 and optimized staging verification |
| Current status | Verified |

### Problem Description

Some seller postal prefixes are associated with multiple states in the geolocation table. A postal prefix therefore cannot always be assumed to represent one unique state.

### Detection Results

| Measurement | Result |
|---|---:|
| Postal prefixes associated with multiple states in geolocation reference | 17 |
| Ambiguous seller postal prefix in seller-specific verification | 1 |

These measures refer to different scopes: 17 prefixes were identified as multi-state in the geolocation reference, while the optimized seller-specific check identified one ambiguous postal prefix among the seller population.

### Investigation Results

The assessment found ambiguous postal-prefix/state associations in the geolocation reference. It did not establish that seller master records contain incorrect state values.

### Analytical Impact

- A postal prefix alone may not reliably identify a unique state.
- Geographic aggregation based exclusively on postal prefix may produce ambiguous state assignments.
- Seller-level state analysis may become inconsistent if geolocation records are used as the sole source of state information.

### Treatment Decision

1. Retain all original seller and geolocation records.
2. Do not assign a unique state based solely on an ambiguous postal prefix.
3. Use `seller_state` from the seller master table for seller-level state analysis.
4. Use geolocation records for location-related analysis while preserving multiple-state associations.
5. Do not arbitrarily remove geolocation records.

### Implementation and Verification

Seller-level geographic analysis used `seller_state` from the seller staging/master data. The seller staging population was checked for 3,095 rows and 3,095 distinct sellers. The optimized seller-specific geographic check identified one ambiguous postal prefix and seven unmatched geolocation records.

| Activity | Status |
|---|---|
| Multi-state geolocation prefixes identified | Completed: 17 prefixes |
| Seller-specific ambiguity checked | Completed: 1 ambiguous prefix |
| Analytical impact assessed | Completed |
| Treatment documented | Completed |
| Raw data modified | No |
| Staging implementation | Completed |
| Staging verification | Completed |

**Final disposition:** Retain geographic records and use the seller master state for seller-level state analysis. **Status: Verified.**

---

## DQ-011 — Zero Payment Installments

### Issue Information

| Attribute | Details |
|---|---|
| Issue ID | DQ-011 |
| Affected table | `raw.order_payments`; implemented treatment in `staging.order_payments` |
| Affected columns | `payment_type`, `payment_installments` |
| Quality dimension | Validity |
| Detection reference | `02_data_quality_assessment.sql`, Section 4.2.3 |
| Current status | Verified |

### Problem Description

Two credit-card payment records contain zero installments. The initial validation check expected installment values to be positive.

### Detection Results

| Order ID | Payment Sequence | Payment Type | Installments | Payment Value |
|---|---:|---|---:|---:|
| `744bade1fcf9ff3f31d860ace076d422` | 2 | credit_card | 0 | 58.69 |
| `1a57108394169c0b47d8f876acc9ba2d` | 2 | credit_card | 0 | 129.94 |

### Investigation Results

Both records are associated with credit-card payments and have zero installments. The assessment did not establish why these values are zero or whether they represent a source-system convention.

### Analytical Impact

- Installment-related metrics may be distorted by zero values.
- Average installment calculations may be misleading if zero values are treated as ordinary installment counts.
- Total payment and general transaction analysis can retain these records.

### Treatment Decision

1. Retain both payment records.
2. Do not automatically replace zero with one.
3. Flag zero-installment records for installment-related analysis.
4. Exclude or separately report these records when calculating installment averages, with the exclusion documented.
5. Preserve all original payment values.

### Implementation and Verification

The zero-installment condition was retained as an explicit data-quality exception in the staging treatment. No installment value was imputed or changed. The two identified payment records remain available to general payment analysis; installment-related analysis must apply the documented exception rule.

| Activity | Status |
|---|---|
| Zero-installment records identified | Completed: 2 records |
| Affected records examined | Completed |
| Analytical impact assessed | Completed |
| Treatment documented | Completed |
| Raw data modified | No |
| Staging implementation | Completed |
| Staging verification | Completed |

**Final disposition:** Retain records and flag zero-installment values for installment-related analysis. **Status: Verified.**

---

## DQ-012 — Missing Values in Orders

### Issue Information

| Attribute | Details |
|---|---|
| Issue ID | DQ-012 |
| Affected table | `raw.orders`; implemented treatment in `staging.orders` |
| Affected columns | `order_approved_at`, `order_delivered_carrier_date`, `order_delivered_customer_date` |
| Quality dimension | Completeness |
| Detection reference | `02_data_quality_assessment.sql`, Sections 2.1 and subsequent investigation |
| Current status | Verified |

### Problem Description

Some order records contain one or more missing values. The initial consolidated completeness check identified 2,980 affected orders.

### Detection Results

| Order Status | Total Orders | Orders with at Least One Missing Value |
|---|---:|---:|
| Approved | 2 | 2 |
| Canceled | 625 | 619 |
| Created | 5 | 5 |
| Delivered | 96,478 | 23 |
| Invoiced | 314 | 314 |
| Processing | 301 | 301 |
| Shipped | 1,107 | 1,107 |
| Unavailable | 609 | 609 |
| **Total** | **99,441** | **2,980** |

All orders had a non-NULL estimated delivery date.

**Missing timestamp counts by order status:**

| Order Status | Missing Approval Date | Missing Carrier Date | Missing Customer Delivery Date |
|---|---:|---:|---:|
| Approved | 0 | 2 | 2 |
| Canceled | 141 | 550 | 619 |
| Created | 5 | 5 | 5 |
| Delivered | 14 | 2 | 8 |
| Invoiced | 0 | 314 | 314 |
| Processing | 0 | 301 | 301 |
| Shipped | 0 | 0 | 1,107 |
| Unavailable | 0 | 609 | 609 |

Column-level missing counts can overlap within the same order and should not be summed to calculate the number of affected orders.

### Investigation Results

Missing values were evaluated against order status. Several are consistent with expected order lifecycle conditions:

- Created orders may not yet have approval or delivery timestamps.
- Approved orders may not yet have carrier or customer delivery timestamps.
- Invoiced and processing orders may not yet have delivery milestones.
- Shipped orders may have carrier handoff timestamps but no customer delivery timestamp.
- Unavailable orders may not have delivery milestones.
- Canceled orders may have missing delivery information.

Delivered orders require particular attention:

- 14 delivered orders are missing approval timestamps.
- 2 delivered orders are missing carrier timestamps.
- 8 delivered orders are missing customer delivery timestamps.
- 23 delivered orders have at least one missing timeline timestamp.

The missing timestamp counts by column overlap; the eight missing customer delivery dates are part of the 23 delivered orders with incomplete timelines.

### Analytical Impact

- Missing order timestamps may affect fulfillment and delivery-duration calculations.
- Missing approval timestamps may affect approval-processing metrics.
- Missing carrier timestamps may affect carrier handoff analysis.
- Missing customer delivery timestamps may affect delivery completion and delivery performance calculations.
- Treating all missing timestamps as errors would incorrectly classify expected lifecycle conditions as defects.

### Treatment Decision

1. Retain all order records.
2. Preserve NULL timestamps.
3. Do not replace missing timestamps with estimated or invented values.
4. Apply status-aware completeness rules in staging.
5. Flag delivered orders with incomplete timelines.
6. Keep expected missing delivery milestones for non-delivered statuses as NULL.
7. Exclude affected records only from calculations that require the missing timestamps.
8. Consider the overlapping status/timestamp findings in DQ-006 together with this completeness issue rather than counting the same missing timestamp as an unrelated defect.

### Implementation and Verification

Status-aware completeness and timestamp eligibility treatments were implemented in staging and checked against the documented lifecycle patterns. The exploratory delivery analysis used only delivered orders with non-NULL purchase, customer delivery, and estimated delivery timestamps, and excluded records with customer delivery earlier than purchase.

| Activity | Status |
|---|---|
| Missing values detected | Completed: 2,980 orders |
| Missing timestamps classified by order status | Completed |
| Analytical impact assessed | Completed |
| Treatment documented | Completed |
| Raw data modified | No |
| Staging implementation | Completed |
| Staging verification | Completed |

**Final disposition:** Retain records and apply status-aware completeness rules and metric-specific timestamp eligibility. **Status: Verified.**

---

# 4. Overall Treatment Principles

The following principles apply to all identified issues:

1. **Preserve raw data:** Original source records remain unchanged.
2. **Retain records by default:** Missing values, repeated identifiers, and inconsistencies do not automatically justify deletion.
3. **Do not invent values:** Corrections require supporting evidence.
4. **Apply analysis-specific treatment:** A record may be suitable for one analytical purpose but unsuitable for another.
5. **Preserve relationships:** Incomplete descriptive attributes should not cause valid transactional relationships to be discarded.
6. **Document transformations:** Approved treatments must be implemented and verified in the appropriate data layer.
7. **Make analytical limitations visible:** Flags and documented exclusions should make data quality limitations transparent.

---

# 5. Implementation and Closure Status

All 12 issues have received an investigation outcome and treatment decision. The approved treatments were implemented in staging and verified against the documented requirements for the intended exploratory analysis.

| Activity | Status |
|---|---|
| Initial data quality checks | Completed |
| Issue identification | Completed |
| Investigation of identified issues | Completed to the level required for disposition |
| Treatment decisions | Completed |
| Treatment documentation | Completed |
| Staging transformation implementation | Completed |
| Staging verification | Completed for the documented treatments and intended EDA use |
| Exploratory analysis using staging data | Completed |
| Business-specific metric validation | Completed for the documented business analyses and reporting KPIs; see `results/validation_results.md` |

**Current overall status:** DQ-001 to DQ-012 are verified for their documented staging treatments and intended analytical use. This does not mean the original anomalies have been corrected or that the dataset is fully clean. Business-specific analyses and the downstream Power BI reporting layer have been completed with explicit populations, metric definitions, and validation checks. Reporting-layer validation is documented separately in `results/validation_results.md`; this issue register remains focused on source and staging data-quality issues.
