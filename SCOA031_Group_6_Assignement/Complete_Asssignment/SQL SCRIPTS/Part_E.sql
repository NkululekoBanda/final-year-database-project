-- SCOA031 DATABASE ADMINISTRATION PROJECT 2026

USE AdventureWorks2022;
GO

-- TASK 1: CREATING THE AUDIT TABLE
IF OBJECT_ID('dbo.AuditTable', 'U') IS NOT NULL
    DROP TABLE dbo.AuditTable;
GO

CREATE TABLE dbo.AuditTable (
    AuditID     INT IDENTITY(1,1) PRIMARY KEY,
    TableName      VARCHAR(128) NOT NULL,
    ActionType     VARCHAR(10)  NOT NULL, 
    RecordID       VARCHAR(20)  NOT NULL,
    ActionUser     VARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
    ActionDateTime DATETIME      NOT NULL DEFAULT GETDATE(),
    Description    VARCHAR(MAX) NOT NULL
);
GO

PRINT 'AuditTable created successfully.';
GO

-- TASK 4: DATABASE MAIL CONFIGURATION (PREREQUISITE)
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Database Mail XPs', 1;
RECONFIGURE;
GO

IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysmail_profile WHERE name = 'DBA_Alert_Profile')
BEGIN
    EXEC msdb.dbo.sysmail_add_account_sp
        @account_name = 'DBA_Email_Account',
        @description = 'Mail account for Database Alerts',
        @email_address = 'tshepomakola23@gmail.com',
        @display_name = 'AdventureWorks DBA Alerts',
        @mailserver_name = 'smtp.gmail.com',
        @port = 587,
        @enable_ssl = 1,
        @username = 'tshepomakola23@gmail.com',
        @password = 'your_password_here'; 

    EXEC msdb.dbo.sysmail_add_profile_sp
        @profile_name = 'DBA_Alert_Profile',
        @description = 'Profile used for administrative alerts';

    EXEC msdb.dbo.sysmail_add_profileaccount_sp
        @profile_name = 'DBA_Alert_Profile',
        @account_name = 'DBA_Email_Account',
        @sequence_number = 1;
END
GO

-- TASK 2 & 3: TRIGGERS FOR SALES.CUSTOMER

-- Drop legacy triggers from previous scripts to prevent NULL RecordID errors
DROP TRIGGER IF EXISTS Sales.trg_Customer_Audit;
DROP TRIGGER IF EXISTS Sales.trg_Customer_Insert;
DROP TRIGGER IF EXISTS Sales.trg_Customer_Update;
DROP TRIGGER IF EXISTS Sales.trg_Customer_Delete;
GO

-- Drop legacy product triggers
DROP TRIGGER IF EXISTS Production.trg_Product_Audit;
DROP TRIGGER IF EXISTS Production.trg_Product_Insert;
DROP TRIGGER IF EXISTS Production.trg_Product_Update;
GO

CREATE TRIGGER Sales.trg_Customer_Audit
ON Sales.Customer
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Action NVARCHAR(10);
    DECLARE @Desc NVARCHAR(MAX);
    DECLARE @User NVARCHAR(128) = SUSER_NAME();
    DECLARE @Recipients NVARCHAR(MAX) = 'tshepomakola23@gmail.com';
    DECLARE @CurrentDate DATETIME = GETDATE();

    -- Determine Action Type
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        SET @Action = 'UPDATE';
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        SET @Action = 'INSERT';
    ELSE
        SET @Action = 'DELETE';

    -- Logging and Alert Logic
    IF @Action = 'DELETE'
    BEGIN
        INSERT INTO dbo.AuditTable (TableName, ActionType, RecordID, ActionUser, ActionDateTime, Description)
        SELECT 'Sales.Customer', @Action, CAST(d.CustomerID AS NVARCHAR(20)), @User, @CurrentDate,
               'The record that was deleted by ' + @User + ' belong to customer with CustomerId: ' + CAST(d.CustomerID AS VARCHAR(10))
        FROM deleted d;

        -- TASK 4: Sending an Alert for Deletion
        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = 'DBA_Alert_Profile',
                @recipients = @Recipients,
                @subject = 'CRITICAL: Customer Record Deleted',
                @body = 'A customer record has been removed from the system.';
        END TRY
        BEGIN CATCH
            PRINT 'Warning: Could not send email alert for Customer deletion.';
        END CATCH
    END

    IF @Action = 'INSERT'
    BEGIN
        INSERT INTO dbo.AuditTable (TableName, ActionType, RecordID, ActionUser, ActionDateTime, Description)
        SELECT 'Sales.Customer', @Action, CAST(i.CustomerID AS NVARCHAR(20)), @User, @CurrentDate,
               'New customer added with CustomerID: ' + CAST(i.CustomerID AS VARCHAR(10))
        FROM inserted i;
    END

    IF @Action = 'UPDATE'
    BEGIN
        INSERT INTO dbo.AuditTable (TableName, ActionType, RecordID, ActionUser, ActionDateTime, Description)
        SELECT 'Sales.Customer', @Action, CAST(i.CustomerID AS NVARCHAR(20)), @User, @CurrentDate,
               'Customer info updated for CustomerID: ' + CAST(i.CustomerID AS VARCHAR(10))
        FROM inserted i;

        -- TASK 5: Conditional Alert (Sensitive Data: PersonID or AccountNumber modified)
        IF UPDATE(PersonID) --
        BEGIN
            BEGIN TRY
                EXEC msdb.dbo.sp_send_dbmail
                    @profile_name = 'DBA_Alert_Profile',
                    @recipients = @Recipients,
                    @subject = 'SECURITY ALERT: Sensitive Customer Data Modified',
                    @body = 'A critical update occurred: PersonID or AccountNumber was modified.';
            END TRY
            BEGIN CATCH
                PRINT 'Warning: Could not send email alert for sensitive data modification.';
            END CATCH
        END
    END
