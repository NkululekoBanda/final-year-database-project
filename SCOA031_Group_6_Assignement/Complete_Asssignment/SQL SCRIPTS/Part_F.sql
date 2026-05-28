-- PART F: MAINTENANCE & SERVER HEALTH

USE AdventureWorks2022;
GO

-- TASK 1: MAINTENANCE STORED PROCEDURE

IF OBJECT_ID('dbo.usp_RunDatabaseMaintenance', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_RunDatabaseMaintenance;
GO

CREATE PROCEDURE dbo.usp_RunDatabaseMaintenance
AS
BEGIN
    SET NOCOUNT ON;
    PRINT '--- STARTING DATABASE MAINTENANCE: ' + CONVERT(VARCHAR, GETDATE(), 120) + ' ---';

    -- 1. Database Integrity Check
    PRINT 'Step 1: Running DBCC CHECKDB...';
    BEGIN TRY
        DBCC CHECKDB ('AdventureWorks2022') WITH NO_INFOMSGS, ALL_ERRORMSGS;
        PRINT 'SUCCESS: Integrity check passed.';
    END TRY
    BEGIN CATCH
        PRINT 'CRITICAL ERROR: Integrity check failed. Error: ' + ERROR_MESSAGE();
    END CATCH

    -- 2. Index Maintenance 
    PRINT 'Step 2: Performing Index Maintenance...';
    DECLARE @SchemaName VARCHAR(255);
    DECLARE @TableName  VARCHAR(255);
    DECLARE @IndexName  VARCHAR(255);
    DECLARE @Frag       FLOAT;
    DECLARE @SQL        VARCHAR(MAX);

    DECLARE IndexCursor CURSOR FOR
    SELECT 
        OBJECT_SCHEMA_NAME(i.object_id) AS SchemaName,
        OBJECT_NAME(i.object_id) AS TableName,
        i.name AS IndexName,
        ips.avg_fragmentation_in_percent
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE avg_fragmentation_in_percent > 10.0 -- Only process fragmented indexes
      AND i.index_id > 0; -- Exclude heaps

    OPEN IndexCursor;
    FETCH NEXT FROM IndexCursor INTO @SchemaName, @TableName, @IndexName, @Frag;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @Frag >= 30.0
        BEGIN
            SET @SQL = 'ALTER INDEX ' + QUOTENAME(@IndexName) + ' ON ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + ' REBUILD;';
            PRINT 'Action: REBUILDING ' + QUOTENAME(@IndexName) + ' on ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + ' (Frag: ' + CAST(@Frag AS VARCHAR(10)) + '%)';
        END
        ELSE
        BEGIN
            SET @SQL = 'ALTER INDEX ' + QUOTENAME(@IndexName) + ' ON ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + ' REORGANIZE;';
            PRINT 'Action: REORGANIZING ' + QUOTENAME(@IndexName) + ' on ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + ' (Frag: ' + CAST(@Frag AS VARCHAR(10)) + '%)';
        END

        EXEC sp_executesql @SQL;
        FETCH NEXT FROM IndexCursor INTO @SchemaName, @TableName, @IndexName, @Frag;
    END

    CLOSE IndexCursor;
    DEALLOCATE IndexCursor;

    PRINT '--- MAINTENANCE COMPLETE: ' + CONVERT(VARCHAR, GETDATE(), 120) + ' ---';
END;
GO

-- TASK 2: AUTOMATION

USE msdb;
GO

IF NOT EXISTS (SELECT name FROM syscategories WHERE name = 'Database Maintenance' AND category_class = 1)
BEGIN
    EXEC sp_add_category @class = 'JOB', @type = 'LOCAL', @name = 'Database Maintenance';
END
GO

DECLARE @JobID BINARY(16);

IF EXISTS (SELECT job_id FROM sysjobs WHERE name = 'AdventureWorks_Weekly_Maintenance')
    EXEC sp_delete_job @job_name = 'AdventureWorks_Weekly_Maintenance';

-- 2.1 Create the Job
EXEC sp_add_job 
    @job_name = 'AdventureWorks_Weekly_Maintenance', 
    @enabled = 1, 
    @description = 'Weekly Integrity Check and Index Optimization.',
    @category_name = 'Database Maintenance',
    @owner_login_name = 'sa',
    @job_id = @JobID OUTPUT;

-- 2.2 Step 1: Maintenance Procedure
EXEC sp_add_jobstep 
    @job_id = @JobID, 
    @step_name = 'Run Maintenance Procedure', 
    @subsystem = 'TSQL', 
    @command = 'EXEC dbo.usp_RunDatabaseMaintenance;', 
    @database_name = 'AdventureWorks2022',
    @retry_attempts = 1,
    @retry_interval = 5;

-- 2.3 Step 2: Full Backup 
EXEC sp_add_jobstep 
    @job_id = @JobID, 
    @step_name = 'Weekly Full Backup', 
    @subsystem = 'TSQL', 
    @command = 'BACKUP DATABASE AdventureWorks2022 TO DISK = ''C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\Backup\AW_Weekly_Full.bak'' WITH FORMAT;', 
    @database_name = 'master';

-- 2.4 Scheduling the Job (Every Sunday at 1:00 AM)
EXEC sp_add_jobschedule 
    @job_id = @JobID, 
    @name = 'Weekly_Sunday_1AM', 
    @freq_type = 8, -- Weekly
    @freq_interval = 1, -- Sunday
    @freq_recurrence_factor = 1, 
    @active_start_time = 010000; -- 01:00:00

EXEC sp_add_jobserver @job_id = @JobID, @server_name = '(local)';
GO

-- TEST & VALIDATION
USE AdventureWorks2022;
GO

EXEC dbo.usp_RunDatabaseMaintenance; 

-- Query to verify that the job was created and scheduled
SELECT 
    j.name AS JobName, 
    j.enabled AS IsEnabled, 
    s.name AS ScheduleName,
    CASE j.enabled WHEN 1 THEN 'Yes' ELSE 'No' END AS Active
FROM msdb.dbo.sysjobs j
JOIN msdb.dbo.sysjobschedules js ON j.job_id = js.job_id
JOIN msdb.dbo.sysschedules s ON js.schedule_id = s.schedule_id
WHERE j.name = 'AdventureWorks_Weekly_Maintenance';

DBCC CHECKDB ('AdventureWorks2022') WITH NO_INFOMSGS;
GO