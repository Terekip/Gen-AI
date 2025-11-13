# Gen-AI

This repository contains two password generator implementations that create random passwords with uppercase letters, lowercase letters, digits, and symbols.

## Projects

- **Python Password Generator**: A Python script to generate random passwords. [View assign.py](assign.py)
- **Jaclang Password Generator**: A Jaclang script using the \`byllm\` library to generate random passwords. [View assign.jac](assign.jac)

## Requirements

### Python Password Generator (\`assign.py\`)
- **Python**: Version 3.6 or higher
- No external libraries required (uses standard library modules like \`random\`)

### Jaclang Password Generator (\`assign.jac\`)
- **Jaclang**: Latest version (install via \`pip install jaclang\`)
- **Byllm**: Install the \`byllm\` library (e.g., \`pip install byllm\`) and configure with a valid API key for the \`gemini/gemini-2.0-flash\` model
- **Python**: Version 3.12 or higher (required by Jaclang and \`byllm\`)

Ensure you have the necessary API credentials for \`byllm\` (e.g., for Gemini models) set up in your environment.

## Running the Code

### Python Password Generator (\`assign.py\`)
1. Ensure Python 3.6+ is installed.
2. Run the script:
   \`\`\`bash
   python assign.py
   \`\`\`
   This will output a random password (e.g., \`Kj#9mP$2vN&x\`).

### Jaclang Password Generator (\`assign.jac\`)
1. Set up a Python 3.12+ virtual environment and activate it:
   \`\`\`bash
   python3 -m venv jac_env
   source jac_env/bin/activate  # On Linux/macOS
   \`\`\`
2. Install dependencies:
   \`\`\`bash
   pip install jaclang byllm
   \`\`\`
3. Set up the API key for the \`gemini/gemini-2.0-flash\` model:
   - Obtain a free API key from [Google AI Studio](https://aistudio.google.com/app/apikey).
   - Export the key:
     \`\`\`bash
     export GOOGLE_API_KEY="your-gemini-api-key-here"
     \`\`\`

4. Run the script:
   \`\`\`bash
   jac run assign.jac
   \`\`\`
   This will output a random password.
5. If issues arise, check the [byLLM documentation](https://www.jac-lang.org/learn/jac-byllm/) for supported models and setup details.
   
# CodeGenius AI 
[View Assignment_2](Assignment_2)

**Instant, AI-powered documentation for any GitHub repo.**

**CodeGenius AI** is an intelligent documentation generator that analyzes any public GitHub repository and automatically creates a structured `documentation.md` file.  
It reads the README, scans source files, identifies functions, and builds a clear, human-readable summary of the codebase — all in one click.

---

---

## Features
- **Clones & analyzes** Python/Jac repos    
- **Smart file ranking** (LLM-powered)  
- **Call graph diagrams** (Mermaid)  
- **Download `.md` instantly**

---

## Quick Start

```bash
# 1. Clone
git clone https://github.com/Terekip/agentic_codebase_genius.git
cd agentic_codebase_genius

# 2. Setup
python -m venv jac_env
source jac_env/bin/activate
pip install -r requirements.txt
pip install jaclang

# 3. Set API key
export GEMINI_API_KEY="your-key"

# 4. Run
jac run backend.jac        # Terminal 1
streamlit run frontend.py  # Terminal 2

## Steps to generate documentation:
- Enter a GitHub repository URL
- Click "Generate Documentation"
- Wait for the spinner to complete each step
- Download the generated documentation.md file
 ## Output Example
Example of an output can be view here [View documentation.md](documentation.md)