END;
GO

-- TASK 2 & 3: TRIGGERS FOR PRODUCTION.PRODUCT
CREATE TRIGGER Production.trg_Product_Audit
ON Production.Product
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Action NVARCHAR(10);
    DECLARE @User NVARCHAR(128) = SUSER_NAME();
    DECLARE @Recipients NVARCHAR(MAX) = 'tshepomakola23@gmail.com';
    DECLARE @CurrentDate DATETIME = GETDATE();

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        SET @Action = 'UPDATE';
    ELSE IF EXISTS (SELECT 1 FROM inserted)
        SET @Action = 'INSERT';
    ELSE
        SET @Action = 'DELETE';

    -- DELETE Logic
    IF @Action = 'DELETE'
    BEGIN
        INSERT INTO dbo.AuditTable (TableName, ActionType, RecordID, ActionUser, ActionDateTime, Description)
        SELECT 'Production.Product', @Action, CAST(d.ProductID AS NVARCHAR(20)), @User, @CurrentDate,
               'Product deleted by ' + @User + '. ProductID: ' + CAST(d.ProductID AS VARCHAR(10))
        FROM deleted d;

        BEGIN TRY
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = 'DBA_Alert_Profile',
                @recipients = @Recipients,
                @subject = 'ALERT: Product Record Deleted',
                @body = 'A product has been removed from the inventory.';
        END TRY
        BEGIN CATCH
            PRINT 'Warning: Could not send email alert for Product deletion.';
        END CATCH
    END

    -- INSERT Logic
    IF @Action = 'INSERT'
    BEGIN
        INSERT INTO dbo.AuditTable (TableName, ActionType, RecordID, ActionUser, ActionDateTime, Description)
        SELECT 'Production.Product', @Action, CAST(i.ProductID AS NVARCHAR(20)), @User, @CurrentDate,
               'New product created. ProductID: ' + CAST(i.ProductID AS VARCHAR(10))
        FROM inserted i;
    END

    -- UPDATE Logic
    IF @Action = 'UPDATE'
    BEGIN
        INSERT INTO dbo.AuditTable (TableName, ActionType, RecordID, ActionUser, ActionDateTime, Description)
        SELECT 'Production.Product', @Action, CAST(i.ProductID AS NVARCHAR(20)), @User, @CurrentDate,
               'Product details updated. ProductID: ' + CAST(i.ProductID AS VARCHAR(10))
        FROM inserted i;

        --Conditional Alert (Price change > 10%)
        IF UPDATE(ListPrice)
        BEGIN
            IF EXISTS (
                SELECT 1 
                FROM inserted i 
                JOIN deleted d ON i.ProductID = d.ProductID
                WHERE d.ListPrice > 0 
                  AND (ABS(i.ListPrice - d.ListPrice) / d.ListPrice) > 0.10
            )
            BEGIN
                BEGIN TRY
                    EXEC msdb.dbo.sp_send_dbmail
                        @profile_name = 'DBA_Alert_Profile',
                        @recipients = @Recipients,
                        @subject = 'PRICE ALERT: Significant Price Change',
                        @body = 'A product price has been changed by more than 10%. Please review.';
                END TRY
                BEGIN CATCH
                    PRINT 'Warning: Could not send email alert for price change.';
                END CATCH
            END
        END
    END
END;
GO

-- TEST SCRIPTS

-- Test Trigger 1: Delete a customer (Will log to AuditTable and attempt email)
DELETE FROM Sales.Customer WHERE CustomerID = 1;

-- Test Trigger 2: Update Product Price > 10%
UPDATE Production.Product SET ListPrice = ListPrice * 1.20 WHERE ProductID = 707;

-- Viewing Logs
SELECT TOP 20 * FROM dbo.AuditTable ORDER BY [ActionDateTime] DESC;

-- View Email Status
SELECT * FROM msdb.dbo.sysmail_event_log;
SELECT * FROM msdb.dbo.sysmail_mailitems;
GO

PRINT 'Part E Script Execution Finished.';
GO