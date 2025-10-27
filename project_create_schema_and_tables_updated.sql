-- CREATE SCHEMA csc540_project;
-- USE csc540_project;

-- Main User Table
CREATE TABLE User (
    UserID INT PRIMARY KEY AUTO_INCREMENT,
    Username VARCHAR(255) NOT NULL UNIQUE,
    FirstName VARCHAR(255) NOT NULL UNIQUE,
    LastName VARCHAR(255) NOT NULL UNIQUE,
    UserRole VARCHAR(20) NOT NULL
		CHECK (UserRole IN ('VIEWER', 'MANUFACTURER', 'SUPPLIER'))
);

-- Supplier table
CREATE TABLE Supplier (
    SupplierID INT PRIMARY KEY AUTO_INCREMENT,
    UserID INT NOT NULL UNIQUE,
    FOREIGN KEY (UserID) REFERENCES User(UserID)
		ON DELETE CASCADE
);

-- Manufacturer table
CREATE TABLE Manufacturer (
    ManufacturerID INT PRIMARY KEY AUTO_INCREMENT,
    UserID INT NOT NULL UNIQUE,
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
    EffectiveStartDate DATE DEFAULT (CURRENT_DATE()) NOT NULL,
    EffectiveEndDate DATE NOT NULL,
    CHECK (EffectiveStartDate < EffectiveEndDate),
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
-- Needs the trigger to generate LotID
CREATE TABLE IngredientBatch (
    LotID VARCHAR(255) PRIMARY KEY,
    FormulationID INT NOT NULL,
	ManufacturerID INT,
	Quantity FLOAT NOT NULL CHECK (Quantity >= 0),
    -- CostPerUnit DECIMAL(10,2) NOT NULL CHECK (CostPerUnit >= 0),
    ExpirationDate DATE NOT NULL,
    FOREIGN KEY (FormulationID) REFERENCES Formulation(FormulationID)
		ON DELETE RESTRICT,
	FOREIGN KEY (ManufacturerID) REFERENCES Manufacturer(ManufacturerID)
		ON DELETE CASCADE
);

-- Do not combine list table
CREATE TABLE DoNotCombineList (
    Ingredient1ID INT NOT NULL,
    Ingredient2ID INT NOT NULL,
    FOREIGN KEY (Ingredient1ID) REFERENCES Ingredient(IngredientID)
		ON DELETE CASCADE,
    FOREIGN KEY (Ingredient2ID) REFERENCES Ingredient(IngredientID)
		ON DELETE CASCADE,
	CHECK (Ingredient1ID < Ingredient2ID)
);

-- Product category table
CREATE TABLE ProductCategory (
	CategoryID INT PRIMARY KEY AUTO_INCREMENT,
    CategoryName VARCHAR(255) NOT NULL
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
-- Needs the trigger to generate LotID
CREATE TABLE ProductBatch (
    LotID VARCHAR(255) PRIMARY KEY,
    RecipeID INT NOT NULL,
    ProductionDate DATE NOT NULL DEFAULT (CURRENT_DATE()),
    ExpirationDate DATE NOT NULL,
    BatchQuantity INT NOT NULL CHECK (BatchQuantity >= 0),
    FOREIGN KEY (RecipeID) REFERENCES Recipe(RecipeID)
        ON DELETE CASCADE
);

CREATE TABLE ProductBatchIngredientBatch (
    ProductLotID VARCHAR(255) NOT NULL,
    IngredientLotID VARCHAR(255) NOT NULL,
    QuantityUsed INT NOT NULL CHECK (QuantityUsed > 0),
    PRIMARY KEY (ProductLotID, IngredientLotID),
    FOREIGN KEY (ProductLotID) REFERENCES ProductBatch(LotID)
        ON DELETE CASCADE,
    FOREIGN KEY (IngredientLotID) REFERENCES IngredientBatch(LotID)
        ON DELETE RESTRICT
);