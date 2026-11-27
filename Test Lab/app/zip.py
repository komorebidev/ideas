import os
import zipfile

zip_path = "../app.zip"

with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zipf:
    for root, dirs, files in os.walk("."):
        dirs[:] = [d for d in dirs if d not in (".venv", "venv", "__pycache__", ".git")]
        for file in files:
            if file.endswith((".pyc", ".pyo")) or file == "zip.py":
                continue
            path = os.path.join(root, file)
            zipf.write(path, os.path.relpath(path, "."))

print(f"Successfully created zip at: {os.path.abspath(zip_path)}")