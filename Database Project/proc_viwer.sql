USE csc540_project;

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