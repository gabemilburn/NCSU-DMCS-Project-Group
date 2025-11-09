-- Queries for the project

-- Run these in this order before testing:
-- project_create_schema_and_tables.sql
-- project_insert_sample_data.sql

USE csc540_project;

-- List the ingredients and the lot number of the last batch of product type Steak Dinner (100) made by manufacturer MFG001
SELECT IngredientID, pb.LotID FROM RecipeBOM rbom
JOIN ProductBatch pb ON pb.RecipeID = rbom.RecipeID
WHERE rbom.RecipeID = (SELECT r.RecipeID FROM ProductBatch pb
					   JOIN Recipe r ON r.RecipeID = pb.RecipeID
					   JOIN Product p ON p.ProductID = r.ProductID
					   WHERE p.ManufacturerID = 1
                       AND p.ProductID = 100
					   ORDER BY pb.ProductionDate DESC
					   LIMIT 1);

-- For manufacturer MFG002, list all the suppliers that they have purchased from and the total amount of money they have spent with that supplier.
SELECT f.SupplierID, u.FirstName, u.LastName, u.UserName, SUM(f.UnitPrice * pbib.QuantityUsed) AS TotalMoneySpent FROM ProductBatchIngredientBatch pbib
JOIN ProductBatch pb ON pb.LotID = pbib.ProductLotID
JOIN Recipe r ON r.RecipeID = pb.RecipeID
JOIN Product p ON p.ProductID = r.ProductID
JOIN IngredientBatch ib ON ib.LotID = pbib.IngredientLotID
JOIN Formulation f ON f.FormulationID = ib.FormulationID
JOIN Supplier s ON s.SupplierID = f.SupplierID
JOIN User u ON u.UserID = s.UserID
WHERE p.ManufacturerID = 2
GROUP BY f.SupplierID;

-- For product with lot number 100-MFG001-B0901, find the unit cost for that product.
-- 		We have a proc for this so not sure if this **needs** to be a query
CALL ProductBatchCostSummary(
    '100-MFG001-B0901',1,
    @total_cost,
    @per_unit_cost,
    @success,
    @message
);
SELECT @per_unit_cost AS UnitCost;

-- Based on the ingredients currently in product lot number 100-MFG001-B0901, what are all ingredients that cannot be included
-- (i.e. that are in conflict with the current ingredient list)
SELECT Ingredient1ID AS DoNotCombineIngredient FROM RecipeBOM rbom
JOIN ProductBatch pb ON pb.RecipeID = rbom.RecipeID
JOIN DoNotCombineList dncl ON dncl.Ingredient2ID = rbom.IngredientID
WHERE pb.LotID = '100-MFG001-B0901'
UNION
SELECT Ingredient2ID AS DoNotCombineIngredient FROM RecipeBOM rbom
JOIN ProductBatch pb ON pb.RecipeID = rbom.RecipeID
JOIN DoNotCombineList dncl ON dncl.Ingredient1ID = rbom.IngredientID
WHERE pb.LotID = '100-MFG001-B0901';

-- Which manufacturers have supplier James Miller (21) NOT supplied to?
SELECT DISTINCT ib.ManufacturerID, u.FirstName, u.LastName, u.UserName FROM IngredientBatch ib
JOIN Manufacturer m ON m.ManufacturerID = ib.ManufacturerID
JOIN User u ON u.UserID = m.UserID
JOIN Formulation f ON f.FormulationID = ib.FormulationID
WHERE NOT f.SupplierID = 21;
