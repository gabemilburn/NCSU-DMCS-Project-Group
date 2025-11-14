-- CREATE SCHEMA csc540_project;
-- USE csc540_project;
CREATE DATABASE IF NOT EXISTS csc540_project;
USE csc540_project;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS ProductBatchIngredientBatch;
DROP TABLE IF EXISTS ProductBatch;
DROP TABLE IF EXISTS RecipeBOM;
DROP TABLE IF EXISTS Recipe;
DROP TABLE IF EXISTS Product;
DROP TABLE IF EXISTS ProductCategory;
DROP TABLE IF EXISTS DoNotCombineList;
DROP TABLE IF EXISTS IngredientBatch;
DROP TABLE IF EXISTS FormulationIngredientList;
DROP TABLE IF EXISTS Formulation;
DROP TABLE IF EXISTS Ingredient;
DROP TABLE IF EXISTS Manufacturer;
DROP TABLE IF EXISTS Supplier;
DROP TABLE IF EXISTS User;

SET FOREIGN_KEY_CHECKS = 1;

-- Main User Table
CREATE TABLE User (
    UserID VARCHAR(7) PRIMARY KEY,
    Username VARCHAR(255) NOT NULL UNIQUE,
    FirstName VARCHAR(255) NOT NULL,
    LastName VARCHAR(255) NOT NULL,
    UserRole VARCHAR(20) NOT NULL
		CHECK (UserRole IN ('VIEWER', 'MANUFACTURER', 'SUPPLIER'))
);

-- Supplier table
CREATE TABLE Supplier (
    SupplierID INT PRIMARY KEY AUTO_INCREMENT,
    UserID VARCHAR(7) NOT NULL UNIQUE,
    FOREIGN KEY (UserID) REFERENCES User(UserID)
		ON DELETE CASCADE
);

-- Manufacturer table
CREATE TABLE Manufacturer (
    ManufacturerID INT PRIMARY KEY AUTO_INCREMENT,
    UserID VARCHAR(7) NOT NULL UNIQUE,
    FOREIGN KEY (UserID) REFERENCES User(UserID)
		ON DELETE CASCADE
);

-- Main Ingredient table
CREATE TABLE Ingredient (
    IngredientID INT PRIMARY KEY AUTO_INCREMENT,
    IngredientName VARCHAR(255) UNIQUE NOT NULL,
    IsCompound BOOL NOT NULL
);

-- Supplier formulations table
CREATE TABLE Formulation (
    FormulationID INT PRIMARY KEY AUTO_INCREMENT,
    IngredientID INT NOT NULL,
    SupplierID INT NOT NULL,
    PackSize FLOAT NOT NULL CHECK (PackSize > 0),
    UnitPrice DECIMAL(10,2) NOT NULL CHECK (UnitPrice > 0),
    VersionNumber INT NOT NULL,
    EffectiveStartDate DATE NOT NULL,
    EffectiveEndDate DATE NOT NULL DEFAULT '9999-12-31',
    CHECK (
    PackSize > 0 AND 
    UnitPrice > 0 AND 
    EffectiveStartDate <= EffectiveEndDate),
    UNIQUE(SupplierID, IngredientID, VersionNumber),
    FOREIGN KEY (IngredientID) REFERENCES Ingredient(IngredientID)
        ON DELETE RESTRICT,
    FOREIGN KEY (SupplierID) REFERENCES Supplier(SupplierID)
        ON DELETE CASCADE
);

-- Ingredient List / Quantity for formulations
CREATE TABLE FormulationIngredientList (
	FormulationID INT NOT NULL,
    MaterialID INT NOT NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    PRIMARY KEY (FormulationID, MaterialID),
    FOREIGN KEY (FormulationID) REFERENCES Formulation(FormulationID)
        ON DELETE CASCADE,
    FOREIGN KEY (MaterialID) REFERENCES Ingredient(IngredientID)
		ON DELETE RESTRICT
);

