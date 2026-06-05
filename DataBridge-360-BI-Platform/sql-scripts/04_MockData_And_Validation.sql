/*
====================================================================
PROJECT: DataBridge 360
SCRIPT:  04_MockData_and_Validation.sql
PURPOSE: Populates the Calendar Dimension, simulates real-world 
         corrupt raw data, runs the pipeline, and verifies integrity.
====================================================================
*/

USE DataBridge360;
GO

--------------------------------------------------------------------
-- 1. POPULATE THE CALENDAR DIMENSION (Bypassing FK Blocks)
--------------------------------------------------------------------
PRINT 'Populating DimDate...';
DECLARE @StartDate DATE = '2020-01-01';
DECLARE @EndDate DATE = '2030-12-31';

-- Delete allows us to clear data row-by-row without breaking FK constraints
DELETE FROM DimDate;

WHILE @StartDate <= @EndDate
BEGIN
    INSERT INTO DimDate (DateKey, FullDate, CalendarYear, CalendarQuarter, MonthName, MonthNumberOfYear)
    VALUES (
        CAST(CONVERT(VARCHAR(8), @StartDate, 112) AS INT),
        @StartDate,
        YEAR(@StartDate),
        DATEPART(QUARTER, @StartDate),
        DATENAME(MONTH, @StartDate),
        MONTH(@StartDate)
    );
    SET @StartDate = DATEADD(DAY, 1, @StartDate);
END;
GO

--------------------------------------------------------------------
-- 2. LOAD RAW "MESSY" DATA INTO LANDING TABLES
--------------------------------------------------------------------
PRINT 'Loading messy landing data...';
TRUNCATE TABLE Landing_Customers;
TRUNCATE TABLE Landing_Products;
TRUNCATE TABLE Landing_Sales;
GO

INSERT INTO Landing_Customers (Raw_CustomerID, Raw_Name, Raw_Phone, Raw_Email, Raw_Country)
VALUES 
('1001', 'John Kamau', '0712345678', 'john.k@gmail.com', 'Kenya'),
('1002', 'John K Kamau', '+254712345678', 'john.k@gmail.com', 'Kenya'),
('1003', 'J. Kamau', '254712345678', 'johngmail.com', 'KE'),
('1004', '  Alice Mwangi  ', '0722999888', 'alice@mwangi.co.ke', 'Kenya'),
('1005', 'Bob Smith', '12345', NULL, 'USA'),
('1006', 'Njeri Korir', '+254 733 111 222', 'njeri@korir.com', NULL);

INSERT INTO Landing_Products (Raw_ProductID, Raw_ProductName, Raw_Category, Raw_Price)
VALUES 
('201', 'Paracetamol 500mg', 'Pharmaceuticals', '5.50'),
('202', 'Paracetamol-500 MG', 'Pharmaceuticals', '5.50'),
('203', 'Paracetamol 500 MG', 'Pharma', '6.00'),
('204', 'Amoxicillin 250mg', NULL, '12.00'),
('205', 'Broken Widget', 'Hardware', '-10.50');

INSERT INTO Landing_Sales (Raw_OrderID, Raw_CustomerID, Raw_ProductID, Raw_SaleDate, Raw_Quantity, Raw_Price)
VALUES 
('9001', '1001', '201', '2026-06-01', '2', '5.50'),
('9002', '1004', '204', '2026-06-02', '1', '12.00'),
('9003', '1005', '201', '2026-06-02', '-5', '5.50'),   
('9004', '1002', '205', '2029-12-25', '1', '-10.50'),  
('9005', NULL, '202', '2026-06-03', '10', '5.50');     
GO

--------------------------------------------------------------------
-- 3. RUN EXTRA MANUAL VERIFIED TRANSACTIONS (Step 2 Data Additions)
--------------------------------------------------------------------
PRINT 'Loading verification test records...';
INSERT INTO Landing_Sales (Raw_OrderID, Raw_CustomerID, Raw_ProductID, Raw_SaleDate, Raw_Quantity, Raw_Price)
VALUES 
('9500', '1001', '201', '2026-06-04', '10', '5.50'), 
('9501', '1004', '201', '2026-06-04', '2', '5.50');  
GO

--------------------------------------------------------------------
-- 4. EXECUTE FULL AUTOMATED ETL PIPELINE RUN
--------------------------------------------------------------------
PRINT 'Executing master ETL flow...';
EXEC usp_Refresh_DataWarehouse;
GO

--------------------------------------------------------------------
-- 5. FINAL PRODUCTION HEALTH AUDIT CHECKS
--------------------------------------------------------------------
SELECT 'FactSales Count' AS AuditType, COUNT(*) AS RecordVolume FROM FactSales
UNION ALL
SELECT 'DimCustomer Count', COUNT(*) FROM DimCustomer
UNION ALL
SELECT 'DimProduct Count', COUNT(*) FROM DimProduct
UNION ALL
SELECT 'Logged DQ Violations', COUNT(*) FROM DataQualityIssues;

SELECT * FROM DataQualityIssues;