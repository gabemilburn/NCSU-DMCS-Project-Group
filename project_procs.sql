USE csc540_project;

DROP PROCEDURE IF EXISTS CheckDoNotCombine;
DROP PROCEDURE IF EXISTS AddProductBatch;
DROP PROCEDURE IF EXISTS ProductBatchCostSummary;
DROP PROCEDURE IF EXISTS RecallIngredientBatch;

DELIMITER $$

-- Checks if product batch's ingredient batchs contain ingredients that should not be combined
-- 	This is used for the next AddProductBatch procedure, and blocks that if this one returns true
CREATE PROCEDURE CheckDoNotCombine(
	-- Procedure inputs
    IN p_product_batch_id VARCHAR(255),
    -- Procudure outputs
    OUT p_contains_dnc BOOL
)
proc_label: BEGIN
	DECLARE v_ingredient_1_id INT;
    DECLARE v_ingredient_2_id INT;
    DECLARE done INT DEFAULT 0;
	-- RecipeBOM cursor 1
    DECLARE rbom_cursor1 CURSOR FOR
        SELECT rbom.IngredientID
        FROM RecipeBOM rbom
        WHERE rbom.RecipeID = (SELECT RecipeID FROM ProductBatch pb WHERE pb.LotID = p_product_batch_id);
	-- RecipeBOM cursor 2
    DECLARE rbom_cursor2 CURSOR FOR
        SELECT rbom.IngredientID
        FROM RecipeBOM rbom
        WHERE rbom.RecipeID = (SELECT RecipeID FROM ProductBatch pb WHERE pb.LotID = p_product_batch_id);
	
    -- Exception handler for cursor loops
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
    -- General exception handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_product_batch_id = NULL;
    END;
    
    START TRANSACTION;
    
    OPEN rbom_cursor1;
    rbom_loop1: LOOP
		FETCH rbom_cursor1 INTO v_ingredient_1_id;
        IF done THEN
			CLOSE rbom_cursor1;
			SET p_contains_dnc = FALSE;
            LEAVE rbom_loop1;
		END IF;
        OPEN rbom_cursor2;
        rbom_loop2: LOOP
			FETCH rbom_cursor2 INTO v_ingredient_2_id;
			IF done THEN
				CLOSE rbom_cursor2;
				LEAVE rbom_loop2;
			END IF;
            IF EXISTS (
				SELECT * FROM DoNotCombineList
                WHERE Ingredient1ID = LEAST(v_ingredient_1_id, v_ingredient_2_id)
                AND Ingredient2ID = GREATEST(v_ingredient_1_id, v_ingredient_2_id)
            ) THEN
				CLOSE rbom_cursor1;
                CLOSE rbom_cursor2;
				SET p_contains_dnc = TRUE;
                LEAVE rbom_loop1;
			END IF;
        END LOOP rbom_loop2;
    END LOOP rbom_loop1;
    
    COMMIT;
END$$

