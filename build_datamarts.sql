/*
--------------------------------------------------------------------------------
 PREREQUISITE 1: STAGING TABLES
--------------------------------------------------------------------------------
*/
CREATE TABLE IF NOT EXISTS staging_categories AS SELECT * FROM northwind.categories;
CREATE TABLE IF NOT EXISTS staging_customers AS SELECT * FROM northwind.customers;
CREATE TABLE IF NOT EXISTS staging_employees AS SELECT * FROM northwind.employees;
CREATE TABLE IF NOT EXISTS staging_order_details AS SELECT * FROM northwind.order_details;
CREATE TABLE IF NOT EXISTS staging_orders AS SELECT * FROM northwind.orders;
CREATE TABLE IF NOT EXISTS staging_products AS SELECT * FROM northwind.products;
CREATE TABLE IF NOT EXISTS staging_shippers AS SELECT * FROM northwind.shippers;
CREATE TABLE IF NOT EXISTS staging_suppliers AS SELECT * FROM northwind.suppliers;
/*
--------------------------------------------------------------------------------
 PREREQUISITE 2: COMMON DIMENSIONS
--------------------------------------------------------------------------------
*/

-- 1. DimDate (Date Dimension)
CREATE TABLE DimDate (
    DateID SERIAL PRIMARY KEY,
    Date DATE NOT NULL,
    Day INT NOT NULL,
    Month INT NOT NULL,
    Year INT NOT NULL,
    Quarter INT NOT NULL,
    WeekOfYear INT NOT NULL
);

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
CREATE TABLE DimCategory (
    CategoryID INT PRIMARY KEY,
    CategoryName VARCHAR(15),
    Description TEXT
);

INSERT INTO DimCategory (CategoryID, CategoryName, Description)
SELECT CategoryID, CategoryName, Description FROM staging_categories;


-- 3. DimProduct (Product Dimension)
CREATE TABLE DimProduct (
    ProductID INT PRIMARY KEY,
    ProductName VARCHAR(40),
    SupplierID INT,
    CategoryID INT,
    QuantityPerUnit VARCHAR(20),
    UnitPrice NUMERIC(10, 2),
    UnitsInStock INT
);

INSERT INTO DimProduct (ProductID, ProductName, SupplierID, CategoryID, QuantityPerUnit, UnitPrice, UnitsInStock)
SELECT ProductID, ProductName, SupplierID, CategoryID, QuantityPerUnit, UnitPrice, UnitsInStock
FROM staging_products;


/*
================================================================================
 DATA MART 1: SUPPLIERS
================================================================================
*/

-- 1.1: DimSupplier (Supplier Dimension)
CREATE TABLE DimSupplier (
    SupplierID INT PRIMARY KEY,
    CompanyName VARCHAR(40),
    ContactName VARCHAR(30),
    ContactTitle VARCHAR(30),
    Address VARCHAR(60),
    City VARCHAR(15),
    Region VARCHAR(15),
    PostalCode VARCHAR(10),
    Country VARCHAR(15),
    Phone VARCHAR(24)
);

INSERT INTO DimSupplier (SupplierID, CompanyName, ContactName, ContactTitle, Address, City, Region, PostalCode, Country, Phone)
SELECT 
    SupplierID, CompanyName, ContactName, ContactTitle, Address, City, Region, PostalCode, Country, Phone
FROM staging_suppliers;


-- 1.2: FactSupplierPurchases (Fact Table)
CREATE TABLE FactSupplierPurchases (
    PurchaseID SERIAL PRIMARY KEY,
    DateID INT,
    SupplierID INT,
    TotalPurchaseAmount DECIMAL(10, 2),
    NumberOfProducts INT,
    FOREIGN KEY (DateID) REFERENCES DimDate(DateID),
    FOREIGN KEY (SupplierID) REFERENCES DimSupplier(SupplierID)
);


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

