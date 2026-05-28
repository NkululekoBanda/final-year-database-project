-- PART B: USER ROLES & SECURITY

USE AdventureWorks2022;
GO

ALTER AUTHORIZATION ON DATABASE::AdventureWorks2022 TO sa;
GO

ALTER AUTHORIZATION ON DATABASE::AdventureWorks2022 TO sa;
GO

IF DATABASE_PRINCIPAL_ID('SalesRole') IS NOT NULL DROP ROLE SalesRole;
IF DATABASE_PRINCIPAL_ID('HRRole') IS NOT NULL DROP ROLE HRRole;
IF DATABASE_PRINCIPAL_ID('DBA_Role') IS NOT NULL DROP ROLE DBA_Role;
GO

CREATE ROLE SalesRole;
CREATE ROLE HRRole;
CREATE ROLE DBA_Role;
GO

PRINT 'Roles SalesRole, HRRole, and DBA_Role created successfully.';
GO

-- 2.1 SalesRole: Read/write sales data
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Sales TO SalesRole;
GRANT SELECT ON SCHEMA::Person TO SalesRole;
GRANT SELECT ON SCHEMA::Production TO SalesRole;
GO

-- 2.2 HRRole: Access employee data
GRANT SELECT ON SCHEMA::HumanResources TO HRRole;
GRANT SELECT ON Person.Person TO HRRole;
GRANT SELECT ON Person.EmailAddress TO HRRole;
GO

-- 2.3 DBA_Role: Full control
GRANT CONTROL TO DBA_Role;
GO

PRINT 'Permissions granted to roles.';
GO

-- SECTION 3: USER MAPPING
-- Step 1: Create Logins at the Server Level
USE master;
GO

-- Creating the Logins first (Server Level)
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'Emmanuel(Sales_2)')
    CREATE LOGIN [Emmanuel(Sales_2)] WITH PASSWORD = 'MyPassword123', CHECK_POLICY = OFF;

IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'MolepoT_(HR_1)')
    CREATE LOGIN [MolepoT_(HR_1)] WITH PASSWORD = 'MyPassword123', CHECK_POLICY = OFF;

IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'Butcher(DBA_3)')
    CREATE LOGIN [Butcher(DBA_3)] WITH PASSWORD = 'MyPassword123', CHECK_POLICY = OFF;
GO

-- Step 2: Create Users in the Database (Mapping Logins)
USE AdventureWorks2022;
GO

-- Create Users for each Login
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'Emmanuel_(Sales_2)')
    CREATE USER [Emmanuel_(Sales_2)] FOR LOGIN [Emmanuel_Sales_Login];

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'Mapaseka(HR_2)')
    CREATE USER [HR_2] FOR LOGIN [Mapaseka(HR_2)];

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'Butcher(DBA_3)')
    CREATE USER [Administrator_3] FOR LOGIN [Butcher(DBA_3)];
GO

-- Step 3: Map Users to Roles
ALTER ROLE SalesRole ADD MEMBER [Emmanuel(Sales_2)];
ALTER ROLE HRRole ADD MEMBER [];
ALTER ROLE DBA_Role ADD MEMBER [];
GO


GRANT IMPERSONATE ON USER::[Emmanuel_(Sales_2)] TO [dbo];
GRANT IMPERSONATE ON USER::[MolepoT_(HR_1)] TO [dbo];
GRANT IMPERSONATE ON USER::[Butcher_(DBA_3)] TO [dbo];
GO

PRINT 'Logins created, users mapped, and impersonation permissions granted.';
GO

-- SECTION 4: SECURITY TESTING

-- 4.1 TEST: SalesRole Access
PRINT 'Testing SalesRole context...';
GO
EXECUTE AS USER = 'Sales person_2';
    SELECT TOP 5 * FROM Sales.SalesPerson; 
REVERT;
GO

-- 4.2 TEST: HRRole Access
PRINT 'Testing HRRole context...';
GO
EXECUTE AS USER = 'HR_1';
    SELECT TOP 5 * FROM HumanResources.Employee;
REVERT;
GO

-- 4.3 TEST: DBA_Role Access
PRINT 'Testing DBA_Role context...';
GO
EXECUTE AS USER = 'Administrator_3';
    SELECT * FROM sys.objects;
REVERT;
GO

-- SECTION 5: UTILITY QUERIES FOR REPORTING
SELECT 
    DP1.name AS RoleName, 
    DP2.name AS MemberName  
FROM sys.database_role_members AS DRM  
JOIN sys.database_principals AS DP1 ON DRM.role_principal_id = DP1.principal_id  
JOIN sys.database_principals AS DP2 ON DRM.member_principal_id = DP2.principal_id  
WHERE DP1.name IN ('SalesRole', 'HRRole', 'DBA_Role')
ORDER BY RoleName;

-- View permissions for the roles
SELECT 
    class_desc, 
    permission_name, 
    state_desc, 
    USER_NAME(grantee_principal_id) AS RoleName
FROM sys.database_permissions
WHERE USER_NAME(grantee_principal_id) IN ('SalesRole', 'HRRole', 'DBA_Role');
GO