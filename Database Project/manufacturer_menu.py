"""
CSC540 Database Project - Manufacturer Menu Module
Food Manufacturing Inventory Management System
"""

import mysql.connector
from datetime import date, datetime, timedelta

class ManufacturerMenu:
    def __init__(self, connection, cursor, user_id, manufacturer_id):
        self.connection = connection
        self.cursor = cursor
        self.user_id = user_id
        self.manufacturer_id = manufacturer_id

    # Utility input helpers
    def validate_date(self, year, month, day):
        try:
            d = date(int(year), int(month), int(day))
            return d.strftime("%Y-%m-%d")
        except ValueError:
            return None

    def validate_positive_number(self, prompt, number_type=float, allow_zero=False):
        while True:
            try:
                value = number_type(input(prompt))
                if value > 0 or (allow_zero and value == 0):
                    return value
                else:
                    print("Error: Value must be positive." if not allow_zero else
                          "Error: Value must be non-negative.")
            except ValueError:
                print(f"Error: Please enter a valid {number_type.__name__}.")

    def validate_int_choice(self, prompt, valid_values):
        while True:
            try:
                val = int(input(prompt))
                if val in valid_values:
                    return val
                print(f"Error: Please enter one of {sorted(valid_values)}.")
            except ValueError:
                print("Error: Please enter a valid integer.")

    def ensure_clean_transaction(self):
        try:
            self.connection.rollback()
        except:
            pass 

    # Main menu loop
    def run(self):
        while True:
            print("\n" + "="*60)
            print("MANUFACTURER MENU")
            print("="*60)
            print("1) Manage Products")
            print("2) Maintain Recipes")
            print("3) Receive Ingredient Batches")
            print("4) Create Product Batch")
            print("5) Reports")
            print("6) Recall & Traceability")
            print("7) View Ingredient Inventory")
            print("8) View Product Batches")
            print("9) Logout") 
            print("="*60)

            try:
                choice = int(input("\nSelection: "))
            except ValueError:
                print("Invalid input. Please enter a number.")
                continue

            try:
                if choice == 1:
                    self.manage_products()
                elif choice == 2:
                    self.maintain_recipes()
                elif choice == 3:
                    self.receive_ingredient_batches()
                elif choice == 4:
                    self.create_product_batch()
                elif choice == 5:
                    self.reports_menu()
                elif choice == 6:
                    self.recall_traceability_menu()
                elif choice == 7:
                    self.view_ingredient_inventory()
                elif choice == 8:
                    self.view_product_batches()
                elif choice == 9:  
                    print("\nReturning to role selection...")
                    break
                else:
                    print("Invalid choice. Please enter 1-9.")  
            except mysql.connector.Error as err:
                print(f"Database error: {err}")
                self.connection.rollback()
            except Exception as e:
                print(f"Unexpected error: {e}")
                self.connection.rollback()

    # 1) Manage Products
    def manage_products(self):
        print("\n" + "-"*60)
        print("MANAGE PRODUCTS")
        print("-"*60)
        print("1) Create New Product")
        print("2) Update Existing Product")
        print("3) View My Products")
        print("4) Back to Main Menu")

        try:
            choice = int(input("\nSelection: "))
        except ValueError:
            print("Invalid input. Please enter a number.")
            return

        if choice == 1:
            self.create_product()
        elif choice == 2:
            self.update_product()
        elif choice == 3:
            self.view_products()
        elif choice == 4:
            return
        else:
            print("Invalid choice.")

    def view_categories(self):
        self.cursor.execute("""
            SELECT CategoryID, CategoryName
            FROM ProductCategory
            ORDER BY CategoryName
        """)
        rows = self.cursor.fetchall()
        if not rows:
            print("\nNo product categories defined yet.")
        else:
            print(f"\n{'CatID':<6} {'Category Name':<30}")
            print("-"*40)
            for r in rows:
                print(f"{r[0]:<6} {r[1]:<30}")
        return rows

    def create_product(self):
        print("\n--- Create New Product ---")
        
        while True:
            cats = self.view_categories()
            
            if not cats:
                print("\nNo categories exist yet. Let's create one first.")
                create_cat = 'Y'
            else:
                create_cat = input("\nCreate a new category? (Y/N): ").strip().upper()
            
            if create_cat == 'Y':
                cat_name = input("New category name: ").strip()
                if not cat_name:
                    print("Error: Category name cannot be empty.")
                    continue
                
                try:
                    self.cursor.execute("""
                        INSERT INTO ProductCategory (CategoryName)
                        VALUES (%s)
                    """, (cat_name,))
                    self.connection.commit()
                    
                    self.cursor.execute("SELECT LAST_INSERT_ID()")
                    category_id = self.cursor.fetchone()[0]
                    print(f"Category '{cat_name}' created with ID {category_id}")
                    
                except mysql.connector.IntegrityError as err:
                    if err.errno == 1062:  # Duplicate entry
                        print(f"Category '{cat_name}' already exists.")
                        # Get the existing category ID
                        self.cursor.execute("""
                            SELECT CategoryID FROM ProductCategory WHERE CategoryName = %s
                        """, (cat_name,))
                        existing = self.cursor.fetchone()
                        if existing:
                            category_id = existing[0]
                            print(f"Using existing category with ID {category_id}.")
                        else:
                            continue
                    else:
                        print(f"Database error: {err}")
                        self.connection.rollback()
                        continue
                except mysql.connector.Error as err:
                    print(f"Database error: {err}")
                    self.connection.rollback()
                    continue
            else:
                if not cats:
                    print("You must create a category first.")
                    continue
                
                # Select existing category
                category_ids = {c[0] for c in cats}
                try:
                    category_id = int(input("\nEnter CategoryID: "))
                    if category_id not in category_ids:
                        print("Error: Invalid CategoryID.")
                        continue
                except ValueError:
                    print("Error: Invalid input.")
                    continue
            
            # Now create the product
            name = input("\nProduct Name: ").strip()
            if not name:
                print("Error: Product name cannot be empty.")
                continue

            default_batch = self.validate_positive_number(
                "Default batch size (units): ", int
            )

            try:
                self.cursor.execute("""
                    INSERT INTO Product (CategoryID, ManufacturerID, ProductName, DefaultBatchSize)
                    VALUES (%s, %s, %s, %s)
                """, (category_id, self.manufacturer_id, name, default_batch))
                self.connection.commit()

                self.cursor.execute("SELECT LAST_INSERT_ID()")
                pid = self.cursor.fetchone()[0]
                print(f"\nProduct created successfully with ID: {pid}")
                break
                
            except mysql.connector.IntegrityError as err:
                if err.errno == 1062:  # Duplicate entry
                    print(f"Error: Product '{name}' already exists for this manufacturer.")
                else:
                    print(f"Database error: {err}")
                self.connection.rollback()
                retry = input("Try again? (Y/N): ").strip().upper()
                if retry != 'Y':
                    break
            except mysql.connector.Error as err:
                print(f"Database error: {err}")
                self.connection.rollback()
                retry = input("Try again? (Y/N): ").strip().upper()
                if retry != 'Y':
                    break

    def view_products(self):
        print("\n--- My Products ---")
        try:
            self.cursor.callproc('sp_view_manufacturer_products', [self.manufacturer_id])
            for result in self.cursor.stored_results():
                rows = result.fetchall()
                if rows:
                    print(f"\n{'ProdID':<8} {'Product Name':<30} {'Category':<20} {'Default Batch':<14}")
                    print("-"*80)
                    for r in rows:
                        print(f"{r[0]:<8} {r[1]:<30} {r[2]:<20} {r[3]:<14}")
                else:
                    print("No products found.")
        except mysql.connector.Error as err:
            print(f"Database error: {err}")

    def update_product(self):
        print("\n--- Update Existing Product ---")
        self.view_products()
        try:
            product_id = int(input("\nEnter ProductID to update (0 to cancel): "))
            if product_id == 0:
                return

            # Ensure this product belongs to this manufacturer
            self.cursor.execute("""
                SELECT ProductName, DefaultBatchSize, CategoryID
                FROM Product
                WHERE ProductID = %s AND ManufacturerID = %s
            """, (product_id, self.manufacturer_id))
            row = self.cursor.fetchone()
            if not row:
                print("Error: Product not found or not owned by you.")
                return

            current_name, current_batch, current_cat = row
            print(f"Current name: {current_name}")
            print(f"Current default batch size: {current_batch}")
            print(f"Current category ID: {current_cat}")

            new_name = input("New name (leave blank to keep current): ").strip()
            if not new_name:
                new_name = current_name

            new_batch = input("New default batch size (leave blank to keep current): ").strip()
            if new_batch:
                try:
                    new_batch = int(new_batch)
                    if new_batch <= 0:
                        print("Error: Default batch size must be positive.")
                        return
                except ValueError:
                    print("Error: Invalid batch size.")
                    return
            else:
                new_batch = current_batch

            print("\nUpdate category? Current categories:")
            cats = self.view_categories()
            new_cat = input("New CategoryID (leave blank to keep current): ").strip()
            if new_cat:
                try:
                    new_cat = int(new_cat)
                except ValueError:
                    print("Error: Invalid CategoryID.")
                    return
            else:
                new_cat = current_cat

            self.cursor.execute("""
                UPDATE Product
                SET ProductName = %s,
                    DefaultBatchSize = %s,
                    CategoryID = %s
                WHERE ProductID = %s AND ManufacturerID = %s
            """, (new_name, new_batch, new_cat, product_id, self.manufacturer_id))
            self.connection.commit()
            print("Product updated successfully.")

        except mysql.connector.Error as err:
            print(f"Database error: {err}")
            self.connection.rollback()

    # 2) Maintain Recipes (versioned)
    def maintain_recipes(self):
        print("\n" + "-"*60)
        print("MAINTAIN RECIPES")
        print("-"*60)
        print("1) Create New Recipe Version")
        print("2) View Recipes for a Product")
        print("3) View Recipe Details")
        print("4) Check Recipe for Incompatibilities")
        print("5) Back to Main Menu")

        try:
            choice = int(input("\nSelection: "))
        except ValueError:
            print("Invalid input.")
            return

        if choice == 1:
            self.create_recipe_version()
        elif choice == 2:
            self.view_recipes_for_product()
        elif choice == 3:
            self.view_recipe_details()
        elif choice == 4:
            self.check_recipe_incompatibilities()
        elif choice == 5:
            return
        else:
            print("Invalid choice.")

    def _select_product(self):
        self.view_products()
        try:
            pid = int(input("\nEnter ProductID (0 to cancel): "))
        except ValueError:
            print("Invalid ProductID.")
            return None
        if pid == 0:
            return None

        self.cursor.execute("""
            SELECT ProductName, DefaultBatchSize
            FROM Product
            WHERE ProductID = %s AND ManufacturerID = %s
        """, (pid, self.manufacturer_id))
        row = self.cursor.fetchone()
        if not row:
            print("Error: Product not found or not owned by you.")
            return None
        print(f"Selected product: {row[0]} (Default batch size: {row[1]} units)")
        return pid

    def create_recipe_version(self):
        print("\n--- Create New Recipe Version ---")
        product_id = self._select_product()
        if product_id is None:
            return

        # See if there are existing recipes to copy from
        self.cursor.execute("""
            SELECT RecipeID, CreationDate
            FROM Recipe
            WHERE ProductID = %s
            ORDER BY CreationDate DESC, RecipeID DESC
        """, (product_id,))
        recipes = self.cursor.fetchall()

        base_bom = {}
        if recipes:
            print("\nExisting recipe versions:")
            print(f"{'RecipeID':<10} {'CreationDate':<20}")
            print("-"*30)
            for r in recipes:
                creation_date = r[1].strftime('%Y-%m-%d') if r[1] else 'N/A'
                print(f"{r[0]:<10} {creation_date:<20}")
            base = input("\nBase this version on an existing RecipeID? (enter ID or 0 for none): ").strip()
            try:
                base_id = int(base)
            except ValueError:
                print("Invalid input.")
                return
            if base_id != 0:
                # Load BOM from the chosen recipe
                self.cursor.execute("""
                    SELECT IngredientID, Quantity
                    FROM RecipeBOM
                    WHERE RecipeID = %s
                """, (base_id,))
                for ing_id, qty in self.cursor.fetchall():
                    base_bom[ing_id] = qty

        # Draft BOM in memory: {ingredient_id: quantity_per_unit}
        draft_bom = dict(base_bom)
        while True:
            # Display current draft
            print("\n--- Current Recipe Draft ---")
            if draft_bom:
                print(f"{'IngredientID':<12} {'Name':<30} {'Qty per Unit (oz)':<18}")
                print("-"*65)
                for ing_id, qty in draft_bom.items():
                    self.cursor.execute("SELECT IngredientName FROM Ingredient WHERE IngredientID = %s",
                                        (ing_id,))
                    name_row = self.cursor.fetchone()
                    name = name_row[0] if name_row else "UNKNOWN"
                    print(f"{ing_id:<12} {name:<30} {qty:<18.3f}")
            else:
                print("No ingredients in this draft yet.")

            print("\nDraft Options:")
            print("1) Add / Update Ingredient")
            print("2) Remove Ingredient")
            print("3) Commit New Recipe Version")
            print("4) Cancel Draft")

            choice = input("Selection: ").strip()
            if choice == "1":
                # Add / update ingredient
                self.cursor.execute("""
                    SELECT IngredientID, IngredientName, IsCompound
                    FROM Ingredient
                    ORDER BY IngredientName
                """)
                print(f"\n{'ID':<6} {'Ingredient Name':<30} {'Type':<10}")
                print("-"*50)
                for ing_id, name, is_comp in self.cursor.fetchall():
                    t = "Compound" if is_comp else "Atomic"
                    print(f"{ing_id:<6} {name:<30} {t:<10}")

                try:
                    ing_id = int(input("\nEnter IngredientID to add/update (0 to cancel): "))
                except ValueError:
                    print("Invalid IngredientID.")
                    continue
                if ing_id == 0:
                    continue

                qty = self.validate_positive_number("Quantity per unit (oz): ", float)
                draft_bom[ing_id] = qty

            elif choice == "2":
                try:
                    ing_id = int(input("IngredientID to remove (0 to cancel): "))
                except ValueError:
                    print("Invalid IngredientID.")
                    continue
                if ing_id == 0:
                    continue
                if ing_id in draft_bom:
                    del draft_bom[ing_id]
                    print("Ingredient removed from draft.")
                else:
                    print("Ingredient not found in draft.")

            elif choice == "3":
                if not draft_bom:
                    print("Cannot commit an empty recipe.")
                    continue
                self._commit_recipe_version(product_id, draft_bom)
                return
                
            elif choice == "4":
                print("Draft cancelled.")
                return
            else:
                print("Invalid choice.")

    def _commit_recipe_version(self, product_id, draft_bom):
        print("\nCommitting new recipe version...")
        try:
            self.ensure_clean_transaction()
            self.connection.start_transaction()

            # Create Recipe header
            self.cursor.execute("""
                INSERT INTO Recipe (ProductID)
                VALUES (%s)
            """, (product_id,))
            
            recipe_id = self.cursor.lastrowid

            # Insert BOM rows
            for ing_id, qty in draft_bom.items():
                self.cursor.execute("""
                    INSERT INTO RecipeBOM (RecipeID, IngredientID, Quantity)
                    VALUES (%s, %s, %s)
                """, (recipe_id, ing_id, qty))

            # Check for incompatibilities
            has_conflicts, conflicts = self.check_recipe_conflicts(recipe_id)

            # Check for conflicts
            self.cursor.callproc('sp_get_recipe_conflicts', [recipe_id])

            for result in self.cursor.stored_results():
                conflicts = result.fetchall()
                if conflicts:
                    print("\n" + "="*70)
                    print("WARNING: Do-Not-Combine Conflicts Detected")
                    print("="*70)
                    print("The following ingredient pairs should not be combined:")
                    print(f"\n{'Ingredient 1':<30} {'Ingredient 2':<30}")
                    print("-"*65)
                    for c in conflicts:
                        print(f"{c[1]:<30} {c[3]:<30}")
                    print("\nThis recipe may pose health risks!")
                else:
                    print("\nNo ingredient conflicts detected")

            # No conflicts - proceed with commit
            self.connection.commit()
            print(f"\nNew recipe version created with RecipeID: {recipe_id}")
            
        except mysql.connector.Error as err:
            print(f"Database error during commit: {err}")
            self.connection.rollback()

    def view_recipes_for_product(self):
        print("\n--- View Recipes for a Product ---")
        pid = self._select_product()
        if pid is None:
            return

        self.cursor.execute("""
            SELECT RecipeID, CreationDate
            FROM Recipe
            WHERE ProductID = %s
            ORDER BY CreationDate DESC, RecipeID DESC
        """, (pid,))
        rows = self.cursor.fetchall()
        if rows:
            print(f"\n{'RecipeID':<10} {'CreationDate':<20}")
            print("-"*30)
            for r in rows:
                # Format datetime properly
                creation_date = r[1].strftime('%Y-%m-%d') if r[1] else 'N/A'
                print(f"{r[0]:<10} {creation_date:<20}")
        else:
            print("No recipes found for that product.")

    def view_recipe_details(self):
        print("\n--- View Recipe Details ---")
        try:
            recipe_id = int(input("Enter RecipeID: "))
        except ValueError:
            print("Invalid RecipeID.")
            return

        # Header
        self.cursor.execute("""
            SELECT r.RecipeID, r.CreationDate, p.ProductID, p.ProductName
            FROM Recipe r
            JOIN Product p ON r.ProductID = p.ProductID
            WHERE r.RecipeID = %s AND p.ManufacturerID = %s
        """, (recipe_id, self.manufacturer_id))
        header = self.cursor.fetchone()
        if not header:
            print("Recipe not found or not owned by you.")
            return

        print("\n--- Recipe Header ---")
        print(f"RecipeID:   {header[0]}")
        print(f"ProductID:  {header[2]} ({header[3]})")
        # Format the date properly
        creation_date = header[1].strftime('%Y-%m-%d %H:%M:%S') if header[1] else 'N/A'
        print(f"Created on: {creation_date}")

        # BOM
        self.cursor.execute("""
            SELECT rb.IngredientID, i.IngredientName, rb.Quantity
            FROM RecipeBOM rb
            JOIN Ingredient i ON rb.IngredientID = i.IngredientID
            WHERE rb.RecipeID = %s
            ORDER BY i.IngredientName
        """, (recipe_id,))
        rows = self.cursor.fetchall()
        if rows:
            print("\n--- Ingredients ---")
            print(f"{'IngredientID':<12} {'Name':<30} {'Qty per Unit (oz)':<18}")
            print("-"*65)
            for r in rows:
                print(f"{r[0]:<12} {r[1]:<30} {r[2]:<18.3f}")
        else:
            print("\nThis recipe has no ingredients defined.")

    def check_recipe_conflicts(self, recipe_id):
        self.cursor.callproc('sp_get_recipe_conflicts', [recipe_id])
        
        conflicts = []
        for result in self.cursor.stored_results():
            conflicts = result.fetchall()
        
        return (len(conflicts) > 0, conflicts)

    def check_recipe_incompatibilities(self):
        print("\n--- Check Recipe for Incompatibilities ---")
        try:
            recipe_id = int(input("Enter RecipeID to check: "))
        except ValueError:
            print("Invalid RecipeID.")
            return

        # Verify ownership
        self.cursor.execute("""
            SELECT r.RecipeID
            FROM Recipe r
            INNER JOIN Product p ON r.ProductID = p.ProductID
            WHERE r.RecipeID = %s AND p.ManufacturerID = %s
        """, (recipe_id, self.manufacturer_id))
        
        if not self.cursor.fetchone():
            print("Recipe not found or not owned by you.")
            return

        # Check for conflicts
        has_conflicts, conflicts = self.check_recipe_conflicts(recipe_id)
        
        if has_conflicts:
            print("\nDo-Not-Combine Violations Found!")
            print(f"{'Ingredient 1 ID':<16} {'Ingredient 1':<30} {'Ingredient 2 ID':<16} {'Ingredient 2':<30}")
            print("-"*100)
            for row in conflicts:
                print(f"{row[0]:<16} {row[1]:<30} {row[2]:<16} {row[3]:<30}")
            print(f"\nTotal conflicts: {len(conflicts)}")
            print("\nThis recipe CANNOT be used for production.")
        else:
            print("\nNo do-not-combine conflicts found.")
            print("Recipe is safe to use in production.")

    # 3) Create Product Batch
    def allocate_ingredients_fefo(self, recipe_id, batch_quantity):
        # Get recipe requirements
        self.cursor.execute("""
            SELECT rb.IngredientID, i.IngredientName, rb.Quantity
            FROM RecipeBOM rb
            INNER JOIN Ingredient i ON rb.IngredientID = i.IngredientID
            WHERE rb.RecipeID = %s
        """, (recipe_id,))
        requirements = self.cursor.fetchall()
        
        allocations = []  # List of (ingredient_lot_id, quantity_used, cost)
        total_cost = 0
        
        for ing_id, ing_name, qty_per_unit in requirements:
            needed_oz = float(qty_per_unit) * batch_quantity 
            
            # Get available batches for this ingredient (FEFO order)
            self.cursor.execute("""
                SELECT 
                    ib.LotID,
                    ib.TotalQuantityOz,
                    f.UnitPrice,
                    f.PackSize,
                    ib.ExpirationDate
                FROM IngredientBatch ib
                INNER JOIN Formulation f ON ib.FormulationID = f.FormulationID
                WHERE f.IngredientID = %s
                AND ib.ManufacturerID = %s
                AND ib.TotalQuantityOz > 0
                AND ib.ExpirationDate >= CURDATE()
                ORDER BY ib.ExpirationDate ASC, ib.LotID ASC
            """, (ing_id, self.manufacturer_id))
            
            available_batches = self.cursor.fetchall()
            
            if not available_batches:
                return (False, None, 0, 
                    f"No available inventory for {ing_name}")
            
            # Allocate whole batches using FEFO
            remaining_needed = needed_oz
            ingredient_allocations = []
            
            for lot_id, available_oz, unit_price, pack_size, exp_date in available_batches:
                if remaining_needed <= 0:
                    break
                
                # Convert Decimals to float for arithmetic
                available_oz = float(available_oz)
                unit_price = float(unit_price)
                pack_size = float(pack_size)
                
                if available_oz >= remaining_needed:
                    qty_to_use = remaining_needed
                    cost = (qty_to_use / pack_size) * unit_price
                    ingredient_allocations.append((lot_id, qty_to_use, cost))
                    total_cost += cost
                    remaining_needed = 0
                    break
                else:
                    # Use the entire batch and continue to next
                    qty_to_use = available_oz
                    cost = (qty_to_use / pack_size) * unit_price
                    ingredient_allocations.append((lot_id, qty_to_use, cost))
                    total_cost += cost
                    remaining_needed -= available_oz
            
            # Check if we have enough
            if remaining_needed > 0:
                return (False, None, 0, 
                    f"Insufficient inventory for {ing_name}. Need {remaining_needed:.2f} more oz.")
            
            # Add this ingredient's allocations to the total list
            allocations.extend(ingredient_allocations)
        
        return (True, allocations, total_cost, "Success")
    
    def create_product_batch(self):
        print("\n" + "-"*60)
        print("CREATE PRODUCT BATCH (FEFO)")
        print("-"*60)

        product_id = self._select_product()
        if product_id is None:
            return

        # Get default batch size
        self.cursor.execute("""
            SELECT DefaultBatchSize
            FROM Product
            WHERE ProductID = %s AND ManufacturerID = %s
        """, (product_id, self.manufacturer_id))
        row = self.cursor.fetchone()
        if not row:
            print("Error: Product not found.")
            return
        default_batch = row[0]

        # Choose recipe version
        self.cursor.execute("""
            SELECT RecipeID, CreationDate
            FROM Recipe
            WHERE ProductID = %s
            ORDER BY CreationDate DESC, RecipeID DESC
        """, (product_id,))
        recipes = self.cursor.fetchall()
        if not recipes:
            print("No recipes exist for this product.")
            return

        print("\nAvailable recipes:")
        print(f"{'RecipeID':<10} {'CreationDate':<20}")
        print("-"*30)
        for r in recipes:
            creation_date = r[1].strftime('%Y-%m-%d') if r[1] else 'N/A'
            print(f"{r[0]:<10} {creation_date:<20}")

        try:
            recipe_id = int(input("\nEnter RecipeID to use: "))
        except ValueError:
            print("Invalid RecipeID.")
            return

        if recipe_id not in [r[0] for r in recipes]:
            print("Error: RecipeID not valid for this product.")
            return

        # Batch quantity
        num_batches = self.validate_positive_number(
            f"Number of batches to produce (each batch = {default_batch} units): ", int
        )
        batch_qty = num_batches * default_batch
        print(f"Total units to produce: {batch_qty}")

        # Dates
        prod_date_str = input("Production date (YYYY-MM-DD, blank for today): ").strip()
        if prod_date_str:
            try:
                datetime.strptime(prod_date_str, "%Y-%m-%d")
            except ValueError:
                print("Invalid production date.")
                return
        else:
            prod_date_str = date.today().strftime("%Y-%m-%d")

        exp_date_str = input("Expiration date (YYYY-MM-DD): ").strip()
        try:
            exp_dt = datetime.strptime(exp_date_str, "%Y-%m-%d").date()
        except ValueError:
            print("Invalid expiration date.")
            return
        if exp_dt <= datetime.strptime(prod_date_str, "%Y-%m-%d").date():
            print("Error: Expiration must be after production date.")
            return

        # FEFO Allocation
        print("\nAllocating ingredients using FEFO (whole batches only)...")
        
        success, allocations, total_cost, message = self.allocate_ingredients_fefo(
            recipe_id, batch_qty
        )
                
        # After allocation is successful
        if not success:
            print(f"\n{message}")
            return

        # Show allocation plan
        print("\n" + "="*70)
        print("ALLOCATION PLAN (FEFO)")
        print("="*70)
        print(f"{'Ingredient Lot':<20} {'Quantity (oz)':<15} {'Cost':<10}")
        print("-"*50)
        for lot_id, qty, cost in allocations:
            print(f"{lot_id:<20} {qty:<15.2f} ${cost:<9.2f}")
        print("-"*50)
        print(f"{'TOTAL COST':<36} ${total_cost:.2f}")
        print(f"Per-Unit Cost: ${total_cost / batch_qty:.4f}")
        print("="*70)

        # Check allocated lots for DNC conflicts
        print("\nEvaluating health risks in allocated ingredient lots...")

        # Build comma-separated list of lot IDs
        lot_ids_str = ','.join([lot_id for lot_id, _, _ in allocations])

        try:
            self.cursor.callproc('sp_evaluate_health_risk_for_allocated_lots', [lot_ids_str])
            
            for result in self.cursor.stored_results():
                violations = result.fetchall()
                if violations:
                    print("\n" + "="*70)
                    print("HEALTH RISK VIOLATION - BATCH CANNOT BE PRODUCED")
                    print("="*70)
                    print("The allocated ingredient lots contain do-not-combine conflicts:")
                    print(f"\n{'Ingredient 1':<30} {'Ingredient 2':<30}")
                    print("-"*65)
                    for v in violations:
                        print(f"{v[1]:<30} {v[3]:<30}")
                    print("\nProduction blocked for safety reasons!")
                    print("="*70)
                    return  # BLOCK production
            
            print("No health risk violations detected - safe to proceed")
            
        except mysql.connector.Error as err:
            print(f"Error checking health risks: {err}")
            return

        confirm = input("\nProceed with production? (Y/N): ").strip().upper()
        if confirm != 'Y':
            print("Production cancelled.")
            return

        # Continue with batch creation
        try:
            self.ensure_clean_transaction()
            self.connection.start_transaction()
            
            # Create product batch
            self.cursor.execute("""
                INSERT INTO ProductBatch (RecipeID, BatchQuantity, ProductionDate, 
                                        ExpirationDate, BatchCost, PerUnitCost)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (recipe_id, batch_qty, prod_date_str, exp_date_str, 
                total_cost, total_cost / batch_qty))
            
            # Get the generated lot ID
            product_lot_id = None
            self.cursor.execute("""
                SELECT LotID FROM ProductBatch 
                WHERE RecipeID = %s 
                ORDER BY ProductionDate DESC 
                LIMIT 1
            """, (recipe_id,))
            result = self.cursor.fetchone()
            if result:
                product_lot_id = result[0]
            
            # Insert consumption records
            for lot_id, qty_used, cost in allocations:
                self.cursor.execute("""
                    INSERT INTO ProductBatchIngredientBatch (ProductLotID, IngredientLotID, QuantityUsed)
                    VALUES (%s, %s, %s)
                """, (product_lot_id, lot_id, qty_used))
            
            self.connection.commit()
            
            print(f"\nProduct batch created successfully!")
            print(f"Product Lot ID: {product_lot_id}")
            print(f"Batch Cost: ${total_cost:.2f}")
            print(f"Per-Unit Cost: ${total_cost / batch_qty:.4f}")
            
        except mysql.connector.Error as err:
            print(f"Database error: {err}")
            self.connection.rollback()

    # 4) Reports Menu
    def reports_menu(self):
        while True:
            print("\n" + "-"*60)
            print("REPORTS MENU")
            print("-"*60)
            print("1) Nearly Out of Stock Items")
            print("2) Almost Expired Ingredient Lots")
            print("3) Batch Cost Summary")
            print("4) Back to Main Menu")
            print("-"*60)

            try:
                choice = int(input("\nSelection: "))
            except ValueError:
                print("Invalid input.")
                continue

            if choice == 1:
                self.report_nearly_out_of_stock()
            elif choice == 2:
                self.report_almost_expired()
            elif choice == 3:
                self.report_batch_cost_summary()
            elif choice == 4:
                break
            else:
                print("Invalid choice.")

    def report_nearly_out_of_stock(self):
        print("\n--- Nearly Out of Stock Items ---")
        print("(Items where on-hand < required for one standard batch)")
        
        try:
            self.cursor.callproc('sp_report_nearly_out_of_stock', [self.manufacturer_id])
            
            for result in self.cursor.stored_results():
                rows = result.fetchall()
                if rows:
                    print(f"\n{'IngID':<6} {'Ingredient':<25} {'On Hand':<12} "
                        f"{'Per Unit':<10} {'Batch Size':<12} {'Required':<12} "
                        f"{'ProdID':<8} {'Product':<20}")
                    print("-"*120)
                    for r in rows:
                        print(f"{r[0]:<6} {r[1]:<25} {r[2]:<12.2f} "
                            f"{r[3]:<10.2f} {r[4]:<12} {r[5]:<12.2f} "
                            f"{r[6]:<8} {r[7]:<20}")
                    print(f"\n{len(rows)} ingredient(s) are running low!")
                else:
                    print("\nAll ingredients are adequately stocked.")
                    
        except mysql.connector.Error as err:
            print(f"Database error: {err}")

    def report_almost_expired(self):
        print("\n--- Almost Expired Ingredient Lots ---")
        
        days = input("Days threshold (default 10): ").strip()
        try:
            days_threshold = int(days) if days else 10
        except ValueError:
            print("Invalid input, using 10 days.")
            days_threshold = 10
        
        try:
            self.cursor.callproc('sp_report_almost_expired', 
                                [self.manufacturer_id, days_threshold])
            
            for result in self.cursor.stored_results():
                rows = result.fetchall()
                if rows:
                    print(f"\n{'Lot ID':<20} {'IngID':<6} {'Ingredient':<25} "
                          f"{'Qty (oz)':<12} {'Expires':<12} {'Days Left':<10} {'Status':<15}")
                    print("-"*115)
                    for r in rows:
                        print(f"{r[0]:<20} {r[1]:<6} {r[2]:<25} "
                            f"{r[3]:<12.2f} {str(r[4]):<12} {r[5]:<10} {r[6]:<15}")
                    print(f"\n{len(rows)} lot(s) are expiring soon or expired!")
                else:
                    print(f"\nNo lots expiring within {days_threshold} days.")
                    
        except mysql.connector.Error as err:
            print(f"Database error: {err}")

    def report_batch_cost_summary(self):
        print("\n--- Batch Cost Summary ---")
        
        # First, show all product batches for this manufacturer
        print("\nYour Product Batches:")
        try:
            self.cursor.callproc('sp_view_manufacturer_product_batches', 
                                [self.manufacturer_id])
            
            batch_list = []
            for result in self.cursor.stored_results():
                rows = result.fetchall()
                if rows:
                    print(f"\n{'#':<4} {'LotID':<20} {'ProdID':<8} {'Product':<25} "
                        f"{'Date':<12} {'Qty':<8}")
                    print("-"*85)
                    for idx, r in enumerate(rows, 1):
                        batch_list.append(r[0])  # Store LotID
                        print(f"{idx:<4} {r[0]:<20} {r[1]:<8} {r[2]:<25} "
                            f"{str(r[3]):<12} {r[5]:<8}")
                else:
                    print("No product batches found.")
                    return
            
            # Let user select by number or enter lot ID
            print("\n" + "-"*85)
            selection = input("Enter batch # (or type Lot ID, or 0 to cancel): ").strip()
            
            if selection == '0':
                return
            
            try:
                batch_num = int(selection)
                if 1 <= batch_num <= len(batch_list):
                    lot_id = batch_list[batch_num - 1]
                else:
                    print(f"Error: Please enter a number between 1 and {len(batch_list)}.")
                    return
            except ValueError:
                # User typed a lot ID directly
                lot_id = selection
            
            # Now get the cost summary
            print(f"\nRetrieving cost summary for: {lot_id}")
            print("="*85)
            
            self.cursor.callproc('sp_get_batch_cost_summary', [lot_id])
            
            results = []
            for result in self.cursor.stored_results():
                results.append(result.fetchall())
            
            # First result set: batch header
            if results and results[0]:
                header = results[0][0]
                print("\n--- Batch Information ---")
                print(f"Lot ID:         {header[0]}")
                print(f"Product ID:     {header[1]}")
                print(f"Product Name:   {header[2]}")
                print(f"Batch Quantity: {header[3]} units")
                print(f"Production:     {header[4]}")
                print(f"Expiration:     {header[5]}")
                print(f"Total Cost:     ${header[6]:.2f}")
                print(f"Per-Unit Cost:  ${header[7]:.4f}")
                
                # Second result set: ingredient breakdown
                if len(results) > 1 and results[1]:
                    print("\n--- Cost Breakdown by Ingredient ---")
                    print(f"{'IngID':<6} {'Ingredient':<25} {'Lot ID':<20} "
                        f"{'Oz Used':<10} {'Pack Size':<10} {'$/Pack':<10} {'Total Cost':<12}")
                    print("-"*100)
                    for row in results[1]:
                        print(f"{row[0]:<6} {row[1]:<25} {row[2]:<20} "
                            f"{row[3]:<10.2f} {row[4]:<10.2f} ${row[5]:<9.2f} ${row[6]:<11.2f}")
                    
                    # Show total
                    total_ingredient_cost = sum(row[6] for row in results[1])
                    print("-"*100)
                    print(f"{'TOTAL':<73} ${total_ingredient_cost:.2f}")
            else:
                print("Batch not found.")
                
        except mysql.connector.Error as err:
            print(f"Database error: {err}")

    # 5) Recall & Traceability 
    def recall_traceability_menu(self):
        print("\n" + "-"*60)
        print("RECALL & TRACEABILITY")
        print("-"*60)
        print("1) Trace by Ingredient ID")
        print("2) Trace by Ingredient Lot ID")
        print("3) Back to Main Menu")
        print("-"*60)

        try:
            choice = int(input("\nSelection: "))
        except ValueError:
            print("Invalid input.")
            return

        if choice == 1:
            self.trace_recall_by_ingredient()
        elif choice == 2:
            self.trace_recall_by_lot()
        elif choice == 3:
            return
        else:
            print("Invalid choice.")

    def trace_recall_by_ingredient(self):
        print("\n--- Trace Recall by Ingredient ---")
        
        try:
            ingredient_id = int(input("Enter Ingredient ID: "))
        except ValueError:
            print("Invalid Ingredient ID.")
            return
        
        # Date range (default: last 20 days per requirements)
        date_to = date.today()
        date_from = date_to - timedelta(days=20)
        
        custom = input(f"Use default date range? ({date_from} to {date_to}) (Y/N): ").strip().upper()
        if custom == 'N':
            from_str = input("Start date (YYYY-MM-DD): ").strip()
            to_str = input("End date (YYYY-MM-DD): ").strip()
            try:
                date_from = datetime.strptime(from_str, "%Y-%m-%d").date()
                date_to = datetime.strptime(to_str, "%Y-%m-%d").date()
            except ValueError:
                print("Invalid date format.")
                return
        
        print(f"\nSearching for product batches using Ingredient {ingredient_id}")
        print(f"Date range: {date_from} to {date_to}")
        
        try:
            self.cursor.callproc('sp_trace_recall', 
                                [ingredient_id, None, date_from, date_to])
            
            for result in self.cursor.stored_results():
                rows = result.fetchall()
                if rows:
                    print(f"\n{len(rows)} affected product batch(es) found!")
                    print(f"\n{'Product Lot':<20} {'ProdID':<8} {'Product':<25} "
                          f"{'Prod Date':<12} {'Quantity':<10} {'Ing Lot':<20} {'Ingredient':<25}")
                    print("-"*130)
                    for r in rows:
                        print(f"{r[0]:<20} {r[1]:<8} {r[2]:<25} "
                            f"{str(r[3]):<12} {r[4]:<10} {r[5]:<20} {r[6]:<25}")
                else:
                    print("\nNo affected product batches found in date range.")
                    
        except mysql.connector.Error as err:
            print(f"Database error: {err}")

    def trace_recall_by_lot(self):
        print("\n--- Trace Recall by Ingredient Lot ---")
        
        lot_id = input("Enter Ingredient Lot ID: ").strip()
        if not lot_id:
            print("Error: Lot ID required.")
            return
        
        # Date range (default: last 20 days per requirements)
        date_to = date.today()
        date_from = date_to - timedelta(days=20)
        
        custom = input(f"Use default date range? ({date_from} to {date_to}) (Y/N): ").strip().upper()
        if custom == 'N':
            from_str = input("Start date (YYYY-MM-DD): ").strip()
            to_str = input("End date (YYYY-MM-DD): ").strip()
            try:
                date_from = datetime.strptime(from_str, "%Y-%m-%d").date()
                date_to = datetime.strptime(to_str, "%Y-%m-%d").date()
            except ValueError:
                print("Invalid date format.")
                return
        
        print(f"\nSearching for product batches using Lot {lot_id}")
        print(f"Date range: {date_from} to {date_to}")
        
        try:
            self.cursor.callproc('sp_trace_recall', 
                                [None, lot_id, date_from, date_to])
            
            for result in self.cursor.stored_results():
                rows = result.fetchall()
                if rows:
                    print(f"\n⚠️  {len(rows)} affected product batch(es) found!")
                    print(f"\n{'Product Lot':<20} {'ProdID':<8} {'Product':<25} "
                          f"{'Prod Date':<12} {'Quantity':<10} {'Ing Lot':<20} {'Ingredient':<25}")
                    print("-"*130)
                    for r in rows:
                        print(f"{r[0]:<20} {r[1]:<8} {r[2]:<25} "
                            f"{str(r[3]):<12} {r[4]:<10} {r[5]:<20} {r[6]:<25}")
                else:
                    print("\nNo affected product batches found in date range.")
                    
        except mysql.connector.Error as err:
            print(f"Database error: {err}")

    # 6) View ingredient inventory for this manufacturer
    def view_ingredient_inventory(self):
        print("\n--- My Ingredient Inventory ---")
        try:
            self.cursor.callproc('sp_view_manufacturer_ingredient_inventory', 
                                [self.manufacturer_id])
            for result in self.cursor.stored_results():
                rows = result.fetchall()
                if rows:
                    print(f"\n{'LotID':<20} {'IngID':<8} {'Ingredient Name':<25} "
                          f"{'PackSize':<10} {'#Packs':<10} {'TotalOz':<12} {'Expires':<12} {'Status':<15}")
                    print("-"*115)
                    for r in rows:
                        print(f"{r[0]:<20} {r[1]:<8} {r[2]:<25} "
                            f"{r[3]:<10.2f} {r[4]:<10.2f} {r[5]:<12.2f} {str(r[6]):<12} {r[7]:<15}")
                else:
                    print("No ingredient inventory found.")
        except mysql.connector.Error as err:
            print(f"Database error: {err}")

    # 7) View product batches for this manufacturer
    def view_product_batches(self):
        print("\n--- My Product Batches ---")
        try:
            self.cursor.callproc('sp_view_manufacturer_product_batches', 
                                [self.manufacturer_id])
            for result in self.cursor.stored_results():
                rows = result.fetchall()
                if rows:
                    print(f"\n{'LotID':<20} {'ProdID':<8} {'Product Name':<25} "
                          f"{'Prod Date':<12} {'Exp Date':<12} {'Qty':<8}")
                    print("-"*95)
                    for r in rows:
                        print(f"{r[0]:<20} {r[1]:<8} {r[2]:<25} "
                            f"{str(r[3]):<12} {str(r[4]):<12} {r[5]:<8}")
                else:
                    print("No product batches found.")
        except mysql.connector.Error as err:
            print(f"Database error: {err}")

    def receive_ingredient_batches(self):
        print("\n" + "-"*60)
        print("RECEIVE INGREDIENT BATCHES")
        print("-"*60)
        print("Claim ingredient batches for ingredients used in your recipes")
        
        # Show available batches from suppliers filtered by recipe needs
        try:
            self.cursor.execute("""
                SELECT 
                    ib.LotID,
                    i.IngredientID,
                    i.IngredientName,
                    s.SupplierID,
                    u.Username AS SupplierName,
                    f.PackSize,
                    ib.Quantity AS NumPacks,
                    ib.TotalQuantityOz,
                    f.UnitPrice,
                    ib.ExpirationDate,
                    DATEDIFF(ib.ExpirationDate, CURDATE()) AS DaysUntilExpiry
                FROM IngredientBatch ib
                INNER JOIN Formulation f ON ib.FormulationID = f.FormulationID
                INNER JOIN Ingredient i ON f.IngredientID = i.IngredientID
                INNER JOIN Supplier s ON f.SupplierID = s.SupplierID
                INNER JOIN User u ON s.UserID = u.UserID
                WHERE ib.ManufacturerID IS NULL
                AND ib.ExpirationDate >= CURDATE()
                AND ib.TotalQuantityOz > 0
                AND EXISTS (
                    SELECT 1 
                    FROM RecipeBOM rb
                    INNER JOIN Recipe r ON rb.RecipeID = r.RecipeID
                    INNER JOIN Product p ON r.ProductID = p.ProductID
                    WHERE p.ManufacturerID = %s
                        AND rb.IngredientID = i.IngredientID
                )
                ORDER BY i.IngredientName, ib.ExpirationDate
            """, (self.manufacturer_id,))
            
            available_batches = self.cursor.fetchall()
            
            if not available_batches:
                print("\nNo ingredient batches available for your recipes at this time.")
                print("Note: Only showing ingredients used in your current recipes.")
                return
            
            print(f"\n{'#':<4} {'Lot ID':<20} {'Ingredient':<25} {'Supplier':<20} "
                f"{'Packs':<8} {'Total Oz':<10} {'$/Pack':<8} {'Expires':<12} {'Days Left':<10}")
            print("-"*130)

            for idx, batch in enumerate(available_batches, 1):
                print(f"{idx:<4} {batch[0]:<20} {batch[2]:<25} {batch[4]:<20} "
                    f"{batch[6]:<8.1f} {batch[7]:<10.2f} ${batch[8]:<7.2f} "
                    f"{str(batch[9]):<12} {batch[10]:<10}")  
            
            print("\n" + "-"*130)
            print("Enter batch numbers to receive (comma-separated, e.g., 1,3,5) or enter '0' to cancel")
            
            selection = input("\nSelection: ").strip()
            
            if selection == '0':
                return
            else:
                try:
                    selected_indices = [int(x.strip()) for x in selection.split(',')]
                except ValueError:
                    print("Error: Invalid input format.")
                    return
            
            # Validate indices
            invalid = [i for i in selected_indices if i < 1 or i > len(available_batches)]
            if invalid:
                print(f"Error: Invalid batch number(s): {invalid}")
                return
            
            # Receive the selected batches
            received_count = 0
            try:
                # Ensure any pending transaction is closed
                try:
                    self.connection.rollback()
                except:
                    pass
                
                self.ensure_clean_transaction()
                self.connection.start_transaction()
                
                for idx in selected_indices:
                    lot_id = available_batches[idx - 1][0]
                    
                    # Set ManufacturerID to claim the batch
                    self.cursor.execute("""
                        UPDATE IngredientBatch
                        SET ManufacturerID = %s
                        WHERE LotID = %s AND ManufacturerID IS NULL
                    """, (self.manufacturer_id, lot_id))
                    
                    if self.cursor.rowcount > 0:
                        received_count += 1
                
                self.connection.commit()
                print(f"\nSuccessfully received {received_count} ingredient batch(es)!")
                print("These batches are now in your inventory.")
                
            except mysql.connector.Error as err:
                print(f"Database error: {err}")
                self.connection.rollback()
                
        except mysql.connector.Error as err:
            print(f"Database error: {err}")
