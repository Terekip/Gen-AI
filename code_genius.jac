import from byllm.llm { Model }
import from git { Repo }
import from pathlib { Path }
import shutil;
import tempfile;
import json;
import from utils { parse_file }
import from file_tree { build_tree }
import from time { sleep }


glob llm = Model(model_name="gemini/gemini-2.0-flash", verbose=False);

# ==============================
# NODES
# ==============================

node repo_mapper {
    has utterance: str;
    has temp_dir: str = '';
    has files: list = [];

def clone_repo(utterance: str) -> dict { 
    self.temp_dir = tempfile.mkdtemp(prefix='repo'); 
    try {
         Repo.clone_from(utterance, self.temp_dir); 
        print("Cloning successful!");
    self.files = [ 
        str(p.relative_to(self.temp_dir)) 
        for p in Path(self.temp_dir).rglob('*') 
        if p.is_file() 
    ]; 

    return {'files': self.files, 
    'temp_dir': self.temp_dir};
 
    } except Exception as e {
 
         return {'files': [], 'temp_dir': ''}; 
}; 
}

"""You are **RepoScout**, an expert GitHub summarizer.

1. Use the `clone_repo(url)` tool to clone the repository.
2. Find the **README.md** (or setup, requirements, or main.py) in the repo.
3. From the README provide a detailed summary of every section
in point form. You must include TITLE
You have to read through it before summarizing and NEVER use the
term seems.

**Return only the few bullets.**
"""
    def readme_summarizer() -> str by llm(
        method = "ReAct",
        tools = (self.clone_repo,),

    );

    def file_tree_generator() -> str {
        if self.temp_dir == '' {
            return "No repo cloned";
        };
        tree = build_tree(self.temp_dir);
        print(json.dumps(tree, indent=2));
        print("File tree generated successfully");
        return json.dumps(tree, indent=2);
    }
}

node code_analyzer {
    has file_path: str;
    has temp_dir: str;
    has files: list = [];

def parse_code() -> dict {
    full_path = Path(self.temp_dir) / self.file_path;
    print("  → [PARSER] Opening: ", str(full_path));

    result = {
        "file": self.file_path,
        "functions": [],
        "classes": [],
        "calls": [],
        "entry_point": False,
        "error": None
    };

    if not full_path.exists() {
        result["error"] = "File not found";
        print("  → [PARSER] FILE NOT FOUND");
        return result;
    }

    try {
        parsed = parse_file(str(full_path));
        print("  → [PARSER] parse_file() returned data");

        result["functions"] = parsed.get("functions", []);
        result["calls"] = parsed.get("calls", []);
        result["classes"] = parsed.get("classes", []);
        result["entry_point"] = parsed.get("entry_point", False);

        print(f"  → PARSED OK: {len(result['functions'])} functions");
        return result;

    } except Exception as e {
        result["error"] = str(e);
        print("  → [PARSER] FAILED: ", str(e));
        return result;
    }
}

def construct_code_context_graph(parsed: dict) -> dict[str, list[dict[str, str | int]]] by llm(
    method = "ReAct",
    tools = (),
    prompt = """
    Extract functions, classes, calls, and entry points.

    Return JSON:
    {
      "nodes": [{"id": "file.py:func", "name": "func", "file": "file.py", "line": 1, "type": "function"}],
      "edges": [{"from": "A", "to": "B", "type": "calls"}],
      "entry_points": ["main.py::run"]
    }

    CODE:
    {parsed}
    """
);
}

node ranker {
    def score_and_rank(files: list, readme: str) -> list[str] by llm(
        method = "ReAct",
        tools = (),
        prompt = """Given a list of repository files and a README summary, identify which files are most important
to the project's functionality.Only rank files that end with .py, .js, .ts, .java, .go, .rb, .cpp, .c, .cs, .php, .rs, .swift, .kt, .m, .scala, .sh, .html, .css.,.jac
And ignore the rest.

Do not give reasons or explanations. juat order the files by importance.
Return ONLY a valid JSON list of filenames, sorted by importance.
If unsure, return at least the main source files (e.g., main.py, app.py, index.js).
Never return text like 'The repository has been cloned' or explanations.

Example output:
["README.md", "main.py", "app.py", "utils.py"]

Files:
{files}

README summary:
{readme}
"""
    );
}

