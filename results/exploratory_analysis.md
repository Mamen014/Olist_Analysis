# Exploratory Data Analysis — Olist Brazilian E-Commerce Dataset

## 1. Purpose and scope

This report summarizes the exploratory analysis of the Brazilian E-Commerce Public Dataset by Olist. The objective is to understand the order lifecycle, transaction patterns, customer and product characteristics, seller activity, delivery performance, and customer reviews before defining focused business-analysis questions.

The analysis was performed in PostgreSQL using the `olist_analysis` database. The source data is retained in the `raw` schema, with quality checks and approved transformations applied in the `staging` schema. The EDA queries use staging objects rather than modifying the source records.

The analysis covers seven areas:

1. Order analysis
2. Transaction analysis
3. Customer analysis
4. Product analysis
5. Seller analysis
6. Delivery performance
7. Review analysis

## 2. Analytical approach and interpretation rules

- **Preserve source data:** Raw tables were not modified. Transformations and data-quality flags were implemented in staging.
- **Respect metric populations:** Each metric uses the population stated in its query. Totals from different populations should not be directly reconciled or compared without accounting for the differences.
- **Distinguish records from entities:** Counts of rows, orders, customers, sellers, products, and review records are not interchangeable.
- **Use delivered orders for fulfillment analysis:** Delivery-time and on-time measures include delivered orders with valid purchase, actual delivery, and estimated delivery dates, and exclude negative purchase-to-delivery intervals.
- **Treat payment totals as payment value:** They are not automatically equivalent to accounting revenue, net sales, or seller proceeds.
- **Treat associations as associations:** The EDA identifies patterns but does not establish causal relationships.
- **Retain data-quality caveats:** Missing attributes, reused review IDs, repeated order-level reviews, lifecycle date anomalies, and incomplete time coverage are considered when interpreting results.

## 3. Executive summary

- The dataset contains **99,441 orders** from September 4, 2016 through October 17, 2018. **97.02%** of orders have a delivered status.
- Payment value totals **R$16.01 million** across 99,440 orders with payment records. Credit cards and boleto account for **96.26%** of payment value.
- There are **96,096 distinct customers**. Only **3.12%** placed more than one order in the observed dataset period.
- Customer records are concentrated in Southeast Brazil: São Paulo, Rio de Janeiro, and Minas Gerais account for **66.60%** of customer records.
- The catalog contains **32,951 products**. The five largest categories account for approximately **40.46%** of products; **610 products (1.85%)** are uncategorized.
- São Paulo accounts for **59.74%** of registered sellers. The top 100 active sellers contribute **45.52%** of delivered merchandise value.
- Among 96,470 eligible delivered orders, **91.89%** arrived on or before the estimated delivery date. Late orders experienced an average delay of **9.55 days**.
- Review scores are predominantly positive: **77.13%** of orders with an unambiguous score received four or five stars. Lower scores are strongly associated with longer delivery times and late delivery.

## 4. Order analysis

### 4.1 Overall order volume

| Metric | Result |
|---|---:|
| Total orders | 99,441 |
| Distinct customer records | 99,441 |
| Distinct customers | 96,096 |
| First purchase timestamp | 2016-09-04 21:15:19 |
| Last purchase timestamp | 2018-10-17 17:30:18 |

The 99,441 orders were associated with 96,096 distinct customers. The difference of **3,345 orders** represents orders beyond each customer's first order; it is not the number of repeat customers.

### 4.2 Order status distribution

| Order status | Orders | Share |
|---|---:|---:|
| Delivered | 96,478 | 97.02% |
| Shipped | 1,107 | 1.11% |
| Canceled | 625 | 0.63% |
| Unavailable | 609 | 0.61% |
| Invoiced | 314 | 0.32% |
| Processing | 301 | 0.30% |
| Created | 5 | 0.01% |
| Approved | 2 | 0.00% |

Delivered orders dominate the dataset. The remaining statuses should not be treated as delivered or automatically discarded; they represent different points or outcomes in the order lifecycle.

### 4.3 Monthly order volume

