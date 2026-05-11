/*
_______________________________________________________________________________
Stored procedure: Load bronze layer (source --> bronze)
    This procedure loads data from source CSV files into the bronze layer tables.
    The tables are truncated first, then bulk insert is used.

    use 'EXEC bronze.load_bronze;' to run it.
_______________________________________________________________________________
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze AS 
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '============================================================';
        PRINT 'START: BULK LOAD';
        PRINT '============================================================';

        PRINT '>>>> LOADING crm TABLES';

        SET @start_time = GETDATE();
        PRINT '______________________________________';
        PRINT 'TRUNCATING TABLE crm_cust_info';
        TRUNCATE TABLE bronze.crm_cust_info;

        PRINT '';
        PRINT 'INSERTING TABLE crm_cust_info';
        BULK INSERT bronze.crm_cust_info 
        FROM '/home/tatiana/Documents/SQL/DataWarehouseProject/datasets/source_crm/cust_info.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        -- Uncomment this for more detailed time stamp 
        -- PRINT 'INFO Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';


        SET @start_time = GETDATE();
        PRINT '______________________________________';
        PRINT 'TRUNCATING TABLE crm_prd_info';
        TRUNCATE TABLE bronze.crm_prd_info;

        PRINT '';
        PRINT 'INSERTING TABLE crm_prd_info';
        BULK INSERT bronze.crm_prd_info 
        FROM '/home/tatiana/Documents/SQL/DataWarehouseProject/datasets/source_crm/prd_info.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        -- Uncomment this for more detailed time stamp 
        -- PRINT 'INFO Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';


        SET @start_time = GETDATE();
        PRINT '______________________________________';
        PRINT 'TRUNCATING TABLE crm_sales_details';
        TRUNCATE TABLE bronze.crm_sales_details;

        PRINT '';
        PRINT 'INSERTING TABLE crm_sales_details';
        BULK INSERT bronze.crm_sales_details 
        FROM '/home/tatiana/Documents/SQL/DataWarehouseProject/datasets/source_crm/sales_details.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        -- Uncomment this for more detailed time stamp 
        -- PRINT 'INFO Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';


        PRINT '___________________________________________________';
        PRINT '>>>> FINISH LOADING crm TABLES';
        PRINT '';

        PRINT '>>>> LOADING erp TABLES';

        SET @start_time = GETDATE();
        PRINT '______________________________________';
        PRINT 'TRUNCATING TABLE erp_cust_az12';
        TRUNCATE TABLE bronze.erp_cust_az12;

        PRINT '';
        PRINT 'INSERTING TABLE erp_cust_az12';
        BULK INSERT bronze.erp_cust_az12 
        FROM '/home/tatiana/Documents/SQL/DataWarehouseProject/datasets/source_erp/cust_az12.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        -- Uncomment this for more detailed time stamp 
        -- PRINT 'INFO Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';


        SET @start_time = GETDATE();
        PRINT '______________________________________';
        PRINT 'TRUNCATING TABLE erp_loc_a101';
        TRUNCATE TABLE bronze.erp_loc_a101;

        PRINT '';
        PRINT 'INSERTING TABLE erp_loc_a101';
        BULK INSERT bronze.erp_loc_a101 
        FROM '/home/tatiana/Documents/SQL/DataWarehouseProject/datasets/source_erp/loc_a101.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        -- Uncomment this for more detailed time stamp 
        -- PRINT 'INFO Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';


        SET @start_time = GETDATE();
        PRINT '______________________________________';
        PRINT 'TRUNCATING TABLE erp_px_cat_g1v2';
        TRUNCATE TABLE bronze.erp_px_cat_g1v2;

        PRINT '';
        PRINT 'INSERTING TABLE erp_px_cat_g1v2';
        BULK INSERT bronze.erp_px_cat_g1v2 
        FROM '/home/tatiana/Documents/SQL/DataWarehouseProject/datasets/source_erp/px_cat_g1v2.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            TABLOCK
        );
        SET @end_time = GETDATE();
        -- Uncomment this for more detailed time stamp 
        -- PRINT 'INFO Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';

        PRINT '___________________________________________________';

        SET @batch_end_time = GETDATE();
        PRINT ''
        PRINT 'Batch load duration:' + CAST(DATEDIFF(second, @batch_start_time,@batch_end_time) AS VARCHAR) + ' seconds.';


        PRINT '============================================================';
        PRINT 'FINISH: BULK LOAD';
        PRINT '============================================================';

    END TRY
    BEGIN CATCH
        PRINT 'ERROR >>> BRONZE LAYER LOAD FAILED TO START.';
        PRINT 'Error message:' + ERROR_MESSAGE();
        PRINT 'Error number:' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error state:' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '___________________________________________________'
    END CATCH
END


EXEC bronze.load_bronze;
