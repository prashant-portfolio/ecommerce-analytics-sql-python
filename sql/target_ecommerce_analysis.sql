
-- ============================================================================
-- E-Commerce Analytics Project
-- Dataset: Target Brazil E-Commerce
-- Tools: SQL (BigQuery)
-- ============================================================================

-- ============================================================================
-- 1. Database Exploration & Data Validation
-- ============================================================================
-- Column/Data Type Check
   
   Select 
   column_name as Customers, 
   data_type as Type 
   From TargetSQL.COLUMNS 
   Where table_name = 'Customers';

-- Order Date Range Check
   
   Select 
   min(order_purchase_timestamp) as Start_Date, 
   max(order_purchase_timestamp) as End_Date 
   from TargetSQL.orders;

-- Distinct Cities & States Count

   Select 
   count(distinct customer_city) as Total_Cities, 
   count(distinct customer_state) as Total_States 
   from TargetSQL.Customers;


-- ============================================================================
-- 2. Customer Analysis
-- ============================================================================
-- Customer Distribution by State

   Select
   a.customer_state, 
   a.Customer_Count, 
   dense_rank() over (order by a.Customer_Count desc) as Ranking 
   from (Select customer_state, count(distinct(customer_id)) as Customer_Count 
   from TargetSQL.Customers 
   group by customer_state 
   order by Customer_Count desc) a 
   order by Ranking asc;


-- ============================================================================
-- 3. Order Trends & Seasonality Analysis
-- ============================================================================
-- Analyze yearly order growth trend

   Select 
   a.Year, 
   a.Total_Orders, 
   round(((a.Total_Orders - a.prev_year) / a.prev_year) * 100 , 2) as Percentage_Growth 
   from (Select extract(year from order_purchase_timestamp) as Year, 
   count(*) as Total_Orders, 
   lag(count(*)) over (order by count(*) asc) as prev_year
   from TargetSQL.orders 
   group by Year 
   order by Year asc) a;

-- Analyze monthly order seasonality

   Select 
   a.Monthly_Orders, 
   a.Total_Orders, (case 
                        when ntile(3) over (order by a.Total_Orders) = 3 then "High" 
                        when ntile(3) over (order by a.Total_Orders) = 2 then "Medium" 
                        when ntile(3) over (order by a.Total_Orders) = 1 then "Low" end) as Order_Seasonality 
                        from 
                        (Select format_date("%B" , Date(order_purchase_timestamp)) as Monthly_Orders, 
                        count(*) as Total_Orders 
                        from TargetSQL.orders 
                        group by format_date("%B" , Date(order_purchase_timestamp)) ) a 
                        group by a.Monthly_Orders, a.Total_Orders 
                        order by a.Total_Orders desc;

-- Analyze peak customer ordering hours

   Select case 
              when hour_range between 0 AND 6 THEN '0-6 hrs' 
              when hour_range between 7 AND 12 THEN '07-12 hrs' 
              when hour_range between 13 AND 18 THEN '13-18 hrs' 
              when hour_range between 19 AND 23 THEN '19-23 hrs' end as Hours_Range, 
              sum(a.Total_Orders) as Total_Orders 
              from
              (Select 
              extract(hour from order_purchase_timestamp) as Hour_Range, 
              count(order_id) as Total_Orders, 
              count(*) as grand_total 
              from TargetSQL.orders 
              group by Hour_Range 
              order by Total_Orders desc) a 
              group by Hours_Range 
              order by Hours_Range asc;



-- ============================================================================
-- 4. Payment Analysis
-- ============================================================================
-- Analyze customer payment method preferences

   Select 
   a.Year, 
   a.Month, 
   a.payment_type, 
   a.Total_Orders 
   from 
   (Select 
   extract(year from o.order_purchase_timestamp) as Year, 
   format_date('%B' , o.order_purchase_timestamp) as Month, 
   extract(month from o.order_purchase_timestamp) as Month_Number, 
   p.payment_type, 
   count(distinct o.order_id) as Total_Orders 
   from TargetSQL.orders o 
   join TargetSQL.payments p
   on o.order_id = p.order_id 
   where o.order_purchase_timestamp is not null 
   group by Year,Month,Month_Number,p.payment_type) a 
   order by a.Year asc, a.Month_Number asc;

-- Analyze installment payment behavior

   Select 
   payment_installments as Installments, 
   count(distinct order_id) as Total_Orders 
   from TargetSQL.payments 
   where payment_installments >=1 
   group by payment_installments 
   order by Installments asc;


-- ============================================================================
-- 5. Delivery Performance Analysis
-- ============================================================================
-- Analyze delivery time performance

   with cte_1 as 
              (Select 
              c.customer_state,
              round(avg(date_diff(date(order_delivered_customer_date),
              date(order_purchase_timestamp),day)),2) as delivery_time
              from TargetSQL.Customers c
              join TargetSQL.orders o
              on c.customer_id = o.customer_id
              group by c.customer_state
              order by delivery_time desc),

        cte_2 as 
              (Select 
              c.customer_state,
              round(avg(date_diff(date(order_delivered_customer_date),
              date(order_purchase_timestamp),day)),2) as delivery_time
              from TargetSQL.Customers c
              join TargetSQL.orders o
              on c.customer_id = o.customer_id
              group by c.customer_state
              order by delivery_time asc)

   Select customer_state, delivery_time,'Bottom' as State_Rank
   from cte_2
   union all
   Select customer_state, delivery_time, 'Top' as State_Rank
   from cte_1
   order by State_Rank desc, delivery_time desc;

-- Analyze regional freight cost distribution

   with cte_1 as 
              (Select 
              c.customer_state, 
              round(avg(oi.freight_value),2) as Average_freight_value 
              from TargetSQL.Customers c 
              join TargetSQL.orders o 
              on c.customer_id = o.customer_id 
              join TargetSQL.order_items oi 
              on o.order_id = oi.order_id
              group by c.customer_state 
              order by Average_freight_value desc), 

        cte_2 as 
              (Select 
              c.customer_state, 
              round(avg(oi.freight_value),2) as Average_freight_value 
              from TargetSQL.Customers c 
              join TargetSQL.orders o 
              on c.customer_id = o.customer_id 
              join TargetSQL.order_items oi 
              on o.order_id = oi.order_id 
              group by c.customer_state 
              order by Average_freight_value asc) 
              
   Select customer_state, Average_freight_value , 'Bottom' as State_Rank 
   from cte_2 
   union all 
   Select customer_state, Average_freight_value , 'Top' as State_Rank 
   from cte_1 
   order by State_Rank desc, Average_freight_value desc;


-- ============================================================================
-- 6. Business Insights & Recommendations
-- ============================================================================

-- Strong growth trend observed in overall order volume across years.

-- Mid-year months show higher order activity, indicating seasonal demand patterns.

-- Afternoon hours contribute the highest customer order activity.

-- Customer demand is concentrated in a few key states.

-- Delivery performance and freight costs vary significantly across regions.

-- Most customers prefer single-payment transactions over multiple installments.



   