# parser_test.py
from tree_sitter_language_pack import get_parser  # ← Updated import

def parse_file(file_path: str) -> dict:
    """Parse Python, JS, or TS file and extract functions, classes, and calls, with debug logs."""
    try:
        ext = file_path.split(".")[-1].lower().strip()
        if ext == "py":
            parser = get_parser("python")
        elif ext == "js":
            parser = get_parser("javascript")
        elif ext == "ts":
            parser = get_parser("typescript")
        else:
            print(f"Warning: Unsupported file type: {file_path}")
            return {"error": f"Unsupported file extension: {ext}"}

        with open(file_path, "rb") as f:
            source = f.read()

        if not source.strip():
            print(f"Warning: Empty file: {file_path}")
            return {"file": file_path, "functions": [], "classes": [], "calls": [], "entry_point": False}

        tree = parser.parse(source)
        root = tree.root_node
        print(f"Parsed {file_path}: root='{root.type}', children={len(root.children)}")

        functions, classes, calls = [], [], []

        def walk(node):
            # Function definitions (Python, JS, TS)
            if node.type in [
                "function_definition", "async_function_definition",
                "function_declaration", "method_definition",
                "arrow_function", "generator_function_declaration"
            ]:
                name_node = node.child_by_field_name("name")
                if name_node:
                    name = source[name_node.start_byte:name_node.end_byte].decode(errors="ignore")
                    line = name_node.start_point[0] + 1
                    functions.append({"name": name, "line": line})

            # Class definitions
            elif node.type in ["class_definition", "class_declaration"]:
                name_node = node.child_by_field_name("name")
                if name_node:
                    name = source[name_node.start_byte:name_node.end_byte].decode(errors="ignore")
                    line = name_node.start_point[0] + 1
                    classes.append({"name": name, "line": line})

            # Function calls
            elif node.type in ["call", "call_expression"]:
                func = node.child_by_field_name("function")
                if func and func.type == "identifier":
                    func_name = source[func.start_byte:func.end_byte].decode(errors="ignore")
                    calls.append(func_name)

            # Recurse
            for child in node.children:
                walk(child)

        walk(root)

        # Entry point detection
        has_main = any(
            "main" in f["name"].lower() or 
            f["name"] in ["main", "__main__", "start", "run", "init"]
            for f in functions
        )

        if not functions and not classes and not calls:
            print(f"Warning: No parse results for {file_path}")

        return {
            "file": file_path,
            "functions": functions,
            "classes": classes,
            "calls": calls,
            "entry_point": has_main
        }

    except Exception as e:
        print(f"Error parsing {file_path}: {e}")
        return {"error": str(e)}



