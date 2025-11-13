# streamlit_frontend.py
import streamlit as st
import requests
import time
import json

st.set_page_config(page_title="CodeGenius AI", page_icon="brain", layout="centered")

# --- minimal CSS + spinner ---
st.markdown("""
<style>
.centered { max-width: 950px; margin: 0 auto; }
.header-title { font-size: 2.6rem; font-weight: 900; text-align: center; }
.input-card { background: #fff; padding: 1.6rem; border-radius: 12px; box-shadow: 0 8px 20px rgba(0,0,0,.06); }
.file-item { background: #f8f9ff; padding: .6rem .8rem; border-radius: 8px; border-left: 4px solid #2575fc; margin: .35rem 0; font-family: 'JetBrains Mono'; font-size: .95rem; }
#MainMenu, footer { visibility: hidden; }
.spinner { display:inline-block; width:18px; height:18px; border:3px solid rgba(0,0,0,0.15); border-radius:50%; border-top-color:#2575fc; animation:spin 1s linear infinite; vertical-align:middle; margin-right:8px; }
@keyframes spin { to { transform: rotate(360deg);} }
</style>
""", unsafe_allow_html=True)

st.markdown("<div class='centered'>", unsafe_allow_html=True)
st.markdown("<h1 class='header-title'>CodeGenius AI</h1>", unsafe_allow_html=True)
st.markdown("<p style='text-align:center;color:#444'>AI reads GitHub repos and generates docs</p>", unsafe_allow_html=True)

# Input row
st.markdown("<div class='input-card'>", unsafe_allow_html=True)
c1, c2, c3 = st.columns([5,1,1])
with c1:
    url = st.text_input("GitHub Repo URL", placeholder="https://github.com/...", label_visibility="collapsed")
with c2:
    generate_btn = st.button("Generate Docs")
with c3:
    show_live = st.checkbox("Show analyzed files live", value=True)
st.markdown("</div>", unsafe_allow_html=True)

# Session defaults
for k, v in {
    "analyzed_files": [],
    "md_content": None,
    "last_updated": None,
    "in_progress": False,
    "total_files": 0,
    "current_file": 0,
    "_staged_analyzed": []
}.items():
    if k not in st.session_state:
        st.session_state[k] = v

# placeholders
status_ph = st.empty()
progress_ph = st.empty()
files_ph = st.empty()
download_ph = st.empty()

def safe_parse_line(line_bytes):
    # Try decode and parse JSON, otherwise attempt to find a JSON-like object in the line
    try:
        s = line_bytes.decode("utf-8").strip()
    except:
        return None
    if not s:
        return None
    # Some backends stream plain JSON objects per line, others print "report {...}"
    # Try direct json first
    try:
        return json.loads(s)
    except:
        # find first "{" and last "}" and try to parse substring
        if "{" in s and "}" in s:
            j = s[s.find("{"): s.rfind("}")+1]
            try:
                return json.loads(j)
            except:
                return None
    return None

