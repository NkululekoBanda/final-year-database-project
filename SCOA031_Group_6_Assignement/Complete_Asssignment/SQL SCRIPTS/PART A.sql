
-- PART A: STORED PROCEDURES (DATABASE AUTOMATION)


USE AdventureWorks2022;
GO

-- SECTION 1: DATA MANAGEMENT PROCEDURES



IF OBJECT_ID('dbo.usp_AddNewCustomer', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_AddNewCustomer;
GO

CREATE PROCEDURE dbo.usp_AddNewCustomer
    @FirstName      VARCHAR(50),           
    @LastName       VARCHAR(50),          
    @EmailAddress   VARCHAR(50),           
    @Phone          VARCHAR(25),           
    @AddressLine1   VARCHAR(60),           
    @City           VARCHAR(30),           
    @StateProvince  VARCHAR(50),          
    @PostalCode     VARCHAR(15),           
    @CountryRegion  VARCHAR(3) = N'US'
AS
BEGIN
    SET NOCOUNT ON;

    IF LTRIM(RTRIM(ISNULL(@FirstName, ''))) = ''
    BEGIN
        RAISERROR('FirstName cannot be empty.', 16, 1);
        RETURN;
    END

    IF LTRIM(RTRIM(ISNULL(@LastName, ''))) = ''
    BEGIN
        RAISERROR('LastName cannot be empty.', 16, 1);
        RETURN;
    END

    IF ISNULL(@EmailAddress,'') = '' OR @EmailAddress NOT LIKE '%@%.%'
    BEGIN
        RAISERROR('A valid EmailAddress is required (must contain @ and a dot).', 16, 1);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM Person.EmailAddress WHERE EmailAddress = @EmailAddress)
    BEGIN
        RAISERROR('A person with email ''%s'' already exists.', 16, 1, @EmailAddress);
        RETURN;
    END

    IF LTRIM(RTRIM(ISNULL(@AddressLine1, ''))) = ''
    BEGIN
        RAISERROR('AddressLine1 cannot be empty.', 16, 1);
        RETURN;
    END

    DECLARE @StateProvinceID INT;
    SELECT  @StateProvinceID = StateProvinceID
    FROM    Person.StateProvince
    WHERE   Name                = @StateProvince
      AND   CountryRegionCode   = @CountryRegion;

    IF @StateProvinceID IS NULL
    BEGIN
        RAISERROR('StateProvince "%s" not found for CountryRegion "%s". Run: SELECT Name, CountryRegionCode FROM Person.StateProvince ORDER BY Name to see valid values.', 16, 1, @StateProvince, @CountryRegion);
        RETURN;
    END

    DECLARE @AddressTypeID INT;
    SELECT  @AddressTypeID = AddressTypeID
    FROM    Person.AddressType
    WHERE   Name = N'Home';

    IF @AddressTypeID IS NULL
    BEGIN
        RAISERROR('"Home" not found in Person.AddressType.', 16, 1);
        RETURN;
    END

    DECLARE @PhoneTypeID INT;
    SELECT  @PhoneTypeID = PhoneNumberTypeID
    FROM    Person.PhoneNumberType
    WHERE   Name = N'Cell';

    IF @PhoneTypeID IS NULL
    BEGIN
        SELECT TOP 1 @PhoneTypeID = PhoneNumberTypeID
        FROM   Person.PhoneNumberType
        ORDER  BY PhoneNumberTypeID;
    END

    DECLARE @BusinessEntityID INT;
    DECLARE @AddressID        INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Person.BusinessEntity (rowguid, ModifiedDate)
        VALUES (NEWID(), GETDATE());
        SET @BusinessEntityID = SCOPE_IDENTITY();

        INSERT INTO Person.Person
            (BusinessEntityID, PersonType, NameStyle,
             FirstName, LastName, EmailPromotion, rowguid, ModifiedDate)
        VALUES
            (@BusinessEntityID, 'IN', 0,
             @FirstName, @LastName, 0, NEWID(), GETDATE());


        INSERT INTO Person.EmailAddress
            (BusinessEntityID, EmailAddress, rowguid, ModifiedDate)
        VALUES
            (@BusinessEntityID, @EmailAddress, NEWID(), GETDATE());

        INSERT INTO Person.PersonPhone
            (BusinessEntityID, PhoneNumber, PhoneNumberTypeID, ModifiedDate)
        VALUES
            (@BusinessEntityID, @Phone, @PhoneTypeID, GETDATE());

        INSERT INTO Person.Address
            (AddressLine1, City, StateProvinceID, PostalCode, rowguid, ModifiedDate)
        VALUES
            (@AddressLine1, @City, @StateProvinceID, @PostalCode, NEWID(), GETDATE());
        SET @AddressID = SCOPE_IDENTITY();

        INSERT INTO Person.BusinessEntityAddress
            (BusinessEntityID, AddressID, AddressTypeID, rowguid, ModifiedDate)
        VALUES
            (@BusinessEntityID, @AddressID, @AddressTypeID, NEWID(), GETDATE());


        INSERT INTO Sales.Customer
            (PersonID, StoreID, TerritoryID, rowguid, ModifiedDate)
        VALUES
            (@BusinessEntityID, NULL, NULL, NEWID(), GETDATE());

        DECLARE @RecordID VARCHAR(20) = CAST(SCOPE_IDENTITY() AS VARCHAR(20));

        COMMIT TRANSACTION;

        SELECT
            c.CustomerID,
            p.FirstName,
            p.LastName,
            ea.EmailAddress     AS Email,
            pp.PhoneNumber      AS Phone,
            a.AddressLine1,
            a.City,
            a.PostalCode
        FROM  Sales.Customer              c
        JOIN  Person.Person               p   ON p.BusinessEntityID  = c.PersonID
        JOIN  Person.EmailAddress         ea  ON ea.BusinessEntityID = c.PersonID
        JOIN  Person.PersonPhone          pp  ON pp.BusinessEntityID = c.PersonID
        JOIN  Person.BusinessEntityAddress bea ON bea.BusinessEntityID = c.PersonID
        JOIN  Person.Address              a   ON a.AddressID         = bea.AddressID
        WHERE c.PersonID = @BusinessEntityID;

        PRINT 'SUCCESS: Customer created. RecordID (CustomerID) = ' + ISNULL(@RecordID, 'Unknown')
              + ' | BusinessEntityID = ' + CAST(ISNULL(@BusinessEntityID, 0) AS VARCHAR(10));

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();
        RAISERROR('usp_AddNewCustomer failed: %s', @ErrSev, @ErrState, @ErrMsg);
    END CATCH;
