# Power BI Report

## Report contents

The report is organized into four pages:

1. **01 — Executive Overview:** overall marketplace scale, order status, and delivery KPIs.
2. **02 — Commercial Performance:** category contribution, seller performance, seller geography, seller concentration, and freight intensity.
3. **03 — Customer & Market Insights:** unique customers, repeat-purchase segments, merchandise value contribution, and customer-state distribution.
4. **04 — Delivery & Customer Experience:** on-time performance, delivery trends, state comparisons, and review-score distribution by delivery outcome.


## Data source

The report connects to the PostgreSQL database `olist_analysis` and consumes views in the `analytics` schema. Create and validate these views by executing the SQL scripts in numerical order before opening or refreshing the report.

The report is not self-sufficient without the source dataset and PostgreSQL reporting layer. The PBIX file may contain an imported model snapshot, but refreshing it requires a working local database connection.

## Semantic model

The model uses four dimensions and three fact tables:

- Dimensions: `Dim Date`, `Dim Customer`, `Dim Product`, `Dim Seller`.
- Facts: `Fact Orders`, `Fact Order Items`, `Fact Order Payments`.

Use one-to-many, single-direction relationships from dimensions to facts. Do not create relationships between fact tables. The expected relationships and grains are documented in [`../docs/data_model.md`](../docs/data_model.md).

Important modeling considerations:

- `Dim Customer` is at `customer_id` grain. Distinct-person measures use `customer_unique_id`.
- `Dim Product` and `Dim Seller` filter `Fact Order Items`.
- `Fact Orders` is used for order-level and delivery measures.
- `Fact Order Payments` is kept separate from order items to avoid multiplying transactional values.
- The active date relationship uses purchase date.

## Measures and definitions

Use [`../docs/metric_dictionary.md`](../docs/metric_dictionary.md) for the definitions, populations, and interpretation of the principal measures. Default full-period KPI controls are in [`../results/validation_results.md`](../results/validation_results.md).

## Opening and refreshing

### If the repository contains a PBIP project

1. Open the `.pbip` file in a compatible version of Power BI Desktop.
2. Confirm the PostgreSQL connector is available.
3. Update the data-source server/database settings to match the local PostgreSQL installation.
4. Authenticate using local credentials; do not store passwords in the repository.
5. Refresh the model and verify the default-period control totals.

Commit the `.pbip` file and its associated `.Report/` and `.SemanticModel/` folders. Retain Power BI-generated project files needed to open the report, but exclude local cache and user-specific settings according to the generated `.gitignore`.

### If only a PBIX file is available

Open the `.pbix` in Power BI Desktop. For source control, consider using **File → Save As → Power BI Project (.pbip)** and commit the resulting project files. A PBIX is a binary package and does not provide useful line-by-line Git diffs; it is better suited to distribution as a release asset than routine source-code review.

## Screenshots

Screenshots should show each page in reading mode with default filters, no selections, no open editing panes, and no personal or connection details. The full-period dashboard numbers should match the SQL controls before screenshots are captured.
