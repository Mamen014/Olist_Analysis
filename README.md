# Brazilian E-Commerce Analytics

**End-to-end SQL and Power BI portfolio project** using the Brazilian E-Commerce Public Dataset by Olist.

This project demonstrates a complete analytical workflow: source-data profiling, data-quality investigation, SQL staging transformations, exploratory and business analysis, dimensional reporting views, metric validation, and interactive Power BI reporting.

The objective is not simply to produce a dashboard. It is to show how raw transactional data can be assessed, transformed without hiding source limitations, modeled at appropriate grains, translated into defensible business metrics, and communicated to stakeholders.

## Dashboard preview

The Power BI report contains four pages:

| Page | Analytical focus |
|---|---|
| 01 — Executive Overview | Marketplace scale, order status, and overall delivery performance |
| 02 — Commercial Performance | Product categories, seller contribution, and freight intensity |
| 03 — Customer & Market Insights | Purchase frequency, repeat-customer value, and customer geography |
| 04 — Delivery & Customer Experience | Delivery reliability, regional performance, and review outcomes |

Add the four exported report-page images under [`powerbi/screenshots/`](powerbi/screenshots/). Once added, they will provide a quick way to review the report without opening Power BI Desktop.

## Business questions

1. **Commercial performance:** Which product categories and sellers contribute most to delivered merchandise value? How does recorded freight compare with merchandise value?
2. **Customer behavior:** How concentrated is purchasing among one-time customers, and how much value is associated with repeat purchasers?
3. **Marketplace geography:** How are customers and sellers distributed across Brazilian states, and how do their roles differ?
4. **Delivery operations:** How reliable are deliveries against estimated dates, and which customer markets combine meaningful order volume with weaker outcomes?
5. **Customer experience:** How are delivery outcomes associated with customer review scores?

## Selected findings

- The source contains **99,441 orders** from September 2016 through October 2018.
- **96,478 orders** have a delivered status. Of these, **96,470** meet the defined eligibility conditions for delivery-performance analysis.
- Delivered merchandise value is **R$13,221,498.11**; delivered recorded freight is **R$2,198,275.64**.
- The eligible delivered-order on-time rate is **91.89%** (88,644 on-time orders out of 96,470 eligible orders).
- **93,358 distinct customers** have at least one delivered purchase. **2,801 (3.00%)** have two or more delivered orders in the observed period and account for **5.51%** of delivered merchandise value.
- The top five product categories contribute **39.83%** of delivered merchandise value.
- The top 100 sellers contribute **45.52%** of delivered merchandise value.
- **54.08%** of late orders with unambiguous review scores received one- or two-star ratings, compared with **9.19%** of on-time orders. This is an observed association, not evidence of causation.

These are historical dataset findings, not statements about Olist's current operating performance.

## Workflow

| Stage | Work performed | Main deliverable |
|---|---|---|
| 01. Database setup | Create `olist_analysis`, schemas, and source-table loading process | `sql/01_database_setup.sql` |
| 02. Data quality assessment | Profile completeness, uniqueness, validity, referential integrity, consistency, and temporal integrity | Data quality report and issue register |
| 03. Staging transformations | Preserve `raw`; implement documented flags and analysis-specific treatments in `staging` | `sql/03_staging_transformations.sql` |
| 04. Exploratory analysis | Examine orders, transactions, customers, products, sellers, delivery, and reviews | `results/exploratory_analysis.md` |
| 05. Business analysis | Investigate customer value, category performance, seller contribution, and regional delivery priorities | `results/business_analysis.md` |
| 06. Reporting layer | Create Power BI-ready dimensions and fact views in `analytics` | `sql/06_reporting_layer.sql` |
| 07. BI reporting | Build the semantic model, DAX measures, and four report pages | `powerbi/` |

## Repository structure

```text
olist-ecommerce-analytics/
├── README.md
├── NOTICE.md
├── .gitignore
├── sql/
│   ├── 01_database_setup.sql
│   ├── 02_data_quality_assessment.sql
│   ├── 03_staging_transformations.sql
│   ├── 04_exploratory_analysis.sql
│   ├── 05_business_analysis.sql
│   └── 06_reporting_layer.sql
├── docs/
│   ├── data_dictionary.md
│   ├── data_model.md
│   ├── methodology.md
│   ├── metric_dictionary.md
│   ├── data_quality_report.md
│   └── data_quality_issue_register.md
├── results/
│   ├── exploratory_analysis.md
│   ├── business_analysis.md
│   └── validation_results.md
├── data/
│   └── README.md
├── powerbi/
│   ├── README.md
│   ├── screenshots/
│   └── [PBIP project files or PBIX release]
└── presentation/
    ├── Olist_Business_Analysis.pptx
    └── Olist_Business_Analysis.pdf
```

The raw dataset is intentionally not included. Download and load it locally by following [`data/README.md`](data/README.md).

## Reproducing the project

1. Install PostgreSQL and a SQL client such as pgAdmin.
2. Download the Olist CSV files from the [original Kaggle dataset page](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).
3. Create the `olist_analysis` database and load the nine source CSV files into the `raw` schema. Preserve the source column names; see [`data/README.md`](data/README.md).
4. Execute the SQL scripts in numerical order. The reporting layer depends on the completed staging layer.
5. Compare the results with [`results/validation_results.md`](results/validation_results.md).
6. Open the Power BI project and configure its PostgreSQL connection to the local database. See [`powerbi/README.md`](powerbi/README.md).

See [`docs/methodology.md`](docs/methodology.md) for the detailed workflow and [`docs/data_model.md`](docs/data_model.md) for the reporting model.

## Tools

- PostgreSQL and SQL
- Power BI Desktop and DAX
- Git and GitHub

## Important analytical limitations

- The dataset covers historical activity from 2016–2018 and should not be interpreted as current Olist performance.
- Raw source records are preserved; staging treatments do not make every source record error-free or suitable for every analysis.
- Payment value is not automatically equivalent to recognized revenue, net sales, or seller proceeds.
- Merchandise value is the sum of item prices and excludes freight. It is not profit or contribution margin.
- Recorded freight charges are not actual logistics costs.
- Customer repeat-purchase analysis uses `customer_unique_id`; customer records and unique customers are different grains.
- Delivery metrics use an explicitly eligible delivered-order population.
- Orders with conflicting review scores are excluded from order-level review-score analysis.
- Associations between delivery and reviews do not establish causation.
- September and October 2018 have incomplete period coverage.

## Documentation

- [Data dictionary](docs/data_dictionary.md)
- [Data model](docs/data_model.md)
- [Project methodology](docs/methodology.md)
- [Metric dictionary](docs/metric_dictionary.md)
- [Data quality report](docs/data_quality_report.md)
- [Data quality issue register](docs/data_quality_issue_register.md)
- [EDA results](results/exploratory_analysis.md)
- [Business analysis results](results/business_analysis.md)
- [Reporting-layer validation](results/validation_results.md)

## Attribution

Dataset source: Olist, [Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). Review the license and attribution requirements on the source dataset page before redistributing dataset-derived files. See [`NOTICE.md`](NOTICE.md).
