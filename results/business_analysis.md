# Business Analysis Report

## 1. Executive Summary

This report presents four business analyses conducted using the Brazilian E-Commerce Public Dataset by Olist. The analyses build on the data quality assessment, staging transformations, and exploratory data analysis documented elsewhere in this project.

The objective is to translate descriptive findings into commercially and operationally relevant observations. The analysis focuses on customer purchase value, product category performance, seller contribution by state, and geographical delivery performance.

Four analyses were completed:

1. **Customer value segmentation:** Repeat customers have higher cumulative merchandise value per customer, but account for only 5.51% of delivered merchandise value.
2. **Product category performance:** The top five product categories contribute 39.83% of delivered merchandise value; freight intensity varies materially by category.
3. **Seller contribution by state:** São Paulo accounts for 64.36% of delivered merchandise value. Some smaller seller markets show high average value per active seller, although individual sellers can dominate those state-level averages.
4. **Geographical delivery improvement:** Rio de Janeiro and Bahia combine meaningful order volume with weaker delivery performance and comparatively high low-rating percentages. São Paulo has the greatest absolute number of late orders because it is the largest customer market.

These findings identify areas for further investigation. They do not establish causal relationships, profitability, or current Olist performance.

---

## 2. Analysis Scope and Method

### 2.1 Data scope

The analyses use the prepared tables in the `staging` schema and focus primarily on delivered orders. The reporting period is limited to the historical dataset, covering September 2016 through October 2018 at the order level. The dataset should not be treated as evidence of current marketplace performance.

### 2.2 Analytical principles

- Preserve the original records in the `raw` schema.
- Use delivered orders where the business question concerns completed transactions or completed delivery.
- Define the unit of analysis explicitly: customer, order, item line, product category, seller, or customer state.
- Use merchandise value to mean the sum of order-item prices. It is not profit or necessarily recognized accounting revenue.
- Treat recorded freight value as a transaction amount, not as the marketplace's actual logistics cost.
- Apply the documented review treatment: use one order-level score only when all review records for that order agree; exclude orders with conflicting review scores from score-based calculations.
- Interpret associations as associations, not proof of causation.

### 2.3 Supporting SQL

The queries for these analyses are maintained in `sql/05_business_analysis.sql` and are identified in this report as BA-01 through BA-04. Detailed query outputs are not reproduced in full; this report presents the principal results and their business implications.

---

## 3. BA-01 — Customer Purchase Frequency and Value Contribution

### Business question

Do repeat customers contribute a disproportionately large share of delivered merchandise value?

### Metric definitions

- **Customer segment:** Based on the number of distinct delivered orders per `customer_unique_id`.
- **Merchandise value:** Sum of delivered order-item prices, excluding freight.
- **Average merchandise per customer:** Segment merchandise value divided by customers in that segment.
- **Average merchandise per order:** Segment merchandise value divided by delivered orders in that segment.
- **Freight-to-merchandise percentage:** Segment freight value divided by segment merchandise value.

### Results

| Customer segment | Customers | Customer share | Delivered orders | Order share | Merchandise value | Value share | Avg. value per customer | Avg. value per order | Freight / merchandise |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| One-time | 90,557 | 97.00% | 90,557 | 93.86% | R$12,493,089.36 | 94.49% | R$137.96 | R$137.96 | 16.51% |
| 2 orders | 2,573 | 2.76% | 5,146 | 5.33% | R$631,274.90 | 4.77% | R$245.35 | R$122.67 | 18.62% |
| 3+ orders | 228 | 0.24% | 775 | 0.80% | R$97,133.85 | 0.73% | R$426.03 | R$125.33 | 18.78% |
| **Total** | **93,358** | **100.00%** | **96,478** | **100.00%** | **R$13,221,498.11** | **99.99%*** | — | — | — |

*The segment value shares sum to 99.99% because of rounding.*

### Findings

