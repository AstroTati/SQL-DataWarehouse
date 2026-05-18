/*
__________________________________________________________________________________________
Silver Layer Data Quality Tests
Author:       Tatiana Rodriguez
Last updated: 2026-05-18
Layer:        Silver
 
Run these queries to validate the integrity and consistency of the Silver layer tables
before moving data to the Gold layer. These are read-only checks, no data is modified.

If any query returns unexpected results, the fix belongs in 5_load_silver_tables.sql.
__________________________________________________________________________________________
*/

-- ==========================================================================================
-- Checks for the crm_cust_info table
-- ==========================================================================================
-- 
-- Duplicates in Primary Key (PK):
-- Duplicate customer IDs would cause row inflation in the Gold layer fact table.

SELECT cst_id, 
COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id 
HAVING COUNT(*) > 1 OR cst_id IS NULL

-- Expected result: none.
-- Resolution: keep only the most recent entry by cst_create_date (handled in 5_load_silver_tables.sql).

-- __________________________________________________________________________________________
-- Unwanted spaces in string values
-- Leading or trailing spaces cause mismatches in joins and GROUP BY operations.
  
SELECT cst_firstname FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname)
-- Expected result: none.
  
SELECT cst_lastname FROM silver.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname)
-- Expected result: none.
  
SELECT cst_gndr FROM silver.crm_cust_info
WHERE cst_gndr != TRIM(cst_gndr)
-- Expected result: none.
  
-- __________________________________________________________________________________________
-- Data consistency:
-- Unexpected values here indicate unstandardized source data leaking into Silver.
  
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info
-- Expected result: Male, Female, N/A.

SELECT DISTINCT cst_marital_status
FROM silver.crm_cust_info
-- Expected result: Single, Married, N/A.

-- ==========================================================================================
-- Checks for the crm_prd_info table
-- ==========================================================================================
-- 
-- Duplicates in the PK
-- Duplicate product IDs would produce a many-to-many join with the sales fact table.

SELECT prd_id, 
COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL
-- Expected result: none.

-- __________________________________________________________________________________________
-- Column derivation: cross-table key alignment
-- Validates that transformed prd_key values can be matched to sales records.
-- If this returns fewer rows than the full table, the key derivation logic needs review.
  
SELECT 
prd_id,
prd_key,
prd_nm 
prd_cost,
prd_line,
prd_start_dt,
prd_end_dt
FROM silver.crm_prd_info
WHERE SUBSTRING(prd_key, 7, LEN(prd_key)) IN (
    SELECT sls_prd_key FROM silver.crm_sales_details
);
-- Expected result: the whole table.

-- __________________________________________________________________________________________
-- Validity of data
-- Negative or NULL costs would corrupt revenue calculations in the Gold layer.

SELECT prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL
-- Expect result: none

-- __________________________________________________________________________________________
-- Data consistency: categorial columns
  
SELECT DISTINCT prd_line
FROM silver.crm_prd_info

-- Expected result: Mountain, Road, Other Sales, Touring, N/A

-- __________________________________________________________________________________________
-- Data validity:
-- An end date before a start date indicates a transformation error in the Silver load.
  
SELECT * FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt

-- Expected result: none.

-- ==========================================================================================
-- Checks for the crm_sales_details table
-- ==========================================================================================
-- 
-- Duplicates and NULLs in the PK
-- Duplicates would double-count sales.
  
SELECT sls_prd_key, 
COUNT(*)
FROM silver.crm_sales_details
GROUP BY sls_prd_key
HAVING COUNT(*) > 1 OR sls_prd_key IS NULL
-- Expected result: none.

-- __________________________________________________________________________________________
-- Unwanted spaces

SELECT *
FROM silver.crm_sales_details
WHERE sls_ord_num != TRIM(sls_ord_num)
-- Expected result: none.

-- __________________________________________________________________________________________
-- Consistency between tables
-- Orphaned keys mean sales records cannot be enriched with product or customer attributes.
SELECT * FROM silver.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info)
-- Expected result: none.

SELECT * FROM silver.crm_sales_details
WHERE sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info)
-- Expected result: none.

-- __________________________________________________________________________________________
-- Data validity
-- Dates outside a plausible range or with invalid formatting signal upstream data issues.
  
SELECT sls_order_dt FROM silver.crm_sales_details
WHERE sls_order_dt <= 0 OR LEN(sls_order_dt) != 8 OR sls_order_dt > 20500101 OR sls_order_dt < 19000101
-- Expected result: none.

SELECT sls_ship_dt FROM silver.crm_sales_details
WHERE sls_ship_dt <= 0 OR LEN(sls_ship_dt) != 8 OR sls_ship_dt > 20500101 OR sls_ship_dt < 19000101
-- Expected result: none.

SELECT sls_due_dt FROM silver.crm_sales_details
WHERE sls_due_dt <= 0 OR LEN(sls_due_dt) != 8 OR sls_due_dt > 20500101 OR sls_due_dt < 19000101
-- Expected result: none.

SELECT * FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt
-- Expected result: none.

-- __________________________________________________________________________________________
-- Business rules:
-- Violations here indicate a calculation error in the Silver load script.
-- No negatives, zeros, or NULLs are permitted in any of the three columns.

SELECT sls_sales, sls_quantity, sls_price FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price
-- Expected result: none.

-- ==========================================================================================
-- Checks for the erp_cust_az12 table
-- ==========================================================================================
-- 
-- Duplicates and NULLs in the PK
  
SELECT cid, 
COUNT(*)
FROM silver.erp_cust_az12
GROUP BY cid
HAVING COUNT(*) > 1 OR cid IS NULL
-- Expected result: none.

-- __________________________________________________________________________________________
-- Referential integrity: erp-source customers to crm-source customers
-- All erp-source customer IDs must match a known crm-source customer key after transformation.
  
SELECT cid FROM silver.erp_cust_az12
WHERE cid NOT IN (SELECT DISTINCT cst_key FROM silver.crm_cust_info)
-- Expected result: none.

-- __________________________________________________________________________________________
-- Data validity
-- Future dates or dates before 1900 indicate bad source data or a transformation error.

SELECT DISTINCT 
bdate
FROM silver.erp_cust_az12
WHERE bdate < '1900-01-01' OR bdate > GETDATE()
-- Expected result: none.

-- __________________________________________________________________________________________
-- Data consistency
  
SELECT DISTINCT gen 
FROM silver.erp_cust_az12
-- Expected result: Male, Female, N/A.

-- ==========================================================================================
-- Checks for the erp_loc_a101 table
-- ==========================================================================================
-- Data consistency: country names
-- Inconsistent naming (for example, "DE" vs "Germany") would fragment country-level reporting.

SELECT DISTINCT cntry FROM silver.erp_loc_a101 
-- Expected result: distinct countries with consistent naming and no abbreviation variants.

-- ==========================================================================================
-- Checks for the erp_px_cat_g1v2 table
-- ==========================================================================================

-- Standardization and unwanted spaces: categorical columns
-- Spaces in category values cause silent mismatches in GROUP BY and JOIN operations.

SELECT DISTINCT cat FROM silver.erp_px_cat_g1v2
WHERE cat != TRIM(cat)
-- Expected result: none.

SELECT DISTINCT subcat FROM silver.erp_px_cat_g1v2
WHERE subcat != TRIM(subcat)
-- Expected result: none.

SELECT DISTINCT maintenance FROM silver.erp_px_cat_g1v2
WHERE maintenance != TRIM(maintenance)
-- Expected result: none.

