/*========================================================
  DATABASE: Retail_Sales
  PURPOSE: Create normalized tables, load data, 
           check quality and run analytical queries
========================================================*/

USE Retail_Sales;
GO

--------------------------------------------------------
-- 1) CREATE TABLES
--------------------------------------------------------
-- Dimension Tables
/*
CREATE TABLE dbo.Customers (
    Customer_ID NVARCHAR(50) PRIMARY KEY,
    Customer_Name NVARCHAR(100),
    Segment NVARCHAR(50)
);

CREATE TABLE dbo.Products (
    Product_ID NVARCHAR(50) PRIMARY KEY,
    Product_Name NVARCHAR(150),
    Category NVARCHAR(50),
    Sub_Category NVARCHAR(50)
);

CREATE TABLE dbo.Location (
    Postal_Code INT PRIMARY KEY,
    Country NVARCHAR(50),
    City NVARCHAR(50),
    State NVARCHAR(50),
    Region NVARCHAR(50)
);

-- Fact Tables
CREATE TABLE dbo.Orders (
    Order_ID NVARCHAR(50) PRIMARY KEY,
    Order_Date DATE,
    Ship_Date DATE,
    Ship_Mode NVARCHAR(50),
    Customer_ID NVARCHAR(50),
    FOREIGN KEY (Customer_ID) REFERENCES dbo.Customers(Customer_ID)
);

CREATE TABLE dbo.Sales (
    Row_ID INT PRIMARY KEY,
    Order_ID NVARCHAR(50),
    Product_ID NVARCHAR(50),
    Postal_Code INT,
    Sales FLOAT,
    Quantity INT,
    Discount FLOAT,
    Profit FLOAT,
    FOREIGN KEY (Order_ID) REFERENCES dbo.Orders(Order_ID),
    FOREIGN KEY (Product_ID) REFERENCES dbo.Products(Product_ID),
    FOREIGN KEY (Postal_Code) REFERENCES dbo.Location(Postal_Code)
);
GO

--------------------------------------------------------
-- 2) LOAD DATA
--------------------------------------------------------
-- Load Customers
INSERT INTO dbo.Customers
SELECT DISTINCT Customer_ID, Customer_Name, Segment
FROM dbo.Superstore
WHERE Customer_ID IS NOT NULL;

-- Load Products
INSERT INTO dbo.Products
SELECT 
    Product_ID,
    MIN(Product_Name) AS Product_Name,
    MIN(Category) AS Category,
    MIN(Sub_Category) AS Sub_Category
FROM dbo.Superstore
WHERE Product_ID IS NOT NULL
GROUP BY Product_ID;

-- Load Location
INSERT INTO dbo.Location
SELECT 
    Postal_Code,
    MIN(Country) AS Country,
    MIN(City) AS City,
    MIN(State) AS State,
    MIN(Region) AS Region
FROM dbo.Superstore
WHERE Postal_Code IS NOT NULL
GROUP BY Postal_Code;

-- Load Orders
INSERT INTO dbo.Orders
SELECT DISTINCT Order_ID, Order_Date, Ship_Date, Ship_Mode, Customer_ID
FROM dbo.Superstore
WHERE Order_ID IS NOT NULL;

-- Load Sales
INSERT INTO dbo.Sales
SELECT Row_ID, Order_ID, Product_ID, Postal_Code, Sales, Quantity, Discount, Profit
FROM dbo.Superstore;
GO
*/
--------------------------------------------------------
-- 3) DATA QUALITY CHECKS
--------------------------------------------------------
-- Duplicate Checks
SELECT Customer_ID, COUNT(*) AS Duplicate_Count FROM dbo.Customers GROUP BY Customer_ID HAVING COUNT(*) > 1;
SELECT Product_ID, COUNT(*) AS Duplicate_Count FROM dbo.Products GROUP BY Product_ID HAVING COUNT(*) > 1;
SELECT Order_ID, COUNT(*) AS Duplicate_Count FROM dbo.Orders GROUP BY Order_ID HAVING COUNT(*) > 1;
SELECT Postal_Code, COUNT(*) AS Duplicate_Count FROM dbo.Location GROUP BY Postal_Code HAVING COUNT(*) > 1;
SELECT Row_ID, COUNT(*) AS Duplicate_Count FROM dbo.Sales GROUP BY Row_ID HAVING COUNT(*) > 1;