1. **The delivered customer base is dominated by one-time purchasers.** Of 93,358 customers with delivered purchases, 90,557 (97.00%) placed exactly one delivered order. This segment generated 94.49% of merchandise value.
2. **Repeat customers have higher cumulative value per customer.** Customers with two delivered orders averaged R$245.35 in merchandise value per customer; customers with three or more averaged R$426.03. The combined repeat-customer average was approximately R$260.05 per customer, compared with R$137.96 for one-time customers.
3. **Repeat customers do not have higher average merchandise value per order.** The average was R$122.67 for customers with two orders and R$125.33 for customers with three or more, versus R$137.96 for one-time customers. Their higher cumulative value primarily reflects additional purchases rather than higher value per order.
4. **Repeat customers remain a small share of total value.** Customers with at least two delivered orders represented 3.00% of customers and contributed approximately 5.51% of merchandise value.

### Business implications

The results suggest an opportunity to investigate repeat purchasing. A large share of the delivered customer base appears only once in the observed dataset, while customers who purchase repeatedly have higher cumulative merchandise value. Potential areas for further investigation include post-purchase engagement, second-purchase conversion, and relevant product or category recommendations.

The analysis does not establish why customers do not return or whether a particular retention initiative would increase repeat purchasing.

### Limitations

- Segments are based on delivered orders during the dataset observation period, not customer lifetime purchasing behavior.
- This analysis includes 93,358 customers with delivered purchases. It is not directly comparable to the EDA customer frequency analysis, which used a broader order population and therefore reported a different customer count and repeat-customer percentage.
- Merchandise value excludes freight, costs, commissions, refunds, and other accounting adjustments. It should not be interpreted as profit or net revenue.

### BA-01 conclusion

Repeat customers have higher cumulative merchandise value per customer, but their small share of the delivered customer base means they contribute only about 5.51% of delivered merchandise value. Increasing repeat purchase frequency is a potential commercial opportunity that warrants further investigation.

---

## 4. BA-02 — Product Category Commercial Performance

### Business question

Which product categories generate the most merchandise value, and how significant are their recorded freight charges relative to merchandise value?

### Metric definitions

- **Merchandise value:** Sum of delivered order-item prices within a category.
- **Merchandise value share:** Category merchandise value divided by total merchandise value across categories.
- **Average item price:** Average recorded order-item price within a category.
- **Freight-to-merchandise percentage:** Category freight value divided by category merchandise value.
- **Delivered orders, item lines, and distinct products:** Separate measures of transaction reach, item-line activity, and catalog breadth.

### Results — Largest categories by merchandise value

| Product category | Delivered orders | Item lines | Distinct products | Merchandise value | Value share | Avg. item price | Freight value | Freight / merchandise |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Health & Beauty | 8,647 | 9,465 | 2,397 | R$1,233,131.72 | 9.33% | R$130.28 | R$178,957.81 | 14.51% |
| Watches & Gifts | 5,495 | 5,859 | 1,300 | R$1,166,176.98 | 8.82% | R$199.04 | R$98,156.14 | 8.42% |
| Bed & Bath Table | 9,272 | 10,953 | 2,991 | R$1,023,434.76 | 7.74% | R$93.44 | R$201,774.50 | 19.72% |
| Sports & Leisure | 7,530 | 8,431 | 2,822 | R$954,852.55 | 7.22% | R$113.25 | R$163,404.36 | 17.11% |
| Computers & Accessories | 6,530 | 7,644 | 1,600 | R$888,724.61 | 6.72% | R$116.26 | R$143,999.16 | 16.20% |
| Furniture & Decor | 6,307 | 8,160 | 2,593 | R$711,927.69 | 5.38% | R$87.25 | R$168,402.23 | 23.65% |
| Housewares | 5,743 | 6,795 | 2,282 | R$615,628.69 | 4.66% | R$90.60 | R$142,763.56 | 23.19% |
| Cool Stuff | 3,559 | 3,718 | 770 | R$610,204.10 | 4.62% | R$164.12 | R$81,476.79 | 13.35% |
| Auto | 3,810 | 4,140 | 1,853 | R$578,966.65 | 4.38% | R$139.85 | R$90,488.10 | 15.63% |
| Toys | 3,804 | 4,030 | 1,373 | R$471,286.48 | 3.56% | R$116.94 | R$75,774.58 | 16.08% |

The top five categories contribute **39.83%** of total delivered merchandise value. The top ten contribute **62.43%**.

