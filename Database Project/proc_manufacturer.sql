USE csc540_project;

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