| Purchase month | Orders |
|---|---:|
| 2016-09 | 4 |
| 2016-10 | 324 |
| 2016-12 | 1 |
| 2017-01 | 800 |
| 2017-02 | 1,780 |
| 2017-03 | 2,682 |
| 2017-04 | 2,404 |
| 2017-05 | 3,700 |
| 2017-06 | 3,245 |
| 2017-07 | 4,026 |
| 2017-08 | 4,331 |
| 2017-09 | 4,285 |
| 2017-10 | 4,631 |
| 2017-11 | 7,544 |
| 2017-12 | 5,673 |
| 2018-01 | 7,269 |
| 2018-02 | 6,728 |
| 2018-03 | 7,211 |
| 2018-04 | 6,939 |
| 2018-05 | 6,873 |
| 2018-06 | 6,167 |
| 2018-07 | 6,292 |
| 2018-08 | 6,512 |
| 2018-09 | 16 |
| 2018-10 | 4 |

**November 2017 was the peak month**, with 7,544 orders. September and October 2018 contain only 16 and 4 orders respectively, indicating incomplete end-of-period coverage. These partial months should not be interpreted as a collapse in demand or compared directly with complete months.

## 5. Transaction analysis

### 5.1 Payment and item/freight totals

| Metric | Result |
|---|---:|
| Total orders | 99,441 |
| Orders with payment | 99,440 |
| Orders with order items | 98,666 |
| Total payment value | R$16,008,872.12 |
| Total item and freight value | R$15,843,553.24 |
| Average payment per order | R$160.99 |
| Average item and freight value per order | R$160.58 |

The populations behind the two totals differ: 99,440 orders have payment records, while 98,666 have order items. The difference between the totals should therefore not be interpreted as a simple reconciliation variance. The per-order reconciliation analysis separately identified unmatched and differing order populations.

Payment value is a transaction measure in this dataset. It should not be described as accounting revenue, net sales, or profit without additional accounting definitions and adjustments.

### 5.2 Payment type distribution

| Payment type | Payment records | Distinct orders | Payment value | Share of payment value |
|---|---:|---:|---:|---:|
| Credit card | 76,795 | 76,505 | R$12,542,084.19 | 78.34% |
| Boleto | 19,784 | 19,784 | R$2,869,361.27 | 17.92% |
| Voucher | 5,775 | 3,866 | R$379,436.87 | 2.37% |
| Debit card | 1,529 | 1,528 | R$217,989.79 | 1.36% |
| Not defined | 3 | 3 | R$0.00 | 0.00% |

Credit cards and boleto together account for **96.26% of payment value**. Payment records are not equivalent to orders: an order can have multiple payment records, which is particularly visible for vouchers.

### 5.3 Payment value distribution per order

| Statistic | Payment value |
|---|---:|
| Orders with payment | 99,440 |
| Minimum | R$0.00 |
| Average | R$160.99 |
| Median | R$105.29 |
| Third quartile (Q3) | R$176.97 |
| Maximum | R$13,664.08 |

The average is higher than the median, indicating a right-skewed distribution in which a relatively small number of high-value orders influence the mean. The median is a more representative measure of the typical order's payment value. The maximum is a potential outlier for further investigation, not evidence of an error by itself.

## 6. Customer analysis

### 6.1 Purchase frequency

| Metric | Result |
|---|---:|
| Distinct customers | 96,096 |
| Customers with one order | 93,099 |
| Customers with more than one order | 2,997 |
| Repeat-customer share | 3.12% |
| Average orders per customer | 1.03 |
| Maximum orders by one customer | 17 |

| Orders per customer | Customers | Share of customers |
|---|---:|---:|
| 1 | 93,099 | 96.88% |
| 2 | 2,745 | 2.86% |
| 3 | 203 | 0.21% |
| 4 or more | 49 | 0.05% |

Only **252 customers placed three or more orders**. This describes observed purchase frequency within the available dataset window; it is not a true retention or cohort-retention rate. The observation period is limited, and customers may have purchased before or after the recorded period.

### 6.2 Customer geography

The state distribution below is based on customer records. The count of records and the count of distinct customers differ because the underlying customer dataset contains repeat customer records.

