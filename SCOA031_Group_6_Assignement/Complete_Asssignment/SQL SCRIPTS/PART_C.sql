-- PART C: PERFORMANCE OPTIMIZATION (CORRECTED VERSION)

USE AdventureWorks2022;
GO

-- SECTION 1:
-- Enable statistics to measure improvement
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

-- SECTION 2: CREATE NECESSARY INDEXES (No redundant ones)

-- INDEX 1: Supports Query 1 (OrderDate range) & Query 4 (Customer grouping)
-- Allows index seek on OrderDate; includes all extra columns needed.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesOrderHeader_OrderDate_TotalDue' AND object_id = OBJECT_ID('Sales.SalesOrderHeader'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_SalesOrderHeader_OrderDate_TotalDue
    ON Sales.SalesOrderHeader (OrderDate ASC)
    INCLUDE (CustomerID, TotalDue);
    PRINT 'INDEX CREATED: IX_SalesOrderHeader_OrderDate_TotalDue';
END
ELSE
    PRINT 'INDEX ALREADY EXISTS: IX_SalesOrderHeader_OrderDate_TotalDue';
GO

-- INDEX 2: Supports Query 2 (Product name prefix + ListPrice)
-- Leading column Name allows seek on 'Mountain%'
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Product_Name_ListPrice' AND object_id = OBJECT_ID('Production.Product'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Product_Name_ListPrice
    ON Production.Product (Name ASC, ListPrice ASC)
    INCLUDE (ProductID, StandardCost, ProductSubcategoryID);
    PRINT 'INDEX CREATED: IX_Product_Name_ListPrice';
END
ELSE
    PRINT 'INDEX ALREADY EXISTS: IX_Product_Name_ListPrice';
GO

-- INDEX 3: Supports Query 3 (Sales per person + date filter)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesOrderHeader_SalesPersonID_OrderDate' AND object_id = OBJECT_ID('Sales.SalesOrderHeader'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_SalesOrderHeader_SalesPersonID_OrderDate
    ON Sales.SalesOrderHeader (SalesPersonID ASC, OrderDate ASC)
    INCLUDE (SalesOrderID, TotalDue);
    PRINT 'INDEX CREATED: IX_SalesOrderHeader_SalesPersonID_OrderDate';
END
ELSE
    PRINT 'INDEX ALREADY EXISTS: IX_SalesOrderHeader_SalesPersonID_OrderDate';
GO

-- INDEX 4: Supports Query 4 (Customer purchase aggregation) – originally missing
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesOrderHeader_CustomerID' AND object_id = OBJECT_ID('Sales.SalesOrderHeader'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_SalesOrderHeader_CustomerID
    ON Sales.SalesOrderHeader (CustomerID ASC)
    INCLUDE (OrderDate, TotalDue, SalesOrderID);
    PRINT 'INDEX CREATED: IX_SalesOrderHeader_CustomerID';
END
ELSE
    PRINT 'INDEX ALREADY EXISTS: IX_SalesOrderHeader_CustomerID';
GO

-- Remove redundant indexes (they duplicate clustered keys or offer no benefit)
DROP INDEX IF EXISTS IX_Customer_CustomerID_PersonID ON Sales.Customer;
DROP INDEX IF EXISTS IX_Person_BusinessEntityID_Name ON Person.Person;
PRINT 'Redundant indexes dropped.';
GO

-- OPTIMIZED QUERY 1: Sales orders by date range
SELECT 
    soh.SalesOrderID,
    soh.OrderDate,
    soh.TotalDue,
    c.AccountNumber,
    p.FirstName,
    p.LastName
FROM Sales.SalesOrderHeader soh
INNER JOIN Sales.Customer c ON soh.CustomerID = c.CustomerID
INNER JOIN Person.Person p ON c.PersonID = p.BusinessEntityID
WHERE soh.OrderDate >= '2013-01-01'
  AND soh.OrderDate <  '2014-01-01'   
ORDER BY soh.TotalDue DESC;
GO

-- OPTIMIZED QUERY 2: Product search
SELECT 
    p.ProductID,
    p.Name,
    p.ListPrice,
    p.StandardCost,
    ps.Name AS SubcategoryName,
    pc.Name AS CategoryName
