# DataBridge 360: Multi-Source ETL, Data Quality, & Business Intelligence Platform

## 📌 Project Overview
DataBridge 360 is an enterprise-grade data warehousing and automated ETL (Extract, Transform, Load) platform built using **MSSQL (T-SQL)** and **Power BI**.

In real-world corporate environments, raw transactional data arriving from legacy systems, ERPs, and web forms is notoriously unstable—plagued by duplicate records, inconsistent naming conventions, orphaned transactions, and format corruptions. This project builds a resilient, self-auditing Data Quality Engine that intercepts, profiles, and isolates corrupted records into an audit layer while processing clean financial and customer data into a high-performance Star Schema data warehouse.

---

## 🏗️ Architecture & Data Flow

[Raw Data Sources] ──► [Landing Layer] ──► [Data Quality Engine (Stored Procs)]
│
┌──────────────────────────────────────────────────┴──────────────────────────────────────────────────┐
▼                                                                                                     ▼
[DataQualityIssues Audit Table]                                                                  [Staging / Reporting Layer]
(Tracks: Future dates, negative quantities,                                                   (DimCustomer, DimProduct, DimDate ──► FactSales)
invalid emails, bad phone lengths)                                                                            │
▼
[Power BI Star Schema Views]


*   **Landing Layer:** Raw data is ingested exactly as-is into `Landing_` tables with loose constraints to ensure zero ingestion failures.
*   **Staging & Validation Layer:** Specialized T-SQL stored procedures execute data cleansing algorithms (text trimming, capitalization, phone/email string validation) and evaluate advanced business logic rules.
*   **Audit & Rejection Layer:** Records violating data integrity rules are safely routed to a central `DataQualityIssues` table with logged violation signatures, ensuring the pipeline never crashes.
*   **Reporting Warehouse:** Validated records are mapped to surrogate keys and processed into a centralized star schema optimized for fast analytical aggregations.

---

## 💾 Database Schema & Implementation
The repository is logically organized into four core sequence scripts to support a clean deployment lifecycle:

1.  **`01_ddl_schema_setup.sql`:** Provisions the database layout, data types, and primary/foreign key relationships across the landing, staging, and dimensional structures (`DimCustomer`, `DimProduct`, `DimDate`, `FactSales`).
2.  **`02_etl_stored_procedures.sql`:** Houses the transactional logic engines (`usp_Load_Customers`, `usp_Load_Products`, `usp_Load_Sales`) and the master coordinator wrapper (`usp_Refresh_DataWarehouse`).
3.  **`03_reporting_views.sql`:** Decouples the presentation layer from the physical database layout, providing high-performance, denormalized structures natively tailored for Power BI DirectQuery/Import processing.
4.  **`04_mock_data_and_validation.sql`:** Automated testing script that populates the complete 10-year calendar matrix, introduces corrupted sample data payloads, drives the execution pipeline, and prints analytical system health tallies.

---

## 🛡️ Data Quality Rules Matrix & Interception Logs
The pipeline actively evaluates, logs, and mitigates the following system anomalies:

| Source Area | Target Field | Checked Validation Rule | Action Taken on Failure |
| :--- | :--- | :--- | :--- |
| **Customers** | `Raw_Email` | Regular expression check for missing `@` or domain strings. | Route to Audit Log, exclude from Production. |
| **Customers** | `Raw_Phone` | Length verification, stripping local character variations. | Isolate invalid structures. |
| **Products** | `Raw_Category` | Default mapping of unassigned classifications to 'Unassigned'. | Standardize text string, track metadata gap. |
| **Products** | `Raw_Price` | Evaluates for negative valuation pricing loops. | Fail transaction row, alert audit table. |
| **Sales** | `Raw_Quantity` | Blocks negative quantities ($Quantity \le 0$). | Trap structural error, drop order record. |
| **Sales** | `Raw_SaleDate` | Flags and traps future-dated timestamps. | Exclude future out-of-bounds orders. |
| **Sales** | `CustomerID` | Identifies orphaned records missing a parent entity ID. | Enforce structural referential integrity. |

---

## 🛠️ Real-World Engineering Hurdles & Solved Challenges

