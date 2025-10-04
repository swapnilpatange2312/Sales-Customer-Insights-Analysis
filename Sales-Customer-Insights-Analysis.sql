-- Advanced SQL Analysis – Northwind Database
-- Author: Swapnil Patange
-- Description: Complex SQL analytical queries on the Northwind sample database

-------------------------------------------------------------
-- 1. Top 5 customers with revenue, order count & average order value
-------------------------------------------------------------
SELECT 
    c.CompanyName AS Customer,
    COUNT(o.OrderID) AS TotalOrders,
    ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS TotalRevenue,
    ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) / COUNT(DISTINCT o.OrderID), 2) AS AvgOrderValue
FROM 
    Customers c
JOIN 
    Orders o ON c.CustomerID = o.CustomerID
JOIN 
    [Order Details] od ON o.OrderID = od.OrderID
GROUP BY 
    c.CustomerID
ORDER BY 
    TotalRevenue DESC
LIMIT 5;

-------------------------------------------------------------
-- 2. Year-over-Year revenue growth percentage
-------------------------------------------------------------
WITH yearly_sales AS (
    SELECT 
        STRFTIME('%Y', o.OrderDate) AS Year,
        ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS TotalRevenue
    FROM 
        Orders o
    JOIN 
        [Order Details] od ON o.OrderID = od.OrderID
    GROUP BY 
        STRFTIME('%Y', o.OrderDate)
)
SELECT 
    Year,
    TotalRevenue,
    ROUND(((TotalRevenue - LAG(TotalRevenue) OVER (ORDER BY Year)) 
           / LAG(TotalRevenue) OVER (ORDER BY Year)) * 100, 2) AS YoYGrowthPercent
FROM 
    yearly_sales;

-------------------------------------------------------------
-- 3. Top 3 employees by total sales handled
-------------------------------------------------------------
SELECT 
    e.FirstName || ' ' || e.LastName AS Employee,
    COUNT(DISTINCT o.OrderID) AS TotalOrders,
    COUNT(DISTINCT o.CustomerID) AS CustomersServed,
    ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS TotalRevenue,
    ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) / COUNT(DISTINCT o.OrderID), 2) AS AvgRevenuePerOrder
FROM 
    Employees e
JOIN 
    Orders o ON e.EmployeeID = o.EmployeeID
JOIN 
    [Order Details] od ON o.OrderID = od.OrderID
GROUP BY 
    e.EmployeeID
ORDER BY 
    TotalRevenue DESC
LIMIT 3;

-------------------------------------------------------------
-- 4. Top-selling product and top employee per category
-------------------------------------------------------------
WITH product_sales AS (
    SELECT 
        p.ProductID,
        p.ProductName,
        c.CategoryName,
        SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS TotalRevenue
    FROM 
        [Order Details] od
    JOIN 
        Products p ON od.ProductID = p.ProductID
    JOIN 
        Categories c ON p.CategoryID = c.CategoryID
    GROUP BY 
        p.ProductID, p.ProductName, c.CategoryName
),
top_products AS (
    SELECT 
        CategoryName,
        ProductName,
        MAX(TotalRevenue) AS MaxRevenue
    FROM 
        product_sales
    GROUP BY 
        CategoryName
)
SELECT 
    tp.CategoryName,
    tp.ProductName,
    tp.MaxRevenue,
    e.FirstName || ' ' || e.LastName AS TopEmployee,
    COUNT(o.OrderID) AS OrdersHandled
FROM 
    top_products tp
JOIN 
    Products p ON p.ProductName = tp.ProductName
JOIN 
    [Order Details] od ON od.ProductID = p.ProductID
JOIN 
    Orders o ON o.OrderID = od.OrderID
JOIN 
    Employees e ON o.EmployeeID = e.EmployeeID
GROUP BY 
    tp.CategoryName, tp.ProductName, e.EmployeeID
ORDER BY 
    tp.CategoryName, OrdersHandled DESC;

-------------------------------------------------------------
-- 5. Month with highest total revenue & top 3 products sold
-------------------------------------------------------------
WITH monthly_sales AS (
    SELECT 
        STRFTIME('%Y-%m', o.OrderDate) AS Month,
        SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS TotalRevenue
    FROM 
        Orders o
    JOIN 
        [Order Details] od ON o.OrderID = od.OrderID
    GROUP BY 
        STRFTIME('%Y-%m', o.OrderDate)
),
top_month AS (
    SELECT 
        Month
    FROM 
        monthly_sales
    ORDER BY 
        TotalRevenue DESC
    LIMIT 1
)
SELECT 
    tm.Month,
    p.ProductName,
    SUM(od.Quantity) AS UnitsSold,
    ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS ProductRevenue
FROM 
    top_month tm
JOIN 
    Orders o ON STRFTIME('%Y-%m', o.OrderDate) = tm.Month
JOIN 
    [Order Details] od ON o.OrderID = od.OrderID
JOIN 
    Products p ON od.ProductID = p.ProductID
GROUP BY 
    p.ProductName
ORDER BY 
    ProductRevenue DESC