node docgenie {
    has ccg: dict;
    has tree: str;
    has summary: str;
    has priority: list;

    """
You are **DocGenie**, an expert AI technical writer that transforms code analysis data into clear, structured Markdown documentation.
You must use the provided `ccg`, `tree`, `summary`, and `priority` to generate a comprehensive documentation.
If ccg or tree is empty let me know
### Your Input
You will receive structured data containing:
- Repository name
- File list with their parsed content:
  - functions (with names and line numbers)
  - classes (with names and docstrings if available)
  - function calls
  - entry points (main functions or scripts)
- Summaries of README or main purpose if provided

### Your Goal
Write professional, human-readable documentation in **Markdown format** with the following sections:
 Example:
 README summary is found in 'summary', tree is found in 'tree'and ccg is in 'ccg'
```markdown
1. You MUST include title of repo from README
2. **Project Overview**
   - Describe what the repository does (based on README summary or code hints)
   - Mention technologies or frameworks detected

3. **Architecture Overview**
   - Give a simple diagram-like structure USING tree)
   - Summarize how main modules relate (e.g., *extract.py → transform.py → visualize.py*)
   - After giving the tree you must also give a summary of it, use README if necessary

4. **Key Modules and Functions**
     Use README to get functions of classes and function and add brief details
   For each analyzed file:
   - **File:** `<filename>`
   - List all classes and their purpose
   - List functions with a one-line summary each
   - If a function appears to be the entry point, mark it with **(entry point)**
 

4. **Data Flow or Call Graph (if available)**
From self.ccg, draw a code context graph, use mermaid graph
- Describe how modules interact, e.g.:
  `extract.py` → `pivot_data.py` → `time_series_analysis.py`

5. **Usage Instructions**
- If README summary provides run/install commands, include them
- Otherwise, suggest how to run the main script

6. **License & Author Info**
- If not found, DO NOTadd the section

### Style Guide
- Use clean Markdown formatting (`#`, `##`, `###`, `-`, `>`, code blocks)
- Keep explanations short (max 2–3 lines per function)
- Never invent code — only describe what exists and NEVER use the term seems
- End with:  
`_Generated automatically by CodeGenius AI_`

Now, generate the full documentation.
"""
    def generate_docs() -> str by llm(
        method = "ReAct",
        tools = (),
    );
}
# ==============================
# WALKER
# ==============================

