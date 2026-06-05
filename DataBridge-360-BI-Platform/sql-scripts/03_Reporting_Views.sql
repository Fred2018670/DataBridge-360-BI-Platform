-- Executive Reporting Layer (BI Consumption Views)

---------------------------------------------------------------------
-- VIEW: CUSTOMER PERFORMANCE COHORTS
---------------------------------------------------------------------
CREATE VIEW vw_CustomerPerformance AS
SELECT 
    c.CustomerKey,
    c.CustomerName,
    c.Country,
    COUNT(DISTINCT f.OrderID) AS TotalOrders,
    SUM(f.Revenue) AS LifetimeValue,
    SUM(f.Profit) AS TotalProfit,
    CASE 
        WHEN SUM(f.Revenue) > 10000 THEN 'Tier 1 (Enterprise)'
        WHEN SUM(f.Revenue) BETWEEN 2500 AND 10000 THEN 'Tier 2 (Mid-Market)'
        ELSE 'Tier 3 (SMB)'
    END AS CustomerSegment
FROM FactSales f
JOIN DimCustomer c ON f.CustomerKey = c.CustomerKey
GROUP BY c.CustomerKey, c.CustomerName, c.Country;
GO

---------------------------------------------------------------------
-- VIEW: DATA QUALITY RECONCILIATION DASHBOARD SOURCE
---------------------------------------------------------------------
CREATE VIEW vw_DataQualityDashboard AS
SELECT 
    TableName,
    RuleViolated,
    COUNT(*) AS TotalViolations,
    CAST(DetectedDate AS DATE) AS EvaluationDate
FROM DataQualityIssues
GROUP BY TableName, RuleViolated, CAST(DetectedDate AS DATE);
GO
