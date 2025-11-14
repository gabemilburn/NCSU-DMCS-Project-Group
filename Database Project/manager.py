"""
CSC540 Database Project - Main Application
Graduate Version
Food Manufacturing Inventory Management System
"""

import mysql.connector
from mysql.connector import errorcode
import sys
import os

# Import role menu modules
from supplier_menu import SupplierMenu
from manufacturer_menu import ManufacturerMenu
from viewer_menu import ViewerMenu
from query_menu import QueryMenu 


def validate_credentials():
    print("="*60)
    print("CSC540 - Inventory Management System")
    print("Food Manufacturing Database Application")
    print("="*60)
    
    ######################################################
    #### CHANGE THE DATABASE REFERENCE AS NEEDED HERE ####
    ######################################################
    db_config = {
        'user': 'root',
        'host': '127.0.0.1',
        'database': 'csc540_project',
        'password': input("Enter MySQL password: ")
    }
    #######################################################
    
    return db_config

def connect_to_database(config):
    try:
        connection = mysql.connector.connect(**config)
        return connection
    except mysql.connector.Error as err:
        if err.errno == errorcode.ER_ACCESS_DENIED_ERROR:
            print('Error: Invalid database credentials')
        elif err.errno == errorcode.ER_BAD_DB_ERROR:
            print('Error: Database not found')
        else:
            print(f'Error: Cannot connect to database: {err}')
        return None

def login(cursor):
    print("\n" + "="*60)
    print("LOGIN")
    print("="*60)
    
    user_id = input("UserID: ").strip()
    
    # Validate user credentials
    validate_user_query = """
        SELECT UserRole, Username
        FROM User 
        WHERE UserID = %s
    """
    cursor.execute(validate_user_query, (user_id,)) 
    result = cursor.fetchone()
    
    # Keep prompting until valid credentials
    while result is None:
        print("\nError: No matching user found. Please try again.\n")
        user_id = input("UserID: ").strip()
        cursor.execute(validate_user_query, (user_id,)) 
        result = cursor.fetchone()
    
    user_role = result[0]
    username = result[1]
    print(f"\nWelcome, {username}!")
    print(f"User Role: {user_role}")
    
    return user_id, user_role

def select_role_menu():
    print("\n" + "="*60)
    print("SELECT ROLE INTERFACE")
    print("="*60)
    print("1) Manufacturer")
    print("2) Supplier")
    print("3) General Viewer")
    print("4) Query Menu")
    print("="*60)
    
    while True:
        try:
            choice = int(input("\nSelection: "))
            if choice in (1, 2, 3, 4):
                return choice
            else:
                print("Invalid choice. Please enter 1, 2, 3, or 4.")
        except ValueError:
            print("Invalid input. Please enter a number.")

def run_manufacturer_menu(connection, cursor, user_id):
    # Get manufacturer ID for this user
    cursor.execute("""
        SELECT ManufacturerID
        FROM Manufacturer
        WHERE UserID = %s
    """, (user_id,))
    result = cursor.fetchone()

    if result is None:
        print("\nError: No manufacturer record found for this user.")
        input("\nPress Enter to continue...")
        return

    manufacturer_id = result[0]

    manu_menu = ManufacturerMenu(connection, cursor, user_id, manufacturer_id)
    manu_menu.run()

def run_supplier_menu(connection, cursor, user_id):
    # Get supplier ID for this user
    cursor.execute("""
        SELECT SupplierID 
        FROM Supplier 
        WHERE UserID = %s
    """, (user_id,))
    
    result = cursor.fetchone()
    if result is None:
        print("\nError: No supplier record found for this user.")
        input("\nPress Enter to continue...")
        return
    
    supplier_id = result[0]
    
    # Create and run supplier menu
    supplier_menu = SupplierMenu(connection, cursor, user_id, supplier_id)
    supplier_menu.run()

def run_viewer_menu(connection, cursor, user_id):
    # Create and run viewer menu
    viewer_menu = ViewerMenu(connection, cursor, user_id)
    viewer_menu.run()

def run_query_menu(connection, cursor):
    # Create and run query menu
    query_menu = QueryMenu(connection, cursor)
    query_menu.run()

def main():
    # Get database configuration
    db_config = validate_credentials()
    
    # Connect to database
    connection = connect_to_database(db_config)
    if connection is None:
        print("Failed to connect to database. Exiting.")
        sys.exit(1)
    
    cursor = connection.cursor()
    print("\nConnected to database successfully!")
    
    try:
        # Login
        user_id, user_role = login(cursor)
        
        # Main application loop
        while True:
            # Select role menu
            menu_choice = select_role_menu()
            
            if menu_choice == 1:
                # Check if user can access manufacturer role
                if user_role != 'MANUFACTURER':
                    print("\nError: You do not have manufacturer privileges.")
                    print("Your role is:", user_role)
                    input("\nPress Enter to continue...")
                    continue
                run_manufacturer_menu(connection, cursor, user_id)
                
            elif menu_choice == 2:
                # Check if user can access supplier role
                if user_role != 'SUPPLIER':
                    print("\nError: You do not have supplier privileges.")
                    print("Your role is:", user_role)
                    input("\nPress Enter to continue...")
                    continue
                run_supplier_menu(connection, cursor, user_id)
                
            elif menu_choice == 3:
                # Anyone can access viewer menu
                run_viewer_menu(connection, cursor, user_id)
                
            elif menu_choice == 4:
                # Anyone can access query menu
                run_query_menu(connection, cursor)
            
            # Ask if user wants to continue or logout
            print("\n" + "="*60)
            continue_choice = input("Return to role selection? (Y/N): ").strip().upper()
            if continue_choice != 'Y':
                print("\nLogging out...")
                break
    
    except KeyboardInterrupt:
        print("\n\nApplication interrupted by user.")
    except Exception as e:
        print(f"\nAn unexpected error occurred: {e}")
    finally:
        # Clean up
        cursor.close()
        connection.close()
        print("Database connection closed.")
        print("Thank you for using the Inventory Management System!")

if __name__ == "__main__":
    main()