if generate_btn and not st.session_state.in_progress:
    if not url or "github.com" not in url:
        st.error("Please enter a valid GitHub URL")
    else:
        st.session_state.in_progress = True
        st.session_state._staged_analyzed = []
        st.session_state.analyzed_files = []
        status_ph.markdown("<div><span class='spinner'></span>Starting...</div>", unsafe_allow_html=True)
        progress = progress_ph.progress(0.0)

        try:
            with requests.post(
                "http://localhost:8000/walker/code_genius",
                json={"url": url},
                stream=True,
                timeout=400
            ) as resp:
                resp.raise_for_status()

                total_expected = 0
                for raw_line in resp.iter_lines(chunk_size=1024):
                    if raw_line is None or len(raw_line) == 0:
                        continue
                    parsed = safe_parse_line(raw_line)
                    if not parsed:
                        # fallback: try to decode to text and show as status
                        try:
                            text = raw_line.decode("utf-8", errors="ignore").strip()
                            if text:
                                status_ph.text(text[:200])
                        except:
                            pass
                        continue

                    # The backend may wrap reports in a "reports" array or be a single report dict
                    reports = []
                    if isinstance(parsed, dict):
                        if "reports" in parsed and isinstance(parsed["reports"], list):
                            reports = parsed["reports"]
                        else:
                            # check if parsed is the report itself
                            reports = [parsed]
                    elif isinstance(parsed, list):
                        reports = parsed

                    for r in reports:
                        if not isinstance(r, dict):
                            continue
                        step = r.get("step", "")
                        message = r.get("message", "")
                        file = r.get("file", "")
                        current = r.get("current", 0)
                        total = r.get("total", 0)

                        # Update progress heuristics
                        if step == "cloning":
                            status_ph.markdown(f"<div><span class='spinner'></span>Cloning repository...</div>", unsafe_allow_html=True)
                            progress.progress(0.05)
                        elif step == "readme":
                            status_ph.markdown(f"<div><span class='spinner'></span>Reading README...</div>", unsafe_allow_html=True)
                            progress.progress(0.20)
                        elif step == "tree":
                            status_ph.markdown(f"<div><span class='spinner'></span>Building file tree...</div>", unsafe_allow_html=True)
                            progress.progress(0.35)
                        elif step == "ranking":
                            status_ph.markdown(f"<div><span class='spinner'></span>Ranking files...</div>", unsafe_allow_html=True)
                            progress.progress(0.5)
                        elif step == "analyzing" and file:
                            # Update analyzing status and progress
                            status_ph.markdown(f"<div><span class='spinner'></span>Analyzing <code>{file}</code> ({current}/{total})</div>", unsafe_allow_html=True)
                            if total and total > 0:
                                progress.progress(0.5 + (current/total)*0.35)
                            # Append to analyzed lists
                            if file not in st.session_state._staged_analyzed:
                                st.session_state._staged_analyzed.append(file)
                                # show live or stage for later
                                if show_live:
                                    st.session_state.analyzed_files = list(st.session_state._staged_analyzed)
                        elif step == "generating":
                            status_ph.markdown(f"<div><span class='spinner'></span>Generating documentation...</div>", unsafe_allow_html=True)
                            progress.progress(0.95)

                        # Success final report
                        if r.get("status") == "success":
                            # finalize analyzed files
                            st.session_state.analyzed_files = r.get("analyzed", st.session_state._staged_analyzed)
                            st.session_state.last_updated = time.strftime("%b %d, %Y at %I:%M %p")
                            progress.progress(1.0)
                            status_ph.success("Complete!")
                            # Attempt to download generated docs
                            try:
                                dl = requests.get("http://localhost:8000/walker/download_server", timeout=30)
                                # If the server returns plain markdown text (Content-Type text/markdown)
                                content_type = dl.headers.get("Content-Type", "")
                                if "text/markdown" in content_type or dl.text.strip().startswith("#") or dl.text.strip().startswith("---"):
                                    st.session_state.md_content = dl.text
                                else:
                                    # try parse json bodies
                                    j = None
                                    try:
                                        j = dl.json()
                                    except:
                                        j = None
                                    # server might return {"reports": [{"body": "..." }]}
                                    if isinstance(j, dict) and "reports" in j and isinstance(j["reports"], list):
                                        first = j["reports"][0]
                                        if isinstance(first, dict) and "body" in first:
                                            st.session_state.md_content = first["body"]
                                    # fallback to text
                                    if not st.session_state.md_content:
                                        st.session_state.md_content = dl.text
                            except Exception as e:
                                st.error(f"Could not fetch docs: {e}")
                            finally:
                                st.session_state.in_progress = False

                # end streaming loop

        except Exception as e:
            st.session_state.in_progress = False
            status_ph.error(f"Failed: {e}")
        finally:
            # ensure UI updated
            if not show_live:
                st.session_state.analyzed_files = list(st.session_state._staged_analyzed)
            time.sleep(0.8)
            progress_ph.empty()

# show analyzed files (if any)
if st.session_state.analyzed_files:
    files_ph.markdown("### Analyzed Files")
    for f in st.session_state.analyzed_files:
        files_ph.markdown(f"<div class='file-item'>`{f}`</div>", unsafe_allow_html=True)
else:
    files_ph.info("No files analyzed yet.")

# show download card when docs present
if st.session_state.md_content:
    with download_ph.container():
        st.markdown("### Documentation ready")
        st.download_button(
            "Download documentation.md",
            st.session_state.md_content,
            "documentation.md",
            "text/markdown",
            use_container_width=True
        )
        st.caption(f"Last updated: {st.session_state.last_updated}")

st.markdown("</div>", unsafe_allow_html=True)
