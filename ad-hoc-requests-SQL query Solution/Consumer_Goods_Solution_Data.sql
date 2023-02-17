select * from dim_customer; -- 209
select * from dim_product; -- 397
select * from fact_gross_price; -- 579
select * from fact_manufacturing_cost; -- 579
select * from fact_pre_invoice_deductions; -- 418
select * from fact_sales_monthly;  -- 971631

/*
1.Provide the list of markets in which customer "Atliq Exclusive" operates its
business in the APAC region.
*/

SELECT market 
FROM dim_customer 
WHERE customer = "Atliq Exclusive" AND region = 'APAC'
GROUP BY market;

/* 
2.What is the percentage of unique product increase in 2021 vs. 2020? The
final output contains these fields,
unique_products_2020
unique_products_2021
percentage_chg 
*/

WITH unique_product_percentage_cte AS 
(
SELECT ( SELECT COUNT(DISTINCT product_code)
FROM fact_sales_monthly
WHERE fiscal_year = '2020') AS unique_products_2020,
(SELECT COUNT(DISTINCT product_code) 
FROM fact_sales_monthly
WHERE fiscal_year = '2021') AS unique_products_2021
)
SELECT unique_products_2020, unique_products_2021,
ROUND((unique_products_2021-unique_products_2020)*100/unique_products_2020,1) percentage_chg
FROM unique_product_percentage_cte

/*
3.Provide a report with all the unique product counts for each segment and
sort them in descending order of product counts. The final output contains
2 fields,
segment
product_count
*/

SET SESSION sql_mode = ''

SELECT segment, 
COUNT(DISTINCT product_code) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;

/*
4. Follow-up: Which segment had the most increase in unique products in
2021 vs 2020? The final output contains these fields,
segment
product_count_2020
product_count_2021
difference
*/

WITH product_count_2020 AS 
(
SELECT DP.segment,
COUNT(DISTINCT FSM.product_code) product_count_2020
FROM fact_sales_monthly FSM
LEFT JOIN dim_product DP ON DP.product_code = FSM.product_code
WHERE FSM.fiscal_year = '2020'
GROUP BY segment
),
product_count_2021 AS
(
SELECT DP.segment,
COUNT(DISTINCT FSM.product_code) product_count_2021
FROM fact_sales_monthly FSM
LEFT JOIN dim_product DP ON DP.product_code = FSM.product_code
WHERE FSM.fiscal_year = '2021'
GROUP BY segment
)
SELECT PC20.segment,PC20.product_count_2020,PC21.product_count_2021,
(PC21.product_count_2021-PC20.product_count_2020) difference
FROM product_count_2020 PC20
INNER JOIN product_count_2021 PC21
ON PC20.segment = PC21.segment
ORDER BY difference DESC

/*
5. Get the products that have the highest and lowest manufacturing costs.
The final output should contain these fields,
product_code
product
manufacturing_cost
*/

SET SESSION sql_mode = ''

SELECT DP.product_code, DP.product, ROUND(FMC.manufacturing_cost,2) AS manufacturing_cost
FROM dim_product AS DP
INNER JOIN fact_manufacturing_cost FMC ON FMC.product_code = DP.product_code
WHERE FMC.manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost)
OR 
FMC.manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost)
ORDER BY FMC.manufacturing_cost DESC;

/*
6. Generate a report which contains the top 5 customers who received an
average high pre_invoice_discount_pct for the fiscal year 2021 and in the
Indian market. The final output contains these fields,
customer_code
customer
average_discount_percentage
*/

WITH top5_customer AS (
SELECT FPID.customer_code, DC.customer,
CONCAT(ROUND(AVG(FPID.pre_invoice_discount_pct)*100,2),'%') average_discount_percentage,
DENSE_RANK() OVER (ORDER BY AVG(FPID.pre_invoice_discount_pct)DESC) `dense_rank`
FROM dim_customer DC
INNER JOIN 	fact_pre_invoice_deductions FPID ON FPID.customer_code = DC.customer_code
WHERE FPID.fiscal_year = '2021' AND DC.market = 'India'
GROUP BY FPID.customer_code,DC.customer
)
SELECT customer_code,customer,average_discount_percentage
FROM top5_customer
WHERE`dense_rank`<=5;

/*
7. Get the complete report of the Gross sales amount for the customer “Atliq
Exclusive” for each month. This analysis helps to get an idea of low and
high-performing months and take strategic decisions.
The final report contains these columns:
Month
Year
Gross sales Amount
*/

SET SESSION sql_mode = ''

SELECT MONTHNAME(FSM.date) month, YEAR(FSM.date) year,
SUM(FSM.sold_quantity*FGP.gross_price) gross_sales_amount
FROM fact_sales_monthly FSM
LEFT JOIN fact_gross_price FGP ON FGP.product_code = FSM.product_code
LEFT JOIN dim_customer DC ON DC.customer_code = FSM.customer_code
WHERE DC.customer = 'Atliq Exclusive'
GROUP BY month, year
ORDER BY year, MONTH(date)

/*
8. In which quarter of 2020, got the maximum total_sold_quantity? The final
output contains these fields sorted by the total_sold_quantity,
Quarter
total_sold_quantity
*/

SELECT QUARTER(date) quarter,
SUM(sold_quantity) total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = '2020'
GROUP BY quarter
ORDER BY total_sold_quantity DESC

/*
9. Which channel helped to bring more gross sales in the fiscal year 2021
and the percentage of contribution? The final output contains these fields,
channel
gross_sales_mln
percentage
*/

WITH sales_cte AS (
SELECT DC.channel channel,
SUM(FSM.sold_quantity*FGP.gross_price) gross_sales_mln,
RANK() OVER(ORDER BY SUM(FSM.sold_quantity*FGP.gross_price) DESC) rnk
FROM fact_sales_monthly FSM
LEFT JOIN fact_gross_price FGP ON FGP.product_code = FSM.product_code
LEFT JOIN dim_customer DC ON DC.customer_code = FSM.customer_code
WHERE FSM.fiscal_year = '2021'
GROUP BY DC.channel
)
SELECT channel, gross_sales_mln,
CONCAT(ROUND(gross_sales_mln*100/(SELECT SUM(gross_sales_mln)FROM sales_cte),2),'%') percentage
FROM sales_cte
WHERE rnk 
GROUP BY gross_sales_mln 

/*
10. Get the Top 3 products in each division that have a high
total_sold_quantity in the fiscal_year 2021? The final output contains these
fields,
division
product_code
product
total_sold_quantity
rank_order
*/

WITH rank_cte AS (
SELECT DP.division,DP.product_code,DP.product,
SUM(FSM.sold_quantity) total_sold_quantity,
ROW_NUMBER() OVER(PARTITION BY DP.division ORDER BY SUM(FSM.sold_quantity) DESC) rank_order
FROM fact_sales_monthly FSM
LEFT JOIN dim_product DP ON DP.product_code = FSM.product_code
WHERE FSM.fiscal_year = '2021'
GROUP BY DP.division,DP.product_code,DP.product
)
SELECT division,product_code,product,total_sold_quantity,rank_order
FROM rank_cte
WHERE rank_order <= 3;

 