END;
GO



-- 1.2  usp_UpdateProductPrice
--      Updates for Production.Product.ListPrice (money column).

IF OBJECT_ID('dbo.usp_UpdateProductPrice', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_UpdateProductPrice;
GO

CREATE PROCEDURE dbo.usp_UpdateProductPrice
    @ProductID    INT           = NULL, 
    @ProductName  NVARCHAR(50)  = NULL,  
    @NewPrice     MONEY                  
AS
BEGIN
    SET NOCOUNT ON;

    -- ---- Input Validation ----
    IF @ProductID IS NULL AND LTRIM(RTRIM(ISNULL(@ProductName,''))) = ''
    BEGIN
        RAISERROR('Supply either @ProductID or @ProductName.', 16, 1);
        RETURN;
    END

    IF ISNULL(@NewPrice, -1) < 0
    BEGIN
        RAISERROR('@NewPrice must be zero or a positive value.', 16, 1);
        RETURN;
    END

    IF @ProductID IS NULL
    BEGIN
        SELECT @ProductID = ProductID
        FROM   Production.Product
        WHERE  Name = @ProductName;

        IF @ProductID IS NULL
        BEGIN
            RAISERROR('Product "%s" not found in Production.Product.', 16, 1, @ProductName);
            RETURN;
        END
    END
    ELSE
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM Production.Product WHERE ProductID = @ProductID)
        BEGIN
            RAISERROR('ProductID %d not found in Production.Product.', 16, 1, @ProductID);
            RETURN;
        END
    END

    DECLARE @RecordID VARCHAR(20) = CAST(@ProductID AS VARCHAR(20));

    DECLARE @CurrentPrice MONEY;
    SELECT  @CurrentPrice = ListPrice
    FROM    Production.Product
    WHERE   ProductID = @ProductID;

    IF @CurrentPrice = @NewPrice
    BEGIN
        DECLARE @NewPriceStr NVARCHAR(50) = CAST(@NewPrice AS NVARCHAR(50));
        RAISERROR('New price (%s) is the same as the current price. No update performed.', 16, 1, @NewPriceStr);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE Production.Product
        SET    ListPrice    = @NewPrice,
               ModifiedDate = GETDATE()
        WHERE  ProductID    = @ProductID;

        COMMIT TRANSACTION;

        SELECT
            ProductID,
            Name,
            @CurrentPrice AS OldListPrice,
            ListPrice     AS NewListPrice,
            ModifiedDate
        FROM Production.Product
        WHERE ProductID = @ProductID;

        PRINT 'SUCCESS: Price updated for RecordID (ProductID) '
              + @RecordID
              + '  |  Old: ' + CAST(@CurrentPrice AS VARCHAR(20))
              + '  ->  New: ' + CAST(@NewPrice AS VARCHAR(20));

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();
        RAISERROR('usp_UpdateProductPrice failed: %s', @ErrSev, @ErrState, @ErrMsg);
    END CATCH;
