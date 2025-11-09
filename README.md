Group Members:

1. Shraawani Lattoo
2. Gabe Milburn
3. Ava Collier
4. Jazmin Green

Procedures made so far:

-- Checks if product batch's ingredient batchs contain ingredients that should not be combined
--  This is used for the next AddProductBatch procedure, and blocks that if this one returns true
--  Doesn't have much error handling, doesn't really need it
CheckDoNotCombine(
	-- Procedure inputs
    p_product_batch_id VARCHAR(255),
    -- Procudure outputs
    p_contains_dnc BOOL
)

-- Adding a product batch
-- 	Supports manual ingredient batch assignment or automatic consumption (FEFO)
--  One of the tests in the proc_tests.sql file shows how I did manual assignent (through JSON)
AddProductBatch(
	-- Procedure inputs
    p_recipe_id INT,
    p_manufacturer_id INT,
    p_quantity_to_produce INT,
    p_production_date DATE,
    p_expiration_date DATE,
    p_ingredient_batch_list JSON,
    -- Procudure outputs
    p_product_batch_id VARCHAR(255),
    p_success BOOLEAN,
    p_message VARCHAR(255)
)

-- Calculates cost statistics for product batch lot id
-- 	Also makes sure that the lot and manufacturer exists, and that the manufacturer owns the lot
ProductBatchCostSummary(
	-- Procedure inputs
    p_product_batch_id VARCHAR(255),
    p_manufacturer_id INT,
    -- Procudure outputs
    p_total_cost DEC(10,2),
    p_per_unit_cost DEC(10,2),
    p_success BOOLEAN,
    p_message VARCHAR(255)
)

-- Returns (comma seperated) list of product batches affected by ingredient batch recall
-- 	Why is this a procedure? I guess because returning a table is hard? You could just query but idk
RecallIngredientBatch(
	-- Procedure inputs
    p_ingredient_batch_id VARCHAR(255),
    -- Procudure outputs
    p_affected_batches VARCHAR(255),
    p_success BOOLEAN,
    p_message VARCHAR(255)
)