### 1. Bypassing Parent-Child Truncation Locks (Msg 4712)
*   **The Issue:** Standard deployment initialization scripts failed when using `TRUNCATE TABLE` on parent dimension lookup metrics (`DimCustomer`, `DimDate`) due to active foreign key constraints tied to `FactSales`, even when tables contained zero records.
*   **The Solution:** Implemented structured row-by-row `DELETE` statements paired with tactical constraint ordering within the data maintenance procedures, allowing schema clearance without requiring unsafe drop-and-rebuild permissions.

### 2. Time Dimension Lookup Interceptions
*   **The Issue:** Transactional rows passing staging checks were silently dropping out of the reporting tier during final integration joins.
*   **The Solution:** Discovered an empty calendar dimension (`DimDate`) was forcing referential lookup failures. Engineered an automated boundary loop inside `04_mock_data_and_validation.sql` that generates a pre-populated, numeric smart-key matrix (YYYYMMDD) mapping a full decade of dates.

---

## 📊 Business Intelligence & Dashboard Deliverables
The Power BI Desktop implementation hooks directly into the database reporting views via an optimized Star Schema model utilizing clean one-to-many ($1:*$) directional filtering relationships.

### 1. Executive Revenue Tracker
*   Tracks enterprise revenue execution against valid database entities.
*   Dynamically aggregates processed financial inputs instantly, demonstrating database calculation performance.

### 2. Operational Data Quality Dashboard
*   A dedicated view displaying active data health metrics.
*   Breaks down corporate data failures by validation category, providing immediate visualization.

---

## 🧱 Advanced Analytical DAX Measures

To transition the dashboard from basic column implicit sums to a high-performance, explicit calculation layer, **6 specialized DAX measures** were engineered to handle data quality profiling, advanced trends, and dynamic cohort behavior:

### 1. **`Total Revenue`**
An explicit core financial aggregation that computes total corporate income across valid transactional records.
```dax
Total Revenue = SUM(FactSales[Revenue])
2. Total DQ Issues
An operational data governance metric that aggregates total validation exceptions caught and isolated by the T-SQL ETL engine.

Code snippet
Total DQ Issues = SUM(vw_DataQualityDashboard[TotalViolations])
3. Data Health Index %
An advanced executive KPI that calculates data ingestion efficiency. It computes the percentage of pristine rows successfully loaded into the reporting warehouse versus total data payloads processed.

Code snippet
Data Health Index % = 
VAR CleanRows = COUNTROWS(FactSales)
VAR ErrorRows = SUM(vw_DataQualityDashboard[TotalViolations])
VAR TotalRows = CleanRows + ErrorRows
RETURN
DIVIDE(CleanRows, TotalRows, 0)
4. Data Quality MoM Issue Variance
A data governance tracking metric that measures the month-over-month percentage change in isolated records to alert engineers to deteriorating source data streams.

Code snippet
DQ MoM Issue Variance = 
VAR CurrentMonthIssues = [Total DQ Issues]
VAR PreviousMonthIssues = 
    CALCULATE(
        [Total DQ Issues], 
        DATEADD(DimDate[FullDate], -1, MONTH)
    )
RETURN
DIVIDE(CurrentMonthIssues - PreviousMonthIssues, PreviousMonthIssues, 0)
5. Rolling 30-Day Clean Revenue Trend
A moving calculation used to monitor revenue stability exclusively from validated records, filtering out short-term operational data shocks.

Code snippet
Rolling 30D Clean Revenue = 
CALCULATE(
    [Total Revenue],
    DATESINPERIOD(
        DimDate[FullDate],
        MAX(DimDate[FullDate]),
        -30,
        DAY
    )
)
6. Customer Cohort Dynamic LTV (Clean Data)
An analytical behavior calculation that determines dynamic customer Lifetime Value exclusively from verified accounts, allowing marketing teams to analyze spending cohorts without data distortion.

Code snippet
Customer Cohort Dynamic LTV = 
CALCULATE(
    [Total Revenue],
    FILTER(
        ALLSELECTED(DimCustomer),
        DimCustomer[CustomerFirstPurchaseDate] <= MAX(DimDate[FullDate])
    )
)