END;
GO


-- Creating archive table
IF OBJECT_ID('Sales.CustomerArchive', 'U') IS NULL
BEGIN
    CREATE TABLE Sales.CustomerArchive
    (
        ArchiveID      INT           IDENTITY(1,1) PRIMARY KEY,
        CustomerID     INT           NOT NULL,
        PersonID       INT           NULL,
        StoreID        INT           NULL,
        TerritoryID    INT           NULL,
        AccountNumber  VARCHAR(10)  NULL,
        ArchivedBy     VARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
        ArchivedDate   DATETIME      NOT NULL DEFAULT GETDATE(),
        ArchiveReason  VARCHAR(255) NULL
    );
    PRINT 'Sales.CustomerArchive table created.';
END
GO

IF OBJECT_ID('dbo.usp_ArchiveInactiveCustomers', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_ArchiveInactiveCustomers;
GO

CREATE PROCEDURE dbo.usp_ArchiveInactiveCustomers
    @MonthsInactive INT = 36,
    @PreviewOnly    BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @MonthsInactive < 1
    BEGIN
        RAISERROR('@MonthsInactive must be >= 1.', 16, 1);
        RETURN;
    END

    DECLARE @CutoffDate DATETIME = DATEADD(MONTH, -@MonthsInactive, GETDATE());

    SELECT
        c.CustomerID,
        p.FirstName,
        p.LastName,
        MAX(soh.OrderDate) AS LastOrderDate,
        CASE
            WHEN MAX(soh.OrderDate) IS NULL
                THEN 'Never ordered'
            ELSE CAST(DATEDIFF(MONTH, MAX(soh.OrderDate), GETDATE()) AS VARCHAR(10))
                 + ' months ago'
        END AS InactivityNote
    FROM  Sales.Customer              c
    LEFT  JOIN Person.Person          p   ON p.BusinessEntityID = c.PersonID
    LEFT  JOIN Sales.SalesOrderHeader soh ON soh.CustomerID     = c.CustomerID
    GROUP BY c.CustomerID, p.FirstName, p.LastName
    HAVING MAX(soh.OrderDate) < @CutoffDate
        OR MAX(soh.OrderDate) IS NULL
    ORDER BY LastOrderDate;

    IF @PreviewOnly = 1
    BEGIN
        PRINT 'PREVIEW MODE: No changes made. Set @PreviewOnly = 0 to archive.';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO Sales.CustomerArchive
            (CustomerID, PersonID, StoreID, TerritoryID, AccountNumber,
             ArchivedBy, ArchivedDate, ArchiveReason)
        SELECT
            c.CustomerID,
            c.PersonID,
            c.StoreID,
            c.TerritoryID,
            c.AccountNumber,
            SUSER_SNAME(),
            GETDATE(),
            'Inactive for over ' + CAST(@MonthsInactive AS VARCHAR(10)) + ' months'
        FROM  Sales.Customer              c
        LEFT  JOIN Sales.SalesOrderHeader soh ON soh.CustomerID = c.CustomerID
        GROUP BY c.CustomerID, c.PersonID, c.StoreID, c.TerritoryID, c.AccountNumber
        HAVING MAX(soh.OrderDate) < @CutoffDate
            OR MAX(soh.OrderDate) IS NULL;

        DECLARE @ArchivedCount INT = @@ROWCOUNT;

        DELETE FROM Sales.Customer
        WHERE  CustomerID IN (SELECT CustomerID FROM Sales.CustomerArchive);

        DECLARE @DeletedCount INT = @@ROWCOUNT;

        COMMIT TRANSACTION;

        PRINT 'SUCCESS: '
              + CAST(@ArchivedCount AS VARCHAR(10)) + ' customers archived, '
              + CAST(@DeletedCount  AS VARCHAR(10)) + ' deleted.';

        SELECT @ArchivedCount AS CustomersArchived,
               @DeletedCount  AS CustomersDeleted;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        DECLARE @ErrMsg   NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrSev   INT            = ERROR_SEVERITY();
        DECLARE @ErrState INT            = ERROR_STATE();
        RAISERROR('usp_ArchiveInactiveCustomers failed: %s', @ErrSev, @ErrState, @ErrMsg);
    END CATCH;
END;
GO

-- SECTION 2: REPORTING PROCEDURES

-- 2.1  usp_MonthlySalesReport
IF OBJECT_ID('dbo.usp_MonthlySalesReport', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_MonthlySalesReport;
GO

CREATE PROCEDURE dbo.usp_MonthlySalesReport
    @StartDate DATE = NULL,
    @EndDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @StartDate IS NULL SET @StartDate = DATEFROMPARTS(YEAR(GETDATE()), 1, 1);
    IF @EndDate   IS NULL SET @EndDate   = CAST(GETDATE() AS DATE);

    IF @StartDate > @EndDate
    BEGIN
        RAISERROR('@StartDate cannot be later than @EndDate.', 16, 1);
        RETURN;
    END

    SELECT
        YEAR(soh.OrderDate)                      AS SalesYear,
        MONTH(soh.OrderDate)                     AS SalesMonth,
        DATENAME(MONTH, soh.OrderDate)           AS MonthName,
        COUNT(DISTINCT soh.SalesOrderID)         AS TotalOrders,
        COUNT(DISTINCT soh.CustomerID)           AS UniqueCustomers,
        SUM(soh.SubTotal)                        AS TotalSubTotal,
        SUM(soh.TaxAmt)                          AS TotalTax,
        SUM(soh.Freight)                         AS TotalFreight,
        SUM(soh.TotalDue)                        AS TotalRevenue,
        AVG(soh.TotalDue)                        AS AvgOrderValue,
        SUM(sod.OrderQty)                        AS TotalUnitsSold
    FROM  Sales.SalesOrderHeader  soh
    JOIN  Sales.SalesOrderDetail  sod ON sod.SalesOrderID = soh.SalesOrderID
    WHERE soh.OrderDate >= CAST(@StartDate AS DATETIME)
      AND soh.OrderDate <  DATEADD(DAY, 1, CAST(@EndDate AS DATETIME))
    GROUP BY
        YEAR(soh.OrderDate),
        MONTH(soh.OrderDate),
        DATENAME(MONTH, soh.OrderDate)
    ORDER BY SalesYear, SalesMonth;
END;
GO


-- 2.2  usp_Top10BestSellingProducts
IF OBJECT_ID('dbo.usp_Top10BestSellingProducts', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_Top10BestSellingProducts;
GO

CREATE PROCEDURE dbo.usp_Top10BestSellingProducts
    @StartDate DATE = NULL,
    @EndDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @StartDate IS NULL SET @StartDate = DATEFROMPARTS(YEAR(GETDATE()), 1, 1);
    IF @EndDate   IS NULL SET @EndDate   = CAST(GETDATE() AS DATE);

    IF @StartDate > @EndDate
    BEGIN
        RAISERROR('@StartDate cannot be later than @EndDate.', 16, 1);
        RETURN;
    END

    SELECT TOP 10
        p.ProductID,
        p.Name                                  AS ProductName,
        pc.Name                                 AS Category,
        psc.Name                                AS SubCategory,
        SUM(sod.OrderQty)                       AS TotalUnitsSold,
        SUM(sod.LineTotal)                      AS TotalRevenue,
        AVG(sod.UnitPrice)                      AS AvgSellingPrice,
        p.ListPrice,
        COUNT(DISTINCT soh.SalesOrderID)        AS TimesOrdered
    FROM  Sales.SalesOrderDetail             sod
    JOIN  Sales.SalesOrderHeader             soh  ON soh.SalesOrderID        = sod.SalesOrderID
    JOIN  Production.Product                 p    ON p.ProductID              = sod.ProductID
    LEFT  JOIN Production.ProductSubcategory psc  ON psc.ProductSubcategoryID = p.ProductSubcategoryID
    LEFT  JOIN Production.ProductCategory    pc   ON pc.ProductCategoryID     = psc.ProductCategoryID
    WHERE soh.OrderDate >= CAST(@StartDate AS DATETIME)
      AND soh.OrderDate <  DATEADD(DAY, 1, CAST(@EndDate AS DATETIME))
    GROUP BY
        p.ProductID, p.Name, pc.Name, psc.Name, p.ListPrice
    ORDER BY TotalUnitsSold DESC;
END;
GO


-- 2.3  usp_EmployeePerformanceSummary
IF OBJECT_ID('dbo.usp_EmployeePerformanceSummary', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_EmployeePerformanceSummary;
GO

CREATE PROCEDURE dbo.usp_EmployeePerformanceSummary
    @StartDate DATE = NULL,
    @EndDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @StartDate IS NULL SET @StartDate = DATEFROMPARTS(YEAR(GETDATE()), 1, 1);
    IF @EndDate   IS NULL SET @EndDate   = CAST(GETDATE() AS DATE);

    IF @StartDate > @EndDate
    BEGIN
        RAISERROR('@StartDate cannot be later than @EndDate.', 16, 1);
        RETURN;
    END

    SELECT
        sp.BusinessEntityID                                          AS SalesPersonID,
        p.FirstName + ' ' + p.LastName                              AS FullName,
        e.JobTitle,
        st.Name                                                      AS SalesTerritory,
        COUNT(DISTINCT soh.SalesOrderID)                             AS TotalOrders,
        COUNT(DISTINCT soh.CustomerID)                               AS UniqueCustomers,
        ISNULL(SUM(soh.TotalDue), 0)                                 AS TotalSales,
        ISNULL(AVG(soh.TotalDue), 0)                                 AS AvgOrderValue,
        sp.SalesQuota,
        CASE
            WHEN ISNULL(sp.SalesQuota, 0) = 0 THEN NULL
            ELSE CAST(ISNULL(SUM(soh.TotalDue), 0)
                      / sp.SalesQuota * 100 AS DECIMAL(10, 2))
        END                                                          AS QuotaAttainmentPct,
        RANK() OVER (ORDER BY ISNULL(SUM(soh.TotalDue), 0) DESC)    AS SalesRank
    FROM  Sales.SalesPerson           sp
    JOIN  Person.Person               p   ON p.BusinessEntityID  = sp.BusinessEntityID
    JOIN  HumanResources.Employee     e   ON e.BusinessEntityID  = sp.BusinessEntityID
    LEFT  JOIN Sales.SalesTerritory   st  ON st.TerritoryID      = sp.TerritoryID
    LEFT  JOIN Sales.SalesOrderHeader soh ON soh.SalesPersonID   = sp.BusinessEntityID
                                         AND soh.OrderDate >= CAST(@StartDate AS DATETIME)
                                         AND soh.OrderDate <  DATEADD(DAY, 1, CAST(@EndDate AS DATETIME))
    GROUP BY
        sp.BusinessEntityID, p.FirstName, p.LastName,
        e.JobTitle, st.Name, sp.SalesQuota
    ORDER BY TotalSales DESC;
END;
GO

-- Add a new customer 
EXEC dbo.usp_AddNewCustomer
    @FirstName     = N'Tshepho',
    @LastName      = N'Makula',
    @EmailAddress  = N'tshepomakola22@gmail.comn',
    @Phone         = N'069-260-6618',
    @AddressLine1  = N'12 Jacaranda Street',
    @City          = N'Monroe',
    @StateProvince = N'Washington',
    @PostalCode    = N'98272',
    @CountryRegion = N'US';
GO

-- Update price by ProductID
EXEC dbo.usp_UpdateProductPrice
    @ProductID = 708,
    @NewPrice  = 36.99;
GO

-- Update price by ProductName
EXEC dbo.usp_UpdateProductPrice
    @ProductName = N'Sport-100 Helmet, Black',
    @NewPrice    = 34.99;
GO

--Preview inactive customers
EXEC dbo.usp_ArchiveInactiveCustomers
    @MonthsInactive = 36,
    @PreviewOnly    = 1;
GO

--Monthly Sales Report
EXEC dbo.usp_MonthlySalesReport
    @StartDate = '2013-01-01',
    @EndDate   = '2013-12-31';
GO

--Top 10 Best-Selling Products
EXEC dbo.usp_Top10BestSellingProducts
    @StartDate = '2013-01-01',
    @EndDate   = '2013-12-31';
GO

-- Employee Performance Summary
EXEC dbo.usp_EmployeePerformanceSummary
    @StartDate = '2013-01-01',
    @EndDate   = '2013-12-31';
GO