| State | Customer records | Distinct customers | Share of records |
|---|---:|---:|---:|
| SP | 41,746 | 40,302 | 41.98% |
| RJ | 12,852 | 12,384 | 12.92% |
| MG | 11,635 | 11,259 | 11.70% |
| RS | 5,466 | 5,277 | 5.50% |
| PR | 5,045 | 4,882 | 5.07% |
| SC | 3,637 | 3,534 | 3.66% |
| BA | 3,380 | 3,277 | 3.40% |
| DF | 2,140 | 2,075 | 2.15% |
| ES | 2,033 | 1,964 | 2.04% |
| GO | 2,020 | 1,952 | 2.03% |

The three largest states (SP, RJ, MG) account for **66.60% of customer records**, showing a strong concentration in Southeast Brazil. Percentages are calculated from customer records, not from a deduplicated customer population.

## 7. Product analysis

### 7.1 Catalog composition

The catalog contains **32,951 products**. A total of **610 products (1.85%)** are uncategorized in the analysis data.

| Product category | Products | Share of catalog |
|---|---:|---:|
| Bed, bath and table (`bed_bath_table`) | 3,029 | 9.19% |
| Sports and leisure (`sports_leisure`) | 2,867 | 8.70% |
| Furniture and decor (`furniture_decor`) | 2,657 | 8.06% |
| Health and beauty (`health_beauty`) | 2,444 | 7.42% |
| Housewares (`housewares`) | 2,335 | 7.09% |

The five largest categories represent approximately **40.46% of the catalog**. Category coverage is incomplete: the data-quality assessment identified missing category values as well as two source category names without translation entries. The `Uncategorized` grouping preserves products for transaction analysis but does not resolve their missing category information.

### 7.2 Delivered category performance

The following measures use delivered order items. Merchandise value is the sum of item prices; freight is shown separately. Average item price is not a measure of profit or margin.

| Category | Item lines | Products | Delivered orders | Merchandise value | Freight value | Average item price |
|---|---:|---:|---:|---:|---:|---:|
| Health and beauty | 9,465 | 2,397 | 8,647 | R$1,233,131.72 | R$178,957.81 | R$130.28 |
| Watches and gifts | 5,859 | 1,300 | 5,495 | R$1,166,176.98 | R$98,156.14 | R$199.04 |
| Bed, bath and table | 10,953 | 2,991 | 9,272 | R$1,023,434.76 | R$201,774.50 | R$93.44 |
| Sports and leisure | 8,431 | 2,822 | 7,530 | R$954,852.55 | R$163,404.36 | R$113.25 |
| Computers and accessories | 7,644 | 1,600 | 6,530 | R$888,724.61 | R$143,999.16 | R$116.26 |
| Furniture and decor | 8,160 | 2,593 | 6,307 | R$711,927.69 | R$168,402.23 | R$87.25 |
| Housewares | 6,795 | 2,282 | 5,743 | R$615,628.69 | R$142,763.56 | R$90.60 |
| Cool stuff | 3,718 | 770 | 3,559 | R$610,204.10 | R$81,476.79 | R$164.12 |
| Auto | 4,140 | 1,853 | 3,810 | R$578,966.65 | R$90,488.10 | R$139.85 |
| Toys | 4,030 | 1,373 | 3,804 | R$471,286.48 | R$75,774.58 | R$116.94 |

Bed, bath and table has the most delivered item lines (10,953), while health and beauty has the highest merchandise value (R$1.23 million) among the listed categories. These are different measures of category performance.

The `computers` category has a notably high average item price of **R$1,098.92**, but only 199 item lines, 30 products, and 177 delivered orders. This illustrates why a high average item price should not be confused with high transaction volume.

Uncategorized products are also transactionally relevant: 584 distinct uncategorized products appeared in 1,537 delivered item lines across 1,392 orders, generating **R$170,726.63** in merchandise value and **R$26,969.06** in freight. Missing category information should therefore be disclosed rather than dropping these transactions.

### 7.3 Frequently purchased products

The highest item-line counts among the top products were:

