/*
_______________________________________________________________________________
Stored procedure: Load silver layer (source --> silver)
    This procedure loads data from the bronze layer into the silver layer tables.
    The tables are truncated first, then insert into is used.
    The data is also cleaned and transformed.

    use 'EXEC silver.load_silver;' to run it.
_______________________________________________________________________________
*/

-- EXEC silver.load_silver;

CREATE OR ALTER PROCEDURE silver.load_silver AS 
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '============================================================';
        PRINT 'START: BULK LOAD SILVER LAYER';
        PRINT '============================================================';

        PRINT '>>>> LOADING crm TABLES';

        SET @start_time = GETDATE();
        PRINT '______________________________________';
        PRINT 'TRUNCATING TABLE crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;

        PRINT '';
        PRINT 'INSERTING TABLE crm_cust_info';
        
        INSERT INTO silver.crm_cust_info (
			cst_id, 
			cst_key, 
			cst_firstname, 
			cst_lastname, 
			cst_marital_status, 
			cst_gndr,
			cst_create_date
        )
        SELECT 
            cst_id,
            cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname) AS cst_lastname,
            -- We include a data transformation step to have clearer information:
            CASE WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
                WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
                ELSE 'N/A'
            END AS cst_marital_status,
            -- We include a data transformation step to have clearer information:
            CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
                WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
                ELSE 'N/A'
            END AS cst_gndr,
            cst_create_date
        FROM (
            SELECT *,
            ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) as flag_last
            FROM bronze.crm_cust_info
        )t WHERE flag_last = 1 AND cst_create_date > '1900-01-01'
        SET @end_time = GETDATE();
        -- Uncomment this for more detailed time stamp: 
        -- PRINT 'INFO Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';



        SET @start_time = GETDATE();
        PRINT '______________________________________';
        PRINT 'TRUNCATING TABLE crm_prd_info';
        TRUNCATE TABLE silver.crm_prd_info;

        PRINT '';
        PRINT 'INSERTING TABLE crm_prd_info';
        
        INSERT INTO silver.crm_prd_info (
			prd_id, 
			cat_id, 
			prd_key, 
			prd_nm, 
			prd_cost,
			prd_line,
            prd_start_dt,
            prd_end_dt
        )
        SELECT 
            prd_id,
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id, 
            SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
            TRIM(prd_nm) as prd_nm,
            ABS(ISNULL(prd_cost,0)) AS prd_cost,
            CASE UPPER(TRIM(prd_line))
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Other Sales'
                WHEN 'T' THEN 'Touring'
                ELSE 'N/A'
            END AS prd_line,
            CAST(prd_start_dt AS DATE) as prd_start_dt,
            CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt ASC)-1 AS DATE) AS prd_end_dt
        FROM (
            SELECT *,
            ROW_NUMBER() OVER (PARTITION BY prd_key ORDER BY prd_key DESC) as flag_last
            FROM bronze.crm_prd_info
        )t WHERE flag_last = 1
        SET @end_time = GETDATE();
        -- Uncomment this for more detailed time stamp: 
        -- PRINT 'INFO Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';


        SET @start_time = GETDATE();
        PRINT '______________________________________';
        PRINT 'TRUNCATING TABLE crm_sales_details';
        TRUNCATE TABLE silver.crm_sales_details;

        PRINT '';
        PRINT 'INSERTING TABLE crm_sales_details';
        
        INSERT INTO silver.crm_sales_details (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
            END AS sls_order_dt,
            CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
            END AS sls_ship_dt,
            CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
                ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
            END AS sls_due_dt,
            CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
                THEN sls_quantity * ABS(sls_price)
                ELSE sls_sales
            END AS sls_sales,
            sls_quantity,
            CASE WHEN sls_price IS NULL OR sls_price <= 0
                THEN sls_sales / NULLIF(sls_quantity,0)
                ELSE sls_price
            END AS sls_price
        FROM bronze.crm_sales_details
        SET @end_time = GETDATE();
        -- Uncomment this for more detailed time stamp: 
        -- PRINT 'INFO Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';
        


        PRINT '>>>> LOADING erp TABLES';

        SET @start_time = GETDATE();
        PRINT '______________________________________';
        PRINT 'TRUNCATING TABLE erp_cust_az12';
        TRUNCATE TABLE silver.erp_cust_az12;

        PRINT '';
        PRINT 'INSERTING TABLE erp_cust_az12';
        
        INSERT INTO silver.erp_cust_az12 (
            cid, 
            bdate,
            gen
        )
        SELECT
            CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
                ELSE cid
            END AS cid,
            CASE WHEN bdate > GETDATE() THEN NULL
                ELSE bdate
            END AS bdate,
            CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
                WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
                ELSE 'N/A'
            END AS gen
        FROM bronze.erp_cust_az12
        SET @end_time = GETDATE();
        -- Uncomment this for more detailed time stamp: 
        -- PRINT 'INFO Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';



        SET @start_time = GETDATE();
        PRINT '______________________________________';
        PRINT 'TRUNCATING TABLE erp_loc_a101';
        TRUNCATE TABLE silver.erp_loc_a101;

        PRINT '';
        PRINT 'INSERTING TABLE erp_loc_a101';
        
        INSERT INTO silver.erp_loc_a101(
            cid,
            cntry
        )
        SELECT
            REPLACE(cid,'-','') AS cid, 
            CASE WHEN UPPER(TRIM(cntry)) = 'USA' THEN 'United States'
                WHEN UPPER(TRIM(cntry)) = 'US'  THEN 'United States'
                WHEN UPPER(TRIM(cntry)) = 'DE'  THEN 'Germany'
                WHEN cntry = '' THEN 'N/A'
                ELSE cntry
            END AS cntry
        FROM bronze.erp_loc_a101
        SET @end_time = GETDATE();
        -- Uncomment this for more detailed time stamp: 
        -- PRINT 'INFO Load duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds.';



        SET @start_time = GETDATE();
        PRINT '______________________________________';
        PRINT 'TRUNCATING TABLE erp_px_cat_g1v2';
        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        PRINT '';
        PRINT 'INSERTING TABLE erp_px_cat_g1v2';
        INSERT INTO silver.erp_px_cat_g1v2 (
            id,
            cat,
            subcat,
            maintenance
        )
        SELECT 
            id,
            TRIM(cat) AS cat,
            TRIM(subcat) AS subcat,
            maintenance
        from bronze.erp_px_cat_g1v2
        SET @end_time = GETDATE();
        -- Uncomment this for more detailed time stamp: 
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
        PRINT 'ERROR >>> silver LAYER LOAD FAILED TO START.';
        PRINT 'Error message:' + ERROR_MESSAGE();
        PRINT 'Error number:' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error state:' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '___________________________________________________'
    END CATCH
END
