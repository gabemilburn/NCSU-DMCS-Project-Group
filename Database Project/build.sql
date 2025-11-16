-- CREATE SCHEMA csc540_project;
-- USE csc540_project;
CREATE DATABASE IF NOT EXISTS csc540_project;
USE csc540_project;


#### BUILD DATABASE ########################################
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


#### TRIGGERS ########################################

DROP TRIGGER IF EXISTS csc540_project.before_insert_ingredient_batch;
DROP TRIGGER IF EXISTS csc540_project.before_insert_product_batch;
DROP TRIGGER IF EXISTS csc540_project.prevent_expired_consumption;
DROP TRIGGER IF EXISTS csc540_project.before_insert_user;

DELIMITER $$
CREATE TRIGGER before_insert_ingredient_batch
BEFORE INSERT ON IngredientBatch
FOR EACH ROW
BEGIN
    DECLARE v_IngredientID INT;
    DECLARE v_SupplierID INT;
    DECLARE v_NewBatchID INT;
    DECLARE v_msg VARCHAR(255);

    SELECT IngredientID, SupplierID
    INTO v_IngredientID, v_SupplierID
    FROM Formulation
    WHERE FormulationID = NEW.FormulationID
    LIMIT 1;

    IF v_IngredientID IS NULL OR v_SupplierID IS NULL THEN
        SET v_msg = CONCAT('Invalid FormulationID for IngredientBatch: ', NEW.FormulationID);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- BatchID is the max of the suppliers current BatchIDs + 1 (in LotID)
    SELECT COALESCE(MAX(CAST(SUBSTRING_INDEX(LotID, '-B', -1) AS UNSIGNED)), 0) INTO v_NewBatchID
    FROM IngredientBatch
    WHERE LotID LIKE CONCAT(v_IngredientID, '-', v_SupplierID, '-%');
    SET v_NewBatchID = v_NewBatchID + 1;

    SET NEW.LotID = CONCAT(v_IngredientID, '-', v_SupplierID, '-B', LPAD(v_NewBatchID, 4, '0'));
END$$

CREATE TRIGGER before_insert_product_batch
BEFORE INSERT ON ProductBatch
FOR EACH ROW
BEGIN
    DECLARE v_ProductID INT;
    DECLARE v_ManufacturerID INT;
    DECLARE v_UserID VARCHAR(7); 
    DECLARE v_NewBatchID INT;
    DECLARE v_msg VARCHAR(255);

    -- Get ProductID from Recipe
    SELECT ProductID
    INTO v_ProductID
    FROM Recipe
    WHERE RecipeID = NEW.RecipeID
    LIMIT 1;

    IF v_ProductID IS NULL THEN
        SET v_msg = CONCAT('Invalid RecipeID for ProductBatch: ', NEW.RecipeID);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    SELECT ManufacturerID
    INTO v_ManufacturerID
    FROM Product
    WHERE ProductID = v_ProductID
    LIMIT 1;

    IF v_ManufacturerID IS NULL THEN
        SET v_msg = CONCAT('Product has no ManufacturerID: product ', v_ProductID);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    SELECT UserID
    INTO v_UserID
    FROM Manufacturer
    WHERE ManufacturerID = v_ManufacturerID
    LIMIT 1;

    IF v_UserID IS NULL THEN
        SET v_msg = CONCAT('Manufacturer has no UserID: manufacturer ', v_ManufacturerID);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    SELECT COALESCE(MAX(CAST(SUBSTRING_INDEX(LotID, '-B', -1) AS UNSIGNED)), 0)
    INTO v_NewBatchID
    FROM ProductBatch
    WHERE LotID LIKE CONCAT(v_ProductID, '-', v_UserID, '-B%');  
    
    SET v_NewBatchID = v_NewBatchID + 1;
    SET NEW.LotID = CONCAT(v_ProductID, '-', v_UserID, '-B', LPAD(v_NewBatchID, 4, '0'));
END$$

CREATE TRIGGER prevent_expired_consumption
BEFORE UPDATE ON IngredientBatch
FOR EACH ROW
BEGIN
    IF NOW() > OLD.ExpirationDate THEN
        IF NEW.TotalQuantityOz <> OLD.TotalQuantityOz THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot consume ingredient batch: Past expiration date';
        END IF;
    END IF;
END$$

CREATE TRIGGER before_insert_user
BEFORE INSERT ON User
FOR EACH ROW
BEGIN
    DECLARE prefix VARCHAR(4);
    DECLARE max_number INT;

    IF NEW.UserRole = 'MANUFACTURER' THEN
        SET prefix = 'MFG';
    ELSEIF NEW.UserRole = 'SUPPLIER' THEN
        SET prefix = 'SUP';
    ELSEIF NEW.UserRole = 'VIEWER' THEN
        SET prefix = 'VIEW';
    END IF;

    SELECT COALESCE(MAX(CAST(SUBSTRING(UserID, 4) AS UNSIGNED)), 0)
    INTO max_number
    FROM User
    WHERE UserRole = NEW.UserRole;

    SET NEW.UserID = CONCAT(prefix, LPAD(max_number + 1, 3, '0'));
