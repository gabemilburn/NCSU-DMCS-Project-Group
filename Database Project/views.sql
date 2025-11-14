USE csc540_project;

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