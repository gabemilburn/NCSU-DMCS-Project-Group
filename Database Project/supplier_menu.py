"""
CSC540 Database Project - Supplier Menu Module
Graduate Version - UPDATED with Batch Viewing and Versioned Formulations
"""

import mysql.connector
from datetime import date, datetime, timedelta

class SupplierMenu:
    def __init__(self, connection, cursor, user_id, supplier_id):
        self.connection = connection
        self.cursor = cursor
        self.user_id = user_id
        self.supplier_id = supplier_id
    
    def validate_date(self, year, month, day):
        try:
            valid_date = date(int(year), int(month), int(day))
            return valid_date.strftime("%Y-%m-%d")
        except ValueError:
            return None
    
    def validate_positive_number(self, prompt, number_type=float):
        while True:
            try:
                value = number_type(input(prompt))
                if value > 0:
                    return value
                else:
                    print("Error: Value must be positive.")
            except ValueError:
                print(f"Error: Please enter a valid {number_type.__name__}.")

    def ensure_clean_transaction(self):
        try:
            self.connection.rollback()
        except:
            pass 
    
    def run(self):
        while True:
            print("\n" + "="*60)
            print("SUPPLIER MENU")
            print("="*60)
            print("1) Manage Ingredients Supplied")
            print("2) Maintain Formulations")
            print("3) Create Ingredient Batch")
            print("4) View Ingredient Batches")
            print("5) Manage Do-Not-Combine List")
            print("6) View My Ingredients")
            print("7) Logout")
            print("="*60)
            
            try:
                choice = int(input("\nSelection: "))
                if choice == 1:
                    self.manage_ingredients()
                elif choice == 2:
                    self.maintain_formulations()
                elif choice == 3:
                    self.create_ingredient_batch()
                elif choice == 4:
                    self.view_ingredient_batches()
                elif choice == 5:
                    self.manage_do_not_combine()
                elif choice == 6:
                    self.view_my_ingredients()
                elif choice == 7:
                    print("\nLogging out...")
                    break
                else:
                    print("Invalid choice. Please enter 1-7.")
            except ValueError:
                print("Invalid input. Please enter a number.")
            except Exception as e:
                print(f"An error occurred: {e}")
                self.connection.rollback()
    
    def manage_ingredients(self):
        print("\n" + "-"*60)
        print("MANAGE INGREDIENTS SUPPLIED")
        print("-"*60)
        
        print("\n1) Add New Ingredient")
        print("2) View All Ingredients")
        print("3) Back to Main Menu")
        
        try:
            choice = int(input("\nSelection: "))
            
            if choice == 1:
                self.add_new_ingredient()
            elif choice == 2:
                self.view_all_ingredients()
            elif choice == 3:
                return
            else:
                print("Invalid choice.")
        except ValueError:
            print("Invalid input. Please enter a number.")
    
    def add_new_ingredient(self):
        print("\n--- Add New Ingredient ---")
        
        ingredient_name = input("Ingredient Name: ").strip()
        if not ingredient_name:
            print("Error: Ingredient name cannot be empty.")
            return
        
        while True:
            compound = input("Is this ingredient compound? (Y/N): ").strip().upper()
            if compound in ['Y', 'N']:
                is_compound = (compound == 'Y')
                break
            print("Invalid input. Please enter Y or N.")
        
        try:
            self.ensure_clean_transaction()
            self.connection.start_transaction()
            
            self.cursor.execute("""
                INSERT INTO Ingredient (IngredientName, IsCompound)
                VALUES (%s, %s)
            """, (ingredient_name, is_compound))
            
            ingredient_id = self.cursor.lastrowid
            self.connection.commit()
            print(f"\nIngredient '{ingredient_name}' added successfully!")
            print(f"Ingredient ID: {ingredient_id}")
            
        except mysql.connector.IntegrityError as err:
            if err.errno == 1062:  # Duplicate entry
                print(f"Error: Ingredient '{ingredient_name}' already exists.")
            else:
                print(f"Database error: {err}")
            self.connection.rollback()
        except mysql.connector.Error as err:
            print(f"Database error: {err}")
            self.connection.rollback()
    
    def view_all_ingredients(self):
        print("\n--- All Ingredients ---")
        try:
            self.cursor.execute("""
                SELECT IngredientID, IngredientName, IsCompound
                FROM Ingredient
                ORDER BY IngredientName
            """)
            
            results = self.cursor.fetchall()
            if results:
                print(f"\n{'ID':<6} {'Name':<30} {'Type':<10}")
                print("-" * 50)
                for row in results:
                    ing_type = "Compound" if row[2] else "Atomic"
                    print(f"{row[0]:<6} {row[1]:<30} {ing_type:<10}")
            else:
                print("No ingredients found.")
                
        except mysql.connector.Error as err:
            print(f"Database error: {err}")

    def check_formulation_conflicts(self, formulation_id):
        self.cursor.callproc('sp_get_formulation_conflicts', [formulation_id])
        
        conflicts = []
        for result in self.cursor.stored_results():
            conflicts = result.fetchall()
        
        return (len(conflicts) > 0, conflicts)
    
    def maintain_formulations(self):
        print("\n" + "-"*60)
        print("MAINTAIN FORMULATIONS")
        print("-"*60)
        
        print("\n1) Create New Formulation Version")
        print("2) View My Formulations")
        print("3) View Formulation Details")
        print("4) Back to Main Menu")
        
        try:
            choice = int(input("\nSelection: "))
            
            if choice == 1:
                self.create_new_formulation_version()
            elif choice == 2:
                self.view_my_formulations()
            elif choice == 3:
                self.view_formulation_details()
            elif choice == 4:
                return
            else:
                print("Invalid choice.")
        except ValueError:
            print("Invalid input. Please enter a number.")

    
    def create_new_formulation_version(self):
        print("\n--- Create New Formulation Version ---")

        try:
            # Show all ingredients
            self.cursor.execute("""
                SELECT IngredientID, IngredientName, IsCompound
                FROM Ingredient
                ORDER BY IngredientName
            """)
            ingredients = self.cursor.fetchall()

            if not ingredients:
                print("No ingredients found. Add ingredients first.")
                return

            print(f"\n{'ID':<6} {'Ingredient Name':<30} {'Type':<10}")
            print("-" * 50)
            for ing_id, ing_name, is_comp in ingredients:
                ing_type = "Compound" if is_comp else "Atomic"
                print(f"{ing_id:<6} {ing_name:<30} {ing_type:<10}")

            try:
                ingredient_id = int(input("\nEnter Ingredient ID (0 to cancel): "))
            except ValueError:
                print("Error: Invalid ingredient ID.")
                return

            if ingredient_id == 0:
                return

            # Look up ingredient
            self.cursor.execute("""
                SELECT IngredientName, IsCompound
                FROM Ingredient WHERE IngredientID = %s
            """, (ingredient_id,))
            row = self.cursor.fetchone()

            if not row:
                print("Error: Invalid ingredient ID.")
                return

            ingredient_name, is_compound = row
            is_compound = bool(is_compound)

            # Get pack size and unit price
            pack_size = self.validate_positive_number("Pack Size (oz per package): ", float)
            unit_price = self.validate_positive_number("Unit Price ($ per package): ", float)

            if not is_compound:
                # Atomic - just create formulation
                self.commit_formulation_version(ingredient_id, pack_size, unit_price, {})
                return

            # Compound - enter draft mode
            print(f"\nSelected COMPOUND ingredient: {ingredient_name}")
            
            # Check for existing formulations to base on
            draft_materials = {}
            
            self.cursor.execute("""
                SELECT FormulationID, VersionNumber
                FROM Formulation
                WHERE SupplierID = %s AND IngredientID = %s
                ORDER BY VersionNumber DESC
            """, (self.supplier_id, ingredient_id))
            existing = self.cursor.fetchall()
            
            if existing:
                print("\nExisting formulation versions:")
                for f in existing:
                    print(f"  Version {f[1]} (FormulationID: {f[0]})")
                
                base_choice = input("Base on existing version? (Y/N): ").strip().upper()
                if base_choice == 'Y':
                    try:
                        base_id = int(input("Enter FormulationID to base on: "))
                        # Load materials
                        self.cursor.execute("""
                            SELECT MaterialID, Quantity
                            FROM FormulationIngredientList
                            WHERE FormulationID = %s
                        """, (base_id,))
                        for mid, qty in self.cursor.fetchall():
                            draft_materials[mid] = qty
                        print("Loaded existing materials into draft.")
                    except (ValueError, mysql.connector.Error):
                        print("Could not load base formulation; starting fresh.")

            # Draft editing loop
            while True:
                print("\n--- Current Draft ---")
                print(f"Pack Size: {pack_size:.1f} oz, Unit Price: ${unit_price:.2f}")

                if draft_materials:
                    print(f"\n{'MaterialID':<12} {'Name':<30} {'Qty (oz)':<10}")
                    print("-" * 55)
                    for mid, qty in draft_materials.items():
                        self.cursor.execute("""
                            SELECT IngredientName FROM Ingredient WHERE IngredientID = %s
                        """, (mid,))
                        name_row = self.cursor.fetchone()
                        name = name_row[0] if name_row else "UNKNOWN"
                        print(f"{mid:<12} {name:<30} {qty:<10.2f}")
                else:
                    print("\nNo materials in draft yet.")

                print("\nDraft Options:")
                print("1) Add / Update Material")
                print("2) Remove Material")
                print("3) Change Pack Size / Unit Price")
                print("4) Commit New Version")
                print("5) Cancel Draft")

                try:
                    choice = int(input("Selection: "))
                except ValueError:
                    print("Invalid choice.")
                    continue

                if choice == 1:
                    # Add/update material
                    self.cursor.execute("""
                        SELECT IngredientID, IngredientName
                        FROM Ingredient
                        WHERE IsCompound = FALSE
                        ORDER BY IngredientName
                    """)
                    atoms = self.cursor.fetchall()
                    
                    if not atoms:
                        print("No atomic ingredients available.")
                        continue

                    print(f"\n{'ID':<6} {'Name':<30}")
                    print("-" * 40)
                    for mid, mname in atoms:
                        print(f"{mid:<6} {mname:<30}")

                    try:
                        mat_id = int(input("\nMaterial Ingredient ID: "))
                        qty = self.validate_positive_number("Quantity (oz): ", float)
                        draft_materials[mat_id] = qty
                        print("Material added/updated in draft.")
                    except ValueError:
                        print("Invalid input.")

                elif choice == 2:
                    # Remove material
                    if not draft_materials:
                        print("No materials to remove.")
                        continue
                    try:
                        mat_id = int(input("Material ID to remove: "))
                        if mat_id in draft_materials:
                            del draft_materials[mat_id]
                            print("Material removed from draft.")
                        else:
                            print("Material not in draft.")
                    except ValueError:
                        print("Invalid material ID.")

                elif choice == 3:
                    # Change pricing
                    pack_size = self.validate_positive_number("New Pack Size (oz): ", float)
                    unit_price = self.validate_positive_number("New Unit Price ($): ", float)

                elif choice == 4:
                    # Commit
                    if not draft_materials:
                        print("Error: Compound formulations must have at least one material.")
                        continue
                    
                    self.commit_formulation_version(ingredient_id, pack_size, unit_price, draft_materials)
                    return

                elif choice == 5:
                    print("Draft cancelled.")
                    return

        except mysql.connector.Error as err:
            print(f"Database error: {err}")
            self.connection.rollback()

    def commit_formulation_version(self, ingredient_id, pack_size, unit_price, materials):
        try:
            self.ensure_clean_transaction()
            self.connection.start_transaction()

            # Find latest version number
            self.cursor.execute("""
                SELECT MAX(VersionNumber) FROM Formulation
                WHERE SupplierID = %s AND IngredientID = %s
            """, (self.supplier_id, ingredient_id))
            result = self.cursor.fetchone()
            next_version = 1 if not result[0] else result[0] + 1

            # Close previous version if exists
            self.cursor.execute("""
                UPDATE Formulation
                SET EffectiveEndDate = CURDATE()
                WHERE SupplierID = %s 
                AND IngredientID = %s 
                AND EffectiveEndDate >= CURDATE()
            """, (self.supplier_id, ingredient_id))

            # Insert new version
            self.cursor.execute("""
                INSERT INTO Formulation (
                    IngredientID, SupplierID, PackSize, UnitPrice,
                    VersionNumber, EffectiveStartDate, EffectiveEndDate
                ) VALUES (%s, %s, %s, %s, %s, CURDATE(), '9999-12-31')
            """, (ingredient_id, self.supplier_id, pack_size, unit_price, next_version))

            formulation_id = self.cursor.lastrowid
            
            for mat_id, qty in materials.items():
                self.cursor.execute("""
                    INSERT INTO FormulationIngredientList (FormulationID, MaterialID, Quantity)
                    VALUES (%s, %s, %s)
                """, (formulation_id, mat_id, qty))

            # Check for conflicts
            self.cursor.callproc('sp_get_formulation_conflicts', [formulation_id])

            for result in self.cursor.stored_results():
                conflicts = result.fetchall()
                if conflicts:
                    print("\n" + "="*70)
                    print("WARNING: Do-Not-Combine Conflicts Detected")
                    print("="*70)
                    print("The following material pairs should not be combined:")
                    print(f"\n{'Ingredient 1':<30} {'Ingredient 2':<30}")
                    print("-"*65)
                    for c in conflicts:
                        print(f"{c[1]:<30} {c[3]:<30}")
                    print("\nThis formulation may pose health risks!")
                else:
                    print("\nNo ingredient conflicts detected")

            # Success
            self.connection.commit()
            print(f"\nFormulation version {next_version} created successfully!")
            print(f"Formulation ID: {formulation_id}")
            
        except mysql.connector.Error as err:
            print(f"Database error: {err}")
            self.connection.rollback()

    def view_my_formulations(self):
        print("\n--- Current Active Formulations ---")

        try:
            # Pull from the view, limited to this supplier
            self.cursor.execute("""
                SELECT 
                    FormulationID,
                    IngredientID,
                    IngredientName,
                    IsCompound,          
                    VersionNumber,
                    PackSize,
                    UnitPrice,
                    MaterialCount,
                    EffectiveStartDate,
                    EffectiveEndDate
                FROM vw_active_formulations
                WHERE SupplierID = %s
                ORDER BY IngredientName, FormulationID
            """, (self.supplier_id,))

            rows = self.cursor.fetchall()

            if not rows:
                print("\nYou currently have NO active formulations.")
                return

            print(
                f"\n{'FormID':<8} "
                f"{'IngID':<6} "
                f"{'Ingredient Name':<30} "
                f"{'Type':<10} "
                f"{'Ver':<4} "
                f"{'PackSize':<10} "
                f"{'UnitPrice':<10} "
                f"{'# Materials':<12} "
                f"{'Start':<12} "
                f"{'End':<12}"
            )
            print("-" * 120)

            for r in rows:
                form_id      = r[0]
                ing_id       = r[1]
                ing_name     = r[2]
                is_compound  = r[3]
                version      = r[4]
                pack_size    = r[5]
                unit_price   = r[6]
                material_cnt = r[7]
                start_date   = r[8]
                end_date     = r[9] if r[9] else 'OPEN'
                
                # Convert IsCompound boolean to readable type
                ing_type = 'Compound' if is_compound else 'Atomic'

                print(
                    f"{form_id:<8} "
                    f"{ing_id:<6} "
                    f"{ing_name:<30} "
                    f"{ing_type:<10} "
                    f"{version:<4} "
                    f"{pack_size:<10.2f} "
                    f"{unit_price:<10.2f} "
                    f"{material_cnt:<12} "
                    f"{str(start_date):<12} "
                    f"{str(end_date):<12}"
                )

            print(f"\nTotal active formulations: {len(rows)}")

        except mysql.connector.Error as err:
            print(f"Database error while reading vw_active_formulations: {err}")


    def view_formulation_details(self):
        print("\n--- View Formulation Details ---")
        
        try:
            # Show ALL formulations for this supplier
            self.cursor.execute("""
                SELECT 
                    f.FormulationID,
                    i.IngredientName,
                    f.VersionNumber,
                    f.EffectiveStartDate,
                    f.EffectiveEndDate,
                    CASE 
                        WHEN CURDATE() BETWEEN f.EffectiveStartDate AND f.EffectiveEndDate 
                        THEN 'ACTIVE' 
                        ELSE 'EXPIRED' 
                    END AS Status
                FROM Formulation f
                INNER JOIN Ingredient i ON f.IngredientID = i.IngredientID
                WHERE f.SupplierID = %s
                ORDER BY i.IngredientName, f.VersionNumber DESC
            """, (self.supplier_id,))
            
            formulations = self.cursor.fetchall()
            
            if not formulations:
                print("\nNo formulations found.")
                return
            
            print(f"\n{'FormID':<8} {'Ingredient Name':<30} {'Ver':<5} {'Start':<12} {'End':<12} {'Status':<8}")
            print("-" * 80)
            
            for r in formulations:
                form_id = r[0]
                ing_name = r[1]
                version = r[2]
                start_date = r[3]
                end_date = r[4]
                status = r[5]
                
                end_str = str(end_date) if str(end_date) != '9999-12-31' else 'OPEN'
                
                print(f"{form_id:<8} {ing_name:<30} {version:<5} {str(start_date):<12} {end_str:<12} {status:<8}")
            
            print(f"\nTotal: {len(formulations)} formulation(s)")
            
            # Select by FormulationID
            try:
                formulation_id = int(input("\nEnter Formulation ID (0 to cancel): "))
            except ValueError:
                print("Invalid input.")
                return
            
            if formulation_id == 0:
                return
            
            # Verify it belongs to this supplier
            if formulation_id not in [r[0] for r in formulations]:
                print("Error: Formulation not found or not owned by you.")
                return
            
            # Get and display the details
            self.cursor.callproc('sp_view_formulation_details', [formulation_id])
            
            # Fetch both result sets
            results = []
            for result in self.cursor.stored_results():
                results.append(result.fetchall())
            
            if results and results[0]:
                header = results[0][0]
                print("\n" + "="*70)
                print("FORMULATION DETAILS")
                print("="*70)
                print(f"Formulation ID:   {header[0]}")
                print(f"Ingredient:       {header[2]} (ID: {header[1]})")
                print(f"Type:             {'Compound' if header[3] else 'Atomic'}")
                print(f"Pack Size:        {header[5]} oz")
                print(f"Unit Price:       ${header[6]:.2f}")
                print(f"Version:          {header[7]}")
                print(f"Effective:        {header[8]} to {header[9]}")
                
                if len(results) > 1 and results[1]:
                    print("\n--- Materials ---")
                    print(f"{'Material':<30} {'Quantity (oz)':<15}")
                    print("-" * 50)
                    for material in results[1]:
                        print(f"{material[1]:<30} {material[2]:<15.2f}")
                elif header[3]:
                    print("\nWARNING: This compound has no materials!")
                print("="*70)
            else:
                print("Formulation not found.")
                
        except ValueError:
            print("Error: Invalid input.")
        except mysql.connector.Error as err:
            print(f"Database error: {err}")
    
    def create_ingredient_batch(self):
        print("\n" + "-"*60)
        print("CREATE INGREDIENT BATCH")
        print("-"*60)
        
        try:
            # Show active formulations
            self.cursor.execute("""
                SELECT 
                    f.FormulationID, i.IngredientName, f.PackSize,
                    f.UnitPrice, f.VersionNumber
                FROM Formulation f
                INNER JOIN Ingredient i ON f.IngredientID = i.IngredientID
                WHERE f.SupplierID = %s
                AND CURDATE() BETWEEN f.EffectiveStartDate AND f.EffectiveEndDate
                ORDER BY i.IngredientName
            """, (self.supplier_id,))
            
            formulations = self.cursor.fetchall()
            
            if not formulations:
                print("No active formulations. Create a formulation first.")
                return
            
            print(f"\n{'FormID':<8} {'Ingredient':<25} {'Pack Size':<10} {'Price':<8} {'Ver':<5}")
            print("-" * 70)
            for f in formulations:
                print(f"{f[0]:<8} {f[1]:<25} {f[2]:<10.2f} ${f[3]:<7.2f} {f[4]:<5}")
            
            formulation_id = int(input("\nEnter Formulation ID: "))
            
            # Get pack size
            self.cursor.execute("""
                SELECT PackSize FROM Formulation WHERE FormulationID = %s
            """, (formulation_id,))
            pack_result = self.cursor.fetchone()
            
            if not pack_result:
                print("Error: Invalid formulation ID.")
                return
            
            pack_size = pack_result[0]
            print(f"\nPack Size: {pack_size} oz per package")
            
            # Check for formulation conflicts
            has_conflicts, conflicts = self.check_formulation_conflicts(formulation_id)
            
            if has_conflicts:
                print("\n" + "="*70)
                print("WARNING: Do-Not-Combine Conflicts Detected")
                print("="*70)
                print(f"\n{'Ingredient 1':<30} {'Ingredient 2':<30}")
                print("-"*65)
                for c in conflicts:
                    print(f"{c[1]:<30} {c[3]:<30}")
                print("\nThis formulation may pose health risks!")
                print("="*70)
                
                proceed = input("\nProceed with batch creation anyway? (Y/N): ").strip().upper()
                if proceed != 'Y':
                    print("Batch creation cancelled.")
                    return
            
            quantity = self.validate_positive_number("Quantity (NUMBER of packages): ", float)
            total_oz = quantity * pack_size
            print(f"Total ounces: {total_oz:.2f} oz ({quantity} packages x {pack_size} oz/package)")
            
            # Expiration date with 90-day minimum
            min_expiry = date.today() + timedelta(days=90)
            print(f"\nMinimum expiration date: {min_expiry.strftime('%Y-%m-%d')}")
            
            exp_date = None
            while exp_date is None:
                print("\nExpiration Date:")
                year = input("  Year (YYYY): ")
                month = input("  Month (MM): ")
                day = input("  Day (DD): ")
                exp_date = self.validate_date(year, month, day)
                
                if exp_date is None:
                    print("Invalid date. Please try again.")
                    continue
                
                # Check 90-day rule
                exp_date_obj = datetime.strptime(exp_date, "%Y-%m-%d").date()
                days_until = (exp_date_obj - date.today()).days
                
                if days_until < 90:
                    print(f"Error: Expiration must be at least 90 days from today.")
                    print(f"Current days until expiry: {days_until}")
                    exp_date = None
            
            # Create batch
            self.ensure_clean_transaction()
            self.connection.start_transaction()
            
            self.cursor.execute("""
                INSERT INTO IngredientBatch (
                    FormulationID, Quantity, TotalQuantityOz, ExpirationDate
                ) VALUES (%s, %s, %s, %s)
            """, (formulation_id, quantity, total_oz, exp_date))
            
            # Get generated LotID
            self.cursor.execute("""
                SELECT LotID FROM IngredientBatch
                WHERE FormulationID = %s
                ORDER BY LotID DESC LIMIT 1
            """, (formulation_id,))
            
            lot_id = self.cursor.fetchone()[0]
            
            self.connection.commit()
            
            print(f"\nIngredient batch created successfully!")
            print(f"Lot ID: {lot_id}")
            print(f"Quantity: {quantity} packages ({total_oz:.2f} oz)")
            print(f"Expiration: {exp_date}")
            
        except ValueError:
            print("Error: Invalid number format.")
        except mysql.connector.Error as err:
            print(f"Database error: {err}")
            self.connection.rollback()
    
    def view_ingredient_batches(self):
        print("\n--- My Ingredient Batches ---")

        include_input = input("Include expired batches? (Y/N, default N): ").strip().upper()
        if include_input not in ("Y", "N", ""):
            include_expired = False
        else:
            include_expired = (include_input == "Y")

        try:
            # Build base query
            query = """
                SELECT 
                    ib.LotID,                                
                    i.IngredientName,                        
                    CASE 
                        WHEN i.IsCompound THEN 'Compound' 
                        ELSE 'Atomic' 
                    END AS Type,                             
                    f.PackSize,                             
                    ib.Quantity AS NumPacks,                
                    ib.TotalQuantityOz,                      
                    ib.ExpirationDate,                      
                    CASE 
                        WHEN ib.ExpirationDate < CURDATE() THEN 'EXPIRED'
                        WHEN ib.ExpirationDate <= DATE_ADD(CURDATE(), INTERVAL 30 DAY) THEN 'EXPIRING SOON'
                        ELSE 'GOOD'
                    END AS Status                            
                FROM IngredientBatch ib
                INNER JOIN Formulation f 
                    ON ib.FormulationID = f.FormulationID
                INNER JOIN Ingredient i 
                    ON f.IngredientID = i.IngredientID
                WHERE f.SupplierID = %s
            """

            params = [self.supplier_id]

            # If not including expired, filter them out
            if not include_expired:
                query += " AND ib.ExpirationDate >= CURDATE()"

            query += """
                ORDER BY 
                    CASE 
                        WHEN ib.ExpirationDate < CURDATE() THEN 3
                        WHEN ib.ExpirationDate <= DATE_ADD(CURDATE(), INTERVAL 30 DAY) THEN 2
                        ELSE 1
                    END,
                    ib.ExpirationDate ASC,
                    i.IngredientName
            """

            self.cursor.execute(query, tuple(params))
            results = self.cursor.fetchall()

            if results:
                print(
                    f"\n{'Lot ID':<20} "
                    f"{'Ingredient':<25} "
                    f"{'Type':<10} "
                    f"{'Pack Size':<10} "
                    f"{'# Packs':<10} "
                    f"{'Total Oz':<12} "
                    f"{'Expires':<12} "
                    f"{'Status':<15}"
                )
                print("-" * 120)

                for row in results:
                    lot_id     = row[0]
                    ingredient = row[1]
                    ing_type   = row[2]
                    pack_size  = row[3]
                    num_packs  = row[4]
                    total_oz   = row[5]
                    expiration = row[6]
                    status     = row[7]

                    print(
                        f"{lot_id:<20} "
                        f"{ingredient:<25} "
                        f"{ing_type:<10} "
                        f"{pack_size:<10.2f} "
                        f"{num_packs:<10.1f} "
                        f"{total_oz:<12.2f} "
                        f"{expiration} "
                        f"{status:<15}"
                    )

                expiring_soon_count = sum(1 for row in results if row[7] == 'EXPIRING SOON')
                if expiring_soon_count > 0:
                    print(f"Alert: {expiring_soon_count} batch(es) expiring within 30 days.")
            else:
                print("\nNo ingredient batches found for this supplier.")

        except mysql.connector.Error as err:
            print(f"Database error: {err}")

    
    def manage_do_not_combine(self):
        print("\n" + "-"*60)
        print("MANAGE DO-NOT-COMBINE LIST")
        print("-"*60)
        
        print("\n1) Add Do-Not-Combine Rule")
        print("2) Remove Do-Not-Combine Rule")
        print("3) View Do-Not-Combine List")
        print("4) Back to Main Menu")
        
        try:
            choice = int(input("\nSelection: "))
            
            if choice == 1:
                self.add_do_not_combine_rule()
            elif choice == 2:
                self.remove_do_not_combine_rule()
            elif choice == 3:
                self.view_do_not_combine_list()
            elif choice == 4:
                return
            else:
                print("Invalid choice.")
        except ValueError:
            print("Invalid input. Please enter a number.")
    
    def add_do_not_combine_rule(self):
        print("\n--- Add Do-Not-Combine Rule ---")
        
        self.view_all_ingredients()
        
        try:
            ing1_id = int(input("\nEnter First Ingredient ID: "))
            ing2_id = int(input("Enter Second Ingredient ID: "))
            
            if ing1_id == ing2_id:
                print("Error: Cannot create rule for same ingredient.")
                return
            
            # Ensure smaller ID is first
            if ing1_id > ing2_id:
                ing1_id, ing2_id = ing2_id, ing1_id
            
            self.ensure_clean_transaction()
            self.connection.start_transaction()
            
            # Check if both ingredients exist
            self.cursor.execute("""
                SELECT COUNT(*) FROM Ingredient
                WHERE IngredientID IN (%s, %s)
            """, (ing1_id, ing2_id))
            
            if self.cursor.fetchone()[0] != 2:
                print("Error: One or both ingredients do not exist.")
                self.connection.rollback()
                return
            
            # Check if rule already exists
            self.cursor.execute("""
                SELECT COUNT(*) FROM DoNotCombineList
                WHERE Ingredient1ID = %s AND Ingredient2ID = %s
            """, (ing1_id, ing2_id))
            
            if self.cursor.fetchone()[0] > 0:
                print("\nDo-not-combine rule already exists.")
                self.connection.commit()
                return
            
            # Add rule - trigger will validate both are atomic
            self.cursor.execute("""
                INSERT INTO DoNotCombineList (Ingredient1ID, Ingredient2ID)
                VALUES (%s, %s)
            """, (ing1_id, ing2_id))
            
            self.connection.commit()
            print("\nDo-not-combine rule added successfully!")
            
        except mysql.connector.Error as err:
            print(f"Error: {err}")
            self.connection.rollback()
        except ValueError:
            print("Error: Invalid ingredient ID.")
    
    def remove_do_not_combine_rule(self):
        print("\n--- Remove Do-Not-Combine Rule ---")
        
        self.view_do_not_combine_list()
        
        try:
            ing1_id = int(input("\nEnter First Ingredient ID: "))
            ing2_id = int(input("Enter Second Ingredient ID: "))
            
            # Ensure smaller ID is first
            if ing1_id > ing2_id:
                ing1_id, ing2_id = ing2_id, ing1_id
            
            self.ensure_clean_transaction()
            self.connection.start_transaction()
            
            # Check if rule exists
            self.cursor.execute("""
                SELECT COUNT(*) FROM DoNotCombineList
                WHERE Ingredient1ID = %s AND Ingredient2ID = %s
            """, (ing1_id, ing2_id))
            
            if self.cursor.fetchone()[0] == 0:
                print("Error: Do-not-combine rule does not exist.")
                self.connection.rollback()
                return
            
            # Remove rule
            self.cursor.execute("""
                DELETE FROM DoNotCombineList
                WHERE Ingredient1ID = %s AND Ingredient2ID = %s
            """, (ing1_id, ing2_id))
            
            self.connection.commit()
            print("\nDo-not-combine rule removed successfully!")
            
        except ValueError:
            print("Error: Invalid ingredient ID.")
        except mysql.connector.Error as err:
            print(f"Database error: {err}")
            self.connection.rollback()
    
    def view_do_not_combine_list(self):
        print("\n--- Do-Not-Combine Rules ---")
        try:
            self.cursor.callproc('sp_view_do_not_combine_list', [])
            
            for result in self.cursor.stored_results():
                rows = result.fetchall()
                if rows:
                    print(f"\n{'Ingredient 1 ID':<16} {'Ingredient 1 Name':<30} "
                          f"{'Ingredient 2 ID':<16} {'Ingredient 2 Name':<30}")
                    print("-" * 100)
                    for row in rows:
                        print(f"{row[0]:<16} {row[1]:<30} {row[2]:<16} {row[3]:<30}")
                else:
                    print("No do-not-combine rules found.")
                    
        except mysql.connector.Error as err:
            print(f"Database error: {err}")
    
    def view_my_ingredients(self):
        print("\n--- My Ingredients (All Types) ---")
        try:
            self.cursor.execute("""
                SELECT DISTINCT 
                    i.IngredientID,
                    i.IngredientName,
                    i.IsCompound,
                    COUNT(DISTINCT f.FormulationID) as FormulationCount
                FROM Ingredient i
                INNER JOIN Formulation f ON i.IngredientID = f.IngredientID
                WHERE f.SupplierID = %s
                GROUP BY i.IngredientID, i.IngredientName, i.IsCompound
                ORDER BY i.IngredientName
            """, (self.supplier_id,))
            
            results = self.cursor.fetchall()
            if results:
                print(f"\n{'Ing ID':<8} {'Ingredient Name':<30} {'Type':<12} {'# Formulations':<15}")
                print("-" * 70)
                for row in results:
                    ing_type = "Compound" if row[2] else "Atomic"
                    print(f"{row[0]:<8} {row[1]:<30} {ing_type:<12} {row[3]:<15}")
                print(f"\nTotal: {len(results)} ingredients")
            else:
                print("No ingredients found for this supplier.")
                
        except mysql.connector.Error as err:
            print(f"Database error: {err}")