-- Orphan Records Check
SELECT s.*
FROM dbo.Sales s
LEFT JOIN dbo.Products p ON s.Product_ID = p.Product_ID
WHERE p.Product_ID IS NULL;
GO

--------------------------------------------------------
-- 4) BASIC EXPLORATION
--------------------------------------------------------
SELECT
    O.Order_ID,
    O.Order_Date,
    P.Product_Name,
    P.Category
FROM dbo.Orders O
LEFT JOIN dbo.Sales S ON O.Order_ID = S.Order_ID
LEFT JOIN dbo.Products P ON S.Product_ID = P.Product_ID;

SELECT
    C.Customer_ID,
    C.Customer_Name,
    C.Segment,
    L.Country,
    L.City,
    L.State
FROM dbo.Customers C
LEFT JOIN dbo.Orders O ON C.Customer_ID = O.Customer_ID
LEFT JOIN dbo.Sales S ON O.Order_ID = S.Order_ID
LEFT JOIN dbo.Location L ON S.Postal_Code = L.Postal_Code;

SELECT DISTINCT Segment FROM dbo.Customers;
GO

--------------------------------------------------------
-- 5) OVERALL KPI SUMMARY
--------------------------------------------------------
SELECT 
    SUM(Sales) AS Total_Sales,
    SUM(Quantity) AS Total_Quantity,
    SUM(Profit) AS Total_Profit,
    SUM(Discount) AS Total_Discount
FROM dbo.Sales;
SELECT COUNT(*) AS Total_Orders FROM dbo.Orders;
SELECT COUNT(*) AS Total_Customers FROM dbo.Customers;
SELECT COUNT(*) AS Total_Products FROM dbo.Products;
SELECT COUNT(*) AS Total_Sales_Rows FROM dbo.Sales;

GO

--------------------------------------------------------
-- 6) ORDER PROFIT ANALYSIS
--------------------------------------------------------
-- Orders with negative average profit
SELECT
    O.Order_ID,
    SUM(S.Profit) AS Avg_Loss_Per_Order,
    COUNT(*) AS Number_of_Products
FROM dbo.Orders O
LEFT JOIN dbo.Sales S ON O.Order_ID = S.Order_ID
GROUP BY O.Order_ID
HAVING SUM(S.Profit) < 0
ORDER BY SUM(S.Profit);

-- Profitable orders ranked by total profit
SELECT
    O.Order_ID,
    SUM(S.Profit) AS Net_Profit_Per_Order,
    COUNT(*) AS Number_of_Products,
    AVG(S.Profit) AS Avg_Profit_Per_Order
FROM dbo.Orders O
LEFT JOIN dbo.Sales S ON O.Order_ID = S.Order_ID
GROUP BY O.Order_ID
HAVING SUM(S.Profit) > 0
ORDER BY Net_Profit_Per_Order DESC;

-- Summary of losing orders
SELECT
    COUNT(*) AS Number_of_Losing_Orders,
    AVG(Order_Profit) AS Avg_Loss,
    MIN(Order_Profit) AS Worst_Loss,
    SUM(Order_Profit) AS Total_Loss
FROM (
    SELECT SUM(S.Profit) AS Order_Profit
    FROM dbo.Orders O
    LEFT JOIN dbo.Sales S ON O.Order_ID = S.Order_ID
    GROUP BY O.Order_ID
    HAVING SUM(S.Profit) < 0
) AS Losing_Orders;

-- Summary of profitable orders
SELECT
    COUNT(*) AS Number_of_Profitable_Orders,
    AVG(Order_Profit) AS Avg_Profit,
    MAX(Order_Profit) AS Best_Profit,
    SUM(Order_Profit) AS Total_Profit
FROM (
    SELECT SUM(S.Profit) AS Order_Profit
    FROM dbo.Orders O
    LEFT JOIN dbo.Sales S ON O.Order_ID = S.Order_ID
    GROUP BY O.Order_ID
    HAVING SUM(S.Profit) > 0
) AS Profitable_Orders;
GO

--------------------------------------------------------
-- 7) ORDER SALES AND QUANTITY ANALYSIS
--------------------------------------------------------
SELECT
    O.Order_ID,
    SUM(S.Sales) AS Net_Sales_Per_Order,
    COUNT(*) AS Number_of_Products,
    AVG(S.Sales) AS Avg_Sales_Per_Order
