"""
CSC540 Database Project - Query Menu Module
5 Required Queries for Project Demonstration
"""

import mysql.connector

class QueryMenu:
    def __init__(self, connection, cursor):
        self.connection = connection
        self.cursor = cursor

    def run(self):
        while True:
            print("\n" + "="*70)
            print("QUERY MENU - 5 Required Queries")
            print("="*70)
            print("1) Last Batch Ingredients (Product 100, Manufacturer MFG001)")
            print("2) Supplier Spending (Manufacturer MFG002)")
            print("3) Product Unit Cost (Lot 100-MFG001-B0901)")
            print("4) Conflicting Ingredients (Lot 100-MFG001-B0901)")
            print("5) Manufacturers NOT Supplied By (Supplier 21 - James Miller)")
            print("6) Back to Main Menu")
            print("="*70)

            try:
                choice = int(input("\nSelection: "))
            except ValueError:
                print("Invalid input. Please enter a number.")
                continue

            try:
                if choice == 1:
                    self.query1_last_batch_ingredients()
                elif choice == 2:
                    self.query2_supplier_spending()
                elif choice == 3:
                    self.query3_product_unit_cost()
                elif choice == 4:
                    self.query4_conflicting_ingredients()
                elif choice == 5:
                    self.query5_manufacturers_not_supplied()
                elif choice == 6:
                    break
                else:
                    print("Invalid choice. Please enter 1-6.")
            except mysql.connector.Error as err:
                print(f"Database error: {err}")
            except Exception as e:
                print(f"Unexpected error: {e}")

    # Query 1: Last Batch Ingredients
    def query1_last_batch_ingredients(self):
        print("\n" + "="*70)
        print("QUERY 1: Last Batch Ingredients")
        print("="*70)
        print("Product: Steak Dinner (ID: 100)")
        print("Manufacturer: MFG001")
        print("-"*70)
        
        try:
            self.cursor.callproc('sp_query_last_batch_ingredients', [100, 'MFG001'])
            
            for result in self.cursor.stored_results():
                rows = result.fetchall()
                
                # Check for error message
                if rows and len(rows[0]) == 1:
                    print(f"\n{rows[0][0]}")
                    return
                
                if rows:
                    # Header info from first row
                    print(f"\nProduct Lot ID: {rows[0][0]}")
                    print(f"Production Date: {rows[0][1]}")
                    print(f"\n{'IngID':<8} {'Ingredient Name':<30} {'Ingredient Lot ID':<20} {'Qty Used (oz)':<15}")
                    print("-"*80)
                    for r in rows:
                        print(f"{r[2]:<8} {r[3]:<30} {r[4]:<20} {r[5]:<15.2f}")
                    print(f"\nTotal ingredients used: {len(rows)}")
                else:
                    print("\nNo data found.")
                    
        except mysql.connector.Error as err:
            print(f"Database error: {err}")

    # Query 2: Supplier Spending
    def query2_supplier_spending(self):
        print("\n" + "="*70)
        print("QUERY 2: Supplier Spending by Manufacturer")
        print("="*70)
        print("Manufacturer: MFG002 (Manager B)")
        print("-"*70)
        
        try:
            self.cursor.callproc('sp_query_supplier_spending', [2])
            
            for result in self.cursor.stored_results():
                rows = result.fetchall()
                
                if rows:
                    print(f"\n{'SupplierID':<12} {'Supplier Name':<25} {'Batches':<10} {'Total Spent':<15}")
                    print("-"*70)
                    total_spending = 0
                    for r in rows:
                        print(f"{r[0]:<12} {r[1]:<25} {r[2]:<10} ${r[3]:<14.2f}")
                        total_spending += r[3]
                    print("-"*70)
                    print(f"{'TOTAL SPENDING':<48} ${total_spending:.2f}")
                    print(f"\nPurchased from {len(rows)} supplier(s)")
                else:
                    print("\nNo supplier purchases found.")
                    
        except mysql.connector.Error as err:
            print(f"Database error: {err}")

    # Query 3: Product Unit Cost
    def query3_product_unit_cost(self):
        print("\n" + "="*70)
        print("QUERY 3: Product Unit Cost")
        print("="*70)
        print("Product Lot: 100-MFG001-B0901")
        print("-"*70)
        
        try:
            self.cursor.callproc('sp_query_product_unit_cost', ['100-MFG001-B0901'])
            
            for result in self.cursor.stored_results():
                rows = result.fetchall()
                
                if rows:
                    r = rows[0]
                    print(f"\nLot ID:         {r[0]}")
                    print(f"Product ID:     {r[1]}")
                    print(f"Product Name:   {r[2]}")
                    print(f"Batch Quantity: {r[3]} units")
                    print(f"Production:     {r[4]}")
                    print(f"Batch Cost:     ${r[5]:.2f}")
                    print(f"Per-Unit Cost:  ${r[6]:.4f}")
                else:
                    print("\nProduct lot not found.")
                    
        except mysql.connector.Error as err:
            print(f"Database error: {err}")

    # Query 4: Conflicting Ingredients
    def query4_conflicting_ingredients(self):
        print("\n" + "="*70)
        print("QUERY 4: Conflicting Ingredients")
        print("="*70)
        print("Product Lot: 100-MFG001-B0901")
        print("Find ingredients that CANNOT be included due to conflicts")
        print("-"*70)
        
        try:
            self.cursor.callproc('sp_query_conflicting_ingredients', ['100-MFG001-B0901'])
            
            for result in self.cursor.stored_results():
                rows = result.fetchall()
                
                # After getting rows:
                if rows:
                    distinct_ingredients = len(set(row[0] for row in rows))  # Count unique IDs
                    for r in rows:
                        print(f"{r[0]:<8} {r[1]:<35} {r[2]:<35}")
                    print(f"\n{distinct_ingredients} ingredient(s) cannot be used in this batch")
                else:
                    print("\nNo conflicting ingredients found.")
                    
        except mysql.connector.Error as err:
            print(f"Database error: {err}")

    # Query 5: Manufacturers NOT Supplied
    def query5_manufacturers_not_supplied(self):
        print("\n" + "="*70)
        print("QUERY 5: Manufacturers NOT Supplied By Supplier")
        print("="*70)
        print("Supplier: James Miller (ID: 21)")
        print("-"*70)
        
        try:
            self.cursor.callproc('sp_query_manufacturers_not_supplied', [21])
            
            for result in self.cursor.stored_results():
                rows = result.fetchall()
                
                if rows:
                    print(f"\n{'MfgID':<8} {'Manufacturer Name':<30} {'UserID':<10}")
                    print("-"*55)
                    for r in rows:
                        print(f"{r[0]:<8} {r[1]:<30} {r[2]:<10}")
                    print(f"\nJames Miller has NOT supplied to {len(rows)} manufacturer(s)")
                else:
                    print("\nJames Miller has supplied to all manufacturers.")
                    
        except mysql.connector.Error as err:
            print(f"Database error: {err}")