-- Ingredient Batch table
CREATE TABLE IngredientBatch (
    LotID VARCHAR(255) PRIMARY KEY,
    FormulationID INT NOT NULL,
	ManufacturerID INT,
	Quantity FLOAT NOT NULL CHECK (Quantity >= 0),
    -- CostPerUnit DECIMAL(10,2) NOT NULL CHECK (CostPerUnit >= 0),
    ExpirationDate DATE NOT NULL,
    TotalQuantityOz FLOAT NOT NULL DEFAULT 0 CHECK (TotalQuantityOz >= 0),
    FOREIGN KEY (FormulationID) REFERENCES Formulation(FormulationID)
		ON DELETE RESTRICT,
	FOREIGN KEY (ManufacturerID) REFERENCES Manufacturer(ManufacturerID)
		ON DELETE CASCADE
);

-- Update DoNotCombineList table
CREATE TABLE DoNotCombineList (
    Ingredient1ID INT NOT NULL,
    Ingredient2ID INT NOT NULL,
    PRIMARY KEY (Ingredient1ID, Ingredient2ID),
    FOREIGN KEY (Ingredient1ID) REFERENCES Ingredient(IngredientID) ON DELETE CASCADE,
    FOREIGN KEY (Ingredient2ID) REFERENCES Ingredient(IngredientID) ON DELETE CASCADE,
    CONSTRAINT chk_ingredient1_less_than_ingredient2 CHECK (Ingredient1ID < Ingredient2ID)
);

-- Product category table
CREATE TABLE ProductCategory (
	CategoryID INT PRIMARY KEY AUTO_INCREMENT,
    CategoryName VARCHAR(255) NOT NULL UNIQUE
);

-- Product table
CREATE TABLE Product (
	ProductID INT PRIMARY KEY AUTO_INCREMENT,
    CategoryID INT NOT NULL,
    ManufacturerID INT NOT NULL,
    ProductName VARCHAR(255) NOT NULL,
    DefaultBatchSize INT NOT NULL CHECK (DefaultBatchSize > 0),
    UNIQUE (ManufacturerID, ProductName),
    FOREIGN KEY (CategoryID) REFERENCES ProductCategory(CategoryID)
		ON DELETE RESTRICT,
    FOREIGN KEY (ManufacturerID) REFERENCES Manufacturer(ManufacturerID)
		ON DELETE RESTRICT
);

-- Recipe table
CREATE TABLE Recipe (
	RecipeID INT PRIMARY KEY AUTO_INCREMENT,
	ProductID INT NOT NULL,
    CreationDate DATETIME DEFAULT CURRENT_TIMESTAMP,
	FOREIGN KEY (ProductID) REFERENCES Product(ProductID)
		ON DELETE CASCADE
);

-- Recipe BOM table
CREATE TABLE RecipeBOM (
	RecipeID INT NOT NULL,
    IngredientID INT NOT NULL,
    Quantity FLOAT NOT NULL CHECK (Quantity > 0),
    PRIMARY KEY (RecipeID, IngredientID),
    FOREIGN KEY (RecipeID) REFERENCES Recipe(RecipeID)
		ON DELETE CASCADE,
	FOREIGN KEY (IngredientID) REFERENCES Ingredient(IngredientID)
		ON DELETE RESTRICT
);

-- Product Batch table
CREATE TABLE ProductBatch (
    LotID VARCHAR(255) PRIMARY KEY,
    RecipeID INT NOT NULL,
    ProductionDate DATE NOT NULL DEFAULT (CURRENT_DATE()),
    ExpirationDate DATE NOT NULL,
    BatchQuantity INT NOT NULL CHECK (BatchQuantity >= 0),
    BatchCost   DECIMAL(10,2) NOT NULL DEFAULT 0,
    PerUnitCost DECIMAL(10,4) NOT NULL DEFAULT 0,
    CHECK (ExpirationDate > ProductionDate),
    FOREIGN KEY (RecipeID) REFERENCES Recipe(RecipeID)
        ON DELETE CASCADE
);

CREATE TABLE ProductBatchIngredientBatch (
    ProductLotID VARCHAR(255) NOT NULL,
    IngredientLotID VARCHAR(255) NOT NULL,
    QuantityUsed FLOAT NOT NULL CHECK (QuantityUsed > 0),
    PRIMARY KEY (ProductLotID, IngredientLotID),
    FOREIGN KEY (ProductLotID) REFERENCES ProductBatch(LotID)
        ON DELETE CASCADE,
    FOREIGN KEY (IngredientLotID) REFERENCES IngredientBatch(LotID)
        ON DELETE RESTRICT
);