FROM Production.Product p
LEFT JOIN Production.ProductSubcategory ps ON p.ProductSubcategoryID = ps.ProductSubcategoryID
LEFT JOIN Production.ProductCategory pc   ON ps.ProductCategoryID = pc.ProductCategoryID
WHERE p.ListPrice > 100
  AND p.Name LIKE 'Mountain%'
ORDER BY p.ListPrice DESC;
GO

-- OPTIMIZED QUERY 3: Employee sales performance
SELECT 
    sp.BusinessEntityID,
    p.FirstName,
    p.LastName,
    sp.SalesQuota,
    sp.SalesYTD,
    sp.SalesLastYear,
    agg.TotalOrders,
    agg.TotalRevenue
FROM Sales.SalesPerson sp
INNER JOIN Person.Person p ON sp.BusinessEntityID = p.BusinessEntityID
INNER JOIN (
    SELECT 
        SalesPersonID,
        COUNT(SalesOrderID) AS TotalOrders,
        SUM(TotalDue)       AS TotalRevenue
    FROM Sales.SalesOrderHeader
    WHERE OrderDate >= '2012-01-01'
      AND SalesPersonID IS NOT NULL
    GROUP BY SalesPersonID
) agg ON sp.BusinessEntityID = agg.SalesPersonID
ORDER BY agg.TotalRevenue DESC;
GO

-- OPTIMIZED QUERY 4: Customer purchase history
-- Changes: Pre-filter aggregates before joining Person table
WITH CustomerOrders AS (
    SELECT 
        soh.CustomerID,
        COUNT(soh.SalesOrderID) AS NumberOfOrders,
        SUM(soh.TotalDue)       AS TotalSpent,
        MAX(soh.OrderDate)      AS LastOrderDate
    FROM Sales.SalesOrderHeader soh
    GROUP BY soh.CustomerID
    HAVING COUNT(soh.SalesOrderID) > 2
)
SELECT 
    c.CustomerID,
    p.FirstName,
    p.LastName,
    co.NumberOfOrders,
    co.TotalSpent,
    co.LastOrderDate
FROM CustomerOrders co
INNER JOIN Sales.Customer c ON co.CustomerID = c.CustomerID
INNER JOIN Person.Person p  ON c.PersonID = p.BusinessEntityID
ORDER BY co.TotalSpent DESC;
GO

-- SECTION 4: MONITORING STORED PROCEDURES (FIXED)
-- PROC 1: Detect Long‑Running Queries
IF OBJECT_ID('dbo.usp_DetectLongRunningQueries', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_DetectLongRunningQueries;
GO

CREATE PROCEDURE dbo.usp_DetectLongRunningQueries
    @ThresholdSeconds INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        r.session_id                                          AS SessionID,
        r.status,
        r.command                                             AS CommandType,
        r.cpu_time / 1000000.0                                AS CPU_Seconds,
        r.total_elapsed_time / 1000000.0                      AS Elapsed_Seconds,
        r.logical_reads,
        r.writes,
        DB_NAME(r.database_id)                                AS DatabaseName,
        s.login_name,
        s.host_name,
        SUBSTRING(qt.text, (r.statement_start_offset/2)+1,
            (CASE WHEN r.statement_end_offset = -1 THEN DATALENGTH(qt.text)
                  ELSE r.statement_end_offset END - r.statement_start_offset)/2 + 1
        )                                                     AS QueryText,
        qp.query_plan                                         AS ExecutionPlan
    FROM sys.dm_exec_requests r
    INNER JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) qt
    OUTER APPLY sys.dm_exec_query_plan(r.plan_handle) qp
    WHERE r.session_id <> @@SPID
      AND r.total_elapsed_time / 1000000.0 > @ThresholdSeconds
      AND s.is_user_process = 1
    ORDER BY r.total_elapsed_time DESC;
END;
GO
EXEC dbo.usp_DetectLongRunningQueries;

