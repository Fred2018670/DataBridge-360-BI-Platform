-- DDL Schema Setup
-- this step creates structure for Landing, Staging and DW Table

CREATE DATABASE DataBridge360;
GO

USE DataBridge360;
GO

-- Phase 2 & 3 are for Landing and Staging Architecture
-- Landing layer holds raw data as received and does initial formarting, trimming and type-casting
---------------------------------------------------------------------
-- PHASE 2: LANDING LAYER (Raw, unvalidated strings)
---------------------------------------------------------------------
CREATE TABLE Landing_Customers (
    Raw_CustomerID VARCHAR(255),
    Raw_Name VARCHAR(255),
    Raw_Phone VARCHAR(255),
    Raw_Email VARCHAR(255),
    Raw_Country VARCHAR(255)
);

CREATE TABLE Landing_Products (
    Raw_ProductID VARCHAR(255),
    Raw_ProductName VARCHAR(255),
    Raw_Category VARCHAR(255),
    Raw_Price VARCHAR(255)
);

CREATE TABLE Landing_Sales (
    Raw_OrderID VARCHAR(255),
    Raw_CustomerID VARCHAR(255),
    Raw_ProductID VARCHAR(255),
    Raw_SaleDate VARCHAR(255),
    Raw_Quantity VARCHAR(255),
    Raw_Price VARCHAR(255)
);

---------------------------------------------------------------------
-- PHASE 3: STAGING LAYER (Standardized types, whitespace removed)
---------------------------------------------------------------------
CREATE TABLE stg_Customers (
    CustomerID INT,
    Clean_Name VARCHAR(150),
    Clean_Phone VARCHAR(50),
    Clean_Email VARCHAR(150),
    Country VARCHAR(100)
);

CREATE TABLE stg_Products (
    ProductID INT,
    Clean_ProductName VARCHAR(150),
    Category VARCHAR(100),
    Standard_Price DECIMAL(18,2)
);

CREATE TABLE stg_Sales (
    OrderID INT,
    CustomerID INT,
    ProductID INT,
    SaleDate DATE,
    Quantity INT,
    UnitPrice DECIMAL(18,2)
);

---------------------------------------------------------------------
-- PHASE 5: AUDIT & ETL LOGGING TABLES
---------------------------------------------------------------------
CREATE TABLE ETL_RunLog (
    RunID INT IDENTITY(1,1) PRIMARY KEY,
    RunDate DATETIME DEFAULT GETDATE(),
    ProcedureName VARCHAR(100),
    RowsProcessed INT,
    RowsRejected INT,
    DurationSeconds INT,
    Status VARCHAR(20) -- 'SUCCESS', 'FAILED'
);

CREATE TABLE ETL_ErrorLog (
    ErrorID INT IDENTITY(1,1) PRIMARY KEY,
    RunID INT,
    ErrorType VARCHAR(50),
    ErrorMessage VARCHAR(MAX),
    TableName VARCHAR(100),
    RecordID VARCHAR(50),
    LogTime DATETIME DEFAULT GETDATE()
);

---------------------------------------------------------------------
-- PHASE 4: DATA QUALITY ISSUES TRACE TABLE
---------------------------------------------------------------------
CREATE TABLE DataQualityIssues (
    IssueID INT IDENTITY(1,1) PRIMARY KEY,
    TableName VARCHAR(100),
    RecordID VARCHAR(50),
    RuleViolated VARCHAR(100),
    BadValue VARCHAR(255),
    DetectedDate DATETIME DEFAULT GETDATE()
);

---------------------------------------------------------------------
-- PHASE 6: DIMENSION TABLES
---------------------------------------------------------------------
CREATE TABLE DimCustomer (
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
    SourceCustomerID INT,
    CustomerName VARCHAR(150),
    Phone VARCHAR(50),
    Email VARCHAR(150),
    Country VARCHAR(100),
    IsActive BIT DEFAULT 1
);

CREATE TABLE DimProduct (
    ProductKey INT IDENTITY(1,1) PRIMARY KEY,
    SourceProductID INT,
    ProductName VARCHAR(150),
    Category VARCHAR(100),
    StandardPrice DECIMAL(18,2)
);

CREATE TABLE DimDate (
    DateKey INT PRIMARY KEY, -- YYYYMMDD
    FullDate DATE,
    CalendarYear INT,
    CalendarQuarter INT,
    MonthNumberOfYear INT,
    MonthName VARCHAR(15)
);

---------------------------------------------------------------------
-- PHASE 7: FACT TABLES
---------------------------------------------------------------------
CREATE TABLE FactSales (
    SalesKey INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT,
    CustomerKey INT FOREIGN KEY REFERENCES DimCustomer(CustomerKey),
    ProductKey INT FOREIGN KEY REFERENCES DimProduct(ProductKey),
    DateKey INT FOREIGN KEY REFERENCES DimDate(DateKey),
    Quantity INT,
    Revenue DECIMAL(18,2),
    Cost DECIMAL(18,2),
    Profit DECIMAL(18,2)
);
