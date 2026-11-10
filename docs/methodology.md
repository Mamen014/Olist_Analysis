# Project Methodology

## 1. Objective

The project demonstrates an end-to-end analytical workflow using the Brazilian E-Commerce Public Dataset by Olist. The work is designed to answer marketplace commercial and operational questions while demonstrating data-quality judgment, SQL transformation, dimensional modeling, metric definition, and business-facing reporting.

The analytical scope covers the historical dataset period from September 2016 through October 2018. It does not describe current Olist performance.

## 2. Workflow

### Stage 1 — Database setup

- Create the `olist_analysis` PostgreSQL database.
- Load the nine source CSV files into the `raw` schema.
- Preserve source table and column names.
- Confirm loaded row counts and key fields before analysis.

Script: `sql/01_database_setup.sql`.

### Stage 2 — Data quality assessment

Profile the source data across six dimensions:

1. Completeness
2. Uniqueness
3. Validity
4. Referential integrity
5. Consistency
6. Temporal integrity

For each issue, detect and quantify affected records, investigate context, assess analytical impact, decide on treatment, implement it in staging, and verify the result. The issue register documents individual findings and dispositions; the assessment report summarizes the work.

Scripts and outputs: `sql/02_data_quality_assessment.sql`, `docs/data_quality_report.md`, and `docs/data_quality_issue_register.md`.

### Stage 3 — Staging transformations

- Preserve `raw` unchanged.
- Create prepared objects in `staging`.
- Add quality flags and analysis-specific fields.
- Retain incomplete or anomalous records where possible.
- Avoid inventing missing timestamps, identifiers, or transaction values.
- Verify approved treatments against the initial assessment.

Script: `sql/03_staging_transformations.sql`.

### Stage 4 — Exploratory data analysis

Use staging tables to profile:

- order volume, statuses, and monthly patterns;
- payment values and payment methods;
- customer count, purchase frequency, and geography;
- product catalog and delivered category performance;
- seller footprint and contribution concentration;
- delivery speed, on-time performance, and delay severity;
- review-score distribution and its association with delivery outcomes.

Script: `sql/04_exploratory_analysis.sql`.

Output: `results/exploratory_analysis.md`.

### Stage 5 — Business analysis

Develop focused analyses from the EDA findings:

- BA-01: customer purchase frequency and value contribution;
- BA-02: product category commercial performance;
- BA-03: seller commercial contribution by state;
- BA-04: geographical prioritization of delivery improvement.

Each analysis defines its business question, population, metrics, results, implications, and limitations.

Script: `sql/05_business_analysis.sql`.

Output: `results/business_analysis.md`.

### Stage 6 — Reporting layer

Create the `analytics` schema with four dimensions and three fact views. Define fact grains, aggregate one-to-many child tables before creating order-level facts, and preserve the separation between order items and payment records.

Script: `sql/06_reporting_layer.sql`.

Validation: `results/validation_results.md`.

### Stage 7 — Power BI reporting

Connect Power BI to the PostgreSQL `analytics` views, create one-to-many single-direction dimension-to-fact relationships, define DAX measures, and build four pages: Executive Overview, Commercial Performance, Customer & Market Insights, and Delivery & Customer Experience.

Power BI guide: `powerbi/README.md`.

## 3. Analytical principles

### Preserve source data

Raw source records are retained. Transformations are implemented in staging or analytics objects, not by rewriting the original data.

### Define the grain

A count of customer records is not the same as a count of unique customers. Order counts are not item-line counts. Payment records and review records have their own grains. Metrics must use the entity or record grain that matches the business question.

### Apply population rules explicitly

Delivered-only commercial metrics, delivery-eligible metrics, and review-score metrics use different populations. Their denominators must be stated and must not be assumed to equal one another.

### Keep measures semantically distinct

Merchandise value excludes freight. Recorded freight is not actual logistics cost. Payment value is not automatically revenue or profit. Average order value, average item price, and value per customer are different measures.

### Do not overstate causality

The analysis is descriptive and observational. Associations between delivery delays and low ratings identify a pattern for investigation, not proof that delivery delays caused a particular review score.

### Document limitations

Missing attributes, duplicate/reused identifiers, conflicting reviews, timestamp anomalies, geographic-reference gaps, and incomplete time coverage remain visible as limitations. A passing validation rule only confirms that the tested rule did not detect an exception.

## 4. Reproducibility expectations

- Run SQL scripts in numerical order against the same source dataset version.
- Preserve source field spellings and types as loaded, or document any deliberate type conversion.
- Do not commit credentials or local connection strings.
- Record any changes to SQL logic and refresh the validation results when reporting views change.
- Reconcile Power BI default-period KPIs with the SQL benchmarks before publishing a revised report.
