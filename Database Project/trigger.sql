USE csc540_project;

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
