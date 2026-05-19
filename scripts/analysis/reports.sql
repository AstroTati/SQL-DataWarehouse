/* 
____________________________________________________________________________________
Advanced Data Analysis: Reports
Author:         Tatiana Rodriguez
Last updated:   2026-19-05

This script creates reports (views) containing basic information, aggregated metrics, 
and valuable KPIs for the business. 
Views and tables from datawarehouse_TMR are used, make sure to download and run the
requiered scripts and source data files.

Warning:
    Existing views with the same name will be dropped when this script is run, make 
    backups and proceed with caution.
____________________________________________________________________________________
*/


/*
=================================================================================
CUSTOMER REPORT 

Consolidates the key customer metrics and behaviors. It contains:
    i. Basic information (e.g., name, gender)
    ii. Customer category
    iii. Aggregated metrics (e.g., total sales, lifespan)
    iv. Valuable KPIs (e.g., recency, average order)

This complex query will be saved as a view.
=================================================================================
*/

IF OBJECT_ID('gold.report_customers', 'V') IS NOT NULL
    DROP VIEW gold.report_customers;
GO

CREATE VIEW gold.report_customers AS
-- Retrieve and derive core columns
WITH base_query AS(
SELECT 
    f.order_number,
    f.product_key,
    f.order_date,
    f.sales,
    f.quantity,
    c.customer_key,
    c.customer_number,
    CONCAT(c.last_name, ', ', c.first_name) AS customer_name,
    DATEDIFF(year,c.birth_date,GETDATE()) AS customer_age
FROM gold.fact_sales as f  
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
WHERE order_date IS NOT NULL)


, customer_aggregations AS (
-- Make the necessary aggregations
SELECT 
    customer_key,
    customer_number,
    customer_name,
    customer_age,
    COUNT(DISTINCT order_number) AS total_orders,
    SUM(sales) AS total_sales,
    SUM(quantity) AS total_quantity,
    COUNT(DISTINCT product_key) AS total_products,
    MAX(order_date) AS latest_order_date,
    DATEDIFF(month,MIN(order_date), MAX(order_date)) AS lifespan_months
FROM base_query
GROUP BY customer_key,
    customer_number,
    customer_name,
    customer_age
)
-- Final CTE
SELECT
    customer_key,
    customer_number,
    customer_name,
    -- customer_age,
    CASE WHEN customer_age < 20 THEN '< 20'
        WHEN customer_age BETWEEN 20 and 29 THEN '20 - 29'
        WHEN customer_age BETWEEN 30 and 39 THEN '30 - 39'
        WHEN customer_age BETWEEN 30 and 49 THEN '40 - 49'
        ELSE '>= 50'
    END customer_age_gap,
    CASE WHEN lifespan_months >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan_months >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END customer_category,
    DATEDIFF(month,latest_order_date,GETDATE()) AS months_since_last_order,  
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan_months,
    -- avg order value
    CASE WHEN total_orders = 0 THEN 0
        ELSE total_sales/total_orders 
    END avg_order_value,
    -- avg monthly revenue per customer
    CASE WHEN lifespan_months = 0 THEN total_sales
        ELSE total_sales/lifespan_months 
    END avg_month_spend
FROM customer_aggregations


/*
=================================================================================
PRODUCTS REPORT 

Consolidates the key product metrics and behaviors. It contains:
    i. Basic information (e.g., name, category)
    ii. Segmentation by revenue (e.g., high-performer, mid-range)
    iii. Aggregated metrics (e.g., total orders, quantity sold)
    iv. Valuable KPIs (e.g., recency, AOR)

This complex query will be saved as a view.
=================================================================================
*/


IF OBJECT_ID('gold.report_products', 'V') IS NOT NULL
    DROP VIEW gold.report_products;
GO
CREATE VIEW gold.report_products AS
WITH base_query AS(
SELECT
    f.order_number,
    f.order_date,
    f.customer_key,
    f.sales,
    f.quantity,
    p.product_key,
    p.product_name,
    p.category,
    p.subcategory,
    p.cost
FROM gold.fact_sales f  
LEFT JOIN gold.dim_products p  
    ON f.product_key = p.product_key
WHERE order_date IS NOT NULL
),

product_agg AS (
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan_months,
    MAX(order_date) AS latest_order_date,
    COUNT(DISTINCT order_number) AS total_orders,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(sales) AS total_sales,
    SUM(quantity) AS total_quantity_sold,
    ROUND(AVG(CAST(sales AS FLOAT) / NULLIF(quantity, 0)), 1) AS avg_price 
FROM base_query

GROUP BY 
    product_key,
    product_name,
    category,
    subcategory,
    cost
)

SELECT 
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    latest_order_date,
    DATEDIFF(month, latest_order_date, GETDATE()) AS months_since_last_order,
    CASE WHEN total_sales > 50000 THEN 'High-Performer'
        WHEN total_sales >= 10000 THEN 'Mid-Range'
        ELSE 'Low-Performer'
    END AS product_performance,
    lifespan_months,
    total_orders,
    total_sales,
    total_quantity_sold,
    total_customers,
    avg_price,
    -- Average order revenue (AOR)
    CASE WHEN total_orders = 0 THEN 0
        ELSE total_sales/total_orders
    END AS avg_order_revenue,
    -- Average monthly revenue
    CASE WHEN lifespan_months = 0 THEN total_sales
        ELSE total_sales/lifespan_months
    END AS avg_month_revenue

    FROM product_agg