LIMIT 3;

-------------------------------------------------------------
-- 6. Suppliers contributing more than 10% of total revenue
-------------------------------------------------------------
WITH supplier_revenue AS (
    SELECT 
        s.CompanyName AS Supplier,
        SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS SupplierRevenue
    FROM 
        [Order Details] od
    JOIN 
        Products p ON od.ProductID = p.ProductID
    JOIN 
        Suppliers s ON p.SupplierID = s.SupplierID
    GROUP BY 
        s.SupplierID
),
total_revenue AS (
    SELECT SUM(SupplierRevenue) AS TotalRevenue FROM supplier_revenue
)
SELECT 
    sr.Supplier,
    ROUND(sr.SupplierRevenue, 2) AS SupplierRevenue,
    ROUND((sr.SupplierRevenue / tr.TotalRevenue) * 100, 2) AS RevenuePercent
FROM 
    supplier_revenue sr, total_revenue tr
WHERE 
    (sr.SupplierRevenue / tr.TotalRevenue) * 100 > 10
ORDER BY 
    RevenuePercent DESC;

-------------------------------------------------------------
-- 7. Repeat customers with average gap between orders
-------------------------------------------------------------
WITH customer_orders AS (
    SELECT 
        CustomerID,
        OrderID,
        OrderDate,
        LAG(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate) AS PrevOrderDate
    FROM 
        Orders
)
SELECT 
    c.CompanyName,
    COUNT(co.OrderID) AS TotalOrders,
    ROUND(AVG(JULIANDAY(co.OrderDate) - JULIANDAY(co.PrevOrderDate)), 2) AS AvgDaysBetweenOrders
FROM 
    customer_orders co
JOIN 
    Customers c ON co.CustomerID = c.CustomerID
WHERE 
    co.PrevOrderDate IS NOT NULL
GROUP BY 
    c.CompanyName
HAVING 
    COUNT(co.OrderID) > 5
ORDER BY 
    TotalOrders DESC;

-------------------------------------------------------------
-- 8. Shipper with highest order value and % of total
-------------------------------------------------------------
WITH shipper_sales AS (
    SELECT 
        sh.CompanyName AS Shipper,
        SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS TotalShipperRevenue,
        COUNT(DISTINCT o.OrderID) AS OrdersCount
    FROM 
        Shippers sh
    JOIN 
        Orders o ON sh.ShipperID = o.ShipVia
    JOIN 
        [Order Details] od ON o.OrderID = od.OrderID
    GROUP BY 
        sh.ShipperID
),
total AS (
    SELECT SUM(TotalShipperRevenue) AS TotalRevenue FROM shipper_sales
)
SELECT 
    ss.Shipper,
    ROUND(ss.TotalShipperRevenue, 2) AS TotalRevenue,
    ROUND((ss.TotalShipperRevenue / t.TotalRevenue) * 100, 2) AS PercentOfTotal
FROM 
    shipper_sales ss, total t
ORDER BY 
    PercentOfTotal DESC
LIMIT 1;

-------------------------------------------------------------
-- 9. Top 3 countries by revenue & best employee in each
-------------------------------------------------------------
WITH country_sales AS (
    SELECT 
        c.Country,
        e.EmployeeID,
        e.FirstName || ' ' || e.LastName AS Employee,
        SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS Revenue
    FROM 
        Orders o
    JOIN 
        Customers c ON o.CustomerID = c.CustomerID
    JOIN 
        Employees e ON o.EmployeeID = e.EmployeeID
    JOIN 
        [Order Details] od ON o.OrderID = od.OrderID
    GROUP BY 
        c.Country, e.EmployeeID
),
ranked AS (
    SELECT 
        Country,
        Employee,
        Revenue,
        ROW_NUMBER() OVER (PARTITION BY Country ORDER BY Revenue DESC) AS rn
    FROM 
        country_sales
)
SELECT 
    Country,
    Employee AS TopEmployee,
    ROUND(Revenue, 2) AS EmployeeRevenue
FROM 
    ranked
WHERE 
    rn = 1
ORDER BY 
    Revenue DESC
LIMIT 3;

-------------------------------------------------------------
-- 10. Most profitable product by year
-------------------------------------------------------------
WITH yearly_product_sales AS (
    SELECT 
        STRFTIME('%Y', o.OrderDate) AS Year,
        p.ProductName,
        SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS Revenue
    FROM 
        Orders o
    JOIN 
        [Order Details] od ON o.OrderID = od.OrderID
    JOIN 
        Products p ON od.ProductID = p.ProductID
    GROUP BY 
        Year, p.ProductName
),
ranked AS (
    SELECT 
        Year,
        ProductName,
        Revenue,
        RANK() OVER (PARTITION BY Year ORDER BY Revenue DESC) AS rank
    FROM 
        yearly_product_sales
)
SELECT 
    Year,
    ProductName AS TopProduct,
    ROUND(Revenue, 2) AS TotalRevenue
FROM 
    ranked
WHERE 
    rank = 1
ORDER BY 
    Year;
