/* 
____________________________________________________________________________________
Advanced Data Analysis
Author:         Tatiana Rodriguez
Last updated:   2026-19-05

This script contains examples of data exploration queries. 
Views and tables from datawarehouse_TMR are used, make sure to download and run the
requiered scripts and source data files.
Two views are created by the last two complex queries for customer and product report.
____________________________________________________________________________________
*/

/*=================================================================================
CHANGES OVER TIME

Analyze how measures evolve and identify trends and seasonality in the data
Equation is agg[measure] by [date dim]
=================================================================================*/

-- changes by month (seasonality)
SELECT 
    MONTH(order_date) AS order_month, 
    SUM(sales) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY MONTH(order_date)
ORDER BY MONTH(order_date) ASC

-- changes by year
SELECT 
    DATETRUNC(month,order_date) AS order_date, 
    SUM(sales) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month,order_date)
ORDER BY DATETRUNC(month,order_date)


/*=================================================================================
CUMULATIVE ANALYSIS

Aggregate data progressively over time to understand business growth (or decline).
Equation is agg[cumulative measure] by [date dim]
=================================================================================*/

-- Total sales per month and running total 
SELECT 
    order_date,
    total_sales,
    SUM(total_sales) OVER (PARTITION BY order_date ORDER BY order_date) AS running_total_sales
FROM (
    SELECT 
        DATETRUNC(month, order_date) AS order_date,
        SUM(sales) AS total_sales
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(month, order_date)
)t

-- Price moving average by year
SELECT 
    order_date,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sales,
    AVG(avg_price) OVER (ORDER BY order_date) AS moving_avg_price
FROM (
    SELECT 
        DATETRUNC(year, order_date) AS order_date,
        SUM(sales) AS total_sales,
        AVG(price) AS avg_price
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(year, order_date)
)t


/*=================================================================================
PERFORMANCE ANALYSIS

Comparing the current and target value to measure success 
Equation is current[measure] - target[measure]
=================================================================================*/

-- Yearly product performance compared to previous the year's
WITH year_product_sales AS (
SELECT
    YEAR(f.order_date) AS order_year,
    p.product_name,
    SUM(f.sales) AS current_sales
FROM gold.fact_sales f  
LEFT JOIN gold.dim_products p
    ON f.product_key = p.product_key
WHERE order_date IS NOT NULL
GROUP BY YEAR(f.order_date), p.product_name
)

SELECT 
    order_year,
    product_name,
    current_sales,
    AVG(current_sales) OVER (PARTITION BY product_name) avg_sales,
    current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS delta_avg,
    CASE WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above avg'
        WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below avg'
        ELSE 'Avg'
    END performance,
    LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) previous_year,
    current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS delta_previous_year,
    CASE WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
        ELSE 'No Change'
    END previous_year_change
FROM year_product_sales
ORDER BY product_name, order_year


/*=================================================================================
PART-TO-WHOLE ANALYSIS (Proportional Analysis)

Analyze how a part is performing compared to the overall to understand which
categories (for example) have the biggest impact on the business.
Equation is ([measure]/total[measure]) * 100 by [dimension] 
=================================================================================*/

-- Which categories contribute most to the total sales?

WITH category_sales AS (
SELECT
    p.category,
    SUM(f.sales) AS total_sales
FROM gold.fact_sales f  
LEFT JOIN gold.dim_products p  
    ON p.product_key = f.product_key
GROUP BY category)

SELECT 
    category,
    total_sales,
    SUM(total_sales) OVER () overall_sales,
    CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER ()) * 100, 2), '%') AS total_percentage
FROM category_sales

/*=================================================================================
DATA SEGMENTATION 

Group data on a specific range to understand the correlation between measures.
Equation is [measure] by [measure]
=================================================================================*/

-- Segment products into cost ranges and count how many fall into each segment.
WITH product_segments AS (
SELECT
product_key,
product_name,
cost,
CASE WHEN cost < 100 THEN 'Below 100'
    WHEN cost BETWEEN 100 AND 500 THEN '100 - 500'
    WHEN cost BETWEEN 500 AND 1000 THEN '500 - 1000'
    ELSE 'Above 1000'
END cost_range
FROM gold.dim_products)

SELECT 
cost_range,
COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC


-- Group customers into 3 segments based on the spending behavior: VIP, regular, and new.
WITH customer_spending AS (
    SELECT 
        c.customer_key,
        SUM(f.sales) AS total_spending,
        DATEDIFF(month,MIN(f.order_date), MAX(f.order_date)) AS lifespan_months
    FROM gold.fact_sales f  
    LEFT JOIN gold.dim_customers c  
        ON f.customer_key = c.customer_key
    GROUP BY c.customer_key
)

SELECT
    customer_category,
    COUNT(customer_key) AS total_customers
FROM (
    SELECT 
        customer_key,
        CASE WHEN lifespan_months >= 12 AND total_spending > 5000 THEN 'VIP'
            WHEN lifespan_months >= 12 AND total_spending <= 5000 THEN 'Regular'
            ELSE 'New'
        END customer_category
    FROM customer_spending
    )t  
GROUP BY customer_category
ORDER BY total_customers DESC

/*=================================================================================
CUSTOMER REPORT 

Consolidates the key customer metrics and behaviors. It contains:
    i. Basic information (e.g., name, gender)
    ii. Customer category
    iii. Aggregated metrics (e.g., total sales, lifespan)
    iv. Valuable KPIs (e.g., recency, average order)

This complex query will be saved as a view.
=================================================================================*/

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
WHERE order_date IS NOT NULL),

customer_aggregations AS (
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


/*=================================================================================
PRODUCTS REPORT 

Consolidates the key product metrics and behaviors. It contains:
    i. Basic information (e.g., name, category)
    ii. Segmentation by revenue (e.g., high-performer, mid-range)
    iii. Aggregated metrics (e.g., total orders, quantity sold)
    iv. Valuable KPIs (e.g., recency, AOR)

This complex query will be saved as a view.
=================================================================================*/

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