END$$

DROP TRIGGER IF EXISTS after_insert_consumption$$
CREATE TRIGGER after_insert_consumption
AFTER INSERT ON ProductBatchIngredientBatch
FOR EACH ROW
BEGIN
    DECLARE v_pack_size FLOAT;
    
    SELECT f.PackSize INTO v_pack_size
    FROM IngredientBatch ib
    JOIN Formulation f ON ib.FormulationID = f.FormulationID
    WHERE ib.LotID = NEW.IngredientLotID;
    
    UPDATE IngredientBatch
    SET TotalQuantityOz = TotalQuantityOz - NEW.QuantityUsed,
        Quantity = (TotalQuantityOz - NEW.QuantityUsed) / v_pack_size
    WHERE LotID = NEW.IngredientLotID;
END$$


DROP TRIGGER IF EXISTS before_insert_do_not_combine$$
CREATE TRIGGER before_insert_do_not_combine
BEFORE INSERT ON DoNotCombineList
FOR EACH ROW
BEGIN
    DECLARE is_compound1 BOOLEAN;
    DECLARE is_compound2 BOOLEAN;
    DECLARE ingredient1_name VARCHAR(255);
    DECLARE ingredient2_name VARCHAR(255);
    DECLARE error_msg VARCHAR(500); 

    SELECT IsCompound, IngredientName INTO is_compound1, ingredient1_name
    FROM Ingredient
    WHERE IngredientID = NEW.Ingredient1ID;
    
    SELECT IsCompound, IngredientName INTO is_compound2, ingredient2_name
    FROM Ingredient
    WHERE IngredientID = NEW.Ingredient2ID;
    
    IF is_compound1 THEN
        SET error_msg = CONCAT('Cannot add DNC rule: ', ingredient1_name, 
                               ' (ID:', NEW.Ingredient1ID, 
                               ') is a COMPOUND ingredient. Only ATOMIC ingredients allowed.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_msg;
    END IF;
    
    IF is_compound2 THEN
        SET error_msg = CONCAT('Cannot add DNC rule: ', ingredient2_name, 
                               ' (ID:', NEW.Ingredient2ID, 
                               ') is a COMPOUND ingredient. Only ATOMIC ingredients allowed.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_msg;
    END IF;
END$$

DELIMITER ;

#### SUPPLIER PROCEDURES ########################################

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_view_formulation_details$$
CREATE PROCEDURE sp_view_formulation_details(
    IN p_formulation_id INT
)
BEGIN
    SELECT 
        f.FormulationID, f.IngredientID, i.IngredientName, i.IsCompound,
        f.SupplierID, f.PackSize, f.UnitPrice, f.VersionNumber,
        f.EffectiveStartDate, f.EffectiveEndDate
    FROM Formulation f
    INNER JOIN Ingredient i ON f.IngredientID = i.IngredientID
    WHERE f.FormulationID = p_formulation_id;
    
    SELECT 
        fil.MaterialID, i.IngredientName as MaterialName, fil.Quantity
    FROM FormulationIngredientList fil
    INNER JOIN Ingredient i ON fil.MaterialID = i.IngredientID
    WHERE fil.FormulationID = p_formulation_id
    ORDER BY fil.Quantity DESC;
END$$

DROP PROCEDURE IF EXISTS sp_view_do_not_combine_list$$
CREATE PROCEDURE sp_view_do_not_combine_list()
BEGIN
    SELECT 
        dnc.Ingredient1ID, i1.IngredientName as Ingredient1Name,
        dnc.Ingredient2ID, i2.IngredientName as Ingredient2Name
    FROM DoNotCombineList dnc
    INNER JOIN Ingredient i1 ON dnc.Ingredient1ID = i1.IngredientID
    INNER JOIN Ingredient i2 ON dnc.Ingredient2ID = i2.IngredientID
    ORDER BY i1.IngredientName, i2.IngredientName;
END$$

DROP PROCEDURE IF EXISTS sp_get_formulation_conflicts$$
CREATE PROCEDURE sp_get_formulation_conflicts(
    IN p_formulation_id INT
)
BEGIN
    SELECT DISTINCT
        m1.MaterialID AS Ingredient1ID,
        i1.IngredientName AS Ingredient1Name,
        m2.MaterialID AS Ingredient2ID,
        i2.IngredientName AS Ingredient2Name
    FROM FormulationIngredientList m1
    INNER JOIN FormulationIngredientList m2 
        ON m1.FormulationID = m2.FormulationID
       AND m1.MaterialID < m2.MaterialID
    INNER JOIN Ingredient i1 ON m1.MaterialID = i1.IngredientID
    INNER JOIN Ingredient i2 ON m2.MaterialID = i2.IngredientID
    INNER JOIN DoNotCombineList dnc
        ON (dnc.Ingredient1ID = m1.MaterialID AND dnc.Ingredient2ID = m2.MaterialID)
         OR (dnc.Ingredient2ID = m1.MaterialID AND dnc.Ingredient1ID = m2.MaterialID)
    WHERE m1.FormulationID = p_formulation_id;
END$$

DELIMITER ;

#### MANUFACTURER PROCEDURES ########################################

DELIMITER $$
DROP PROCEDURE IF EXISTS sp_view_manufacturer_products$$
CREATE PROCEDURE sp_view_manufacturer_products(
    IN p_manufacturer_id INT
)
BEGIN
    SELECT 
        p.ProductID,
        p.ProductName,
        c.CategoryName,
        p.DefaultBatchSize
    FROM Product p
    JOIN ProductCategory c ON p.CategoryID = c.CategoryID
    WHERE p.ManufacturerID = p_manufacturer_id
    ORDER BY p.ProductName;
END$$

DROP PROCEDURE IF EXISTS sp_view_manufacturer_ingredient_inventory$$
CREATE PROCEDURE sp_view_manufacturer_ingredient_inventory(
    IN p_manufacturer_id INT
)
BEGIN
    SELECT 
        ib.LotID,
        i.IngredientID,
        i.IngredientName,
        f.PackSize,
        ib.Quantity AS NumPacks,
        ib.TotalQuantityOz,
        ib.ExpirationDate,
        CASE 
            WHEN ib.ExpirationDate < CURDATE() THEN 'EXPIRED'
            WHEN DATEDIFF(ib.ExpirationDate, CURDATE()) <= 7 THEN 'EXPIRING SOON'
            ELSE 'GOOD'
        END AS Status
    FROM IngredientBatch ib
    INNER JOIN Formulation f ON ib.FormulationID = f.FormulationID
    INNER JOIN Ingredient i ON f.IngredientID = i.IngredientID
    WHERE ib.ManufacturerID = p_manufacturer_id
      AND ib.TotalQuantityOz > 0 
    ORDER BY i.IngredientName, ib.ExpirationDate;
END$$

DROP PROCEDURE IF EXISTS sp_view_manufacturer_product_batches$$
CREATE PROCEDURE sp_view_manufacturer_product_batches(
    IN p_manufacturer_id INT
)
BEGIN
    SELECT
        pb.LotID,
        pr.ProductID,
        pr.ProductName,
        pb.ProductionDate,
        pb.ExpirationDate,
        pb.BatchQuantity
    FROM ProductBatch pb
    INNER JOIN Recipe r ON pb.RecipeID = r.RecipeID
    INNER JOIN Product pr ON r.ProductID = pr.ProductID
    WHERE pr.ManufacturerID = p_manufacturer_id
    ORDER BY pb.ProductionDate DESC, pb.LotID DESC;
END$$

DROP PROCEDURE IF EXISTS sp_get_recipe_conflicts$$
CREATE PROCEDURE sp_get_recipe_conflicts(
    IN p_recipe_id INT
)
BEGIN
    SELECT 
        i1.IngredientID AS Ingredient1ID,
        i1.IngredientName AS Ingredient1Name,
        i2.IngredientID AS Ingredient2ID,
        i2.IngredientName AS Ingredient2Name
    FROM RecipeBOM rb1
    JOIN RecipeBOM rb2 ON rb1.RecipeID = rb2.RecipeID 
                       AND rb1.IngredientID < rb2.IngredientID
    JOIN DoNotCombineList dnc 
        ON (dnc.Ingredient1ID = rb1.IngredientID AND dnc.Ingredient2ID = rb2.IngredientID)
        OR (dnc.Ingredient2ID = rb1.IngredientID AND dnc.Ingredient1ID = rb2.IngredientID)
    JOIN Ingredient i1 ON rb1.IngredientID = i1.IngredientID
    JOIN Ingredient i2 ON rb2.IngredientID = i2.IngredientID
    WHERE rb1.RecipeID = p_recipe_id;
END$$

DROP PROCEDURE IF EXISTS sp_report_nearly_out_of_stock$$
CREATE PROCEDURE sp_report_nearly_out_of_stock(
    IN p_manufacturer_id INT
)
BEGIN
    SELECT 
        i.IngredientID,
        i.IngredientName,
        COALESCE(SUM(ib.TotalQuantityOz), 0) AS TotalOnHandOz,
        rb.Quantity AS QuantityPerUnit,
        p.DefaultBatchSize AS RequiredForOneBatch,
        (rb.Quantity * p.DefaultBatchSize) AS RequiredForOneBatchTotal,
        p.ProductID,
        p.ProductName
    FROM Product p
    INNER JOIN (
        SELECT ProductID, MAX(RecipeID) AS LatestRecipeID
        FROM Recipe
        GROUP BY ProductID
    ) latest_recipe ON latest_recipe.ProductID = p.ProductID
    INNER JOIN Recipe r ON r.RecipeID = latest_recipe.LatestRecipeID
    INNER JOIN RecipeBOM rb ON rb.RecipeID = r.RecipeID
    INNER JOIN Ingredient i ON rb.IngredientID = i.IngredientID
    LEFT JOIN IngredientBatch ib 
        ON ib.ManufacturerID = p_manufacturer_id
       AND ib.ExpirationDate >= CURDATE()
       AND EXISTS (
           SELECT 1 FROM Formulation f 
           WHERE f.FormulationID = ib.FormulationID 
             AND f.IngredientID = i.IngredientID
       )
    WHERE p.ManufacturerID = p_manufacturer_id
    GROUP BY 
        i.IngredientID, 
        i.IngredientName, 
        rb.Quantity, 
        p.ProductID, 
        p.ProductName, 
        p.DefaultBatchSize
    HAVING TotalOnHandOz < (rb.Quantity * p.DefaultBatchSize)
    ORDER BY TotalOnHandOz ASC;
END$$

DROP PROCEDURE IF EXISTS sp_report_almost_expired$$
CREATE PROCEDURE sp_report_almost_expired(
    IN p_manufacturer_id INT,
    IN p_days_threshold INT
)
BEGIN
    SELECT 
        ib.LotID,
        i.IngredientID,
        i.IngredientName,
        ib.TotalQuantityOz,
        ib.ExpirationDate,
        DATEDIFF(ib.ExpirationDate, CURDATE()) AS DaysUntilExpiry,
        CASE 
            WHEN ib.ExpirationDate < CURDATE() THEN 'EXPIRED'
            WHEN DATEDIFF(ib.ExpirationDate, CURDATE()) <= p_days_threshold THEN 'EXPIRING SOON'
            ELSE 'OK'
        END AS Status
    FROM IngredientBatch ib
    INNER JOIN Formulation f ON ib.FormulationID = f.FormulationID
    INNER JOIN Ingredient i ON f.IngredientID = i.IngredientID
    WHERE ib.ManufacturerID = p_manufacturer_id
      AND ib.TotalQuantityOz > 0
      AND DATEDIFF(ib.ExpirationDate, CURDATE()) <= p_days_threshold
    ORDER BY ib.ExpirationDate ASC, i.IngredientName;
END$$

DROP PROCEDURE IF EXISTS sp_get_batch_cost_summary$$
CREATE PROCEDURE sp_get_batch_cost_summary(
    IN p_product_lot_id VARCHAR(255)
)
BEGIN
    SELECT 
        pb.LotID,
        p.ProductID,
        p.ProductName,
        pb.BatchQuantity,
        pb.ProductionDate,
        pb.ExpirationDate,
        pb.BatchCost,
        pb.PerUnitCost
    FROM ProductBatch pb
    INNER JOIN Recipe r ON pb.RecipeID = r.RecipeID
    INNER JOIN Product p ON r.ProductID = p.ProductID
    WHERE pb.LotID = p_product_lot_id;
    
    SELECT 
        i.IngredientID,
        i.IngredientName,
        pbib.IngredientLotID,
        pbib.QuantityUsed AS OzUsed,
        f.PackSize,
        f.UnitPrice AS PricePerPack,
        ROUND((pbib.QuantityUsed / f.PackSize) * f.UnitPrice, 2) AS TotalCost
    FROM ProductBatchIngredientBatch pbib
    INNER JOIN IngredientBatch ib ON pbib.IngredientLotID = ib.LotID
    INNER JOIN Formulation f ON ib.FormulationID = f.FormulationID
    INNER JOIN Ingredient i ON f.IngredientID = i.IngredientID
    WHERE pbib.ProductLotID = p_product_lot_id
    ORDER BY TotalCost DESC;
END$$

DROP PROCEDURE IF EXISTS sp_trace_recall$$
CREATE PROCEDURE sp_trace_recall(
    IN p_ingredient_id    INT,
    IN p_ingredient_lot   VARCHAR(255),
    IN p_date_from        DATE,
    IN p_date_to          DATE
)
BEGIN
    IF p_ingredient_lot IS NOT NULL THEN
        SELECT DISTINCT
            pb.LotID AS ProductLotID,
            p.ProductID,
            p.ProductName,
            pb.ProductionDate,
            pb.BatchQuantity,
            pbib.IngredientLotID AS AffectedIngredientLot,
            i.IngredientName AS AffectedIngredient
        FROM ProductBatch pb
        INNER JOIN ProductBatchIngredientBatch pbib ON pb.LotID = pbib.ProductLotID
        INNER JOIN IngredientBatch ib ON pbib.IngredientLotID = ib.LotID
        INNER JOIN Formulation f ON ib.FormulationID = f.FormulationID
        INNER JOIN Ingredient i ON f.IngredientID = i.IngredientID
        INNER JOIN Recipe r ON pb.RecipeID = r.RecipeID
        INNER JOIN Product p ON r.ProductID = p.ProductID
        WHERE pbib.IngredientLotID = p_ingredient_lot
          AND pb.ProductionDate BETWEEN p_date_from AND p_date_to
        ORDER BY pb.ProductionDate DESC;
    
    ELSEIF p_ingredient_id IS NOT NULL THEN
        SELECT DISTINCT
            pb.LotID AS ProductLotID,
            p.ProductID,
            p.ProductName,
            pb.ProductionDate,
            pb.BatchQuantity,
            pbib.IngredientLotID AS AffectedIngredientLot,
            i.IngredientName AS AffectedIngredient
        FROM ProductBatch pb
        INNER JOIN ProductBatchIngredientBatch pbib ON pb.LotID = pbib.ProductLotID
        INNER JOIN IngredientBatch ib ON pbib.IngredientLotID = ib.LotID
        INNER JOIN Formulation f ON ib.FormulationID = f.FormulationID
        INNER JOIN Ingredient i ON f.IngredientID = i.IngredientID
        INNER JOIN Recipe r ON pb.RecipeID = r.RecipeID
        INNER JOIN Product p ON r.ProductID = p.ProductID
        WHERE f.IngredientID = p_ingredient_id
          AND pb.ProductionDate BETWEEN p_date_from AND p_date_to
        ORDER BY pb.ProductionDate DESC;
    
    ELSE
        SELECT 'Error: Must provide either ingredient_id or ingredient_lot' AS ErrorMessage;
    END IF;
END$$

DROP PROCEDURE IF EXISTS sp_get_recipe_conflicts$$
CREATE PROCEDURE sp_get_recipe_conflicts(
    IN p_recipe_id INT
)
BEGIN
    WITH RECURSIVE FlatRecipe AS (
        SELECT 
            rb.IngredientID,
            i.IsCompound,
            CAST(NULL AS UNSIGNED) AS FormulationID,
            1 AS Level
        FROM RecipeBOM rb
        INNER JOIN Ingredient i ON rb.IngredientID = i.IngredientID
        WHERE rb.RecipeID = p_recipe_id
        
        UNION ALL
        
        SELECT 
            fil.MaterialID AS IngredientID,
            i2.IsCompound,
            f.FormulationID,
            fr.Level + 1 AS Level
        FROM FlatRecipe fr
        INNER JOIN (
            SELECT IngredientID, FormulationID, PackSize,
                   ROW_NUMBER() OVER (PARTITION BY IngredientID 
                                      ORDER BY EffectiveStartDate DESC, FormulationID DESC) as rn
            FROM Formulation
            WHERE CURDATE() BETWEEN EffectiveStartDate AND EffectiveEndDate
        ) f ON f.IngredientID = fr.IngredientID AND f.rn = 1
        INNER JOIN FormulationIngredientList fil ON fil.FormulationID = f.FormulationID
        INNER JOIN Ingredient i2 ON fil.MaterialID = i2.IngredientID
        WHERE fr.IsCompound = TRUE AND fr.Level = 1
    ),
    AtomicIngredients AS (
        SELECT DISTINCT IngredientID
        FROM FlatRecipe
        WHERE IsCompound = FALSE
    )
    SELECT DISTINCT
        ai1.IngredientID AS Ingredient1ID,
        i1.IngredientName AS Ingredient1Name,
        ai2.IngredientID AS Ingredient2ID,
        i2.IngredientName AS Ingredient2Name
    FROM AtomicIngredients ai1
    INNER JOIN AtomicIngredients ai2 ON ai1.IngredientID < ai2.IngredientID
    INNER JOIN DoNotCombineList dnc 
        ON (dnc.Ingredient1ID = ai1.IngredientID AND dnc.Ingredient2ID = ai2.IngredientID)
         OR (dnc.Ingredient2ID = ai1.IngredientID AND dnc.Ingredient1ID = ai2.IngredientID)
    INNER JOIN Ingredient i1 ON ai1.IngredientID = i1.IngredientID
    INNER JOIN Ingredient i2 ON ai2.IngredientID = i2.IngredientID;
END$$

DROP PROCEDURE IF EXISTS sp_evaluate_health_risk_for_allocated_lots$$
CREATE PROCEDURE sp_evaluate_health_risk_for_allocated_lots(
    IN p_lot_ids TEXT
)
BEGIN
    WITH RECURSIVE FlattenedLots AS (
        SELECT 
            f.IngredientID,
            i.IngredientName,
            i.IsCompound,
            ib.FormulationID,
            1 AS Level
        FROM IngredientBatch ib
        INNER JOIN Formulation f ON ib.FormulationID = f.FormulationID
        INNER JOIN Ingredient i ON f.IngredientID = i.IngredientID
        WHERE FIND_IN_SET(ib.LotID, p_lot_ids) > 0
        
        UNION ALL
        
        SELECT 
            fil.MaterialID AS IngredientID,
            i2.IngredientName,
            i2.IsCompound,
            fl.FormulationID,
            fl.Level + 1 AS Level
        FROM FlattenedLots fl
        INNER JOIN Formulation f ON fl.FormulationID = f.FormulationID
        INNER JOIN FormulationIngredientList fil ON fil.FormulationID = f.FormulationID
        INNER JOIN Ingredient i2 ON fil.MaterialID = i2.IngredientID
        WHERE fl.IsCompound = TRUE AND fl.Level = 1
    ),
    AtomicIngredients AS (
        SELECT DISTINCT IngredientID, IngredientName
        FROM FlattenedLots
        WHERE IsCompound = FALSE
    )
    SELECT DISTINCT
        ai1.IngredientID AS Ingredient1ID,
        ai1.IngredientName AS Ingredient1Name,
        ai2.IngredientID AS Ingredient2ID,
        ai2.IngredientName AS Ingredient2Name,
        'HEALTH RISK VIOLATION' AS Status
    FROM DoNotCombineList dnc
    INNER JOIN AtomicIngredients ai1 ON ai1.IngredientID = dnc.Ingredient1ID
    INNER JOIN AtomicIngredients ai2 ON ai2.IngredientID = dnc.Ingredient2ID
    ORDER BY ai1.IngredientName, ai2.IngredientName;
END$$

DELIMITER ;

#### VIEWER PROCEDURES ########################################

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_browse_product_batches$$
CREATE PROCEDURE sp_browse_product_batches()
BEGIN
    SELECT 
        pb.LotID,
        p.ProductID,
        p.ProductName,
        pc.CategoryName,
        m.ManufacturerID,
        u.Username AS ManufacturerName,
        pb.BatchQuantity,
        pb.ProductionDate,
        pb.ExpirationDate
    FROM ProductBatch pb
    INNER JOIN Recipe r ON pb.RecipeID = r.RecipeID
    INNER JOIN Product p ON r.ProductID = p.ProductID
    INNER JOIN ProductCategory pc ON p.CategoryID = pc.CategoryID
    INNER JOIN Manufacturer m ON p.ManufacturerID = m.ManufacturerID
    INNER JOIN User u ON m.UserID = u.UserID
    ORDER BY pb.ProductionDate DESC, pb.LotID;
END$$

DROP PROCEDURE IF EXISTS sp_compare_batches_incompatibilities$$
CREATE PROCEDURE sp_compare_batches_incompatibilities(
    IN p_batch1_lot_id VARCHAR(255),
    IN p_batch2_lot_id VARCHAR(255)
)
BEGIN
    -- Check both batches exist
    DECLARE v_count INT;
    
    SELECT COUNT(*) INTO v_count
    FROM ProductBatch
    WHERE LotID IN (p_batch1_lot_id, p_batch2_lot_id);
    
    IF v_count < 2 THEN
        SELECT 'One or both batches not found' AS ErrorMessage;
    ELSE
        WITH CombinedIngredients AS (
            SELECT DISTINCT IngredientID
            FROM vw_flattened_product_bom
            WHERE BatchLotID IN (p_batch1_lot_id, p_batch2_lot_id)
        )
        SELECT DISTINCT
            i1.IngredientID AS Ingredient1ID,
            i1.IngredientName AS Ingredient1Name,
            i2.IngredientID AS Ingredient2ID,
            i2.IngredientName AS Ingredient2Name,
            'CONFLICT' AS Status
        FROM DoNotCombineList dnc
        INNER JOIN CombinedIngredients ci1 ON ci1.IngredientID = dnc.Ingredient1ID
        INNER JOIN CombinedIngredients ci2 ON ci2.IngredientID = dnc.Ingredient2ID
        INNER JOIN Ingredient i1 ON dnc.Ingredient1ID = i1.IngredientID
        INNER JOIN Ingredient i2 ON dnc.Ingredient2ID = i2.IngredientID
        ORDER BY i1.IngredientName, i2.IngredientName;
    END IF;
END$$

DELIMITER ;

#### 5 EXPECTED QUERIES ########################################

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_query_last_batch_ingredients$$
CREATE PROCEDURE sp_query_last_batch_ingredients(
    IN p_product_id INT,
    IN p_manufacturer_userid VARCHAR(50) 
)
BEGIN
    DECLARE v_lot_id VARCHAR(50);

    SELECT LotID INTO v_lot_id
    FROM ProductBatch pb
    INNER JOIN Recipe r ON pb.RecipeID = r.RecipeID
    WHERE r.ProductID = p_product_id
      AND pb.LotID LIKE CONCAT(p_product_id, '-', p_manufacturer_userid, '-%')
    ORDER BY pb.ProductionDate DESC, pb.LotID DESC
    LIMIT 1;
    
    IF v_lot_id IS NULL THEN
        SELECT 'No batches found for this product and manufacturer' AS ErrorMessage;
    ELSE
        SELECT 
            v_lot_id AS ProductLotID,
            pb.ProductionDate,
            i.IngredientID,
            i.IngredientName,
            pbib.IngredientLotID,
            pbib.QuantityUsed
        FROM ProductBatch pb
        INNER JOIN ProductBatchIngredientBatch pbib ON pb.LotID = pbib.ProductLotID
        INNER JOIN IngredientBatch ib ON pbib.IngredientLotID = ib.LotID
        INNER JOIN Formulation f ON ib.FormulationID = f.FormulationID
        INNER JOIN Ingredient i ON f.IngredientID = i.IngredientID
        WHERE pb.LotID = v_lot_id
        ORDER BY i.IngredientName;
    END IF;
END$$

DROP PROCEDURE IF EXISTS sp_query_supplier_spending$$
CREATE PROCEDURE sp_query_supplier_spending(
    IN p_manufacturer_id INT
)
BEGIN
    SELECT 
        s.SupplierID,
        u.Username AS SupplierName,
        COUNT(DISTINCT ib.LotID) AS BatchesPurchased,
        SUM(ib.Quantity * f.UnitPrice) AS TotalSpent
    FROM IngredientBatch ib
    INNER JOIN Formulation f ON ib.FormulationID = f.FormulationID
    INNER JOIN Supplier s ON f.SupplierID = s.SupplierID
    INNER JOIN User u ON s.UserID = u.UserID
    WHERE ib.ManufacturerID = p_manufacturer_id
    GROUP BY s.SupplierID, u.Username
    ORDER BY TotalSpent DESC;
END$$

DROP PROCEDURE IF EXISTS sp_query_product_unit_cost$$
CREATE PROCEDURE sp_query_product_unit_cost(
    IN p_lot_id VARCHAR(50)
)
BEGIN
    SELECT 
        pb.LotID,
        p.ProductID,
        p.ProductName,
        pb.BatchQuantity,
        pb.ProductionDate,
        pb.BatchCost,
        pb.PerUnitCost
    FROM ProductBatch pb
    INNER JOIN Recipe r ON pb.RecipeID = r.RecipeID
    INNER JOIN Product p ON r.ProductID = p.ProductID
    WHERE pb.LotID = p_lot_id;
END$$

DROP PROCEDURE IF EXISTS sp_query_conflicting_ingredients$$
CREATE PROCEDURE sp_query_conflicting_ingredients(
    IN p_lot_id VARCHAR(50)
)
BEGIN
    WITH BatchIngredients AS (
        SELECT DISTINCT f.IngredientID
        FROM ProductBatchIngredientBatch pbib
        INNER JOIN IngredientBatch ib ON pbib.IngredientLotID = ib.LotID
        INNER JOIN Formulation f ON ib.FormulationID = f.FormulationID
        WHERE pbib.ProductLotID = p_lot_id
    )
    SELECT DISTINCT
        CASE 
            WHEN dnc.Ingredient1ID IN (SELECT IngredientID FROM BatchIngredients)
            THEN dnc.Ingredient2ID
            ELSE dnc.Ingredient1ID
        END AS ConflictingIngredientID,
        i.IngredientName AS ConflictingIngredientName,
        CASE 
            WHEN dnc.Ingredient1ID IN (SELECT IngredientID FROM BatchIngredients)
            THEN i2.IngredientName
            ELSE i3.IngredientName
        END AS ConflictsWith
    FROM DoNotCombineList dnc
    INNER JOIN BatchIngredients bi 
        ON bi.IngredientID = dnc.Ingredient1ID 
        OR bi.IngredientID = dnc.Ingredient2ID
    INNER JOIN Ingredient i ON i.IngredientID = CASE 
        WHEN dnc.Ingredient1ID IN (SELECT IngredientID FROM BatchIngredients)
        THEN dnc.Ingredient2ID
        ELSE dnc.Ingredient1ID
    END
    LEFT JOIN Ingredient i2 ON dnc.Ingredient1ID = i2.IngredientID
    LEFT JOIN Ingredient i3 ON dnc.Ingredient2ID = i3.IngredientID
    WHERE CASE 
        WHEN dnc.Ingredient1ID IN (SELECT IngredientID FROM BatchIngredients)
        THEN dnc.Ingredient2ID
        ELSE dnc.Ingredient1ID
    END NOT IN (SELECT IngredientID FROM BatchIngredients)
    ORDER BY ConflictingIngredientName;
END$$

DROP PROCEDURE IF EXISTS sp_query_manufacturers_not_supplied$$
CREATE PROCEDURE sp_query_manufacturers_not_supplied(
    IN p_supplier_id INT
)
BEGIN
    SELECT 
        m.ManufacturerID,
        u.Username AS ManufacturerName,
        u.UserID
    FROM Manufacturer m
    INNER JOIN User u ON m.UserID = u.UserID
    WHERE m.ManufacturerID NOT IN (
        SELECT DISTINCT ib.ManufacturerID
        FROM IngredientBatch ib
        INNER JOIN Formulation f ON ib.FormulationID = f.FormulationID
        WHERE f.SupplierID = p_supplier_id
          AND ib.ManufacturerID IS NOT NULL
    )
    ORDER BY m.ManufacturerID;
END$$

DELIMITER ;

#### OTHER VIEWS ########################################

CREATE OR REPLACE VIEW vw_active_formulations AS
SELECT 
    f.FormulationID,
    f.IngredientID,
    i.IngredientName,
    i.IsCompound,
    f.SupplierID,
    u.Username AS SupplierName,
    f.VersionNumber,
    f.PackSize,
    f.UnitPrice,
    f.EffectiveStartDate,
    f.EffectiveEndDate,
    COUNT(fil.MaterialID) AS MaterialCount
FROM Formulation f
INNER JOIN Ingredient i ON f.IngredientID = i.IngredientID
INNER JOIN Supplier s ON f.SupplierID = s.SupplierID
INNER JOIN User u ON s.UserID = u.UserID
LEFT JOIN FormulationIngredientList fil ON f.FormulationID = fil.FormulationID
WHERE CURDATE() BETWEEN f.EffectiveStartDate AND f.EffectiveEndDate
GROUP BY 
    f.FormulationID, f.IngredientID, i.IngredientName, i.IsCompound,
    f.SupplierID, u.Username, f.VersionNumber, f.PackSize, 
    f.UnitPrice, f.EffectiveStartDate, f.EffectiveEndDate
ORDER BY u.Username, i.IngredientName, f.VersionNumber DESC;

CREATE OR REPLACE VIEW vw_flattened_product_bom AS
WITH RECURSIVE FlatBOM AS (
    SELECT 
        pb.LotID AS BatchLotID,
        p.ProductID,
        p.ProductName,
        m.ManufacturerID,
        u.Username AS ManufacturerName,
        pb.ProductionDate,
        pb.BatchQuantity,
        f.IngredientID,
        i.IngredientName,
        i.IsCompound,
        pbib.QuantityUsed AS TotalQuantity,
        ib.FormulationID,
        1 AS Level
    FROM ProductBatch pb
    INNER JOIN Recipe r ON pb.RecipeID = r.RecipeID
    INNER JOIN Product p ON r.ProductID = p.ProductID
    INNER JOIN Manufacturer m ON p.ManufacturerID = m.ManufacturerID
    INNER JOIN User u ON m.UserID = u.UserID
    INNER JOIN ProductBatchIngredientBatch pbib ON pb.LotID = pbib.ProductLotID
    INNER JOIN IngredientBatch ib ON pbib.IngredientLotID = ib.LotID
    INNER JOIN Formulation f ON ib.FormulationID = f.FormulationID
    INNER JOIN Ingredient i ON f.IngredientID = i.IngredientID
    
    UNION ALL
    
    SELECT 
        fb.BatchLotID,
        fb.ProductID,
        fb.ProductName,
        fb.ManufacturerID,
        fb.ManufacturerName,
        fb.ProductionDate,
        fb.BatchQuantity,
        fil.MaterialID AS IngredientID,
        i2.IngredientName,
        i2.IsCompound,
        fb.TotalQuantity * (fil.Quantity / f.PackSize) AS TotalQuantity,
        fb.FormulationID,
        fb.Level + 1 AS Level
    FROM FlatBOM fb
    INNER JOIN Formulation f ON fb.FormulationID = f.FormulationID
    INNER JOIN FormulationIngredientList fil ON fil.FormulationID = f.FormulationID
    INNER JOIN Ingredient i2 ON fil.MaterialID = i2.IngredientID
    WHERE fb.IsCompound = TRUE 
      AND fb.Level = 1 
)
SELECT 
    BatchLotID,
    ProductID,
    ProductName,
    ManufacturerID,
    ManufacturerName,
    ProductionDate,
    BatchQuantity,
    IngredientID,
    IngredientName,
    SUM(TotalQuantity) AS TotalQuantityOz
FROM FlatBOM
WHERE IsCompound = FALSE 
GROUP BY BatchLotID, ProductID, ProductName, ManufacturerID, ManufacturerName,
         ProductionDate, BatchQuantity, IngredientID, IngredientName
ORDER BY BatchLotID, TotalQuantityOz DESC;