| Product ID | Category | Delivered item lines | Delivered orders | Merchandise value | Average item price |
|---|---|---:|---:|---:|---:|
| `aca2eb7d00ea1a7b8ebd4e68314663af` | Furniture and decor | 520 | 425 | R$37,104.30 | R$71.35 |
| `422879e10f46682990de24d770e7f83d` | Garden tools | 484 | 352 | R$26,577.22 | R$54.91 |
| `99a4788cb24856965c36a24e339b6058` | Bed, bath and table | 477 | 456 | R$42,049.66 | R$88.15 |
| `389d119b48cf3043d311335e499d9c6b` | Garden tools | 390 | 309 | R$21,336.79 | R$54.71 |
| `368c6c730842d78016ad823897a372db` | Garden tools | 388 | 291 | R$21,056.80 | R$54.27 |

The product with the most item lines is not necessarily the product with the highest merchandise value. For example, within the top 20 products ranked by item lines, product `bb50f2e236e5eea0100680137654686c` in health and beauty generated R$63,560.00 across 194 lines. Item-line ranking and merchandise-value ranking should therefore be treated separately.

## 8. Seller analysis

### 8.1 Seller geography

There are 3,095 registered sellers across 23 states in the seller data.

| State | Sellers | Share of registered sellers |
|---|---:|---:|
| SP | 1,849 | 59.74% |
| PR | 349 | 11.28% |
| MG | 244 | 7.88% |
| SC | 190 | 6.14% |
| RJ | 171 | 5.53% |

The five largest states account for **90.57% of registered sellers**. São Paulo alone represents almost 60% of the seller network. This describes seller location, not customer location or delivery destination.

### 8.2 Seller transaction activity

There were **2,970 active sellers** with delivered-order item activity, out of 3,095 registered sellers. The remaining 125 sellers had no delivered item lines in this analysis population; this does not establish that they had no transactions of other statuses.

The highest-value sellers demonstrate different combinations of volume and average item price:

| Seller ID | State | Delivered orders | Item lines | Merchandise value | Average item price |
|---|---|---:|---:|---:|---:|
| `4869f7a5dfa277a7dca6462dcf3b52b2` | SP | 1,124 | 1,148 | R$226,987.93 | R$197.72 |
| `53243585a1d6dc2643021fd1853d8905` | BA | 348 | 400 | R$217,940.44 | R$544.85 |
| `4a3ca9315b744ce9f8e9374361493884` | SP | 1,772 | 1,949 | R$196,882.12 | R$101.02 |
| `fa1c13f2614d7b5c4749cbc52fecda94` | SP | 578 | 579 | R$190,917.14 | R$329.74 |
| `7c67e1448b00f6e969d365cea6b010ab` | SP | 973 | 1,355 | R$186,570.05 | R$137.69 |

Seller order volume, item-line volume, and merchandise value are distinct indicators. For example, the second-ranked seller by merchandise value generated R$217,940.44 from 348 delivered orders, with a much higher average item price than the first-ranked seller.

### 8.3 Seller contribution concentration

| Metric | Result |
|---|---:|
| Active sellers | 2,970 |
| Total delivered merchandise value | R$13,221,498.11 |
| Top 10 seller contribution | 13.27% |
| Top 50 seller contribution | 33.20% |
| Top 100 seller contribution | 45.52% |

The top 100 sellers account for **45.52%** of delivered merchandise value, while the remaining 2,870 active sellers account for 54.48%. The largest sellers make a meaningful contribution, but the value is not concentrated exclusively among a very small number of sellers. These are merchandise-value shares, not profit or seller-revenue shares.

## 9. Delivery performance

### 9.1 Overall delivery performance

The overall delivery query included 96,470 delivered orders with valid purchase, actual delivery, and estimated delivery dates, and with actual delivery not preceding purchase.

| Metric | Result |
|---|---:|
| Eligible delivered orders | 96,470 |
| Average delivery time | 12.56 days |
| Median delivery time | 10.22 days |
| On-time orders | 88,644 |
| Late orders | 7,826 |
| On-time delivery rate | 91.89% |
| Late delivery rate | 8.11% |

The mean delivery time is higher than the median, suggesting a right-skewed distribution in which some long delivery times raise the average. Eight delivered orders were excluded because they lacked a customer delivery date, consistent with the data-quality assessment.

On-time performance is measured against the recorded estimated delivery date. It does not independently establish whether the estimate itself was realistic.

### 9.2 Monthly delivery performance

Monthly results are grouped by purchase month. The table below includes the eligible delivered orders returned by the query.

