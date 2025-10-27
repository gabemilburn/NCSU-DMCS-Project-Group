-- Some attributes don't need to be given in practice (but it's given in the sample data)

-- For User, Supplier, Manufacturer, I'm just going to implement it how we have and ask later if we
-- absolutely need to store it the way they do

-- Also the way they have it makes no sense. The supplier table doesn't get a user ID? Two suppliers are listed
-- and only one gets a userID? And theres no way to tell what supplierID it corresponds to?

INSERT INTO User (UserID, UserName, FirstName, LastName, UserRole)
VALUES (1, 'Manager A', 'John', 'Smith', 'MANUFACTURER'),
	   (2, 'Manager B', 'Alice', 'Lee', 'MANUFACTURER'),
       (3, 'Supplier A', 'Jane', 'Doe', 'SUPPLIER'),
       (4, 'Supplier B', 'Supp', 'Lier', 'SUPPLIER'),
       (5, 'Viewer A', 'Bob', 'Johnson', 'VIEWER');

INSERT INTO Supplier (UserID, SupplierID)
VALUES (3, 20),
	   (4, 21);

INSERT INTO Manufacturer (UserID, ManufacturerID)
VALUES (1, 1),
	   (2, 2);

INSERT INTO Ingredient (IngredientID, IngredientName, IsCompound)
VALUES (101, 'Salt', FALSE),
	   (102, 'Pepper', FALSE),
       (104, 'Sodium Phosphate', FALSE),
       (106, 'Beef Steak', FALSE),
       (108, 'Pasta', FALSE),
       (201, 'Seasoning Blend', TRUE),
       (301, 'Super Seasoning', TRUE);


-- They don't have formulations for atomic ingredients, but our implementation uses this, so
-- I'm adding implicit ones as well
INSERT INTO Formulation (FormulationID, IngredientID, SupplierID, VersionNumber, EffectiveStartDate, EffectiveEndDate, UnitPrice, PackSize)
VALUES (1, 201, 20, 1, '2025-01-01', '2025-06-30', 20.0, 8.0),
	   (2, 101, 20, 1, '2025-01-01', '2025-06-30', 0.1, 1.0),
       (3, 101, 21, 1, '2025-01-01', '2025-06-30', 0.08, 1.0),
       (4, 102, 20, 1, '2025-01-01', '2025-06-30', 0.3, 1.0),
       (5, 106, 20, 1, '2025-01-01', '2025-06-30', 0.5, 1.0),
       (6, 108, 20, 1, '2025-01-01', '2025-06-30', 0.25, 1.0);

-- It **seems** like CostPerUnit is just the formulation price_per_pack / pack_size, so no need to store I think
INSERT INTO IngredientBatch (LotID, FormulationID, Quantity, ExpirationDate, ManufacturerID)
VALUES ('101-20-B0001', 2, 1000, '2025-11-15', 2),
	   ('101-21-B0001', 3, 800, '2025-11-15', NULL),
       ('101-20-B0002', 2, 500, '2025-11-15', 2),
       ('101-20-B0003', 2, 500, '2025-11-15', NULL),
       ('102-20-B0001', 4, 1200, '2025-11-15', NULL),
       ('106-20-B0005', 5, 3000, '2025-11-15', NULL),
       ('106-20-B0006', 5, 600, '2025-11-15', 1),
       ('108-20-B0001', 6, 1000, '2025-11-15', NULL),
       ('108-20-B0003', 6, 6300, '2025-11-15', 2),
       ('201-20-B0001', 1, 100, '2025-11-15', NULL),
       ('201-20-B0002', 1, 20, '2025-11-15', 1);

INSERT INTO ProductCategory (CategoryID, CategoryName)
VALUES (2, 'Dinners'),
	   (3, 'Sides');

-- Product number just seems to be f"P-{ProductID:3d}"? So I'm not sure it needs to be stored
-- Somehow the sample data doesn't include ManufacturerID? I'm inferring it from the rest of the data
INSERT INTO Product (ProductID, ProductName, CategoryID, DefaultBatchSize, ManufacturerID)
VALUES (100, 'Steak Dinner', 2, 500, 1),
	   (101, 'Mac & Cheese', 3, 300, 2);

-- They only have a product BOM but we need to store version of recipes so I'm splitting it up
INSERT INTO Recipe (RecipeID, ProductID, CreationDate)
VALUES (1, 100, '2025-10-26'),
	   (2, 101, '2025-10-26');

INSERT INTO RecipeBOM (RecipeID, IngredientID, Quantity)
VALUES (1, 106, 6.0),
	   (1, 201, 0.2),
       (2, 108, 7.0),
       (2, 101, 0.5),
       (2, 102, 2.0);

-- Uses recipeID since that makes more sense
INSERT INTO ProductBatch (LotID, RecipeID, BatchQuantity, ProductionDate, ExpirationDate)
VALUES ('100-MFG001-B0901', 1, 100, '2025-09-26', '2025-11-15'),
	   ('101-MFG002-B0101', 2, 300, '2025-09-10', '2025-10-30');

INSERT INTO ProductBatchIngredientBatch (ProductLotID, IngredientLotID, QuantityUsed)
VALUES ('100-MFG001-B0901', '106-20-B0006', 600),
	   ('100-MFG001-B0901', '201-20-B0002', 20),
       ('101-MFG002-B0101', '101-20-B0002', 150),
       ('101-MFG002-B0101', '108-20-B0003', 2100),
       ('101-MFG002-B0101', '102-20-B0001', 600);

-- They have it reversed sort of, not that it really matters
INSERT INTO DoNotCombineList (Ingredient1ID, Ingredient2ID)
VALUES (104, 201),
	   (104, 106);