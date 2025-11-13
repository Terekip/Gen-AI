
import os

IGNORED = {'.git', 'node_modules', '__pycache__', '.venv', 'build', 'dist'}

def build_tree(path):
    tree = {"name": os.path.basename(path), "type": "directory", "children": []}
    try:
        for entry in os.scandir(path):
            if entry.is_dir(follow_symlinks=False):
                if entry.name in IGNORED:
                    continue
                tree["children"].append(build_tree(entry.path))
            else:
                tree["children"].append({"name": entry.name, "type": "file"})
    except PermissionError:
        pass
    return tree
