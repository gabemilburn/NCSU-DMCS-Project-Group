-- For each blocked section of tests, I the following files in order first:
-- project_create_schema_and_tables.sql
-- project_insert_sample_data.sql
-- project_triggers.sql
-- project_insert_test_data.sql

USE csc540_project;

-- Test adding ingredient batch success
CALL AddProductBatch(
    3,3,100,'2025-09-26','2025-11-15',NULL,
    @product_batch_id,
    @success,
    @message
);

SELECT @product_batch_id, @success, @message;

-- Test adding ingredient batch fail (Not enough ingredient batch quantity)
CALL AddProductBatch(
    3,3,100,'2025-09-26','2025-11-15',NULL,
    @product_batch_id,
    @success,
    @message
);

SELECT @product_batch_id, @success, @message;

-- Test adding ingredient batch fail (Manufacturer does not own recipe)
CALL AddProductBatch(
    3,2,100,'2025-09-26','2025-11-15',NULL,
    @product_batch_id,
    @success,
    @message
);

SELECT @product_batch_id, @success, @message;

-- Test adding ingredient batch fail (Recipe does not exist)
CALL AddProductBatch(
    4,3,100,'2025-09-26','2025-11-15',NULL,
    @product_batch_id,
    @success,
    @message
);

SELECT @product_batch_id, @success, @message;

/* ---------------------
Testing manual assignment
----------------------- */
-- Test adding ingredient batch success
CALL AddProductBatch(
    3,3,100,'2025-09-26','2025-11-15',
    '[{"ibatch_id":"201-20-B0003","ibatch_quantity_used":20},{"ibatch_id":"106-20-B0007","ibatch_quantity_used":600}]',
    @product_batch_id,
    @success,
    @message
);

SELECT @product_batch_id, @success, @message;

-- Test adding ingredient batch failure (not enough quantity in selected batch)
CALL AddProductBatch(
    3,3,100,'2025-09-26','2025-11-15',
    '[{"ibatch_id":"201-20-B0003","ibatch_quantity_used":20},{"ibatch_id":"106-20-B0007","ibatch_quantity_used":600}]',
    @product_batch_id,
    @success,
    @message
);

SELECT @product_batch_id, @success, @message;

/* ---------------------
Testing cost calculations
----------------------- */
CALL ProductBatchCostSummary(
    '100-MFG001-B0901',1,
    @total_cost,
    @per_unit_cost,
    @success,
    @message
);

SELECT @total_cost, @per_unit_cost, @success, @message;

/* ---------------------
Testing IB recall
----------------------- */
CALL RecallIngredientBatch(
	'106-20-B0006',
    @affected_batches,
    @success,
    @message
);

SELECT @affected_batches, @success, @message;

/* ---------------------
Testing DNCL (Main function)
----------------------- */
CALL AddProductBatch(
    3,3,100,'2025-09-26','2025-11-15',NULL,
    @product_batch_id,
    @success,
    @message
);

SELECT @product_batch_id, @success, @message;

CALL CheckDoNotCombine(
	'102-MFG003-B0001',
    @contains_dnc
);

SELECT @contains_dnc;

INSERT INTO DoNotCombineList (Ingredient1ID, Ingredient2ID)
VALUES (106, 201);

CALL CheckDoNotCombine(
	'102-MFG003-B0001',
    @contains_dnc
);

SELECT @contains_dnc;

/* ---------------------
Testing DNCL (AddProductBatch early stop)
----------------------- */
INSERT INTO DoNotCombineList (Ingredient1ID, Ingredient2ID)
VALUES (106, 201);

CALL AddProductBatch(
    3,3,100,'2025-09-26','2025-11-15',NULL,
    @product_batch_id,
    @success,
    @message
);

SELECT @product_batch_id, @success, @message;