### Additional observations

**Commercial scale and transaction volume differ.** Health & Beauty generated the highest category merchandise value, while Bed & Bath Table had the most delivered orders (9,272) and item lines (10,953).

**High average item price does not necessarily imply high category value.** The Computers category had an average item price of R$1,098.92 and merchandise value of R$218,684.14, but only 177 delivered orders and 199 item lines. Its high average item price did not translate into the value contribution of the largest categories.

**Freight intensity varies by category.** Among the larger categories, Furniture & Decor had a freight-to-merchandise ratio of 23.65%, Housewares 23.19%, and Telephony 22.38%. Watches & Gifts had a much lower ratio of 8.42%, while Health & Beauty was 14.51%.

**Uncategorized products remain commercially relevant.** The Uncategorized group accounted for 584 distinct products, 1,392 delivered orders, 1,537 item lines, and R$170,726.63 in merchandise value (1.29% of the total). Incomplete product categorization should therefore not result in removing otherwise valid transactions from commercial analysis.

The two categories missing from the translation table were retained under their original category names. They are distinct from products with genuinely missing category attributes.

### Business implications

1. **Category prioritization:** Health & Beauty, Watches & Gifts, and Bed & Bath Table are candidates for further investigation into assortment, availability, and seller coverage because of their substantial merchandise value and transaction activity.
2. **Freight-related investigation:** Furniture & Decor and Housewares combine significant merchandise value with relatively high recorded freight-to-merchandise ratios. Further work could examine item dimensions, customer destination, and shipping arrangements.
3. **Catalog completeness:** Improving category completeness could make product segmentation and commercial reporting more reliable, particularly for the Uncategorized group.

### Limitations

- The freight ratio compares recorded freight charges with merchandise value. It is not a measure of actual logistics cost, contribution margin, or profitability.
- Category performance is based on delivered item lines. It does not account for inventory, returns, discounts, commissions, or product-level costs.
- The 610 products with missing category attributes and the two untranslated category names are different data-quality conditions and should remain distinct in reporting.

### BA-02 conclusion

Delivered merchandise value is concentrated in a small group of categories, but transaction volume, average item price, and freight intensity vary substantially. The strongest follow-up opportunities are to investigate the major value-generating categories, review freight intensity in high-volume categories, and improve catalog completeness.

---

## 5. BA-03 — Seller Commercial Contribution by State

### Business question

Does the geographical distribution of sellers correspond to their contribution to delivered merchandise value?

### Metric definitions

- **Registered sellers:** Sellers in the staging seller table, grouped by seller master state.
- **Active sellers:** Registered sellers with at least one delivered order-item line in the analysis period.
- **Merchandise value share:** State merchandise value divided by total delivered merchandise value.
- **Average merchandise per active seller:** State merchandise value divided by active sellers in that state.
- **Freight-to-merchandise percentage:** State freight value divided by state merchandise value.

### Results — Largest seller markets

| Seller state | Registered sellers | Active sellers | Active seller rate | Merchandise value | Value share | Avg. value per active seller | Freight / merchandise |
|---|---:|---:|---:|---:|---:|---:|---:|
| SP | 1,849 | 1,769 | 95.67% | R$8,509,511.46 | 64.36% | R$4,810.35 | 17.01% |
| PR | 349 | 335 | 95.99% | R$1,232,096.99 | 9.32% | R$3,677.90 | 15.59% |
| MG | 244 | 236 | 96.72% | R$977,866.31 | 7.40% | R$4,143.50 | 21.12% |
| RJ | 171 | 163 | 95.32% | R$820,611.59 | 6.21% | R$5,034.43 | 11.13% |
| SC | 190 | 184 | 96.84% | R$613,591.65 | 4.64% | R$3,334.74 | 16.97% |
| RS | 129 | 125 | 96.90% | R$373,412.08 | 2.82% | R$2,987.30 | 15.09% |
| BA | 19 | 18 | 94.74% | R$277,925.51 | 2.10% | R$15,440.31 | 6.92% |

### Findings

