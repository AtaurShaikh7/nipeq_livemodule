import pandas as pd
import os
import re

# File name
file_path = "procedure Automation.xlsx"

# Load Sheet2
df = pd.read_excel(file_path, sheet_name="Sheet2")

# Create folder for procedures
output_folder = "procedures"
os.makedirs(output_folder, exist_ok=True)

# Function to clean and validate file names
def make_valid_filename(name):
    # Replace invalid characters with '_'
    invalid_chars = r'[<>:"/\\|?*\n\r\t]'
    cleaned = re.sub(invalid_chars, '_', str(name))
    # Remove leading/trailing spaces and dots (Windows restriction)
    cleaned = cleaned.strip().strip('.')
    # Truncate if too long (Windows has max 255 char for each file component)
    return cleaned[:200] if len(cleaned) > 200 else cleaned

# Loop through rows
for index, row in df.iterrows():
    proc_name = row["PROCEDURE_NAME"]
    code = row["FULL_CODE"]

    if pd.notna(proc_name) and pd.notna(code):
        # Clean Excel line breaks
        clean_code = code.replace("_x000D_", "\n")

        valid_proc_name = make_valid_filename(proc_name)
        file_path = os.path.join(output_folder, f"{valid_proc_name}.sql")
        
        try:
            with open(file_path, "w", encoding="utf-8") as f:
                f.write(clean_code)
        except OSError as e:
            print(f"Failed to write file: {file_path}")
            print(f"Original proc_name: {proc_name!r}")
            print("OSError:", e)

print("All procedures extracted (some may have been skipped due to invalid filenames)!")