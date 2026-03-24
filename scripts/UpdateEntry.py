#!/usr/bin/env python3
import csv
import sys
import os
import shutil
import copy

# ─────────────────────────────────────────────────────────────────
#  UpdateEntry.py
#  Interactive CLI to edit data/SinclairPrograms_Main.csv
#
#  Usage:  python3 scripts/UpdateEntry.py
# ─────────────────────────────────────────────────────────────────

CSV_PATH = "data/SinclairPrograms_Main.csv"
HTML_PATH = "SinclairExplorer.html"

def check_root():
    """Ensure script is run from project root."""
    if not os.path.exists(HTML_PATH) or not os.path.exists(CSV_PATH):
        print(f"❌  Error: Must be run from project root (containing {HTML_PATH} and {CSV_PATH})")
        sys.exit(1)

def load_data():
    """Load CSV data into a list of dictionaries."""
    with open(CSV_PATH, 'r', encoding='utf-8-sig') as f:
        reader = csv.DictReader(f)
        return list(reader), reader.fieldnames

def save_data(data, fieldnames):
    """Save updated data back to CSV with ACID guarantees."""
    temp_path = f"{CSV_PATH}.tmp"
    backup_path = f"{CSV_PATH}.bak"
    
    print(f"\n💾  Writing to temporary file {temp_path}...")
    try:
        # 1. Write to temp file first (Atomicity preparation)
        with open(temp_path, 'w', encoding='utf-8-sig', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(data)
            # 2. Flush and Fsync (Durability)
            f.flush()
            os.fsync(f.fileno())
            
        # 3. Create backup of the ORIGINAL valid file before overwriting (Safety)
        if os.path.exists(CSV_PATH):
            shutil.copy2(CSV_PATH, backup_path)
            
        # 4. Atomic Rename (Atomicity commit)
        # os.replace is atomic on POSIX compliant systems (Linux/macOS)
        os.replace(temp_path, CSV_PATH)
        
        print(f"✅  Successfully committed changes to {CSV_PATH}")
        print(f"    (Previous version backed up to {backup_path})")
        
    except IOError as e:
        print(f"\n❌  CRITICAL ERROR: Failed to write to disk: {e}")
        if os.path.exists(temp_path):
            os.remove(temp_path)
        sys.exit(1)
    except Exception as e:
        print(f"\n❌  Unexpected error during save: {e}")
        if os.path.exists(temp_path):
            os.remove(temp_path)
        sys.exit(1)

def search_rows(data, query):
    """Find rows matching query in Title column."""
    matches = []
    for idx, row in enumerate(data):
        if query.lower() in row.get('Title', '').lower():
            matches.append((idx, row))
    return matches[:10]  # Return top 10

def print_columns(row, fieldnames):
    """Print all columns with their current values."""
    print("\n📝  Current Values:")
    for i, field in enumerate(fieldnames):
        val = row.get(field, '')
        # Truncate long values for display
        display_val = (val[:50] + '...') if len(val) > 50 else val
        print(f"  [{i+1}] {field}: {display_val}")

def select_row(data):
    """Prompts user to select a row by Number or Search."""
    while True:
        choice = input("\nSelect row by (N)umber or (S)earch? [N/s] (or 'b' to back): ").strip().lower()

        if choice in ('b', 'back', 'q', 'quit', 'exit'):
            return None
        
        if choice == 's':
            query = input("Enter search term (Title) (or 'b' to back): ").strip()
            if query.lower() in ('b', 'back', 'q', 'quit'): continue

            matches = search_rows(data, query)
            if not matches:
                print("No matches found.")
                continue
            
            print(f"\nFound {len(matches)} matches:")
            for i, (original_idx, row) in enumerate(matches):
                print(f"  [{i+1}] {row.get('Title', 'Unknown')}")
            
            raw_sel = input("\nSelect number from list (0 to search again, 'b' to back): ").strip().lower()
            if raw_sel in ('b', 'back', 'q', 'quit'):
                return None
            
            try:
                sel = int(raw_sel)
                if sel == 0: continue
                if 1 <= sel <= len(matches):
                    return matches[sel-1][0]
                else:
                    print("Invalid selection.")
            except ValueError:
                print("Invalid input.")
                
        else:
            # Default to Number
            raw_num = input(f"Enter row number (1-{len(data)}) (or 'b' to back): ").strip()
            if raw_num.lower() in ('b', 'back', 'q', 'quit'):
                return None
            
            if not raw_num: continue

            try:
                row_num = int(raw_num)
                idx = row_num - 1 # 0-indexed internally
                if 0 <= idx < len(data):
                    return idx
                else:
                    print("Row number out of range.")
            except ValueError:
                print("Invalid number.")

def edit_row(data, idx, fieldnames):
    """Handles the editing loop for a selected row."""
    # We edit the row in place within the data list
    selected_row = data[idx]
    
    while True:
        print_columns(selected_row, fieldnames)
        
        col_choice = input(f"\nSelect column number to edit (1-{len(fieldnames)}) or (q)uit editing this row: ").strip()
        if col_choice.lower() in ('q', 'quit', 'b', 'back'):
            break
            
        try:
            col_idx = int(col_choice) - 1
            if 0 <= col_idx < len(fieldnames):
                field = fieldnames[col_idx]
                current_val = selected_row.get(field, '')
                print(f"\nEditing [{field}]")
                print(f"Current: {current_val}")
                new_val = input("New Value (Enter to keep current): ")
                
                if new_val:
                    if ',' in new_val:
                        # Heuristic: Remove commas from numeric fields, replace with space for text
                        numeric_keywords = ['salary', 'pay', 'jobs', 'growth', 'satisfaction', 'year', 'density', 'employment']
                        if any(k in field.lower() for k in numeric_keywords):
                            print(f"⚠️  Numeric field detected: Removing commas ('{new_val}' -> '{new_val.replace(',', '')}')")
                            new_val = new_val.replace(',', '')
                        else:
                            print(f"⚠️  Text field detected: Replacing commas with spaces ('{new_val}' -> '{new_val.replace(',', ' ')}')")
                            new_val = new_val.replace(',', ' ')
                        
                        input("Press Enter to continue...")

                    selected_row[field] = new_val
                    # Ensure update reflects in main data list (it should as it's a ref, but to be sure)
                    data[idx] = selected_row 
                    print("✅ Updated (in memory).")
                else:
                    print("No change made.")
            else:
                print("Invalid column number.")
        except ValueError:
            print("Invalid input.")

def review_changes(data, original_data, fieldnames):
    """Compare current data against original data and print differences."""
    changes_found = False
    print("\n🔍  REVIEW PENDING CHANGES")
    print("──────────────────────────")

    # For now, we assume row order/count hasn't changed
    for i, row in enumerate(data):
        if row != original_data[i]:
            changes_found = True
            print(f"\nRow {i+1}: {row.get('Title', 'Unknown')}")
            for field in fieldnames:
                old_val = original_data[i].get(field, '')
                new_val = row.get(field, '')
                if old_val != new_val:
                    print(f"  📝  {field}:")
                    print(f"      OLD: '{old_val}'")
                    print(f"      NEW: '{new_val}'")

    if not changes_found:
        print("\n  (No changes detected)")
    
    input("\nPress Enter to return to menu...")

def main():
    check_root()
    data, fieldnames = load_data()
    # Deep copy to track original state for diffs
    original_data = copy.deepcopy(data)
    
    print("Welcome to Sinclair Data Editor")
    print("───────────────────────────────")

    while True:
        # Determine if there are pending changes
        is_modified = (data != original_data)
        status = " (Unsaved Changes Pending!)" if is_modified else ""

        print(f"\nMAIN MENU{status}")
        print("1. Select Row to Edit")
        print("2. Review Pending Changes")
        print("3. Save Changes")
        print("4. Quit")
        
        choice = input("\nChoose an option (1-4): ").strip()
        
        if choice == '1':
            idx = select_row(data)
            if idx is not None:
                edit_row(data, idx, fieldnames)
                
        elif choice == '2':
            review_changes(data, original_data, fieldnames)

        elif choice == '3':
            if is_modified:
                save_data(data, fieldnames)
                # Update baseline after save
                original_data = copy.deepcopy(data)
                print("💡  Don't forget to run 'bash scripts/Merge-new_Main-Data.sh' to update the HTML!")
            else:
                print("No changes to save.")
                
        elif choice == '4':
            if is_modified:
                confirm = input("⚠️  You have unsaved changes. Quit anyway? [y/N]: ").strip().lower()
                if confirm != 'y':
                    continue
            print("👋 Bye!")
            break
        
        else:
            print("Invalid option.")

if __name__ == "__main__":
    main()