1. **São Paulo dominates seller-side merchandise value.** It represents 59.74% of registered sellers (1,849 of 3,095) but contributes 64.36% of delivered merchandise value. Its value share is 4.62 percentage points higher than its registered-seller share.
2. **The top six seller states account for most merchandise value.** SP, PR, MG, RJ, SC, and RS together contribute 94.75% of delivered merchandise value.
3. **Active seller rates are high in the largest seller markets.** The six largest states have active seller rates between 95.32% and 96.90%. Across the dataset, 2,970 of 3,095 registered sellers had delivered-order activity.
4. **Some smaller states show high average value per active seller.** Bahia averaged R$15,440.31 per active seller, but this result is heavily concentrated in one seller. Seller `53243585a1d6dc2643021fd1853d8905` generated R$217,940.44, approximately 78.42% of Bahia's merchandise value. The state average should not be interpreted as representative of all its sellers.
5. **Freight intensity differs among large seller markets.** MG had a 21.12% freight-to-merchandise ratio, compared with 17.01% in SP, 15.59% in PR, and 11.13% in RJ.

### Business implications

- **Monitor dependence on the largest seller market:** São Paulo's 64.36% share means disruptions affecting sellers in that state could have a substantial marketplace-wide impact.
- **Review seller concentration in smaller markets:** Bahia's value contribution is unusually dependent on one seller. Monitoring concentration and supplier continuity may be useful.
- **Investigate freight differences:** The relatively high freight ratio in MG warrants further analysis of product mix and customer destinations. The figures alone do not establish an operational inefficiency.

### Limitations

- State is taken from the seller master record. This analysis describes seller location, not customer destination or delivery route.
- Average merchandise value per active seller can be strongly affected by a small number of high-value sellers, especially in states with few registered sellers.
- States with very small seller populations should not be compared as if their averages were equally representative.
- Freight values are recorded transaction amounts, not actual seller or marketplace logistics costs.

### BA-03 conclusion

Seller-side merchandise value is geographically concentrated, especially in São Paulo. However, seller productivity and freight intensity vary across states, and seller count alone does not indicate commercial importance. State-level averages should be interpreted alongside seller concentration.

---

## 6. BA-04 — Geographical Prioritization of Delivery Improvement

### Business question

Which customer markets combine meaningful delivered-order volume with weaker delivery reliability and a higher concentration of low review scores?

### Metric definitions

- **Eligible delivered orders:** Delivered orders with valid purchase, actual delivery, and estimated delivery timestamps, and with actual delivery not earlier than purchase.
- **Order volume share:** State eligible delivered orders divided by the eligible delivered-order total.
- **Late delivery percentage:** Orders delivered after the estimated date divided by eligible delivered orders.
- **Average days late:** Average positive difference between actual and estimated delivery dates, calculated only for late orders.
- **Review coverage:** Orders with an unambiguous order-level review score divided by eligible delivered orders.
- **Low-rating percentage:** Orders with a one- or two-star score divided by orders with an unambiguous review score. Orders with conflicting review scores are not included in this denominator.

### Results — Selected customer markets

| Customer state | Eligible delivered orders | Order share | Avg. delivery days | Late orders | Late rate | Avg. days late | Reviewed orders | Review coverage | Low-rating orders | Low-rating rate |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| SP | 40,494 | 42.06% | 8.76 | 2,387 | 5.89% | 7.03 | 40,195 | 99.26% | 4,278 | 10.64% |
| RJ | 12,350 | 12.83% | 15.31 | 1,664 | 13.47% | 12.85 | 12,175 | 98.58% | 2,228 | 18.30% |
| MG | 11,354 | 11.79% | 12.01 | 637 | 5.61% | 7.53 | 11,267 | 99.23% | 1,321 | 11.72% |
| BA | 3,256 | 3.38% | 19.34 | 457 | 14.04% | 11.10 | 3,222 | 98.96% | 547 | 16.98% |
| CE | 1,279 | 1.33% | 21.27 | 196 | 15.32% | 14.33 | 1,271 | 99.37% | 218 | 17.15% |
| AL | 397 | 0.41% | 24.54 | 95 | 23.93% | 9.25 | 393 | 98.99% | 83 | 21.12% |
| MA | 717 | 0.74% | 21.57 | 141 | 19.67% | 9.97 | 711 | 99.16% | 142 | 19.97% |
| PI | 476 | 0.49% | 19.46 | 76 | 15.97% | 12.30 | 471 | 98.95% | 76 | 16.14% |
| SE | 335 | 0.35% | 21.52 | 51 | 15.22% | 16.89 | 334 | 99.70% | 63 | 18.86% |