-- PROC 2: Checking Database Size 
IF OBJECT_ID('dbo.usp_CheckDatabaseSize', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_CheckDatabaseSize;
GO

CREATE PROCEDURE dbo.usp_CheckDatabaseSize
    @DatabaseName NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- Total space summary
    EXEC sp_spaceused;
    SELECT 
        name          AS LogicalFileName,
        physical_name AS PhysicalPath,
        type_desc     AS FileType,
        size * 8 / 1024.0 AS SizeMB,
        FILEPROPERTY(name, 'SpaceUsed') * 8 / 1024.0 AS UsedMB
    FROM sys.database_files
    ORDER BY type, name;
END;
GO

EXEC dbo.usp_CheckDatabaseSize;

-- PROC 3: Monitor Index Fragmentation (added error handling)
IF OBJECT_ID('dbo.usp_MonitorIndexFragmentation', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_MonitorIndexFragmentation;
GO

CREATE PROCEDURE dbo.usp_MonitorIndexFragmentation
    @FragmentationThreshold FLOAT = 10.0,
    @MinPageCount INT = 8
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT 
            DB_NAME()                                           AS DatabaseName,
            OBJECT_SCHEMA_NAME(ips.object_id)                   AS SchemaName,
            OBJECT_NAME(ips.object_id)                          AS TableName,
            i.name                                              AS IndexName,
            CAST(ips.avg_fragmentation_in_percent AS DECIMAL(5,2)) AS FragmentationPercent,
            ips.page_count                                      AS PageCount,
            ips.record_count                                    AS RecordCount,
            CASE 
                WHEN ips.avg_fragmentation_in_percent >= 30 THEN 'REBUILD (ONLINE = ON)'
                WHEN ips.avg_fragmentation_in_percent >= 10 THEN 'REORGANIZE'
                ELSE 'OK'
            END                                                 AS RecommendedAction
        FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
        INNER JOIN sys.indexes i 
            ON ips.object_id = i.object_id AND ips.index_id = i.index_id
        WHERE ips.avg_fragmentation_in_percent > @FragmentationThreshold
          AND ips.page_count > @MinPageCount
          AND ips.index_id > 0
          AND i.is_disabled = 0
        ORDER BY ips.avg_fragmentation_in_percent DESC;
    END TRY
    BEGIN CATCH
        PRINT 'Error in usp_MonitorIndexFragmentation: ' + ERROR_MESSAGE();
    END CATCH
END;
GO

EXEC dbo.usp_MonitorIndexFragmentation;

-- SECTION 5: PERFORMANCE DASHBOARD 
IF OBJECT_ID('dbo.usp_PerformanceDashboard', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_PerformanceDashboard;
GO

CREATE PROCEDURE dbo.usp_PerformanceDashboard
AS
BEGIN
    SET NOCOUNT ON;
    PRINT REPLICATE('=', 50);
    PRINT ' ADVENTUREWORKS PERFORMANCE DASHBOARD';
    PRINT ' Run Date: ' + CONVERT(VARCHAR, GETDATE(), 120);
    PRINT REPLICATE('=', 50);
    
    PRINT CHAR(10) + '--- LONG‑RUNNING QUERIES ---';
    EXEC dbo.usp_DetectLongRunningQueries @ThresholdSeconds = 10;
    
    PRINT CHAR(10) + '--- DATABASE SIZE ---';
    EXEC dbo.usp_CheckDatabaseSize;
    
    PRINT CHAR(10) + '--- INDEX FRAGMENTATION ---';
    EXEC dbo.usp_MonitorIndexFragmentation @FragmentationThreshold = 10, @MinPageCount = 8;
    
    PRINT CHAR(10) + REPLICATE('=', 50);
    PRINT ' DASHBOARD COMPLETE';
    PRINT REPLICATE('=', 50);
END;
GO
EXEC dbo.usp_PerformanceDashboard;
-- SECTION 6: INDEX USAGE STATISTICS (After optimizations)
SELECT 
    OBJECT_SCHEMA_NAME(i.object_id) + '.' + OBJECT_NAME(i.object_id) AS TableName,
    i.name                           AS IndexName,
    i.type_desc                      AS IndexType,
    ius.user_seeks,
    ius.user_scans,
    ius.user_lookups,
    ius.user_updates,
    ius.last_user_seek,
    ius.last_user_scan
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats ius 
    ON i.object_id = ius.object_id 
   AND i.index_id = ius.index_id 
   AND ius.database_id = DB_ID()
WHERE i.name IN (
    'IX_SalesOrderHeader_OrderDate_TotalDue',
    'IX_Product_Name_ListPrice',
    'IX_SalesOrderHeader_SalesPersonID_OrderDate',
    'IX_SalesOrderHeader_CustomerID'
)
ORDER BY TableName, IndexName;
GO
