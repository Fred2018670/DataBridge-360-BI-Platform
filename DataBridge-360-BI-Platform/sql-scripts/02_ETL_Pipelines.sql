-- Customer Pileline & Validation Engine

CREATE PROCEDURE usp_Load_Customers
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RunID INT;
    DECLARE @Processed INT = 0;
    DECLARE @Rejected INT = 0;

    -- Initialize Log Entry
    INSERT INTO ETL_RunLog (ProcedureName, Status) VALUES ('usp_Load_Customers', 'RUNNING');
    SET @RunID = SCOPE_IDENTITY();

    BEGIN TRY
        -----------------------------------------------------------------
        -- STEP 1: Clean & Standardize into Staging
        -----------------------------------------------------------------
        TRUNCATE TABLE stg_Customers;

        INSERT INTO stg_Customers (CustomerID, Clean_Name, Clean_Phone, Clean_Email, Country)
        SELECT 
            TRY_CAST(Raw_CustomerID AS INT),
            UPPER(LTRIM(RTRIM(Raw_Name))),
            -- Standardize Phone formats to '254...'
            CASE 
                WHEN LTRIM(RTRIM(Raw_Phone)) LIKE '07%' THEN '254' + SUBSTRING(LTRIM(RTRIM(Raw_Phone)), 2, 20)
                WHEN LTRIM(RTRIM(Raw_Phone)) LIKE '+%' THEN REPLACE(LTRIM(RTRIM(Raw_Phone)), '+', '')
                ELSE LTRIM(RTRIM(Raw_Phone))
            END,
            LOWER(LTRIM(RTRIM(Raw_Email))),
            COALESCE(LTRIM(RTRIM(Raw_Country)), 'Unknown')
        FROM Landing_Customers;

        -----------------------------------------------------------------
        -- STEP 2: Run Data Quality Assessments
        -----------------------------------------------------------------
        
        -- Rule 2 & 3: Missing Emails or Invalid Phone Formats
        INSERT INTO DataQualityIssues (TableName, RecordID, RuleViolated, BadValue)
        SELECT 'stg_Customers', CustomerID, 'Missing or Invalid Email', Clean_Email
        FROM stg_Customers WHERE Clean_Email NOT LIKE '%@%.%' OR Clean_Email IS NULL
        UNION ALL
        SELECT 'stg_Customers', CustomerID, 'Invalid Phone Length', Clean_Phone
        FROM stg_Customers WHERE LEN(Clean_Phone) <> 12;

        -- Rule 1: Deduplicate using ROW_NUMBER() and mark duplicates
        WITH CTE_Dedupe AS (
            SELECT CustomerID, Clean_Name,
                   ROW_NUMBER() OVER(PARTITION BY Clean_Name ORDER BY CustomerID) as RowNum
            FROM stg_Customers
        )
        INSERT INTO DataQualityIssues (TableName, RecordID, RuleViolated, BadValue)
        SELECT 'stg_Customers', CustomerID, 'Duplicate Customer Name Identity', Clean_Name
        FROM CTE_Dedupe WHERE RowNum > 1;

        -----------------------------------------------------------------
        -- STEP 3: Load clean records to DimCustomer
        -----------------------------------------------------------------
        -- Records are rejected from production if they hold fatal issues (like duplicates or invalid keys)
        INSERT INTO DimCustomer (SourceCustomerID, CustomerName, Phone, Email, Country)
        SELECT s.CustomerID, s.Clean_Name, s.Clean_Phone, s.Clean_Email, s.Country
        FROM stg_Customers s
        WHERE s.CustomerID IS NOT NULL
          AND s.CustomerID NOT IN (SELECT TRY_CAST(RecordID AS INT) FROM DataQualityIssues WHERE TableName = 'stg_Customers')
          AND NOT EXISTS (SELECT 1 FROM DimCustomer dc WHERE dc.SourceCustomerID = s.CustomerID);

        -- Metric tracking for logging
        SELECT @Processed = COUNT(*) FROM stg_Customers;
        SELECT @Rejected = COUNT(DISTINCT RecordID) FROM DataQualityIssues WHERE TableName = 'stg_Customers';

        -- Finalize Run Log Entry
        UPDATE ETL_RunLog 
        SET Status = 'SUCCESS',
            RowsProcessed = @Processed,
            RowsRejected = @Rejected,
            DurationSeconds = DATEDIFF(SECOND, @StartTime, GETDATE())
        WHERE RunID = @RunID;

    END TRY
    BEGIN CATCH
        -- Capture systemic execution failures
        UPDATE ETL_RunLog SET Status = 'FAILED', DurationSeconds = DATEDIFF(SECOND, @StartTime, GETDATE()) WHERE RunID = @RunID;
        
        INSERT INTO ETL_ErrorLog (RunID, ErrorType, ErrorMessage, TableName)
        VALUES (@RunID, 'SQL_EXCEPTION', ERROR_MESSAGE(), 'stg_Customers');
    END CATCH
END;
GO