The full state-level output is reproducible using BA-04 in `sql/05_business_analysis.sql`. The table above highlights larger markets and states with comparatively weak delivery or review results; it is not the complete state listing.

### Findings

**1. Rio de Janeiro combines meaningful order volume with weaker delivery performance.**

RJ accounts for 12.83% of eligible delivered orders and had a 13.47% late-delivery rate, compared with the overall EDA rate of 8.11%. Its average delivery time was 15.31 days, and its low-rating percentage was 18.30%. It is a strong candidate for further operational investigation.

**2. São Paulo has the largest absolute number of late orders.**

SP accounts for 42.06% of eligible delivered orders and recorded 2,387 late orders. Its late-delivery rate (5.89%) and low-rating percentage (10.64%) are comparatively favorable. Nevertheless, its large volume means it remains important to monitor. SP and RJ together account for 4,051 late orders, approximately 51.8% of the 7,826 late orders in the overall eligible delivery population.

**3. Bahia and Ceará combine meaningful regional volume with weaker results.**

BA recorded a 14.04% late-delivery rate and a 16.98% low-rating percentage across 3,256 eligible delivered orders. CE recorded a 15.32% late-delivery rate and a 17.15% low-rating percentage across 1,279 orders. These markets merit further investigation because their results are not based solely on very small samples.

**4. Some smaller markets have more severe percentages but lower absolute scale.**

AL had the highest late-delivery rate (23.93%) and low-rating percentage (21.12%) in the reported state results, but accounted for only 0.41% of eligible delivered orders. MA also had relatively high rates: 19.67% late deliveries and 19.97% low ratings across 717 orders. These are potential localized issues, but their smaller volumes should be considered when prioritizing broader marketplace initiatives.

**5. Delivery and review performance move together in several markets.**

RJ, BA, CE, AL, MA, PI, and SE show both higher late-delivery and low-rating percentages than SP. This is consistent with the order-level association established in EDA. The state-level comparison does not establish that delivery delays independently cause low ratings.

### Business prioritization

The following is a qualitative investigation order based on order volume, late-delivery rate, and low-rating percentage. It is not a statistically optimized score or a forecast of financial return.

| Investigation priority | Market | Rationale |
|---|---|---|
| 1 | RJ | Large customer market with 13.47% late deliveries and 18.30% low ratings. |
| 2 | BA | Meaningful volume with 14.04% late deliveries and 16.98% low ratings. |
| 3 | CE | 1,279 eligible orders, 15.32% late deliveries, and 17.15% low ratings. |
| Localized follow-up | AL and MA | Highest or near-highest negative-performance rates, but smaller order volumes. |
| Monitor and protect | SP | Largest market and highest absolute late-order count, despite relatively favorable rates. |

### Business implications

1. Investigate delivery performance in RJ and BA, including seller origin, carrier, delivery route, and purchase period.
2. Examine CE and other Northeastern states for persistent delivery problems and possible regional service constraints.
3. Monitor SP because small rate changes can affect a large number of orders.
4. For AL and MA, validate whether the high percentages persist across time periods before assigning substantial operational resources.

### Limitations

- Customer state represents the destination-side customer location, not seller location or carrier route.
- The analysis is descriptive. It does not control for distance, product type, seller, carrier, seasonality, or customer expectations.
- Review coverage is high but not complete. Low-rating percentages use only orders with an unambiguous review score.
- The state-prioritization approach is qualitative. A resource-allocation decision would require additional operational and cost information.
- The results describe 2016–2018 historical transactions and should not be treated as current regional service-level performance.

### BA-04 conclusion

Delivery performance and low-rating percentages differ substantially across customer markets. RJ and BA are strong candidates for investigation because they combine meaningful order volumes with weaker delivery and review outcomes. CE also warrants attention. AL and MA show more severe percentages but lower transaction volume. SP remains important because it contributes the largest absolute number of late orders.