| Purchase month | Eligible delivered orders | Average days | Median days | On-time orders | Late orders | On-time rate |
|---|---:|---:|---:|---:|---:|---:|
| 2016-09 | 1 | 54.81 | 54.81 | 0 | 1 | 0.00% |
| 2016-10 | 265 | 19.60 | 17.94 | 262 | 3 | 98.87% |
| 2016-12 | 1 | 4.69 | 4.69 | 1 | 0 | 100.00% |
| 2017-01 | 750 | 12.65 | 10.73 | 727 | 23 | 96.93% |
| 2017-02 | 1,653 | 13.17 | 10.97 | 1,600 | 53 | 96.79% |
| 2017-03 | 2,546 | 12.95 | 10.13 | 2,404 | 142 | 94.42% |
| 2017-04 | 2,303 | 14.92 | 12.75 | 2,122 | 181 | 92.14% |
| 2017-05 | 3,545 | 11.32 | 9.79 | 3,417 | 128 | 96.39% |
| 2017-06 | 3,135 | 12.01 | 10.80 | 3,014 | 121 | 96.14% |
| 2017-07 | 3,872 | 11.59 | 10.16 | 3,739 | 133 | 96.57% |
| 2017-08 | 4,193 | 11.15 | 9.77 | 4,054 | 139 | 96.68% |
| 2017-09 | 4,150 | 11.85 | 10.31 | 3,934 | 216 | 94.80% |
| 2017-10 | 4,478 | 11.86 | 10.26 | 4,241 | 237 | 94.71% |
| 2017-11 | 7,288 | 15.16 | 12.70 | 6,245 | 1,043 | 85.69% |
| 2017-12 | 5,513 | 15.39 | 13.14 | 5,051 | 462 | 91.62% |
| 2018-01 | 7,069 | 14.08 | 11.83 | 6,605 | 464 | 93.44% |
| 2018-02 | 6,555 | 16.95 | 14.26 | 5,507 | 1,048 | 84.01% |
| 2018-03 | 7,003 | 16.30 | 13.37 | 5,507 | 1,496 | 78.64% |
| 2018-04 | 6,798 | 11.50 | 9.31 | 6,437 | 361 | 94.69% |
| 2018-05 | 6,749 | 11.42 | 9.15 | 6,193 | 556 | 91.76% |
| 2018-06 | 6,096 | 9.24 | 7.96 | 6,013 | 83 | 98.64% |
| 2018-07 | 6,156 | 8.96 | 7.50 | 5,880 | 276 | 95.52% |
| 2018-08 | 6,351 | 7.73 | 7.01 | 5,691 | 660 | 89.61% |

**Main observations:**

- November 2017 had an on-time rate of **85.69%** and 1,043 late orders. It was also the peak month for overall order volume (7,544 orders). The overlap suggests a possible capacity or fulfillment-pressure question, but does not prove that order volume caused the decline.
- February and March 2018 showed another deterioration. March had the lowest on-time rate in the substantial-volume months at **78.64%**, with 1,496 late orders.
- April 2018 recovered to **94.69%** on time, followed by a high of 98.64% in June.
- Average delivery time declined from 11.50 days in April 2018 to 7.73 days in August. However, the on-time rate fell to 89.61% in August, illustrating that delivery speed and performance against the estimate are different measures.
- September and December 2016 each have only one eligible order, so their percentages are not meaningful monthly indicators. The 2018 dataset coverage also becomes incomplete near the end of the period.

The monthly figures are purchase cohorts, not the calendar months in which delivery activity necessarily occurred.

### 9.3 Delivery performance by customer state

Only states with at least 100 eligible delivered orders are included.

