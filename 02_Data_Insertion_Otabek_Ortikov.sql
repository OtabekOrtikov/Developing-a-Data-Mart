/*
--------------------------------------------------------------------------------
 PREREQUISITE 2: POPULATE COMMON DIMENSIONS
--------------------------------------------------------------------------------
*/

-- 1. DimDate (Date Dimension)
INSERT INTO DimDate (Date, Day, Month, Year, Quarter, WeekOfYear)
SELECT 
    d::DATE,
    EXTRACT(DAY FROM d) AS Day,
    EXTRACT(MONTH FROM d) AS Month,
    EXTRACT(YEAR FROM d) AS Year,
    EXTRACT(QUARTER FROM d) AS Quarter,
    EXTRACT(WEEK FROM d) AS WeekOfYear
FROM generate_series(
    (SELECT MIN(OrderDate) FROM staging_orders), 
    (SELECT MAX(OrderDate) FROM staging_orders), 
    '1 DAY'::interval
) d;

-- 2. DimCategory (Category Dimension)
INSERT INTO DimCategory (CategoryID, CategoryName, Description)
SELECT CategoryID, CategoryName, Description FROM staging_categories;

-- 3. DimProduct (Product Dimension)
-- **LOGIC FIX:** Removed 'WHERE Discontinued = false' to load all 20 products
-- from your dataset, which all had the 'Discontinued' flag set to true.
INSERT INTO DimProduct (ProductID, ProductName, SupplierID, CategoryID, QuantityPerUnit, UnitPrice, UnitsInStock)
SELECT ProductID, ProductName, SupplierID, CategoryID, QuantityPerUnit, UnitPrice, UnitsInStock
FROM staging_products;


/*
================================================================================
 DATA MART 1: SUPPLIERS
================================================================================
*/

-- 1.1: DimSupplier (Supplier Dimension)
INSERT INTO DimSupplier (SupplierID, CompanyName, ContactName, ContactTitle, Address, City, Region, PostalCode, Country, Phone)
SELECT 
    SupplierID, CompanyName, ContactName, ContactTitle, Address, City, Region, PostalCode, Country, Phone
FROM staging_suppliers;

-- 1.3: Populate Fact Table
INSERT INTO FactSupplierPurchases (DateID, SupplierID, TotalPurchaseAmount, NumberOfProducts)
SELECT 
    d.DateID,
    p.SupplierID, 
    SUM(od.UnitPrice * od.Quantity * (1 - od.Discount::numeric)) AS TotalPurchaseAmount,
    COUNT(DISTINCT od.ProductID) AS NumberOfProducts
FROM staging_order_details od
JOIN staging_products p ON od.ProductID = p.ProductID
JOIN staging_orders o ON od.OrderID = o.OrderID
JOIN DimDate d ON o.OrderDate = d.Date
GROUP BY d.DateID, p.SupplierID;


/*
================================================================================
 DATA MART 2: PRODUCTS
================================================================================
*/

-- 2.2: Populate Fact Table
INSERT INTO FactProductSales (DateID, ProductID, QuantitySold, TotalSales)
SELECT 
    d.DateID, 
    sod.ProductID, 
    SUM(sod.Quantity) AS QuantitySold, 
    SUM(sod.Quantity * sod.UnitPrice * (1 - sod.Discount::numeric)) AS TotalSales
FROM staging_order_details sod
JOIN staging_orders s ON sod.OrderID = s.OrderID
JOIN DimDate d ON s.OrderDate = d.Date
JOIN DimProduct p ON sod.ProductID = p.ProductID 
GROUP BY d.DateID, sod.ProductID;


/*
================================================================================
 DATA MART 3: CUSTOMERS
================================================================================
*/

-- 3.1: DimCustomer (Customer Dimension)
INSERT INTO DimCustomer (CustomerID, CompanyName, ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax)
SELECT CustomerID, CompanyName, ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax
FROM staging_customers;

-- 3.3: Populate Fact Table
INSERT INTO FactCustomerSales (DateID, CustomerID, TotalAmount, TotalQuantity, NumberOfTransactions)
SELECT
    d.DateID,
    c.CustomerID,
    SUM((od.UnitPrice * od.Quantity) * (1 - od.Discount::numeric)) AS TotalAmount,
    SUM(od.Quantity) AS TotalQuantity,
    COUNT(DISTINCT o.OrderID) AS NumberOfTransactions
FROM
    staging_orders AS o
JOIN
    staging_order_details AS od ON o.OrderID = od.OrderID
JOIN
    DimDate AS d ON d.Date = o.OrderDate
JOIN
    DimCustomer AS c ON c.CustomerID = o.CustomerID
GROUP BY
    d.DateID,
    c.CustomerID;


/*
================================================================================
 DATA MART 4: SALES (The "Super Mart")
================================================================================
*/

-- 4.1: Additional Dimensions for this Mart
INSERT INTO DimEmployee (EmployeeID, LastName, FirstName, Title, City, Country)
SELECT EmployeeID, LastName, FirstName, Title, City, Country
FROM staging_employees;

INSERT INTO DimShipper (ShipperID, CompanyName, Phone)
SELECT ShipperID, CompanyName, Phone
FROM staging_shippers;

-- 4.3: Populate Fact Table
INSERT INTO FactSales (
    DateID, CustomerID, ProductID, EmployeeID, CategoryID, ShipperID, SupplierID, 
    QuantitySold, UnitPrice, Discount
)
SELECT 
    d.DateID,
    dc.CustomerID,
    dp.ProductID,
    de.EmployeeID,
    dcat.CategoryID,
    ds.ShipperID,
    dsup.SupplierID,
    od.Quantity,
    od.UnitPrice,
    od.Discount
FROM staging_order_details od
JOIN staging_orders o ON od.OrderID = o.OrderID
JOIN DimDate d ON o.OrderDate = d.Date
JOIN DimCustomer dc ON o.CustomerID = dc.CustomerID
JOIN DimProduct dp ON od.ProductID = dp.ProductID
JOIN DimEmployee de ON o.EmployeeID = de.EmployeeID
JOIN DimShipper ds ON o.ShipVia = ds.ShipperID
JOIN DimCategory dcat ON dp.CategoryID = dcat.CategoryID
JOIN DimSupplier dsup ON dp.SupplierID = dsup.SupplierID;
