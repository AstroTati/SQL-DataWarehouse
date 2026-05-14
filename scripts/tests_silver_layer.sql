/*
__________________________________________________________________________________________
This script contains SQL queries to test the quality and consistency of the Silver layer
data tables. 
These queries don't change anything in the tables; bad results here imply a change is 
needed in the 5_load_silver_tables.sql file.
__________________________________________________________________________________________
*/

-- ==========================================================================================
-- Checks for the crm_cust_info table
-- ==========================================================================================
-- 
-- Duplicates in Primary Key (PK)
SELECT cst_id, 
COUNT(*)
FROM silver.crm_cust_info
GROUP BY cst_id 
HAVING COUNT(*) > 1 OR cst_id IS NULL

-- We will deal with duplicates by keeping only the latest entry, that is, only the oldest
-- cst_create_date value is kept. 

-- __________________________________________________________________________________________
-- Unwanted spaces in string values
SELECT cst_firstname FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname)

SELECT cst_lastname FROM silver.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname)

SELECT cst_gndr FROM silver.crm_cust_info
WHERE cst_gndr != TRIM(cst_gndr)
-- These searches should return no results.

-- __________________________________________________________________________________________
-- Data consistency:
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info

SELECT DISTINCT cst_marital_status
FROM silver.crm_cust_info

-- This search should return no more than 3 values for gender: Male, Female, n/a.
-- This search should return no more than 3 values for maritan status: Single, Married, n/a.
-- __________________________________________________________________________________________

-- ==========================================================================================
-- Checks for the crm_prd_info table
-- ==========================================================================================
-- 
-- Duplicates in the PK

SELECT prd_id, 
COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL

-- __________________________________________________________________________________________
-- Column derivation: 
-- Make sure you can match the information according to your data integration model.
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
-- Make sure we have no NULLs nor negative cost values
SELECT prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL

-- __________________________________________________________________________________________
-- Data consistency:
SELECT DISTINCT prd_line
FROM silver.crm_prd_info


-- This search should return no more than 5 values for the product line: 
--      Mountain, Road, Other Sales, Touring, N/A

-- __________________________________________________________________________________________
-- Data validity:
-- Make sure end date is after start date
SELECT * FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt

-- Expected result: none.

-- ==========================================================================================
-- Checks for the crm_sales_details table
-- ==========================================================================================
-- 
-- Duplicates and NULLs in the PK
SELECT sls_prd_key, 
COUNT(*)
FROM silver.crm_sales_details
GROUP BY sls_prd_key
HAVING COUNT(*) > 1 OR sls_prd_key IS NULL

-- __________________________________________________________________________________________
-- Unwanted spaces

SELECT *
FROM silver.crm_sales_details
WHERE sls_ord_num != TRIM(sls_ord_num)
-- This should return no results.

-- __________________________________________________________________________________________
-- Consistency between tables
SELECT * FROM silver.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info)

SELECT * FROM silver.crm_sales_details
WHERE sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info)

-- These should return no results.

-- __________________________________________________________________________________________
-- Data validity
SELECT sls_order_dt FROM silver.crm_sales_details
WHERE sls_order_dt <= 0 OR LEN(sls_order_dt) != 8 OR sls_order_dt > 20500101 OR sls_order_dt < 19000101

SELECT sls_ship_dt FROM silver.crm_sales_details
WHERE sls_ship_dt <= 0 OR LEN(sls_ship_dt) != 8 OR sls_ship_dt > 20500101 OR sls_ship_dt < 19000101

SELECT sls_due_dt FROM silver.crm_sales_details
WHERE sls_due_dt <= 0 OR LEN(sls_due_dt) != 8 OR sls_due_dt > 20500101 OR sls_due_dt < 19000101

SELECT * FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt

-- These should return no results.

-- __________________________________________________________________________________________
-- Business rules:
-- sales = quantity * price
-- No negatives, zeros or NULLs.

SELECT sls_sales, sls_quantity, sls_price FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price

-- These should return no results.

-- ==========================================================================================
-- Checks for the erp_cust_az12 table
-- ==========================================================================================
-- 
-- -- Duplicates and NULLs in the PK
-- SELECT cid, 
-- COUNT(*)
-- FROM silver.erp_cust_az12
-- GROUP BY cid
-- HAVING COUNT(*) > 1 OR cid IS NULL

-- __________________________________________________________________________________________
-- Make sure you can match the information according to your data integration model.
SELECT cid FROM silver.erp_cust_az12
WHERE cid NOT IN (SELECT DISTINCT cst_key FROM silver.crm_cust_info)

-- Should return no result.

-- __________________________________________________________________________________________
-- Data validity
SELECT DISTINCT 
bdate
FROM silver.erp_cust_az12
WHERE bdate < '1900-01-01' OR bdate > GETDATE()

-- Should return no result.

-- __________________________________________________________________________________________
-- Data consistency:
SELECT DISTINCT gen 
FROM silver.erp_cust_az12

-- This search should return no more than 3 values for gender: Male, Female, N/A.

-- ==========================================================================================
-- Checks for the erp_loc_a101 table
-- ==========================================================================================
-- 
SELECT DISTINCT cntry FROM silver.erp_loc_a101 

-- This search should return distinct countries with consitent naming

-- ==========================================================================================
-- Checks for the erp_px_cat_g1v2 table
-- ==========================================================================================
-- Uniqueness and validity of variables:

SELECT DISTINCT cat FROM silver.erp_px_cat_g1v2

SELECT DISTINCT subcat FROM silver.erp_px_cat_g1v2

SELECT DISTINCT maintenance FROM silver.erp_px_cat_g1v2