| Customer state | Eligible delivered orders | Average days | Median days | On-time orders | Late orders | On-time rate |
|---|---:|---:|---:|---:|---:|---:|
| AM | 145 | 26.43 | 25.88 | 139 | 6 | 95.86% |
| AL | 397 | 24.54 | 22.33 | 302 | 95 | 76.07% |
| PA | 946 | 23.77 | 21.08 | 829 | 117 | 87.63% |
| MA | 717 | 21.57 | 19.19 | 576 | 141 | 80.33% |
| SE | 335 | 21.52 | 18.01 | 284 | 51 | 84.78% |
| CE | 1,279 | 21.27 | 18.21 | 1,083 | 196 | 84.68% |
| PB | 517 | 20.43 | 18.15 | 460 | 57 | 88.97% |
| PI | 476 | 19.46 | 16.29 | 400 | 76 | 84.03% |
| RO | 243 | 19.37 | 17.58 | 236 | 7 | 97.12% |
| BA | 3,256 | 19.34 | 16.91 | 2,799 | 457 | 85.96% |
| RN | 474 | 19.28 | 16.06 | 423 | 51 | 89.24% |
| PE | 1,593 | 18.45 | 15.70 | 1,421 | 172 | 89.20% |
| MT | 886 | 18.06 | 16.11 | 826 | 60 | 93.23% |
| TO | 274 | 17.66 | 15.87 | 239 | 35 | 87.23% |
| ES | 1,995 | 15.79 | 13.64 | 1,751 | 244 | 87.77% |
| MS | 701 | 15.62 | 13.94 | 620 | 81 | 88.45% |
| GO | 1,957 | 15.61 | 13.95 | 1,797 | 160 | 91.82% |
| RJ | 12,350 | 15.31 | 12.04 | 10,686 | 1,664 | 86.53% |
| RS | 5,344 | 15.30 | 13.18 | 4,962 | 382 | 92.85% |
| SC | 3,546 | 14.95 | 13.01 | 3,200 | 346 | 90.24% |
| DF | 2,080 | 12.97 | 11.36 | 1,933 | 147 | 92.93% |
| MG | 11,354 | 12.01 | 10.31 | 10,717 | 637 | 94.39% |
| PR | 4,923 | 11.99 | 10.43 | 4,677 | 246 | 95.00% |
| SP | 40,494 | 8.76 | 7.21 | 38,107 | 2,387 | 94.11% |

Delivery speed differs materially by destination. SP has the shortest average delivery time (8.76 days) among the reported states and the largest eligible order population (40,494). AM has the longest average delivery time (26.43 days), but its on-time rate is 95.86%. AL has the lowest on-time rate (76.07%) among the states shown.

These results suggest geographical variation in delivery speed and estimate reliability. They do not establish the causes. Distance, carrier coverage, seller dispatch timing, and other operational factors would need separate investigation. A long transit time does not necessarily imply poor on-time performance if the estimated date allows for it.

### 9.4 Delivery delay severity

| Metric | Result |
|---|---:|
| Eligible delivered orders | 96,470 |
| Delivered on or before estimate | 88,644 |
| Late orders | 7,826 |
| Average signed schedule deviation | −11.18 days |
| Average delay among late orders | 9.55 days |
| Median delay among late orders | 5.81 days |
| 90th percentile delay among late orders | 21.54 days |

Schedule deviation is calculated as actual customer delivery date minus estimated delivery date. Negative values indicate delivery before the estimate; positive values indicate lateness.

The average signed deviation of −11.18 days indicates that deliveries were, on average, substantially earlier than their estimated dates. This aggregate is influenced by the large number of orders delivered on time or early and does not mean that late orders were only slightly delayed.

Among late orders, the average delay was 9.55 days and the median was 5.81 days. The 90th percentile was 21.54 days, meaning approximately 10% of late orders were delayed by more than 21.54 days.

## 10. Review analysis

### 10.1 Review score distribution at record level

The staging review table contains review scores and flags for reused review IDs, repeated order IDs, and review dates preceding purchase timestamps.

| Score | Review records | Distinct orders represented | Share of review records | Records with reused review ID | Records with duplicate order ID |
|---:|---:|---:|---:|---:|---:|
| 5 | 57,328 | 57,076 | 57.78% | 823 | 623 |
| 4 | 19,142 | 19,098 | 19.29% | 265 | 193 |
| 3 | 8,179 | 8,160 | 8.24% | 163 | 103 |
| 2 | 3,151 | 3,148 | 3.18% | 73 | 41 |
| 1 | 11,424 | 11,393 | 11.51% | 279 | 138 |

At record level, 77.07% of review records have scores of four or five, while 14.69% have scores of one or two. The record-weighted average score is approximately **4.09 out of 5**.