-- Adding a product batch
-- 	Supports manual ingredient batch assignment or automatic consumption (FEFO)
CREATE PROCEDURE AddProductBatch(
	-- Procedure inputs
    IN p_recipe_id INT,
    IN p_manufacturer_id INT,
    IN p_quantity_to_produce INT,
    IN p_production_date DATE,
    IN p_expiration_date DATE,
    IN p_ingredient_batch_list JSON,
    -- Procudure outputs
    OUT p_product_batch_id VARCHAR(255),
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
proc_label: BEGIN
	-- Helper variables
    DECLARE v_required_qty DEC(10,2);
    DECLARE v_available_qty DEC(10,2);
    DECLARE v_ingredient_id INT;
    DECLARE v_ibatch_id VARCHAR(255);
    DECLARE v_expiration_date DATE;
    DECLARE v_qty_to_use DECIMAL(10,2);
    -- Exception helper bool
    DECLARE done INT DEFAULT 0;
    
    -- Cursor for RecipeBOM items
    DECLARE rbom_cursor CURSOR FOR
        SELECT rbom.IngredientID, rbom.Quantity * p_quantity_to_produce AS required_qty
        FROM RecipeBOM rbom
        WHERE rbom.RecipeID = p_recipe_id;

    -- Cursor for ingredient batches (automatic assignment)
    DECLARE ibatch_cursor CURSOR FOR
        SELECT ib.LotID, ib.Quantity
        FROM IngredientBatch ib
        -- Ingredient batches of the given ingredientID
        WHERE (SELECT f.IngredientID FROM Formulation f WHERE ib.FormulationID = f.FormulationID) = v_ingredient_id
        -- Manufacturer owns ingredient batch
		AND ib.ManufacturerID = p_manufacturer_id
		-- Ingredient batch is non-empty
		AND ib.Quantity > 0
		-- Ingredient batch is not expired
		AND ib.ExpirationDate > CURDATE()
        -- Get earliest expiration date ingredient batches first
        ORDER BY ib.ExpirationDate ASC;
	
	-- Cursor for manually assigned ingredient batches
	DECLARE ibatch_list_cursor CURSOR FOR
			SELECT item.ibatch_id, item.ibatch_quantity_used
            FROM JSON_TABLE(p_ingredient_batch_list, '$[*]' COLUMNS(ibatch_id VARCHAR(255) PATH '$.ibatch_id', ibatch_quantity_used DEC(10,2) PATH '$.ibatch_quantity_used')) item
            WHERE (SELECT f.IngredientID FROM Formulation f WHERE (SELECT ib.FormulationID FROM IngredientBatch ib WHERE ib.LotID = item.ibatch_id) = f.FormulationID) = v_ingredient_id;
	
	-- Exception handler for cursor loops
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
    -- General exception handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = 'An error occurred during batch creation.';
        SET p_product_batch_id = NULL;
    END;
    START TRANSACTION;
	
    -- Validate recipe exists
    IF NOT EXISTS (
        SELECT * FROM Recipe r
        WHERE r.RecipeID = p_recipe_id
    ) THEN
        SET p_success = FALSE;
        SET p_message = 'Recipe does not exist.';
        SET p_product_batch_id = NULL;
        ROLLBACK;
        LEAVE proc_label;
    END IF;
    
    -- Validate manufacturer owns recipe
	IF NOT EXISTS (
        SELECT * FROM Recipe r
        JOIN Product p ON p.ProductID = r.ProductID
        WHERE r.RecipeID = p_recipe_id
        AND p.ManufacturerID = p_manufacturer_id
    ) THEN
        SET p_success = FALSE;
        SET p_message = 'Recipe does not belong to the specified manufacturer.';
        SET p_product_batch_id = NULL;
        ROLLBACK;
        LEAVE proc_label;
    END IF;
	
    -- Create the product batch
    INSERT INTO ProductBatch (RecipeID, BatchQuantity, ProductionDate, ExpirationDate)
		VALUES (p_recipe_id, p_quantity_to_produce, p_production_date, p_expiration_date);
    
	-- Retreive most recently generated product batch lot id
	SELECT pb.LotID INTO p_product_batch_id
		FROM ProductBatch pb
		JOIN Recipe r ON r.RecipeID = pb.RecipeID
		JOIN Product p ON p.ProductID = r.ProductID
		-- Check if LotID product ID matches (recipe match -> product match)
		WHERE r.RecipeID = p_recipe_id
		-- Check if LotID manufacturerID matches (from product table)
		AND p.ManufacturerID = p_manufacturer_id
		-- Get most recent batch (using how the trigger creates batch id)
		ORDER BY CAST(SUBSTRING_INDEX(pb.LotID, '-B', -1) AS UNSIGNED) DESC
		LIMIT 1;
	
	-- Make sure the previous statement worked
	IF p_product_batch_id IS NULL THEN
		ROLLBACK;
		SET p_success = FALSE;
		SET p_message = 'Failed to retrieve generated ProductBatch ID after insert.';
		LEAVE proc_label;
	END IF;
	
    CALL CheckDoNotCombine(
		p_product_batch_id,
		@contains_dnc
	);

	IF (SELECT @contains_dnc) THEN
		ROLLBACK;
		SET p_success = FALSE;
		SET p_message = 'Product recipe contains ingreidents in do not combine list.';
		LEAVE proc_label;
    END IF;
    
    -- Manual ingredient batch assignment
    IF p_ingredient_batch_list IS NOT NULL THEN
		OPEN rbom_cursor;
		rbom_loop: LOOP
			FETCH rbom_cursor INTO v_ingredient_id, v_required_qty;
			IF done THEN
				SET done = 0;
				LEAVE rbom_loop;
			END IF;
            
            OPEN ibatch_list_cursor;
            ibatch_loop: LOOP
				FETCH ibatch_list_cursor INTO v_ibatch_id, v_qty_to_use;
                -- In case specified quantity to use is more than needed
                SET v_qty_to_use = LEAST(v_qty_to_use, v_required_qty);
				-- Not enough stock for current ingredient
				IF done THEN
					SET done = 0;
					CLOSE ibatch_list_cursor;
                    CLOSE rbom_cursor;
					SET p_success = FALSE;
					SET p_message = CONCAT('Selected stock insufficient for ingredient ID: ', v_ingredient_id);
					ROLLBACK;
					LEAVE proc_label;
				END IF;
                -- Get relavent attributes for specified ingredient batch
				SELECT Quantity, ExpirationDate INTO v_available_qty, v_expiration_date
                FROM IngredientBatch
                WHERE LotID = v_ibatch_id;

				-- Make sure specified ingredient batch exists
				IF v_available_qty IS NULL THEN
					CLOSE ibatch_list_cursor;
                    CLOSE rbom_cursor;
					SET p_success = FALSE;
					SET p_message = CONCAT('Ingredient batch does not exist with LotID: ', v_ibatch_id);
					SET p_product_batch_id = NULL;
					ROLLBACK;
					LEAVE proc_label;
				END IF;
                
				-- Make sure specified ingredient is not expired
				IF v_expiration_date < CURDATE() THEN
					CLOSE ibatch_list_cursor;
                    CLOSE rbom_cursor;
					SET p_success = FALSE;
					SET p_message = CONCAT('Ingredient batch expired with LotID: ', v_ibatch_id);
					SET p_product_batch_id = NULL;
					ROLLBACK;
					LEAVE proc_label;
				END IF;

				-- Make sure specified ingredient batch has enough quantity
				IF v_available_qty < v_qty_to_use THEN
					CLOSE ibatch_list_cursor;
                    CLOSE rbom_cursor;
					SET p_success = FALSE;
					SET p_message = CONCAT('Ingredient batch does not have enough quantity with LotID: ', v_ibatch_id);
					SET p_product_batch_id = NULL;
					ROLLBACK;
					LEAVE proc_label;
				END IF;
                
				-- If the current batch has at least enough quantity (required or to use)
				IF v_available_qty >= v_qty_to_use THEN
					-- Add that the product batch uses given ingredient batch
					INSERT INTO ProductBatchIngredientBatch (ProductLotID, IngredientLotID, QuantityUsed)
					VALUES (p_product_batch_id, v_ibatch_id, v_qty_to_use);
					-- Decrease quantity left in used ingredient batch
					UPDATE IngredientBatch
						SET Quantity = Quantity - v_qty_to_use
						WHERE LotID = v_ibatch_id;

					SET v_required_qty = v_required_qty - v_qty_to_use;
                    -- In the case that selected amount was less than required
                    IF v_required_qty = 0 THEN
						CLOSE ibatch_list_cursor;
						LEAVE ibatch_loop;
					END IF;
				-- If the current batch does not have enough
				ELSE
					INSERT INTO ProductBatchIngredientBatch (ProductLotID, IngredientLotID, QuantityUsed)
					VALUES (p_product_batch_id, v_ibatch_id, v_available_qty);
					-- Set ingredient batch quantity to 0 (use it up completely)
					UPDATE IngredientBatch
						SET Quantity = 0
						WHERE LotID = v_ibatch_id;

					SET v_required_qty = v_required_qty - v_available_qty;
				END IF;
            END LOOP ibatch_loop;
		END LOOP rbom_loop;
        CLOSE rbom_cursor;
	-- Automatic (FEFO) assignment
	ELSE
		-- Process each RecipeBOM item
		OPEN rbom_cursor;
		rbom_loop: LOOP
			FETCH rbom_cursor INTO v_ingredient_id, v_required_qty;
			IF done THEN
				SET done = 0;
				LEAVE rbom_loop;
			END IF;
			
			-- Consume ingredient batches automatically
			OPEN ibatch_cursor;
			ibatch_loop: LOOP
				FETCH ibatch_cursor INTO v_ibatch_id, v_available_qty;
				-- Not enough stock for current ingredient
				IF done THEN
					SET done = 0;
					CLOSE ibatch_cursor;
					SET p_success = FALSE;
					SET p_message = CONCAT('Insufficient stock for ingredient ID: ', v_ingredient_id);
					ROLLBACK;
					LEAVE proc_label;
				END IF;
				
				-- If the current batch has at least enough quantity
				IF v_available_qty >= v_required_qty THEN
					-- Add that the product batch uses given ingredient batch
					INSERT INTO ProductBatchIngredientBatch (ProductLotID, IngredientLotID, QuantityUsed)
					VALUES (p_product_batch_id, v_ibatch_id, v_required_qty);
					-- Decrease quantity left in used ingredient batch
					UPDATE IngredientBatch
						SET Quantity = Quantity - v_required_qty
						WHERE LotID = v_ibatch_id;

					SET v_qty_to_use = 0;
					CLOSE ibatch_cursor;
					LEAVE ibatch_loop;
				-- If the current batch does not have enough
				ELSE
					INSERT INTO ProductBatchIngredientBatch (ProductLotID, IngredientLotID, QuantityUsed)
					VALUES (p_product_batch_id, v_ibatch_id, v_available_qty);
					-- Set ingredient batch quantity to 0 (use it up completely)
					UPDATE IngredientBatch
						SET Quantity = 0
						WHERE LotID = v_ibatch_id;

					SET v_required_qty = v_required_qty - v_available_qty;
				END IF;
			END LOOP ibatch_loop;
		END LOOP rbom_loop;
		CLOSE rbom_cursor;
	END IF;

    -- Success
    COMMIT;
    SET p_success = TRUE;
    SET p_message = 'Product batch created successfully.';
END$$



-- Calculates cost statistics for product batch lot id
-- 	Also makes sure that the lot and manufacturer exists, and that the manufacturer owns the lot
CREATE PROCEDURE ProductBatchCostSummary(
	-- Procedure inputs
    IN p_product_batch_id VARCHAR(255),
    IN p_manufacturer_id INT,
    -- Procudure outputs
    OUT p_total_cost DEC(10,2),
    OUT p_per_unit_cost DEC(10,2),
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
proc_label: BEGIN
    -- General exception handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = 'An error occurred calculation.';
        SET p_total_cost = NULL;
        SET p_per_unit_cost = NULL;
    END;

	START TRANSACTION;
    
    IF NOT EXISTS (
		SELECT * FROM ProductBatch pb
        JOIN Recipe r ON r.RecipeID = pb.RecipeID
        JOIN Product p ON p.ProductID = r.ProductID
        WHERE pb.LotID = p_product_batch_id
    ) THEN
		SET p_success = FALSE;
		SET p_message = CONCAT('Manufacturer or product batch does not exist');
        ROLLBACK;
        LEAVE proc_label;
	END IF;
    
    IF NOT (
		SELECT p.ManufacturerID FROM ProductBatch pb
        JOIN Recipe r ON r.RecipeID = pb.RecipeID
        JOIN Product p ON p.ProductID = r.ProductID
        WHERE pb.LotID = p_product_batch_id
    ) = p_manufacturer_id THEN
		SET p_success = FALSE;
		SET p_message = 'Manufacturer does not own product batch.';
        ROLLBACK;
        LEAVE proc_label;
	END IF;
    
	-- Total cost
	SELECT SUM(f.UnitPrice * pbib.QuantityUsed) INTO p_total_cost
	FROM ProductBatchIngredientBatch pbib
	JOIN IngredientBatch ib ON ib.LotID = pbib.IngredientLotID
	JOIN Formulation f ON f.FormulationID = ib.FormulationID
	WHERE pbib.ProductLotID = p_product_batch_id;
    -- Per unit cost
    SET p_per_unit_cost = p_total_cost / (SELECT BatchQuantity FROM ProductBatch pb WHERE pb.LotID = p_product_batch_id);
    
    COMMIT;
	SET p_success = TRUE;
    SET p_message = 'Returned costs successfully.';
END$$



-- Returns (comma seperated) list of product batches affected by ingredient batch recall
-- 	Why is this a procedure? I guess because returning a table is hard? You could just query but idk
CREATE PROCEDURE RecallIngredientBatch(
	-- Procedure inputs
    IN p_ingredient_batch_id VARCHAR(255),
    -- Procudure outputs
    OUT p_affected_batches VARCHAR(255),
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
proc_label: BEGIN
	DECLARE v_product_batch_lot_id VARCHAR(255);
    DECLARE done INT DEFAULT 0;
    
	-- Cursor for scanning through ProductBatchIngredientBatch
	DECLARE pbib_cursor CURSOR FOR
			SELECT ProductLotID FROM ProductBatchIngredientBatch
            WHERE IngredientLotID = p_ingredient_batch_id;
	
	-- Exception handler for cursor loops
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
    -- General exception handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_message = 'An error occurred calculation.';
        SET p_affected_batches = NULL;
    END;

	START TRANSACTION;
		OPEN pbib_cursor;
		pbib_loop: LOOP
			FETCH pbib_cursor INTO v_product_batch_lot_id;
			IF done THEN
				CLOSE pbib_cursor;
				LEAVE pbib_loop;
			END IF;
            IF p_affected_batches IS NULL THEN
				SET p_affected_batches = v_product_batch_lot_id;
			ELSE
				SET p_affected_batches = CONCAT(p_affected_batches,",",v_product_batch_lot_id);
            END IF;
        END LOOP pbib_loop;
    COMMIT;
	SET p_success = TRUE;
    SET p_message = 'Returned product batch lot ids successfully.';
END$$

DELIMITER ;