---

## 7. Consolidated Business Findings and Recommendations

### 7.1 Main findings

| Business theme | Evidence | Business interpretation |
|---|---|---|
| Customer value | Repeat customers are 3.00% of delivered customers and contribute approximately 5.51% of merchandise value. | Investigate second-purchase conversion and repeat-purchase behavior. |
| Product categories | Top five categories contribute 39.83% of merchandise value; top ten contribute 62.43%. | Focus commercial review on high-contribution categories while monitoring freight intensity. |
| Seller geography | SP contributes 64.36% of merchandise value; top six seller states contribute 94.75%. | Monitor dependence on major seller markets and assess concentration in smaller states. |
| Delivery geography | RJ and BA combine significant order volume with higher late-delivery and low-rating percentages; SP has the most late orders by count. | Target operational investigation by both rate and absolute volume. |

### 7.2 Recommended follow-up investigations

The current analysis identifies where to investigate, but does not contain enough evidence to prescribe specific operational changes. The following analyses would help validate the opportunities:

1. **Customer repeat purchasing:** Examine purchase timing and category transitions for one-time and repeat customers. A cohort-based approach would be needed to distinguish customers who had sufficient observation time to repurchase from those acquired near the end of the dataset period.
2. **Category and freight drivers:** Compare freight-to-merchandise ratios by product dimensions, customer destination, and seller state. This could help distinguish product-mix effects from geographic effects.
3. **Seller concentration:** Measure each seller's contribution within their state and category, and assess whether high state-level averages depend on a small number of sellers.
4. **Delivery root causes:** Break down late deliveries by seller, carrier-related fields where available, destination, purchase month, and delay severity. This is necessary before attributing delays to a particular logistics cause.
5. **Customer experience:** Examine review comments alongside delivery status and score, while respecting review identifier reuse and conflicting order-level scores.

### 7.3 Recommendations supported by current evidence

- Treat repeat purchase as a commercial opportunity to investigate, not as a proven retention intervention.
- Prioritize commercial monitoring of the categories contributing the most merchandise value.
- Investigate high freight-to-merchandise ratios in categories with material transaction volume.
- Monitor seller-market concentration, particularly São Paulo's contribution and Bahia's dependence on one major seller.
- Prioritize deeper fulfillment investigation in RJ, BA, and CE; monitor SP by absolute late-order count; validate AL and MA patterns across time before treating them as broad-scale priorities.

---

## 8. Overall Limitations

1. **Historical scope:** The source dataset covers 2016–2018. Findings are descriptive of that period and do not represent current marketplace conditions.
2. **No profitability measurement:** The available analysis does not include full costs, commissions, returns, or accounting adjustments. Merchandise value is not profit or necessarily recognized revenue.
3. **Freight interpretation:** Freight value is a recorded transaction amount, not necessarily the actual cost incurred by the marketplace, seller, or carrier.
4. **Observational analysis:** Relationships between delivery performance and review scores do not establish causality.
5. **Customer observation window:** Repeat-purchase segmentation is bounded by the period covered by the dataset and is not lifetime value or a definitive retention measure.
6. **Data-quality treatment:** The analysis follows the documented handling of incomplete product attributes, review identifier reuse, conflicting order-level review scores, and other data-quality issues. Results should be interpreted using those eligibility rules.
7. **Operational root causes:** The dataset identifies patterns and differences but does not independently explain carrier, seller, route, inventory, or service failures.

---

## 9. Conclusion

The business analysis identified four actionable areas for further investigation: increasing repeat purchasing, focusing commercial attention on high-contribution product categories, monitoring seller concentration, and prioritizing delivery-performance investigations by customer market.

The strongest evidence-based observations are that repeat customers contribute a small but higher cumulative value per customer; the top product categories account for a substantial share of delivered merchandise value; São Paulo dominates seller-side merchandise value; and delivery reliability and low-rating percentages vary across customer states.

These findings provide a basis for more targeted business questions. They should be treated as historical, descriptive evidence rather than causal conclusions or current performance benchmarks. Any proposed intervention or investment decision would require further analysis of costs, operational drivers, and expected outcomes.