FROM dbo.Orders O
LEFT JOIN dbo.Sales S ON O.Order_ID = S.Order_ID
GROUP BY O.Order_ID
ORDER BY Net_Sales_Per_Order DESC;

SELECT
    O.Order_ID,
    SUM(S.Quantity) AS Net_Quantity_Per_Order,
    COUNT(*) AS Number_of_Products,
    AVG(S.Quantity) AS Avg_Quantity_Per_Order
FROM dbo.Orders O
LEFT JOIN dbo.Sales S ON O.Order_ID = S.Order_ID
GROUP BY O.Order_ID
ORDER BY Net_Quantity_Per_Order DESC;

-- Overall quantity statistics per order
SELECT
    COUNT(*) AS Total_Orders,
    AVG(Total_Quantity_Per_Order) AS Avg_Quantity_Per_Order,
    SUM(Total_Quantity_Per_Order) AS Total_Quantity,
    MAX(Total_Quantity_Per_Order) AS Max_Quantity_Per_Order
FROM (
    SELECT SUM(S.Quantity) AS Total_Quantity_Per_Order
    FROM dbo.Orders O
    LEFT JOIN dbo.Sales S ON O.Order_ID = S.Order_ID
    GROUP BY O.Order_ID
) AS t;

-- Overall sales statistics per order
SELECT
    COUNT(*) AS Total_Orders,
    AVG(Total_Sales_Per_Order) AS Avg_Sales_Per_Order,
    SUM(Total_Sales_Per_Order) AS Total_Sales,
    MAX(Total_Sales_Per_Order) AS Max_Sales_Per_Order
FROM (
    SELECT SUM(S.Sales) AS Total_Sales_Per_Order
    FROM dbo.Orders O
    LEFT JOIN dbo.Sales S ON O.Order_ID = S.Order_ID
    GROUP BY O.Order_ID
) AS t;
GO

--------------------------------------------------------
-- 8) SALES / PROFIT METRICS
--------------------------------------------------------
SELECT
    MAX(Sales) AS Max_Sale,
    MIN(Sales) AS Min_Sale,
    AVG(Sales) AS Avg_Sale
FROM dbo.Sales;

SELECT
    ROUND(100.0 * SUM(Profit) / NULLIF(SUM(Sales), 0), 4) AS Overall_Profit_Margin
FROM dbo.Sales;

SELECT
    L.State,
    ROUND(100.0 * SUM(S.Profit) / NULLIF(SUM(S.Sales), 0), 4) AS Profit_Margin_By_State
FROM dbo.Location L
LEFT JOIN dbo.Sales S ON L.Postal_Code = S.Postal_Code
GROUP BY L.State;


--------------------------------------------------------
-- 9) CUSTOMER / PRODUCT / ORDER BEHAVIOR
--------------------------------------------------------
SELECT
    C.Customer_Name,
    C.Customer_ID,
    COUNT(O.Order_ID) AS Orders_Per_Customer
FROM dbo.Customers C
LEFT JOIN dbo.Orders O ON C.Customer_ID = O.Customer_ID
GROUP BY C.Customer_ID, C.Customer_Name
ORDER BY Orders_Per_Customer DESC;

SELECT
    P.Product_ID,
    P.Product_Name,
    COUNT(DISTINCT O.Order_ID) AS Orders_Per_Product
FROM dbo.Products P
LEFT JOIN dbo.Sales S ON P.Product_ID = S.Product_ID
LEFT JOIN dbo.Orders O ON O.Order_ID = S.Order_ID
GROUP BY P.Product_ID, P.Product_Name
ORDER BY Orders_Per_Product DESC;

SELECT
    O.Order_ID,
    COUNT(DISTINCT S.Product_ID) AS Products_Per_Order
FROM dbo.Orders O
LEFT JOIN dbo.Sales S ON O.Order_ID = S.Order_ID
GROUP BY O.Order_ID
ORDER BY Products_Per_Order DESC;
GO

--------------------------------------------------------
-- 10) Comparative Analysis
--------------------------------------------------------