-- 2.1: FactProductSales (Fact Table)
CREATE TABLE FactProductSales (
    FactSalesID SERIAL PRIMARY KEY,
    DateID INT,
    ProductID INT,
    QuantitySold INT,
    TotalSales DECIMAL(10,2),
    FOREIGN KEY (DateID) REFERENCES DimDate(DateID),
    FOREIGN KEY (ProductID) REFERENCES DimProduct(ProductID)
);

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
CREATE TABLE DimCustomer (
    CustomerID VARCHAR(5) PRIMARY KEY,
    CompanyName VARCHAR(40),
    ContactName VARCHAR(30),
    ContactTitle VARCHAR(30),
    Address VARCHAR(60),
    City VARCHAR(15),
    Region VARCHAR(15),
    PostalCode VARCHAR(10),
    Country VARCHAR(15),
    Phone VARCHAR(24),
    Fax VARCHAR(24)
);

INSERT INTO DimCustomer (CustomerID, CompanyName, ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax)
SELECT CustomerID, CompanyName, ContactTitle, Address, City, Region, PostalCode, Country, Phone, Fax
FROM staging_customers;


-- 3.2: FactCustomerSales (Fact Table)
CREATE TABLE FactCustomerSales (
    FactCustomerSalesID SERIAL PRIMARY KEY,
    DateID INT,
    CustomerID VARCHAR(5),
    TotalAmount DECIMAL(10,2),
    TotalQuantity INT,
    NumberOfTransactions INT,
    FOREIGN KEY (DateID) REFERENCES DimDate(DateID),
    FOREIGN KEY (CustomerID) REFERENCES DimCustomer(CustomerID)
);

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

-- DimEmployee (Employee Dimension)
CREATE TABLE DimEmployee (
    EmployeeID INT PRIMARY KEY,
    LastName VARCHAR(20),
    FirstName VARCHAR(10),
    Title VARCHAR(30),
    City VARCHAR(15),
    Country VARCHAR(15)
);

INSERT INTO DimEmployee (EmployeeID, LastName, FirstName, Title, City, Country)
SELECT EmployeeID, LastName, FirstName, Title, City, Country
FROM staging_employees;

-- DimShipper (Shipper Dimension)
CREATE TABLE DimShipper (
    ShipperID INT PRIMARY KEY,
    CompanyName VARCHAR(40),
    Phone VARCHAR(24)
);

INSERT INTO DimShipper (ShipperID, CompanyName, Phone)
SELECT ShipperID, CompanyName, Phone
FROM staging_shippers;


-- 4.2: FactSales (Fact Table)
CREATE TABLE FactSales ( 
    FactSalesID SERIAL PRIMARY KEY, 
    DateID INT, 
    CustomerID VARCHAR(5),
    ProductID INT, 
    EmployeeID INT, 
    CategoryID INT, 
    ShipperID INT, 
    SupplierID INT, 
    QuantitySold INT, 
    UnitPrice NUMERIC(10, 2),
    Discount REAL, 
    
    TotalAmount DECIMAL(10, 2) GENERATED ALWAYS AS (QuantitySold * UnitPrice * (1 - Discount::numeric)) STORED, 
    TaxAmount DECIMAL(10, 2) GENERATED ALWAYS AS ((QuantitySold * UnitPrice * (1 - Discount::numeric)) * 0.1) STORED, 
    
    FOREIGN KEY (DateID) REFERENCES DimDate(DateID), 
    FOREIGN KEY (CustomerID) REFERENCES DimCustomer(CustomerID), 
    FOREIGN KEY (ProductID) REFERENCES DimProduct (ProductID), 
    FOREIGN KEY (EmployeeID) REFERENCES DimEmployee (EmployeeID), 
    FOREIGN KEY (CategoryID) REFERENCES DimCategory (CategoryID), 
    FOREIGN KEY (ShipperID) REFERENCES DimShipper (ShipperID), 
    FOREIGN KEY (SupplierID) REFERENCES DimSupplier (SupplierID) 
);


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