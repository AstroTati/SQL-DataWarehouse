/* 
_________________________________________________________________________________________
Project Initialization: Create database and schemas
Author:       Tatiana Rodriguez
Last updated: 2026-05-10

This script creates a database (db) named 'datawarehouse_TMR' (TMR are my initials).
It will first check if the db already exists, in which case it will drop it. 
Once the db is created, it will create three schemas: 'Bronze', 'Silver', and 'Gold'.

WARNING: It will drop any existing db with the same name. This is irreversible and will 
delete everything the db contains. Make backups and proceed with caution.
_________________________________________________________________________________________
*/

USE master;
GO

-- Drop and recreate the database if it already exists
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'datawarehouse_TMR')
BEGIN   
    ALTER DATABASE datawarehouse_TMR SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE datawarehouse_TMR;
END;
GO

-- Create the database
CREATE DATABASE datawarehouse_TMR;

USE datawarehouse_TMR;
GO

-- Create schemas
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO
