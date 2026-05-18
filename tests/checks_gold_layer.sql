/*
______________________________________________________________________________
Gold Layer Quality Checks
Author:       Tatiana Rodriguez
Last updated: 2026-05-18
Layer:        Gold

This script contains SQL queries to test the quality, integrity, consistency, 
and accuracy of the Gold layer. 
______________________________________________________________________________
*/

-- ===========================================================================
-- Checks for dim_customers
-- ===========================================================================
-- Uniqueness of customer key (surrogate)

SELECT 
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;
-- Expectation: No results 


-- ===========================================================================
-- Checks for dim_products
-- ===========================================================================
-- Uniqueness of product key (surrogate)

SELECT 
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;
-- Expectation: No results 


-- ===========================================================================
-- Checks for fact_sales
-- ===========================================================================
-- Check the data model connectivity between fact and dimensions
-- This validates the relationships in the data model for analytical purposes.

SELECT * 
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
  ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
  ON p.product_key = f.product_key
WHERE p.product_key IS NULL OR c.customer_key IS NULL  
-- Expectation: No results 