SELECT
    P.[Category] AS CategoryName ,
    SUM(S.Sales) Total_Sales_Per_Category,
    ROUND(100.0 * SUM(S.[Profit]) / NULLIF(SUM(S.[Sales]),0),2) AS Profit_Margin_Percent,
    ROUND(100.0 * SUM(S.Sales) / SUM(SUM(S.Sales)) OVER(), 2) AS Sales_Percentage
FROM [dbo].[Products] P
LEFT JOIN [dbo].[Sales] S
ON P.Product_ID=S.Product_ID
GROUP BY P.[Category]
ORDER BY SUM(S.Sales) DESC;

SELECT
    P.[Category] AS CategoryName ,
    SUM(S.[Profit]) Total_Profit_Per_Category,
    ROUND(100.0 * SUM(S.[Profit]) / NULLIF(SUM(S.[Sales]),0),2) AS Profit_Margin_Percent,
    ROUND(100.0 * SUM(S.Profit) / SUM(SUM(S.Profit)) OVER(), 2) AS Profit_Percentage
FROM [dbo].[Products] P 
LEFT JOIN [dbo].[Sales] S
ON P.Product_ID=S.Product_ID
GROUP BY P.[Category]
ORDER BY SUM(S.[Profit])DESC;




SELECT 
    L.[State],
    L.[Region],
    ROUND(100.0* SUM(S.[Profit])/NULLIF(SUM(S.[Sales]),0),2) AS Profit_Margin_Percent,
    ROUND(100.0*SUM(S.[Profit])/SUM(SUM(S.[Profit])) OVER(),2) AS Profit_Percentage
   

FROM [dbo].[Location] L
LEFT JOIN   [dbo].[Sales] S
ON L.[Postal_Code]=S.[Postal_Code]
GROUP BY  L.[State],L.[Region]
ORDER BY  Profit_Margin_Percent DESC;





SELECT 
    [Order_Date],
    [Ship_Date],
    [Ship_Mode]
FROM [dbo].[Orders]


SELECT 
   [Order_Date], 
   YEAR([Order_Date]) AS Year,
   MONTH([Order_Date]) AS Month,
   DATEPART(QUARTER,[Order_Date]) AS QUARTER,
   DATEPART(WEEKDAY,[Order_Date]) AS WeekDay
   
FROM [dbo].[Orders]
ORDER BY [Order_Date] DESC;


SELECT top 10
   YEAR(O.[Order_Date]) AS Year,
   MONTH(O.[Order_Date]) AS Month,
   ROUND(100.0* SUM(S.[Profit])/NULLIF(SUM(S.[Sales]),0),2) AS Profit_Margin_Percent,
   ROUND(100.0*SUM(S.[Profit])/SUM(SUM(S.[Profit])) OVER(),2) AS Profit_Percentage
   
FROM [dbo].[Orders] O
LEFT JOIN [dbo].[Sales] S
ON O.Order_ID = S.Order_ID
GROUP BY  YEAR(O.[Order_Date]),MONTH(O.[Order_Date]) 
ORDER BY  Profit_Margin_Percent DESC;




SELECT top 10
   YEAR(O.[Order_Date]) AS Year,
   DATEPART(QUARTER,[Order_Date]) AS QUARTER,
   ROUND(100.0* SUM(S.[Profit])/NULLIF(SUM(S.[Sales]),0),2) AS Profit_Margin_Percent,
   ROUND(100.0*SUM(S.[Profit])/SUM(SUM(S.[Profit])) OVER(),2) AS Profit_Percentage
   
FROM [dbo].[Orders] O
LEFT JOIN [dbo].[Sales] S
ON O.Order_ID = S.Order_ID
GROUP BY  YEAR(O.[Order_Date]),DATEPART(QUARTER,[Order_Date]) 
ORDER BY  Profit_Margin_Percent DESC;

GO
-------------------------
--VIEWS
-------------------------
CREATE OR ALTER VIEW dbo.vw_overall_kpi_summary AS

SELECT 
    SUM(Sales) AS Total_Sales,
    SUM(Quantity) AS Total_Quantity,
    SUM(Profit) AS Total_Profit,
    COUNT(*) AS Total_Orders
FROM dbo.Sales;
GO


