/* 
____________________________________________________________________________________
Advanced Data Analysis
Author:         Tatiana Rodriguez
Last updated:   2026-19-05

This script contains examples of data exploration queries. 
Views and tables from datawarehouse_TMR are used, make sure to download and run the
requiered scripts and source data files.
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


