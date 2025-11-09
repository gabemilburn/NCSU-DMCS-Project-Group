 -- Test data (non sample data, for testing procedures)
INSERT INTO User (UserID, UserName, FirstName, LastName, UserRole)
VALUES (6, 'Manufacturer C', 'John', 'Smith', 'MANUFACTURER');

INSERT INTO Manufacturer (UserID, ManufacturerID)
VALUES (6, 3);

INSERT INTO IngredientBatch (FormulationID, Quantity, ExpirationDate, ManufacturerID)
VALUES (1, 20, '2025-11-15', 3),
	   (5, 3000, '2025-11-15', 3);
       
INSERT INTO Product (ProductID, ProductName, CategoryID, DefaultBatchSize, ManufacturerID)
VALUES (102, 'Steak Dinner', 2, 500, 3);

INSERT INTO Recipe (RecipeID, ProductID, CreationDate)
VALUES (3, 102, '2025-10-26');

INSERT INTO RecipeBOM (RecipeID, IngredientID, Quantity)
VALUES (3, 106, 6.0),
	   (3, 201, 0.2);