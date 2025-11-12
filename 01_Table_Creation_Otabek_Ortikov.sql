/*
================================================================================
 Purpose: Creates the schema for all Staging, Dimension, and Fact tables.
================================================================================
*/

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

-- 2. DimCategory (Category Dimension)
CREATE TABLE DimCategory (
    CategoryID INT PRIMARY KEY,
    CategoryName VARCHAR(15),
    Description TEXT
);

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

-- DimShipper (Shipper Dimension)
CREATE TABLE DimShipper (
    ShipperID INT PRIMARY KEY,
    CompanyName VARCHAR(40),
    Phone VARCHAR(24)
);

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