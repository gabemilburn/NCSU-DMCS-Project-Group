USE csc540_project;

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