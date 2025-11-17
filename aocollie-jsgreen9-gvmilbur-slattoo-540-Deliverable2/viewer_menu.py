"""
CSC540 Database Project - Viewer Menu Module
Food Manufacturing Inventory Management System
Read-only access for viewing products, recipes, and ingredients
"""

import mysql.connector

class ViewerMenu:
    def __init__(self, connection, cursor, user_id):
        self.connection = connection
        self.cursor = cursor
        self.user_id = user_id

    # Main menu loop
    def run(self):
        while True:
            print("\n" + "="*60)
            print("VIEWER MENU")
            print("="*60)
            print("1) Browse Product Batches")
            print("2) View Batch Ingredients (Flattened)")
            print("3) Compare Batches for Incompatibilities")
            print("4) Logout")
            print("="*60)

            try:
                choice = int(input("\nSelection: "))
            except ValueError:
                print("Invalid input. Please enter a number.")
                continue

            try:
                if choice == 1:
                    self.browse_product_batches()
                elif choice == 2:
                    self.view_product_recipes_flattened()
                elif choice == 3:
                    self.compare_products_incompatibilities()
                elif choice == 4:
                    print("\nReturning to role selection...")
                    break
                else:
                    print("Invalid choice. Please enter 1-4.")
            except mysql.connector.Error as err:
                print(f"Database error: {err}")
            except Exception as e:
                print(f"Unexpected error: {e}")

    # 1) Browse Products (uses stored procedure)
    def browse_product_batches(self):
        print("\n--- Browse Product Batches ---")
        
        try:
            self.cursor.callproc('sp_browse_product_batches')
            
            for result in self.cursor.stored_results():
                rows = result.fetchall()
                if rows:
                    print(f"\n{'#':<4} {'Batch LotID':<20} {'ProdID':<8} {'Product':<25} {'Category':<15} "
                        f"{'Manufacturer':<15} {'Qty':<6} {'Production':<12}")
                    print("-"*120)
                    for idx, r in enumerate(rows, 1):
                        print(f"{idx:<4} {r[0]:<20} {r[1]:<8} {r[2]:<25} {r[3]:<15} "
                            f"{r[5]:<15} {r[6]:<6} {str(r[7]):<12}")
                    print(f"\nTotal: {len(rows)} batch(es)")
                else:
                    print("No product batches found.")
                    
        except mysql.connector.Error as err:
            print(f"Database error: {err}")

    # 2) View Product Recipes (Flattened)
    def view_product_recipes_flattened(self):
        print("\n--- View Batch Ingredients ---")
        
        try:
            self.cursor.callproc('sp_list_all_product_batches')
            
            for result in self.cursor.stored_results():
                batches = result.fetchall()
            
            if not batches:
                print("No product batches found.")
                return
            
            print(f"\n{'#':<4} {'Batch LotID':<20} {'ProdID':<8} {'Product':<25} {'Manufacturer':<20} {'Production':<12} {'Qty':<6}")
            print("-"*105)
            for idx, b in enumerate(batches, 1):
                print(f"{idx:<4} {b[0]:<20} {b[1]:<8} {b[2]:<25} {b[3]:<20} {str(b[4]):<12} {b[5]:<6}")
            
            try:
                selection = int(input("\nEnter batch # (0 to cancel): "))
            except ValueError:
                print("Invalid input.")
                return
            
            if selection == 0:
                return
            
            if selection < 1 or selection > len(batches):
                print(f"Error: Please enter a number between 1 and {len(batches)}.")
                return
            
            selected_batch = batches[selection - 1]
            batch_lot_id = selected_batch[0]
            
            self.cursor.callproc('sp_get_batch_info', [batch_lot_id])
            
            for result in self.cursor.stored_results():
                batch_info = result.fetchone()
            
            if not batch_info:
                print("Batch not found.")
                return
            
            print("\n" + "="*70)
            print("FLATTENED INGREDIENT LIST (PER UNIT)")
            print("="*70)
            print(f"Batch Lot ID: {batch_info[0]}")
            print(f"Product:      {batch_info[1]}")
            print(f"Manufacturer: {batch_info[2]}")
            print(f"Production:   {batch_info[3]}")
            print(f"Batch Size:   {batch_info[4]} units")
            
            self.cursor.execute("""
                SELECT IngredientID, IngredientName, TotalQuantityOz, BatchQuantity
                FROM vw_flattened_product_bom
                WHERE BatchLotID = %s
                ORDER BY TotalQuantityOz DESC, IngredientName
            """, (batch_lot_id,))
            
            rows = self.cursor.fetchall()
            
            if rows:
                print(f"\n{'IngID':<8} {'Ingredient Name':<35} {'Qty per Unit (oz)':<20}")
                print("-"*70)
                total_oz = 0
                for r in rows:
                    qty_per_unit = r[2] / r[3]
                    print(f"{r[0]:<8} {r[1]:<35} {qty_per_unit:<20.3f}")
                    total_oz += qty_per_unit
                print("-"*70)
                print(f"{'TOTAL PER UNIT':<44} {total_oz:<20.3f}")
                print(f"\nShowing {len(rows)} atomic ingredient(s)")
                print("="*70)
            else:
                print("\nNo ingredients found for this batch.")
                    
        except mysql.connector.Error as err:
            print(f"Database error: {err}")

    def compare_products_incompatibilities(self):
        print("\n--- Compare Product Batches for Incompatibilities ---")
        print("Check if two batches have conflicting ingredients (Based on actual formulations used in production)")
        
        try:
            self.cursor.callproc('sp_list_all_product_batches')
            
            for result in self.cursor.stored_results():
                batches = result.fetchall()
            
            if not batches:
                print("No product batches found.")
                return
            
            print(f"\n{'#':<4} {'Batch LotID':<20} {'ProdID':<8} {'Product':<25} {'Manufacturer':<20} {'Production':<12} {'Qty':<6}")
            print("-"*105)
            for idx, b in enumerate(batches, 1):
                print(f"{idx:<4} {b[0]:<20} {b[1]:<8} {b[2]:<25} {b[3]:<20} {str(b[4]):<12} {b[5]:<6}")
            
            try:
                selection1 = int(input("\nEnter first batch # (0 to cancel): "))
            except ValueError:
                print("Invalid input.")
                return
            
            if selection1 == 0:
                return
            
            if selection1 < 1 or selection1 > len(batches):
                print(f"Error: Please enter a number between 1 and {len(batches)}.")
                return
            
            try:
                selection2 = int(input("Enter second batch # (0 to cancel): "))
            except ValueError:
                print("Invalid input.")
                return
            
            if selection2 == 0:
                return
            
            if selection2 < 1 or selection2 > len(batches):
                print(f"Error: Please enter a number between 1 and {len(batches)}.")
                return
            
            if selection1 == selection2:
                print("Error: Please select two different batches.")
                return
            
            batch1 = batches[selection1 - 1]
            batch2 = batches[selection2 - 1]
            batch1_id = batch1[0]
            batch2_id = batch2[0]
            
            print(f"\nComparing:")
            print(f"  Batch {selection1}: {batch1_id} ({batch1[2]})")
            print(f"  Batch {selection2}: {batch2_id} ({batch2[2]})")
            
            self.cursor.callproc('sp_compare_batches_incompatibilities', 
                                [batch1_id, batch2_id])
            
            for result in self.cursor.stored_results():
                rows = result.fetchall()
                
                if rows and len(rows[0]) == 1:
                    print(f"\n{rows[0][0]}")
                    return
                
                if rows:
                    print("\n" + "="*70)
                    print("INCOMPATIBILITY CONFLICTS FOUND!")
                    print("="*70)
                    print(f"\n{'Ingredient 1 ID':<16} {'Ingredient 1':<25} "
                        f"{'Ingredient 2 ID':<16} {'Ingredient 2':<25}")
                    print("-"*90)
                    for r in rows:
                        print(f"{r[0]:<16} {r[1]:<25} {r[2]:<16} {r[3]:<25}")
                    print("\n" + "="*70)
                    print(f"Total conflicts: {len(rows)}")
                    print("These batches should NOT be manufactured together!")
                else:
                    print("\nNo incompatibility conflicts found.")
                    print("These batches can be safely manufactured together.")
                    
        except mysql.connector.Error as err:
            print(f"Database error: {err}")