DROP TRIGGER IF EXISTS csc540_project.before_insert_ingredient_batch;
DROP TRIGGER IF EXISTS csc540_project.before_insert_product_batch;
DROP TRIGGER IF EXISTS csc540_project.prevent_expired_consumption;

DELIMITER $$
# Insert into IngredientBatch trigger
CREATE TRIGGER before_insert_ingredient_batch
BEFORE INSERT ON IngredientBatch
FOR EACH ROW
BEGIN
    DECLARE v_IngredientID INT;
    DECLARE v_SupplierID INT;
    DECLARE v_NewBatchID INT;

    SELECT IngredientID INTO v_IngredientID
    FROM Formulation
    WHERE FormulationID = NEW.FormulationID;
    
    SELECT SupplierID INTO v_SupplierID
    FROM Formulation
    WHERE FormulationID = NEW.FormulationID;

    -- BatchID is the max of the suppliers current BatchIDs + 1 (in LotID)
    SELECT COALESCE(MAX(CAST(SUBSTRING_INDEX(LotID, '-B', -1) AS UNSIGNED)), 0) INTO v_NewBatchID
    FROM IngredientBatch
    WHERE LotID LIKE CONCAT('%-', v_SupplierID, '-%');
    SET v_NewBatchID = v_NewBatchID + 1;

    SET NEW.LotID = CONCAT(v_IngredientID, '-', v_SupplierID, '-B', v_NewBatchID);
END$$



# Insert into ProductBatch trigger
CREATE TRIGGER before_insert_product_batch
BEFORE INSERT ON ProductBatch
FOR EACH ROW
BEGIN
    DECLARE v_ProductID INT;
    DECLARE v_ManufacturerID INT;
    DECLARE v_NewBatchID INT;

    SELECT ProductID INTO v_ProductID
    FROM Recipe
    WHERE RecipeID = NEW.RecipeID;
    
    SELECT ManufacturerID INTO v_ManufacturerID
    FROM Product
    WHERE ProductID = v_ProductID;

    -- BatchID is the max of the manufacturers current BatchIDs + 1 (in LotID)
    SELECT COALESCE(MAX(CAST(SUBSTRING_INDEX(LotID, '-B', -1) AS UNSIGNED)), 0) INTO v_NewBatchID
    FROM ProductBatch
    WHERE LotID LIKE CONCAT('%-', v_ManufacturerID, '-%');
    SET v_NewBatchID = v_NewBatchID + 1;

    SET NEW.LotID = CONCAT(v_IngredientID, '-', v_ManufacturerID, '-B', v_NewBatchID);
END$$



-- Prevent expired consumption of ingredient batches
CREATE TRIGGER prevent_expired_consumption
BEFORE UPDATE ON IngredientBatch
FOR EACH ROW
BEGIN
    IF NOW() > OLD.ExpirationDate THEN
        IF NEW.Quantity <> OLD.Quantity THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot consume ingredient batch: Past expiration date';
        END IF;
    END IF;
END$$

DELIMITER ;