These percentages are based on review records, not unique orders. An order can have multiple review records, and a review ID can be reused across different orders. Therefore, this initial distribution is descriptive and should not be interpreted as a unique-order distribution.

### 10.2 Review multiplicity by order

| Review records per order | Orders | Orders with multiple scores | Orders with repeated review IDs within the order |
|---:|---:|---:|---:|
| 1 | 98,126 | 0 | 0 |
| 2 | 543 | 200 | 0 |
| 3 | 4 | 2 | 0 |
| **Total** | **98,673** | **202** | **0** |

A total of **547 orders** have multiple review records. Of these, 345 have consistent scores across their records and 202 have conflicting scores. No order has a repeated review ID within its own review records.

This is separate from the earlier data-quality finding that 789 duplicated review-ID groups were reused across multiple orders, with identical review content within each group. Consequently, `review_id` alone is not a safe key for joining reviews to orders; `order_id` is the appropriate order-level association, subject to the repeated-order review treatment described here.

### 10.3 Order-level review score distribution

To avoid giving orders with multiple review records additional weight, the order-level distribution retains orders where all review records for that order have the same score. The 202 orders with conflicting scores are excluded.

| Score | Distinct orders | Underlying review records | Share of eligible orders |
|---:|---:|---:|---:|
| 5 | 56,955 | 57,206 | 57.84% |
| 4 | 18,993 | 19,037 | 19.29% |
| 3 | 8,094 | 8,112 | 8.22% |
| 2 | 3,113 | 3,116 | 3.16% |
| 1 | 11,316 | 11,347 | 11.49% |
| **Total** | **98,471** | **98,818** | **100.00%** |

Among the 98,471 orders with an unambiguous review score:

- Four- and five-star reviews account for **77.13%** of orders.
- Three-star reviews account for **8.22%**.
- One- and two-star reviews account for **14.65%**.
- The average score is approximately **4.09 out of 5**.

The order-level distribution is very similar to the record-level distribution. This indicates that the repeated review records do not materially change the overall pattern, although excluding conflicting-score orders remains necessary for a consistent order-level measure.

### 10.4 Review score versus delivery performance

This comparison includes **95,635 delivered orders** with an unambiguous review score and valid delivery dates.

| Review score | Eligible delivered orders | Average delivery days | Median delivery days | On-time orders | Late orders | On-time rate |
|---:|---:|---:|---:|---:|---:|---:|
| 5 | 56,697 | 10.68 | 9.23 | 54,996 | 1,701 | 97.00% |
| 4 | 18,844 | 12.30 | 10.78 | 17,901 | 943 | 95.00% |
| 3 | 7,878 | 14.24 | 12.04 | 7,013 | 865 | 89.02% |
| 2 | 2,904 | 16.65 | 13.27 | 2,305 | 599 | 79.37% |
| 1 | 9,312 | 21.34 | 16.81 | 5,779 | 3,533 | 62.06% |

Lower review scores are consistently associated with longer delivery times and lower on-time delivery rates. Comparing five-star and one-star orders:

- Average delivery time is **10.66 days longer** for one-star orders.
- Median delivery time is **7.58 days longer** for one-star orders.
- The on-time delivery rate is **34.94 percentage points lower** for one-star orders.

This is a strong descriptive association, not proof that delivery delays independently cause lower ratings. Product quality, seller service, customer expectations, and other factors may also influence review scores.

### 10.5 Review score distribution by delivery status

The same population of 95,635 orders is viewed from the perspective of delivery status. Percentages are calculated within each delivery-status group.

| Review score group | On-time deliveries | Late deliveries |
|---|---:|---:|
| 5 stars | 62.50% | 22.26% |
| 4 stars | 20.34% | 12.34% |
| 3 stars | 7.97% | 11.32% |
| 2 stars | 2.62% | 7.84% |
| 1 star | 6.57% | 46.24% |
| **4–5 stars combined** | **82.84%** | **34.60%** |
| **1–2 stars combined** | **9.19%** | **54.08%** |

More than half of late-delivery orders (54.08%) received one or two stars, compared with 9.19% of on-time orders. Conversely, 62.50% of on-time orders received five stars, compared with 22.26% of late orders.

