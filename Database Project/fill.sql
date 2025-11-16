USE csc540_project;

-- Clean existing data
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE ProductBatchIngredientBatch;
TRUNCATE TABLE ProductBatch;
TRUNCATE TABLE RecipeBOM;
TRUNCATE TABLE Recipe;
TRUNCATE TABLE Product;
TRUNCATE TABLE ProductCategory;
TRUNCATE TABLE DoNotCombineList;
TRUNCATE TABLE IngredientBatch;
TRUNCATE TABLE FormulationIngredientList;
TRUNCATE TABLE Formulation;
TRUNCATE TABLE Ingredient;
TRUNCATE TABLE Manufacturer;
TRUNCATE TABLE Supplier;
TRUNCATE TABLE User;

SET FOREIGN_KEY_CHECKS = 1;

-- Reset auto-increment
ALTER TABLE Supplier AUTO_INCREMENT = 20;
ALTER TABLE Manufacturer AUTO_INCREMENT = 1;
ALTER TABLE Ingredient AUTO_INCREMENT = 101;
ALTER TABLE Formulation AUTO_INCREMENT = 1;
ALTER TABLE ProductCategory AUTO_INCREMENT = 1;
ALTER TABLE Product AUTO_INCREMENT = 100;
ALTER TABLE Recipe AUTO_INCREMENT = 1;


-- TEMPORARILY DISABLE TRIGGERS
DROP TRIGGER IF EXISTS before_insert_user;
DROP TRIGGER IF EXISTS before_insert_ingredient_batch;
DROP TRIGGER IF EXISTS before_insert_product_batch;
DROP TRIGGER IF EXISTS after_insert_consumption;
DROP TRIGGER IF EXISTS prevent_expired_consumption;

INSERT INTO User (UserID, Username, UserRole) VALUES 
    ('MFG001', 'John Smith', 'MANUFACTURER'),
    ('MFG002', 'Alice Lee', 'MANUFACTURER'),
    ('SUP020', 'Jane Doe', 'SUPPLIER'),
    ('SUP021', 'James Miller', 'SUPPLIER'),
    ('VIEW001', 'Bob Johnson', 'VIEWER');

INSERT INTO Supplier (SupplierID, UserID) VALUES 
    (20, 'SUP020'),
    (21, 'SUP021');

INSERT INTO Manufacturer (ManufacturerID, UserID) VALUES 
    (1, 'MFG001'),
    (2, 'MFG002');


INSERT INTO ProductCategory (CategoryID, CategoryName) VALUES 
    (2, 'Dinners'), 
    (3, 'Sides');

INSERT INTO Ingredient (IngredientID, IngredientName, IsCompound) VALUES 
    (101, 'Salt', FALSE), 
    (102, 'Pepper', FALSE), 
    (104, 'Sodium Phosphate', FALSE), 
    (106, 'Beef Steak', FALSE), 
    (108, 'Pasta', FALSE), 
    (201, 'Seasoning Blend', TRUE), 
    (301, 'Super Seasoning', TRUE);


INSERT INTO Product (ProductID, ProductName, CategoryID, DefaultBatchSize, ManufacturerID) VALUES 
    (100, 'Steak Dinner', 2, 100, 1),
    (101, 'Mac & Cheese', 3, 300, 2);


INSERT INTO Formulation (FormulationID, IngredientID, SupplierID, VersionNumber, EffectiveStartDate, EffectiveEndDate, UnitPrice, PackSize) VALUES 
    -- From document: Formulation 1 for Seasoning Blend
    (1, 201, 20, 1, '2025-01-01', '2025-06-30', 2.5, 8.0),
    
    -- Implied formulations for atomic ingredients 
    (2, 101, 20, 1, '2025-01-01', '9999-12-31', 0.1, 1.0),  
    (3, 101, 21, 1, '2025-01-01', '9999-12-31', 0.08, 1.0), 
    (4, 102, 20, 1, '2025-01-01', '9999-12-31', 0.3, 1.0), 
    (5, 106, 20, 1, '2025-01-01', '9999-12-31', 0.5, 1.0),  
    (6, 108, 20, 1, '2025-01-01', '9999-12-31', 0.25, 1.0); 

INSERT INTO FormulationIngredientList (FormulationID, MaterialID, Quantity) VALUES 
    (1, 101, 6.0),   
    (1, 102, 2.0); 

INSERT INTO Recipe (RecipeID, ProductID, CreationDate) VALUES 
    (1, 100, '2025-10-01'), 
    (2, 101, '2025-10-01'); 

INSERT INTO RecipeBOM (RecipeID, IngredientID, Quantity) VALUES 
    (1, 106, 6.0),   
    (1, 201, 0.2),  
    (2, 108, 7.0),  
    (2, 101, 0.5),   
    (2, 102, 2.0);  

INSERT INTO DoNotCombineList (Ingredient1ID, Ingredient2ID) VALUES 
    (104, 106);  

INSERT INTO IngredientBatch (LotID, FormulationID, Quantity, TotalQuantityOz, ExpirationDate, ManufacturerID) 
VALUES 
    ('101-20-B0001', 2, 1000, 1000, '2025-11-15', NULL),    
    ('101-21-B0001', 3, 800, 800, '2025-10-30', NULL),     
    ('101-20-B0002', 2, 350, 350, '2025-11-01', 2),        
    ('101-20-B0003', 2, 500, 500, '2025-12-15', NULL);      

INSERT INTO IngredientBatch (LotID, FormulationID, Quantity, TotalQuantityOz, ExpirationDate, ManufacturerID) 
VALUES 
    ('102-20-B0001', 4, 600, 600, '2025-12-15', 2);  
    
INSERT INTO IngredientBatch (LotID, FormulationID, Quantity, TotalQuantityOz, ExpirationDate, ManufacturerID) 
VALUES 
    ('106-20-B0005', 5, 3000, 3000, '2025-12-15', NULL),   
    ('106-20-B0006', 5, 0, 0, '2025-12-20', 1);            

INSERT INTO IngredientBatch (LotID, FormulationID, Quantity, TotalQuantityOz, ExpirationDate, ManufacturerID) 
VALUES 
    ('108-20-B0001', 6, 1000, 1000, '2025-09-28', NULL),   
    ('108-20-B0003', 6, 4200, 4200, '2025-12-31', 2);     
    
INSERT INTO IngredientBatch (LotID, FormulationID, Quantity, TotalQuantityOz, ExpirationDate, ManufacturerID) 
VALUES 
    ('201-20-B0001', 1, 100, 800, '2025-11-30', NULL),     
    ('201-20-B0002', 1, 17.5, 140, '2025-12-30', 1);     

INSERT INTO ProductBatch (LotID, RecipeID, BatchQuantity, ProductionDate, ExpirationDate, BatchCost, PerUnitCost) 
VALUES 
    ('100-MFG001-B0901', 1, 100, '2025-09-26', '2025-11-15', 350.00, 3.50),
    ('101-MFG002-B0101', 2, 300, '2025-09-10', '2025-10-30', 570.00, 1.90);

INSERT INTO ProductBatchIngredientBatch (ProductLotID, IngredientLotID, QuantityUsed) 
VALUES 
    ('100-MFG001-B0901', '106-20-B0006', 600),
    ('100-MFG001-B0901', '201-20-B0002', 20),
    
    ('101-MFG002-B0101', '101-20-B0002', 150),
    ('101-MFG002-B0101', '108-20-B0003', 2100),
    ('101-MFG002-B0101', '102-20-B0001', 600);

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

DELIMITER ;