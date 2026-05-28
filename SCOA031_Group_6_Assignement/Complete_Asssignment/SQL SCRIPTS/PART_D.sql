-- PART D: BACKUP & RECOVERY

USE master;
GO

ALTER DATABASE AdventureWorks2022 SET RECOVERY FULL;
GO

-- SECTION 2: BACKUP IMPLEMENTATION

-- 2.1 Full Backup
PRINT 'Starting Full Backup...';
BACKUP DATABASE AdventureWorks2022
TO DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\Backup\AW2022_Full.bak'
WITH FORMAT, 
     MEDIANAME = 'AW_Backups', 
     NAME = 'Full Backup of AdventureWorks2022',
     STATS = 10;
GO

-- 2.2 Differential Backup
PRINT 'Starting Differential Backup...';
BACKUP DATABASE AdventureWorks2022
TO DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\Backup\AW2022_Diff.bak'
WITH DIFFERENTIAL, 
     FORMAT, 
     NAME = 'Differential Backup of AdventureWorks2022',
     STATS = 10;
GO

-- 2.3 Transaction Log Backup
PRINT 'Starting Transaction Log Backup...';
BACKUP LOG AdventureWorks2022
TO DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\Backup\AW2022_Log.trn'
WITH FORMAT, 
     NAME = 'Log Backup of AdventureWorks2022',
     STATS = 10;
GO

-- SECTION 3: RESTORE PROCESS DEMONSTRATION
PRINT 'Starting Restore Process Demonstration...';

-- 3.1 Restore Full Backup
RESTORE DATABASE AdventureWorks_RestoreTest
FROM DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\Backup\AW2022_Full.bak'
WITH MOVE 'AdventureWorks2022' TO 'C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\Backup\AW_RestoreTest.mdf',
     MOVE 'AdventureWorks2022_Log' TO 'C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\Backup\AW_RestoreTest_log.ldf',
     NORECOVERY,
     REPLACE;

-- 3.2 Restore Differential Backup 
RESTORE DATABASE AdventureWorks_RestoreTest
FROM DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\Backup\AW2022_Diff.bak'
WITH NORECOVERY;

-- 3.3 Restore Transaction Log Backup
RESTORE LOG AdventureWorks_RestoreTest
FROM DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQL\Backup\AW2022_Log.trn'
WITH RECOVERY;

PRINT 'Restore Process completed. Database AdventureWorks_RestoreTest is now online.';
GO