This reinforces the association found in the previous analysis: late deliveries have a substantially higher concentration of low review scores. It remains an association and should not be presented as causal evidence.

## 11. Data-quality considerations relevant to EDA

The following known issues affect interpretation of the results. The detailed issue register and data-quality report remain the authoritative records for issue-level investigations and treatment decisions.

| Area | Finding | EDA implication |
|---|---|---|
| Product attributes | 611 products have at least one missing attribute; 610 are missing category values; one product has all attributes missing. | Retain transactional records where appropriate, but disclose incomplete category and product-attribute coverage. |
| Category translation | Two source category names have no translation entry. | Category coverage and translated labels are incomplete. Do not assume every uncategorized product is solely a translation failure. |
| Review IDs | 789 duplicated review-ID groups, all reused across multiple orders; records within each group have identical review content. | Do not use `review_id` alone as a unique order-review join key. |
| Order review multiplicity | 547 orders have multiple review records; 202 orders have conflicting scores. | Use one order-level score only when all scores for that order agree; exclude conflicting-score orders from the order-level score comparison. |
| Review dates | 74 reviews have creation dates before purchase; review timestamps are date-only at midnight. | Date-ordering anomalies should be flagged; same-day timestamp ordering is not reliable. |
| Delivery dates | Eight delivered orders are missing customer delivery dates. | Overall delivery analysis includes 96,470 eligible orders rather than all 96,478 delivered orders. |
| Delivery lifecycle dates | 1,182 orders have delivery dates while carrying a non-delivered status; 1,359 carrier handoff dates precede approval; 23 customer delivery dates precede carrier handoff. | Use lifecycle-aware filters and avoid assuming every populated timestamp is valid for every status. |
| Geolocation | Customer and seller postal prefixes have unmatched geolocation records; seller postal prefixes also include one ambiguous prefix in the optimized verification. | Avoid implying complete geographic coverage or precision at postal-prefix level. |
| Payment/installment | Two credit-card payment records have zero installments. | Retain the anomaly as a data-quality caveat; do not assume every payment field is valid. |
| Payment-item reconciliation | Some orders have payment without items, items without payment, or differences between payment and item/freight totals. | Do not treat aggregate payment and item/freight totals as a direct accounting reconciliation. |
| Time coverage | Order coverage is very small in September and October 2018; monthly delivered-order analysis ends in August 2018. | Treat end-of-period monthly comparisons as incomplete. |

## 12. EDA conclusions and opportunities for business analysis

The exploratory analysis identifies several patterns that can be developed into focused business questions in the next stage:

1. **Delivery reliability:** What operational factors are associated with the deterioration in on-time performance during November 2017 and February–March 2018?
2. **Geographic fulfillment:** Why do delivery times vary substantially between customer states, and which destination markets have the greatest combination of order volume and late-delivery exposure?
3. **Customer satisfaction:** How much of the observed review-score difference is associated with delivery timing after considering other available factors such as seller, product category, and destination?
4. **Seller performance:** How do seller order volume, item price, delivery outcomes, and customer reviews vary across high-contribution sellers?
5. **Customer repeat purchasing:** What customer, order, product, or service characteristics distinguish repeat purchasers from customers with only one recorded order?
6. **Product/category performance:** Which categories combine high merchandise value, order volume, and customer satisfaction, rather than ranking on only one metric?

These are investigation opportunities, not conclusions already established by the EDA. The business-analysis stage should define each question, metric, eligible population, comparison method, and limitation before presenting recommendations.

## 13. Reproducibility and supporting files

The analysis is supported by the SQL project structure:

```text
sql/
├── 01_database_setup.sql
├── 02_data_quality_assessment.sql
├── 03_staging_transformations.sql
├── 04_exploratory_analysis.sql
└── 05_business_analysis.sql
```

Supporting documentation:

```text
documentation/
├── data_dictionary.md
├── data_model.md
├── data_quality_methodology.md
├── data_quality_issue_register.md
├── data_quality_report.md
└── methodology.md
```

The SQL scripts provide the reproducible calculations. This report summarizes the findings and their interpretation; it is not a substitute for the underlying queries or data-quality documentation.
