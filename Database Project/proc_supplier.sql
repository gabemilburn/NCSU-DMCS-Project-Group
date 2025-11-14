USE csc540_project;

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