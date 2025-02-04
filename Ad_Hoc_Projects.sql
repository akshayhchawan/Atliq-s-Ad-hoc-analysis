-- 1.Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.
SELECT DISTINCT market
FROM dim_customer
WHERE region = 'APAC' 
  AND customer = 'Atliq Exclusive';

-- 2. What is the percentage of unique product increase in 2021 vs. 2020? 
-- The final output contains these fields, unique_products_2020 unique_products_2021 percentage_chg
SELECT 
    COUNT(DISTINCT CASE WHEN fiscal_year = '2020' THEN product_code END) AS unique_products_2020,
    COUNT(DISTINCT CASE WHEN fiscal_year = '2021' THEN product_code END) AS unique_products_2021,
    ROUND(
        (
            (COUNT(DISTINCT CASE WHEN fiscal_year = '2021' THEN product_code END) - 
             COUNT(DISTINCT CASE WHEN fiscal_year = '2020' THEN product_code END)) * 100.0
        ) / COUNT(DISTINCT CASE WHEN fiscal_year = '2020' THEN product_code END), 
        2
    ) AS percentage_chg
FROM fact_sales_monthly;
    
-- 3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
-- The final output contains 2 fields, segment product_count
SELECT 
    segment, 
    COUNT(DISTINCT product_code) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;

-- 4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 
-- The final output contains these fields, segment product_count_2020 product_count_2021 difference
SELECT 
    segment,
    COUNT(DISTINCT CASE WHEN fiscal_year = '2020' THEN fsm.product_code END) AS unique_products_2020,
    COUNT(DISTINCT CASE WHEN fiscal_year = '2021' THEN fsm.product_code END) AS unique_products_2021,
    ROUND(
        (
            (COUNT(DISTINCT CASE WHEN fiscal_year = '2021' THEN fsm.product_code END) -
             COUNT(DISTINCT CASE WHEN fiscal_year = '2020' THEN fsm.product_code END)) * 100.0
        ) / COUNT(DISTINCT CASE WHEN fiscal_year = '2020' THEN fsm.product_code END), 
        2
    ) AS percentage_chg
FROM fact_sales_monthly AS fsm
JOIN dim_product AS dp ON fsm.product_code = dp.product_code
WHERE fiscal_year IN ('2020', '2021')
GROUP BY segment
ORDER BY percentage_chg DESC;

-- 5. Get the products that have the highest and lowest manufacturing costs. 
-- The final output should contain these fields, product_code product manufacturing_cost
SELECT 
    dp.product_code, 
    dp.product, 
    manufacturing_cost, 
    dp.category
FROM fact_manufacturing_cost AS fmc
JOIN dim_product AS dp 
    ON fmc.product_code = dp.product_code
WHERE manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost)
   OR manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost)
GROUP BY dp.product_code, dp.product, dp.category, manufacturing_cost
ORDER BY manufacturing_cost DESC;

-- 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct 
-- for the fiscal year 2021 and in the Indian market. The final output contains these fields, customer_code customer average_discount_percentage
SELECT 
    dc.customer_code, 
    dc.customer, 
    AVG(pre_invoice_discount_pct) AS average_discount_percentage
FROM fact_pre_invoice_deductions AS fpid
JOIN dim_customer AS dc 
    ON fpid.customer_code = dc.customer_code
WHERE fiscal_year = '2021'  
    AND market = 'India'
GROUP BY dc.customer_code, dc.customer
ORDER BY average_discount_percentage DESC
LIMIT 5;

-- 7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . 
-- This analysis helps to get an idea of low and high-performing months and take strategic decisions. 
-- The final report contains these columns: Month Year Gross sales Amount
SELECT 
    MONTH(`date`) AS `month`, 
    YEAR(`date`) AS `year`, 
    ROUND(SUM(gross_price * sold_quantity), 2) AS gross_sales_amount
FROM fact_sales_monthly AS fsm
JOIN fact_gross_price AS fgp 
    ON fsm.product_code = fgp.product_code
JOIN dim_customer AS dc 
    ON fsm.customer_code = dc.customer_code
WHERE customer = 'Atliq Exclusive'
GROUP BY MONTH(`date`), YEAR(`date`)
ORDER BY MONTH(`year`) ASC;

-- 8. In which quarter of 2020, got the maximum total_sold_quantity? 
-- The final output contains these fields sorted by the total_sold_quantity, Quarter total_sold_quantity
SELECT
    CASE 
        WHEN MONTH(date) IN (9, 10, 11) THEN 'Q1'
        WHEN MONTH(date) IN (12, 1, 2) THEN 'Q2'
        WHEN MONTH(date) IN (3, 4, 5) THEN 'Q3'
        WHEN MONTH(date) IN (6, 7, 8) THEN 'Q4'
    END AS `Quarter`, 
    SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly 
WHERE fiscal_year = '2020'  
GROUP BY `Quarter`
ORDER BY total_sold_quantity DESC;

-- 9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?
-- The final output contains these fields, channel gross_sales_mln percentage
WITH Gross_Sales_Million AS (
    SELECT 
        channel, 
        ROUND(SUM(gross_price * sold_quantity) / 1000000, 2) AS gross_sales_mln
    FROM fact_sales_monthly AS fsm
    JOIN dim_customer AS dc ON fsm.customer_code = dc.customer_code
    JOIN fact_gross_price AS fgp ON fsm.product_code = fgp.product_code
    WHERE fsm.fiscal_year = '2021'
    GROUP BY channel
    ORDER BY gross_sales_mln DESC
)
SELECT 
    channel, 
    gross_sales_mln, 
    ROUND((gross_sales_mln / SUM(gross_sales_mln) OVER ()) * 100, 1) AS percentage
FROM Gross_Sales_Million
GROUP BY channel;

-- 10. Get the Top 3 products in each division that have a high total_sold_quantity in the
-- fiscal_year 2021? The final output contains these fields, division, product_code,product, total_sold_quantity,  rank_order
WITH Total_Sold_Quantity AS (
    SELECT 
        division, 
        dp.product_code AS product_code, 
        product, 
        SUM(sold_quantity) AS total_sold_quantity, 
        variant
    FROM dim_product AS dp
    JOIN fact_sales_monthly AS fsm ON dp.product_code = fsm.product_code
    WHERE fsm.fiscal_year = '2021'
    GROUP BY dp.division, dp.product_code, product, variant
),
Rank_Number AS (
    SELECT 
        division, 
        product_code, 
        product, 
        total_sold_quantity,
        DENSE_RANK() OVER (PARTITION BY division ORDER BY total_sold_quantity DESC) AS rank_order, 
        variant
    FROM Total_Sold_Quantity
)

SELECT 
    division, 
    product_code, 
    product, 
    total_sold_quantity, 
    rank_order, 
    variant
FROM Rank_Number
WHERE rank_order <= 3;
