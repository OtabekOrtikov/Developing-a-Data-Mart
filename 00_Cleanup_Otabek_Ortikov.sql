/*
================================================================================
 Purpose: Safely drops all data mart tables to allow for a clean re-run.
 Use 'CASCADE' to handle dependencies automatically.
================================================================================
*/

-- Drop Fact Tables (depend on Dims)
DROP TABLE IF EXISTS FactSales CASCADE;
DROP TABLE IF EXISTS FactCustomerSales CASCADE;
DROP TABLE IF EXISTS FactProductSales CASCADE;
DROP TABLE IF EXISTS FactSupplierPurchases CASCADE;

-- Drop Dimension Tables
DROP TABLE IF EXISTS DimEmployee CASCADE;
DROP TABLE IF EXISTS DimShipper CASCADE;
DROP TABLE IF EXISTS DimCustomer CASCADE;
DROP TABLE IF EXISTS DimSupplier CASCADE;
DROP TABLE IF EXISTS DimProduct CASCADE;
DROP TABLE IF EXISTS DimCategory CASCADE;
DROP TABLE IF EXISTS DimDate CASCADE;

-- Drop Staging Tables
DROP TABLE IF EXISTS staging_categories CASCADE;
DROP TABLE IF EXISTS staging_customers CASCADE;
DROP TABLE IF EXISTS staging_employees CASCADE;
DROP TABLE IF EXISTS staging_order_details CASCADE;
DROP TABLE IF EXISTS staging_orders CASCADE;
DROP TABLE IF EXISTS staging_products CASCADE;
DROP TABLE IF EXISTS staging_shippers CASCADE;
DROP TABLE IF EXISTS staging_suppliers CASCADE;