walker code_genius {
    has url: str = "";
    has analyzed: list = [];
    has file_tree: str = "";
    has readme_summary: str = "";
    has temp_dir: str = "";
    has all_files: list = [];
    has tree: str = "";
    has summary: str = "";
    has parsed: dict = {};
    has priority: dict = {};
    has parsed_graph: dict[str, str] = {};
    has parsed_files: list = [];
    has ccg: dict = {
    "nodes": [],
    "edges": [],
    "entry_points": []
        };





    edge repo_mapper;
    edge code_analyzer;
    edge docgenie;
    edge ranker;

    obj __specs__ {
        static has auth: bool = False;
    
    }

    can start with entry {
        print(f"CodeGenius starting → {self.url}");
        
        report {"status": "progress", "step": "cloning", "message": "Cloning repository..."};

        # --- 1. Clone repository ---
        mapper = (here ++> repo_mapper(utterance=self.url))[0];
        clone = mapper.clone_repo(utterance=self.url);
        self.temp_dir = clone["temp_dir"];
        self.all_files = clone["files"];
        
         print("CLONE RESULT: ", clone);
         print("self.temp_dir = ", self.temp_dir);
         print("self.all_files = ", self.all_files[:10]);
         print(f"Cloned repository: {len(self.all_files)} files found");

        if len(self.all_files) == 0 {
            
            return;
        };
        sleep(3);
        

        # --- 2. Summaries (README + file tree) ---
        report {"status": "progress", "step": "readme", "message": "Reading README..."};
        self.readme_summary = mapper.readme_summarizer();

        print("README Summary → " + self.readme_summary);

        sleep(2);

        report {"status": "progress", "step": "tree", "message": "Building file tree..."};
        self.file_tree = mapper.file_tree_generator();
        sleep(1);
        print("File tree generated successfully");

                # --- 3. Rank files ---
        report {"status": "progress", "step": "ranking", "message": "Ranking files..."};
        print("Ranking files...");
        ranker_node = (here ++> ranker())[0];
        ranked = ranker_node.score_and_rank(
            files=self.all_files,
            readme=self.readme_summary
        );
        sleep(5);


        self.top_files = [];

        # --- CASE 1: DICT → EXTRACT + SORT ---
        if self.priority is dict {
            for key in self.priority.keys() {
                self.top_files.append(key);
            }

            # Bubble sort by priority score
            n = self.top_files.length();
            for i in 0..n-1 {
                for j in 0..n-i-2 {
                    if self.priority[self.top_files[j]] > self.priority[self.top_files[j+1]] {
                        temp = self.top_files[j];
                        self.top_files[j] = self.top_files[j+1];
                        self.top_files[j+1] = temp;
                    }
                }
            }
        }
        else {
            # --- CASE 2: LIST 
            if self.priority is list {
                self.top_files = self.priority;
            }
            #--- CASE 3: FALLBACK ---
            else {
                self.top_files = [];
            }
        }
        # Initialize priority list
        priority_list = [];

        # Case 1: LLM returns a dict like {"file.py": {"score": 0.8, "rank": 2}}
        if ranked and type(ranked) == dict {
            scored_files = [];
            for file_name in ranked.keys() {
                scored_files.append({
                    "file": file_name,
                    "score": ranked[file_name]["score"] if type(ranked[file_name]) == dict else ranked[file_name]
                });
            }

            # Sort by score (descending)
            sorted_files = [];
            for entry in scored_files {
                inserted = False;
                for i in range(len(sorted_files)) {
                    if entry["score"] > sorted_files[i]["score"] {
                        sorted_files.insert(i, entry);
                        inserted = True;
                        break;
                    }
                }
                if not inserted {
                    sorted_files.append(entry);
                }
            }

            for item in sorted_files {
                priority_list.append(item["file"]);
            }

        # Case 2: LLM returns a list 
        } elif ranked and type(ranked) == list {
            priority_list = ranked;

        # Case 3: Fallback
        } else {
            priority_list = self.all_files;
        }

        # ──────────────────────────────────────────────────────────────────────
        # FILTER: Remove .git/ and non-source files
        # ──────────────────────────────────────────────────────────────────────
        priority_list = [
            f for f in priority_list
            if f.endswith((".py", ".js", ".ts", ".md", ".txt", ".json", ".yaml", ".yml"))
               and not f.startswith(".git/")
        ];

        # Fallback: if filter removed everything, use clean version of all_files
        if len(priority_list) == 0 {
            priority_list = [
                f for f in self.all_files
                if f.endswith((".py", ".js", ".ts", ".md", ".txt", ".json", ".yaml", ".yml"))
                   and not f.startswith(".git/")
            ];
        }
        # ──────────────────────────────────────────────────────────────────────

        # --- Store priority map ---
        self.priority = {priority_list[i]: i for i in range(len(priority_list))};

        print(f"Ranking complete — total ranked files: {len(priority_list)}");
        print(f"Top 5: {priority_list[:5]}");


        # --------------------------------------------------------------
        # 5. BUILD VALIDATED top_files 
        # --------------------------------------------------------------
        valid_py_files = [];
        for f in self.all_files {
            if f.endswith(".py") and (Path(self.temp_dir) / f).exists() {
                valid_py_files.append(f);
            }
        }

        top_files = [];
        for f in priority_list {
            if f in valid_py_files and f not in top_files {
                top_files.append(f);
            }
        }

        # Fallback: add any missing .py files
        for f in valid_py_files {
            if f not in top_files {
                top_files.append(f);
            }
        }

        top_files = top_files[:8];
        print("VALIDATED top_files = ", top_files);

        # Reset counters
        self.analyzed = [];
        current_count = 0;

        print("Starting code analysis for top ", len(top_files), " Python files...");

        # --------------------------------------------------------------
        # 6. MAIN LOOP 
        # --------------------------------------------------------------
        for file_path in top_files {
            file_path = str(file_path).strip();
            print("\n--- ANALYSING: ", file_path, " ---");
           

            if file_path in self.analyzed {
                print("  → Already analysed – skipping");
                continue;
            }

           
            self.analyzed.append(file_path);
            current_count += 1;

            report {"status": "progress", "step": "analyzing", "file": file_path, "current": current_count, "total": len(top_files), "message": "Analyzing {file_path}..."};

            # --------------------------------------------------------------
            # 7. CALL THE ANALYZER
            # --------------------------------------------------------------
            print("  → Spawning code_analyzer for ", file_path);
            analyzer = (here ++> code_analyzer(file_path=file_path, temp_dir=self.temp_dir))[0];
            parsed_data = analyzer.parse_code();

            # --------------------------------------------------------------
            # 8. ERROR HANDLING 
            # --------------------------------------------------------------
            if not parsed_data {
                print("  → parse_code() returned None");
                self.analyzed.remove(file_path);
                current_count -= 1;
                continue;
            }

        # Only show error if "error" key exists AND is not null
        if type(parsed_data) == dict and parsed_data.get("error") {
            print("  → PARSE ERROR: ", parsed_data["error"]);
            self.analyzed.remove(file_path);
            current_count -= 1;
           continue;
        }
        sleep(2);

        print("  → PARSED OK – ", len(parsed_data.get("functions", [])), " function(s) found");
           
            # --------------------------------------------------------------
            # 9. Build local CCG 
            # --------------------------------------------------------------
            file_id = file_path.replace("/", "_").replace(".", "_");
            local_ccg = { "nodes": [], "edges": [], "entry_points": [] };

            for fn in parsed_data.get("functions", []) {
                name = "unknown"; line = 0;
                if type(fn) == dict {
                    name = fn.get("name", "unknown");
                    line = fn.get("line", 0);
                } else {
                    name = str(fn);
                }
                node_id = file_id + ":" + name;
                local_ccg["nodes"].append({
                    "id": node_id,
                    "name": name,
                    "file": file_path,
                    "line": line,
                    "type": "function"
                });
            }

            entry_node_id = None;
            if len(local_ccg["nodes"]) > 0 {
                entry_name = local_ccg["nodes"][0]["name"];
                entry_node_id = file_id + ":" + entry_name;
                local_ccg["entry_points"].append(file_path + "::" + entry_name);
            }

            if entry_node_id {
                for call in parsed_data.get("calls", []) {
                    callee = "";
                    if type(call) == dict {
                        callee = call.get("name", "");
                    } else {
                        callee = str(call);
                    }
                    if callee == "" { continue; }

                    target_id = None;
                    for n in local_ccg["nodes"] {
                        if n["name"] == callee {
                            target_id = n["id"];
                            break;
                        }
                    }
                    if target_id == None {
                        for n in self.ccg["nodes"] {
                            if n["name"] == callee {
                                target_id = n["id"];
                                break;
                            }
                        }
                    }
                    if target_id == None {
                        target_id = "external:" + callee;
                        if not any([n["id"] == target_id for n in self.ccg["nodes"]]) {
                            self.ccg["nodes"].append({
                                "id": target_id,
                                "name": callee,
                                "file": "external",
                                "line": 0,
                                "type": "external"
                            });
                        }
                    }
                    local_ccg["edges"].append({
                        "from": entry_node_id,
                        "to": target_id,
                        "type": "calls"
                    });
                }
            }

            # --------------------------------------------------------------
            # 10. Merge into global CCG
            # --------------------------------------------------------------
            self.ccg["nodes"] += local_ccg["nodes"];
            self.ccg["edges"] += local_ccg["edges"];
            self.ccg["entry_points"] += local_ccg["entry_points"];

            unique_eps = [];
            for ep in self.ccg["entry_points"] {
                if ep not in unique_eps { unique_eps.append(ep); }
            }
            self.ccg["entry_points"] = unique_eps;

            # --------------------------------------------------------------
            # 11. Progress report 
            # --------------------------------------------------------------

            print("  → REPORT SENT: ", current_count, "/", len(top_files));
            sleep(1);


        print(f"Total CCG size: {len(self.ccg['nodes'])} nodes, {len(self.ccg['edges'])} edges");

         
        # --- Sanitize priority for LLM ---
        sanitized_priority = {};
        for file in self.top_files {
            clean_key = file.replace(".", "_").replace("/", "_");
            sanitized_priority[clean_key] = file;
        }

        # --- Debug before doc generation ---
        print("CCGs: ", len(self.ccg["nodes"]), " nodes, ", len(self.ccg["edges"]), " edges");
        print("Priority: ", sanitized_priority);

        }
        sleep(3);

        report {"status": "progress", "step": "generating", "message": "Generating documentation..."};

        doc_node = (here ++> docgenie(
            ccg=self.ccg,
            tree=self.file_tree,
            summary=self.readme_summary,
            priority=self.top_files,
        ))[0];

        final_doc = doc_node.generate_docs();
        print("Documentation process");

        # --- Save documentation ---
        Path("outputs").mkdir(exist_ok=True);
        Path("outputs/documentation.md").write_text(final_doc);

        print("Documentation saved at outputs/documentation.md");


        #--- Display top file ---
        top_file = "none";
        if len(self.top_files) > 0 {
            top_file = self.top_files[0];
        }
        print("Top file: ", top_file);
                
                if self.temp_dir {
                    shutil.rmtree(self.temp_dir, ignore_errors=True);
                };

                report {
                    "status": "success",
                    "download": "/download/documentation.md",
                    "files_analyzed": len(self.analyzed),
                    "analyzed": [f for f in self.analyzed],
                };
            

        }


}


walker download_server {
    obj __specs__ {
        static has auth: bool = False;
        static has methods: list = ["get"];
    }

    can start with entry {
        file_path = "outputs/documentation.md";
        file = Path(file_path);

        if file.exists() {
            content = file.read_text(encoding="utf-8");

            # Explicitly return HTTP response
            report {
                "status_code": 200,
                "headers": {"Content-Type": "text/markdown"},
                "body": content
            };
        } else {
            report {
                "status_code": 404,
                "headers": {"Content-Type": "text/plain"},
                "body": "Error: documentation.md not found."
            };
        }
    }
}