CREATE OR ALTER VIEW dbo.vw_sales_by_category AS
SELECT
    P.Category AS CategoryName,
    SUM(S.Sales) AS Total_Sales,
    SUM(S.Profit) AS Total_Profit,
    ROUND(100.0 * SUM(S.Profit) / NULLIF(SUM(S.Sales), 0), 2) AS Profit_Margin_Percent
FROM dbo.Products P
LEFT JOIN dbo.Sales S ON P.Product_ID = S.Product_ID
GROUP BY P.Category;
GO


CREATE OR ALTER VIEW dbo.vw_profit_by_state_region AS
SELECT 
    L.State,
    L.Region,
    SUM(S.Sales) AS Total_Sales,
    SUM(S.Profit) AS Total_Profit,
    ROUND(100.0 * SUM(S.Profit) / NULLIF(SUM(S.Sales), 0), 2) AS Profit_Margin_Percent
FROM dbo.Location L
LEFT JOIN dbo.Sales S ON L.Postal_Code = S.Postal_Code
GROUP BY L.State, L.Region;
GO


CREATE OR ALTER VIEW dbo.vw_profit_margin_by_month AS
SELECT
    YEAR(O.Order_Date) AS [Year],
    MONTH(O.Order_Date) AS [Month],
    SUM(S.Sales) AS Total_Sales,
    SUM(S.Profit) AS Total_Profit,
    ROUND(100.0 * SUM(S.Profit) / NULLIF(SUM(S.Sales), 0), 2) AS Profit_Margin_Percent
FROM dbo.Orders O
LEFT JOIN dbo.Sales S ON O.Order_ID = S.Order_ID
GROUP BY YEAR(O.Order_Date), MONTH(O.Order_Date);
GO


CREATE OR ALTER VIEW dbo.vw_orders_per_customer AS
SELECT
    C.Customer_Name,
    COUNT(O.Order_ID) AS Orders_Per_Customer
FROM dbo.Customers C
LEFT JOIN dbo.Orders O ON C.Customer_ID = O.Customer_ID
GROUP BY C.Customer_Name;
GO


CREATE OR ALTER VIEW dbo.vw_order_profit_summary AS
SELECT
    SUM(CASE WHEN Order_Profit < 0 THEN 1 ELSE 0 END) AS Losing_Orders,
    SUM(CASE WHEN Order_Profit > 0 THEN 1 ELSE 0 END) AS Profitable_Orders
FROM (
    SELECT 
        SUM(S.Profit) AS Order_Profit
    FROM dbo.Orders O
    LEFT JOIN dbo.Sales S ON O.Order_ID = S.Order_ID
    GROUP BY O.Order_ID
) t;
GO



CREATE OR ALTER VIEW dbo.vw_avg_sales_per_order AS
SELECT
    COUNT(*) AS Total_Orders,
    AVG(Total_Sales_Per_Order) AS Avg_Order_Value
FROM (
    SELECT SUM(S.Sales) AS Total_Sales_Per_Order
    FROM dbo.Orders O
    LEFT JOIN dbo.Sales S ON O.Order_ID = S.Order_ID
    GROUP BY O.Order_ID
) t;
GO


CREATE OR ALTER VIEW dbo.vw_avg_quantity_per_order AS
SELECT
    AVG(Total_Quantity_Per_Order) AS Avg_Quantity_Per_Order
FROM (
    SELECT SUM(S.Quantity) AS Total_Quantity_Per_Order
    FROM dbo.Orders O
    LEFT JOIN dbo.Sales S ON O.Order_ID = S.Order_ID
    GROUP BY O.Order_ID
) t;
GO

CREATE OR ALTER VIEW dbo.vw_products_per_order AS
SELECT
    AVG(Products_Per_Order * 1.0) AS Avg_Products_Per_Order
FROM (
    SELECT
        O.Order_ID,
        COUNT(DISTINCT S.Product_ID) AS Products_Per_Order
    FROM dbo.Orders O
    LEFT JOIN dbo.Sales S 
        ON O.Order_ID = S.Order_ID
    GROUP BY O.Order_ID
) t;
GO



CREATE OR ALTER VIEW dbo.vw_shipping_analysis AS
SELECT
    Ship_Mode,
    AVG(DATEDIFF(DAY, Order_Date, Ship_Date)) AS Avg_Shipping_Days
FROM dbo.Orders
GROUP BY Ship_Mode;
GO






































