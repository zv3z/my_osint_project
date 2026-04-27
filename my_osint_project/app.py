"""Titan OSINT — Cyberpunk Cyber Intelligence Platform"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))

import json, time, datetime
import streamlit as st
import streamlit.components.v1 as components
import plotly.graph_objects as go
import pandas as pd

from titan.config       import CONF, AI_AVAILABLE, ACTIVE_ENGINES
from titan.classifier   import classify, TYPE_COLORS
from titan.lang         import T
from titan.db           import (save_scan, get_history, get_cached, set_cache,
                                add_bookmark, get_bookmarks, delete_bookmark,
                                add_note, get_notes, stats)
from titan.engines      import run_all, ENGINE_CATEGORIES
from titan.scoring      import compute_score
from titan.ioc          import extract as extract_iocs, to_csv as iocs_to_csv
from titan.ai_engine    import analyze as ai_analyze, chat as ai_chat, extract_mitre

# ─────────────────────────────────────────────────────────────────────────────
# PAGE CONFIG
# ─────────────────────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="Titan OSINT",
    page_icon="⚡",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ─────────────────────────────────────────────────────────────────────────────
# SESSION STATE DEFAULTS
# ─────────────────────────────────────────────────────────────────────────────
_defaults = {
    "lang":         "ar",
    "results":      None,
    "target":       "",
    "ttype":        "",
    "score":        None,
    "ioc_data":     None,
    "ai_analysis":  "",
    "chat_history": [],
    "scan_ts":      None,
}
for k, v in _defaults.items():
    if k not in st.session_state:
        st.session_state[k] = v

def lang():  return st.session_state.lang
def is_ar(): return lang() == "ar"

# ─────────────────────────────────────────────────────────────────────────────
# CYBERPUNK CSS + ANIMATIONS
# ─────────────────────────────────────────────────────────────────────────────
st.markdown("""
<style>
@import url('https://fonts.googleapis.com/css2?family=Share+Tech+Mono&family=Orbitron:wght@400;700;900&family=Rajdhani:wght@300;400;600;700&display=swap');

*, *::before, *::after { box-sizing: border-box; }

html, body, [data-testid="stAppViewContainer"], [data-testid="stApp"] {
    background: #050508 !important;
    color: #c8d8e8 !important;
    font-family: 'Rajdhani', 'Share Tech Mono', monospace !important;
}

/* Scanline overlay */
[data-testid="stAppViewContainer"]::before {
    content: "";
    position: fixed; top: 0; left: 0; right: 0; bottom: 0;
    background: repeating-linear-gradient(
        0deg, transparent, transparent 2px,
        rgba(0,230,160,0.018) 2px, rgba(0,230,160,0.018) 4px
    );
    pointer-events: none; z-index: 9999;
    animation: scanMove 8s linear infinite;
}
@keyframes scanMove { 0%{background-position:0 0;} 100%{background-position:0 100vh;} }

/* Sidebar */
[data-testid="stSidebar"] {
    background: linear-gradient(180deg,#07090f 0%,#060810 100%) !important;
    border-right: 1px solid #00e5b430 !important;
}
[data-testid="stSidebar"] * { color: #a0c0d0 !important; }

[data-testid="stMainBlockContainer"] { padding-top: 0.5rem !important; }
section[data-testid="stMain"] { background: transparent !important; }

/* Metrics */
[data-testid="stMetric"] {
    background: linear-gradient(135deg,#0a1520 0%,#060d18 100%) !important;
    border: 1px solid #00e5b440 !important;
    border-radius: 8px !important;
    padding: 14px 16px !important;
}
[data-testid="stMetricValue"] {
    color: #00e5b4 !important;
    font-family: 'Orbitron', monospace !important;
    font-size: 1.6rem !important;
}
[data-testid="stMetricLabel"] { color: #6090a0 !important; font-size: 0.75rem !important; }

/* Tabs */
[data-testid="stTabs"] > div:first-child { border-bottom: 1px solid #00e5b430 !important; gap: 4px; }
button[data-baseweb="tab"] {
    background: #080f1a !important;
    border: 1px solid #00e5b425 !important;
    border-radius: 6px 6px 0 0 !important;
    color: #6090a0 !important;
    font-family: 'Rajdhani', monospace !important;
    font-weight: 600 !important; font-size: 0.8rem !important;
    letter-spacing: 0.06em !important; padding: 6px 14px !important;
    transition: all 0.2s ease !important;
}
button[data-baseweb="tab"]:hover { color: #00e5b4 !important; border-color: #00e5b460 !important; }
button[aria-selected="true"][data-baseweb="tab"] {
    background: linear-gradient(180deg,#0d2030 0%,#081520 100%) !important;
    border-color: #00e5b4 !important; color: #00e5b4 !important;
    box-shadow: 0 0 12px #00e5b430 !important;
}

/* Inputs */
.stTextInput input, .stTextArea textarea {
    background: #080f1a !important;
    border: 1px solid #00e5b440 !important;
    border-radius: 6px !important;
    color: #c8d8e8 !important;
    font-family: 'Share Tech Mono', monospace !important;
    font-size: 0.9rem !important;
}
.stTextInput input:focus, .stTextArea textarea:focus {
    border-color: #00e5b4 !important;
    box-shadow: 0 0 0 2px #00e5b420 !important;
}

/* Buttons */
.stButton > button {
    background: linear-gradient(135deg,#003d30 0%,#001e18 100%) !important;
    border: 1px solid #00e5b4 !important; border-radius: 6px !important;
    color: #00e5b4 !important; font-family: 'Orbitron', monospace !important;
    font-size: 0.72rem !important; font-weight: 700 !important;
    letter-spacing: 0.12em !important; padding: 8px 20px !important;
    transition: all 0.2s ease !important; cursor: pointer !important;
}
.stButton > button:hover {
    background: linear-gradient(135deg,#00e5b4 0%,#00b48c 100%) !important;
    color: #000 !important;
    box-shadow: 0 0 20px #00e5b460,0 0 40px #00e5b420 !important;
    transform: translateY(-1px) !important;
}

/* Progress */
.stProgress > div > div > div {
    background: linear-gradient(90deg,#00e5b4,#0080ff) !important;
    border-radius: 4px !important; box-shadow: 0 0 8px #00e5b460 !important;
}

/* Expander */
details { border: 1px solid #00e5b420 !important; border-radius: 6px !important; margin-bottom: 6px !important; }
summary { padding: 8px 12px !important; color: #00e5b4 !important; font-family: 'Rajdhani', monospace !important; font-weight: 600 !important; }

/* Scrollbar */
::-webkit-scrollbar { width: 5px; height: 5px; }
::-webkit-scrollbar-track { background: #07090f; }
::-webkit-scrollbar-thumb { background: #00e5b440; border-radius: 3px; }
::-webkit-scrollbar-thumb:hover { background: #00e5b4; }

/* Cards */
.titan-card {
    background: linear-gradient(135deg,#0a1520 0%,#060d18 100%);
    border: 1px solid #00e5b430; border-radius: 10px;
    padding: 18px 20px; margin-bottom: 14px;
    position: relative; overflow: hidden;
}
.titan-card::before {
    content: ""; position: absolute; top: 0; left: 0; right: 0; height: 2px;
    background: linear-gradient(90deg,transparent,#00e5b4,transparent);
}
.titan-card h3 {
    color: #00e5b4; font-family: 'Orbitron', monospace;
    font-size: 0.8rem; font-weight: 700; letter-spacing: 0.14em;
    margin: 0 0 12px 0; text-transform: uppercase;
}

/* Score */
.score-ring { display:flex; flex-direction:column; align-items:center; justify-content:center; padding:20px; }
.score-value { font-family:'Orbitron',monospace; font-size:4rem; font-weight:900; line-height:1; text-shadow:0 0 30px currentColor; }
.score-label { font-family:'Orbitron',monospace; font-size:1rem; font-weight:700; letter-spacing:.2em; margin-top:6px; text-shadow:0 0 15px currentColor; }

/* Type badge */
.type-badge { display:inline-block; padding:3px 10px; border-radius:4px;
    font-family:'Share Tech Mono',monospace; font-size:.75rem; font-weight:700;
    letter-spacing:.1em; border:1px solid currentColor; }

/* Signal rows */
.signal-row { display:flex; align-items:center; gap:10px; padding:8px 14px;
    border-radius:6px; margin-bottom:6px; background:#0a1520; border-left:3px solid; }

/* Chat */
.chat-msg-user {
    background:#0d2030; border:1px solid #00e5b440; border-radius:10px 10px 0 10px;
    padding:10px 14px; margin:6px 0; color:#c8d8e8;
    font-family:'Rajdhani',monospace; font-size:.95rem; text-align:right;
}
.chat-msg-ai {
    background:#060d18; border:1px solid #0080ff30; border-radius:10px 10px 10px 0;
    padding:10px 14px; margin:6px 0; color:#c8d8e8;
    font-family:'Rajdhani',monospace; font-size:.95rem;
}

hr { border-color: #00e5b415 !important; }
.stCheckbox label span, .stRadio label span { color: #a0c0d0 !important; }
#MainMenu, footer, header[data-testid="stHeader"] { display: none !important; }
</style>
""", unsafe_allow_html=True)

# ─────────────────────────────────────────────────────────────────────────────
# MATRIX RAIN HEADER
# ─────────────────────────────────────────────────────────────────────────────
components.html("""
<style>
#mw{position:relative;width:100%;height:90px;overflow:hidden;background:#050508;border-bottom:1px solid #00e5b430;}
#mc{position:absolute;top:0;left:0;width:100%;height:100%;opacity:.18;}
#hc{position:absolute;top:0;left:0;right:0;bottom:0;display:flex;align-items:center;justify-content:space-between;padding:0 28px;}
.ht{font-family:Orbitron,monospace;font-size:1.7rem;font-weight:900;color:#00e5b4;letter-spacing:.18em;text-shadow:0 0 20px #00e5b4,0 0 40px #00e5b460;}
.hs{font-family:Share Tech Mono,monospace;font-size:.7rem;color:#607080;letter-spacing:.12em;margin-top:4px;}
.hr{text-align:right;}
.hst{font-family:Share Tech Mono,monospace;font-size:.65rem;color:#00e5b490;letter-spacing:.1em;}
.hp{display:inline-block;width:6px;height:6px;border-radius:50%;background:#00e5b4;margin-right:6px;animation:pulse 1.5s ease-in-out infinite;}
@keyframes pulse{0%,100%{opacity:1;box-shadow:0 0 6px #00e5b4;}50%{opacity:.3;box-shadow:none;}}
</style>
<div id="mw">
  <canvas id="mc"></canvas>
  <div id="hc">
    <div>
      <div class="ht">&#9889; TITAN OSINT</div>
      <div class="hs">CYBER INTELLIGENCE PLATFORM &nbsp;|&nbsp; 33+ ENGINES &nbsp;|&nbsp; AI FUSION</div>
    </div>
    <div class="hr">
      <div class="hst"><span class="hp"></span>SYSTEMS ONLINE</div>
      <div class="hst" style="margin-top:4px;">TitanAI &bull; Gemini 1.5 Flash</div>
    </div>
  </div>
</div>
<script>
const c=document.getElementById('mc'),x=c.getContext('2d');
function rsz(){c.width=c.offsetWidth;c.height=c.offsetHeight;}rsz();
const ch='ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%&*<>/|';
const fs=11;let cols=Math.floor(c.width/fs);let dr=Array(cols).fill(1);
function draw(){
  x.fillStyle='rgba(5,5,8,.15)';x.fillRect(0,0,c.width,c.height);
  x.fillStyle='#00e5b4';x.font=fs+'px monospace';
  for(let i=0;i<dr.length;i++){
    x.fillText(ch[Math.floor(Math.random()*ch.length)],i*fs,dr[i]*fs);
    if(dr[i]*fs>c.height&&Math.random()>.975)dr[i]=0;dr[i]++;
  }
}
setInterval(draw,45);
window.addEventListener('resize',()=>{rsz();cols=Math.floor(c.width/fs);dr=Array(cols).fill(1);});
</script>
""", height=95)

# ─────────────────────────────────────────────────────────────────────────────
# SIDEBAR
# ─────────────────────────────────────────────────────────────────────────────
with st.sidebar:
    col_logo, col_lang = st.columns([2, 1])
    with col_logo:
        st.markdown('<span style="font-family:Orbitron,monospace;color:#00e5b4;font-weight:900;font-size:1rem;letter-spacing:.15em;">⚡ TITAN</span>', unsafe_allow_html=True)
    with col_lang:
        if st.button(T("lang_btn"), key="lang_toggle", use_container_width=True):
            st.session_state.lang = "en" if is_ar() else "ar"
            st.rerun()

    st.markdown('<hr style="border-color:#00e5b420;margin:8px 0;">', unsafe_allow_html=True)

    # Scan section
    st.markdown(f'<div style="font-family:Orbitron,monospace;font-size:.7rem;color:#00e5b4;letter-spacing:.15em;margin-bottom:8px;">{T("scan_section")}</div>', unsafe_allow_html=True)

    scan_mode = st.radio("Scan Mode", [T("mode_single"), T("mode_bulk")], horizontal=True, label_visibility="collapsed")
    bulk_mode = (scan_mode == T("mode_bulk"))

    if bulk_mode:
        raw_bulk     = st.text_area(T("bulk_ph"), height=100, label_visibility="collapsed", placeholder=T("bulk_ph"))
        targets_list = [x.strip() for x in raw_bulk.splitlines() if x.strip()]
        single_target = ""
    else:
        single_target = st.text_input("Target", placeholder=T("target_ph"), label_visibility="collapsed", key="target_input")
        targets_list  = []

    use_cache = st.checkbox(T("cache_chk"), value=True)
    run_btn   = st.button(T("scan_btn"), use_container_width=True, type="primary")

    st.markdown('<hr style="border-color:#00e5b420;margin:8px 0;">', unsafe_allow_html=True)

    # Status
    st.markdown(f'<div style="font-family:Orbitron,monospace;font-size:.7rem;color:#00e5b4;letter-spacing:.15em;margin-bottom:8px;">{T("status_section")}</div>', unsafe_allow_html=True)
    c1, c2 = st.columns(2)
    c1.metric(T("apis_configured"), ACTIVE_ENGINES)
    c2.metric(T("ai_engine"), "Gemini" if CONF["GEMINI_KEY"] else ("OpenAI" if CONF["OPENAI_KEY"] else "OFF"))

    st.markdown('<hr style="border-color:#00e5b420;margin:8px 0;">', unsafe_allow_html=True)

    # Engines list — always visible
    st.markdown(f'<div style="font-family:Orbitron,monospace;font-size:.7rem;color:#00e5b4;letter-spacing:.15em;margin-bottom:8px;">{T("engines_section")}</div>', unsafe_allow_html=True)

    CAT_COLORS = {"THREAT":"#ff4444","NETWORK":"#4488ff","REPUTATION":"#ffaa00","IDENTITY":"#cc88ff","DEVELOPER":"#00cc88"}
    CAT_ICONS  = {"THREAT":"🔴","NETWORK":"🔵","REPUTATION":"🟡","IDENTITY":"🟣","DEVELOPER":"🟢"}

    for cat, engines in ENGINE_CATEGORIES.items():
        col  = CAT_COLORS.get(cat, "#888")
        icon = CAT_ICONS.get(cat, "⚪")
        with st.expander(f"{icon} {cat} ({len(engines)})", expanded=False):
            for eng in engines:
                # Heuristic key detection
                eng_key = eng.upper().replace(" ","_").replace(".","").replace("-","_")
                has_key = any(
                    CONF.get(k) for k in CONF
                    if any(part in k for part in [eng_key[:5], eng_key.split("_")[0]])
                )
                dot_col = col if has_key else "#334455"
                st.markdown(
                    f'<div style="padding:3px 0;font-size:.78rem;font-family:Share Tech Mono,monospace;">'
                    f'<span style="color:{dot_col};text-shadow:0 0 6px {dot_col};">●</span> {eng}</div>',
                    unsafe_allow_html=True
                )

    st.markdown('<hr style="border-color:#00e5b420;margin:8px 0;">', unsafe_allow_html=True)

    # History
    st.markdown(f'<div style="font-family:Orbitron,monospace;font-size:.7rem;color:#00e5b4;letter-spacing:.15em;margin-bottom:8px;">{T("history_section")}</div>', unsafe_allow_html=True)
    history = get_history(limit=8)
    if history:
        for row in history:
            ts  = (row[1] or "")[:16]
            tgt = (row[2] or "")[:22]
            typ = row[3] or ""
            if st.button(f"● {tgt}  [{typ}]", key=f"h_{row[0]}", use_container_width=True):
                cached = get_cached(tgt)
                if cached:
                    st.session_state.results  = json.loads(cached[2])
                    st.session_state.target   = tgt
                    st.session_state.ttype    = typ
                    st.session_state.score    = compute_score(st.session_state.results)
                    st.session_state.ioc_data = extract_iocs(st.session_state.results, tgt)
                    st.rerun()
    else:
        st.caption(T("no_history"))

    st.markdown('<hr style="border-color:#00e5b420;margin:8px 0;">', unsafe_allow_html=True)

    # Bookmarks
    st.markdown(f'<div style="font-family:Orbitron,monospace;font-size:.7rem;color:#00e5b4;letter-spacing:.15em;margin-bottom:8px;">{T("bookmarks_section")}</div>', unsafe_allow_html=True)
    bookmarks = get_bookmarks()
    if bookmarks:
        for bm in bookmarks:
            bc1, bc2 = st.columns([4, 1])
            with bc1:
                if st.button(f"⭐ {bm[1][:18]}", key=f"bm_{bm[0]}", use_container_width=True):
                    st.session_state["target_input"] = bm[1]
            with bc2:
                if st.button("✕", key=f"delbm_{bm[0]}"):
                    delete_bookmark(bm[0])
                    st.rerun()
    else:
        st.caption(T("no_bookmarks"))

# ─────────────────────────────────────────────────────────────────────────────
# SCAN EXECUTION
# ─────────────────────────────────────────────────────────────────────────────
if run_btn:
    if bulk_mode:
        if not targets_list:
            st.warning("أدخل أهداف للمسح الجماعي" if is_ar() else "Enter targets for bulk scan")
        else:
            st.markdown(f'<div class="titan-card"><h3>{T("bulk_results")}</h3></div>', unsafe_allow_html=True)
            prog = st.progress(0)
            bulk_rows = []
            for i, tgt in enumerate(targets_list[:20]):
                ttype_b = classify(tgt)
                prog.progress((i + 1) / len(targets_list), f"Scanning {tgt}")
                cached_b = get_cached(tgt) if use_cache else None
                if cached_b:
                    res_b = json.loads(cached_b[2])
                else:
                    res_b = run_all(tgt, ttype_b)
                    set_cache(tgt, json.dumps(res_b))
                    save_scan(tgt, ttype_b, json.dumps(res_b))
                sc_b = compute_score(res_b)
                bulk_rows.append({"Target": tgt, "Type": ttype_b,
                                  "Score": sc_b["score"], "Level": sc_b["label"],
                                  "Cached": cached_b is not None})
            prog.empty()
            st.dataframe(pd.DataFrame(bulk_rows), use_container_width=True)
            st.stop()
    else:
        target_in = single_target.strip()
        if not target_in:
            st.warning("أدخل هدفاً" if is_ar() else "Enter a target")
        else:
            ttype_in = classify(target_in)
            cached_in = get_cached(target_in) if use_cache else None
            if cached_in:
                st.toast(T("cache_hit"), icon="⚡")
                results_in = json.loads(cached_in[2])
            else:
                prog_bar  = st.progress(0, "Initializing...")
                prog_text = st.empty()

                def _cb(frac, eng_name):
                    prog_bar.progress(frac, f"[{eng_name}]")
                    prog_text.markdown(
                        f'<span style="font-family:Share Tech Mono,monospace;font-size:.75rem;color:#00e5b4;">▶ {eng_name}</span>',
                        unsafe_allow_html=True
                    )

                results_in = run_all(target_in, ttype_in, _cb)
                prog_bar.progress(1.0, T("engines_done"))
                time.sleep(0.4)
                prog_bar.empty(); prog_text.empty()
                set_cache(target_in, json.dumps(results_in))
                save_scan(target_in, ttype_in, json.dumps(results_in))

            st.session_state.results      = results_in
            st.session_state.target       = target_in
            st.session_state.ttype        = ttype_in
            st.session_state.score        = compute_score(results_in)
            st.session_state.ioc_data     = extract_iocs(results_in, target_in)
            st.session_state.ai_analysis  = ""
            st.session_state.chat_history = []
            st.session_state.scan_ts      = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

# ─────────────────────────────────────────────────────────────────────────────
# STANDBY SCREEN
# ─────────────────────────────────────────────────────────────────────────────
if st.session_state.results is None:
    components.html("""
    <style>
    #sb{text-align:center;padding:60px 20px;}
    .sbt{font-family:Orbitron,monospace;font-size:2.5rem;font-weight:900;color:#00e5b4;
         text-shadow:0 0 30px #00e5b4,0 0 60px #00e5b440;animation:flicker 4s infinite;}
    .sbs{font-family:Share Tech Mono,monospace;font-size:.85rem;color:#405060;margin-top:16px;letter-spacing:.12em;}
    .sbg{display:flex;gap:16px;justify-content:center;margin-top:40px;flex-wrap:wrap;}
    .sbc{padding:8px 18px;border:1px solid #00e5b430;border-radius:6px;
         font-family:Share Tech Mono,monospace;font-size:.72rem;color:#405060;letter-spacing:.1em;}
    @keyframes flicker{0%,100%{opacity:1;}92%{opacity:1;}93%{opacity:.7;}95%{opacity:1;}97%{opacity:.8;}}
    </style>
    <div id="sb">
      <div class="sbt">TITAN OSINT</div>
      <div class="sbs">ENTER A TARGET TO BEGIN CYBER ANALYSIS</div>
      <div class="sbg">
        <div class="sbc">IP ADDRESS</div><div class="sbc">DOMAIN</div>
        <div class="sbc">EMAIL</div><div class="sbc">HASH MD5/SHA</div>
        <div class="sbc">ASN</div><div class="sbc">URL</div>
        <div class="sbc">GITHUB USER</div><div class="sbc">npm PACKAGE</div>
      </div>
    </div>
    """, height=280)
    st.stop()

# ─────────────────────────────────────────────────────────────────────────────
# RESULT HEADER
# ─────────────────────────────────────────────────────────────────────────────
results = st.session_state.results
target  = st.session_state.target
ttype   = st.session_state.ttype
score   = st.session_state.score

tc       = TYPE_COLORS.get(ttype, "#888888")
sc_color = score["color"] if score else "#888"
sc_val   = score["score"] if score else 0
sc_label = score["label"] if score else "N/A"
sc_icon  = score["icon"]  if score else ""

hc1, hc2, hc3 = st.columns([3, 1.5, 1.5])
with hc1:
    st.markdown(
        f'<div style="padding:16px 20px;background:linear-gradient(135deg,#0a1520,#060d18);'
        f'border:1px solid {tc}40;border-radius:10px;border-left:4px solid {tc};">'
        f'<div style="font-family:Share Tech Mono,monospace;font-size:.7rem;color:#607080;letter-spacing:.12em;">TARGET</div>'
        f'<div style="font-family:Orbitron,monospace;font-size:1.3rem;color:{tc};font-weight:700;'
        f'text-shadow:0 0 15px {tc}80;word-break:break-all;margin:4px 0;">{target}</div>'
        f'<span class="type-badge" style="color:{tc};border-color:{tc}40;">{ttype}</span>'
        f'&nbsp;<span style="font-family:Share Tech Mono,monospace;font-size:.7rem;color:#405060;">'
        f'{st.session_state.scan_ts or ""}</span></div>',
        unsafe_allow_html=True
    )
with hc2:
    st.markdown(
        f'<div style="padding:16px 20px;background:linear-gradient(135deg,#0a1520,#060d18);'
        f'border:1px solid {sc_color}40;border-radius:10px;text-align:center;">'
        f'<div style="font-family:Orbitron,monospace;font-size:3.5rem;font-weight:900;'
        f'color:{sc_color};text-shadow:0 0 25px {sc_color};line-height:1;">{sc_val}</div>'
        f'<div style="font-family:Orbitron,monospace;font-size:.85rem;font-weight:700;'
        f'color:{sc_color};letter-spacing:.2em;margin-top:4px;">{sc_icon} {sc_label}</div>'
        f'<div style="font-family:Share Tech Mono,monospace;font-size:.6rem;color:#405060;margin-top:4px;">THREAT SCORE</div>'
        f'</div>', unsafe_allow_html=True
    )
with hc3:
    ioc_total = st.session_state.ioc_data["summary"]["total"] if st.session_state.ioc_data else 0
    eng_ok    = sum(1 for v in results.values() if isinstance(v, dict) and "error" not in v)
    st.markdown(
        f'<div style="padding:16px 20px;background:linear-gradient(135deg,#0a1520,#060d18);'
        f'border:1px solid #00e5b430;border-radius:10px;">'
        f'<div style="font-family:Share Tech Mono,monospace;font-size:.6rem;color:#405060;">ENGINES OK</div>'
        f'<div style="font-family:Orbitron,monospace;font-size:1.6rem;color:#00e5b4;font-weight:700;">{eng_ok}/{len(results)}</div>'
        f'<div style="font-family:Share Tech Mono,monospace;font-size:.6rem;color:#405060;margin-top:8px;">IOCs FOUND</div>'
        f'<div style="font-family:Orbitron,monospace;font-size:1.6rem;color:#ffaa00;font-weight:700;">{ioc_total}</div>'
        f'</div>', unsafe_allow_html=True
    )

# Action buttons row
ab1, ab2, ab3, _ = st.columns([1, 1, 1, 3])
with ab1:
    if st.button(T("bookmark_btn"), key="bm_add"):
        add_bookmark(target, ttype)
        st.toast(T("bookmarked_ok"), icon="⭐")
with ab2:
    json_dl = json.dumps(results, ensure_ascii=False, indent=2)
    st.download_button(T("dl_json"), json_dl, f"{target}_titan.json", "application/json")
with ab3:
    if st.session_state.ioc_data:
        st.download_button(T("dl_ioc"), iocs_to_csv(st.session_state.ioc_data), f"{target}_iocs.csv", "text/csv")

st.markdown("<hr>", unsafe_allow_html=True)

# ─────────────────────────────────────────────────────────────────────────────
# TABS
# ─────────────────────────────────────────────────────────────────────────────
tabs = st.tabs([
    T("tab_dash"), T("tab_signals"), T("tab_ai"),
    T("tab_dev"),  T("tab_geo"),     T("tab_graph"),
    T("tab_raw"),  T("tab_history"), T("tab_mitre"),
])

# ══════════════════════════════════════════════════════════════════
# TAB 0 — DASHBOARD
# ══════════════════════════════════════════════════════════════════
with tabs[0]:
    r      = results
    vt     = r.get("VirusTotal",     {})
    abuse  = r.get("AbuseIPDB",      {})
    shodan = r.get("Shodan",         {})
    otx    = r.get("AlienVault OTX", {})
    tfox   = r.get("ThreatFox",      {})
    ipinf  = r.get("IPInfo",         {})
    grey   = r.get("GreyNoise",      {})
    cip    = r.get("CriminalIP",     {})

    m1, m2, m3, m4, m5, m6 = st.columns(6)
    m1.metric(T("metric_vt"),     vt.get("malicious",              "N/A"))
    m2.metric(T("metric_abuse"),  abuse.get("abuseConfidenceScore","N/A"))
    m3.metric(T("metric_ports"),  len(shodan.get("ports", [])))
    m4.metric(T("metric_pulses"), otx.get("pulse_count",           "N/A"))
    m5.metric(T("metric_ioc"),    tfox.get("total",                "N/A"))
    m6.metric(T("metric_score"),  sc_val)

    st.markdown("<br>", unsafe_allow_html=True)

    # Gauge + infra info
    col_gauge, col_info = st.columns([1.2, 2])
    with col_gauge:
        fig_g = go.Figure(go.Indicator(
            mode="gauge+number",
            value=sc_val,
            number={"font": {"family": "Orbitron", "color": sc_color, "size": 48}},
            gauge={
                "axis": {"range": [0, 100], "tickcolor": "#405060", "tickfont": {"size": 9}},
                "bar": {"color": sc_color, "thickness": 0.25},
                "bgcolor": "#050508", "bordercolor": "rgba(0,229,180,0.18)", "borderwidth": 1,
                "steps": [
                    {"range": [0,  20], "color": "#002010"},
                    {"range": [20, 45], "color": "#201500"},
                    {"range": [45, 70], "color": "#200a00"},
                    {"range": [70,100], "color": "#200000"},
                ],
                "threshold": {"line": {"color": sc_color, "width": 3}, "thickness": .8, "value": sc_val},
            },
            title={"text": T("threat_score"), "font": {"family": "Orbitron", "size": 12, "color": "#607080"}},
        ))
        fig_g.update_layout(paper_bgcolor="#050508", plot_bgcolor="#050508",
                            font_color="#c8d8e8", height=230,
                            margin=dict(t=40, b=20, l=20, r=20))
        st.plotly_chart(fig_g, use_container_width=True)

    with col_info:
        st.markdown('<div class="titan-card"><h3>INFRASTRUCTURE</h3>', unsafe_allow_html=True)
        rows = [
            ("ORG",            shodan.get("org")    or ipinf.get("org",    "N/A")),
            ("ISP",            abuse.get("isp")     or shodan.get("isp",   "N/A")),
            ("COUNTRY",        ipinf.get("country") or shodan.get("country","N/A")),
            ("CITY",           ipinf.get("city")    or shodan.get("city",  "N/A")),
            ("OS",             shodan.get("os",      "N/A")),
            ("HOSTNAME",       ipinf.get("hostname", "N/A")),
            ("NOISE",          str(grey.get("noise",  "N/A"))),
            ("CLASSIFICATION", grey.get("classification", "N/A")),
            ("VPN",            str(cip.get("is_vpn",  "N/A"))),
            ("TOR",            str(cip.get("is_tor",  "N/A"))),
        ]
        for lbl, val in rows:
            if val not in ("N/A", "None", "", "False", None):
                st.markdown(
                    f'<div style="display:flex;gap:12px;padding:4px 0;border-bottom:1px solid #00e5b410;">'
                    f'<span style="font-family:Share Tech Mono,monospace;font-size:.72rem;color:#405060;min-width:110px;">{lbl}</span>'
                    f'<span style="font-family:Share Tech Mono,monospace;font-size:.82rem;color:#c8d8e8;">{val}</span>'
                    f'</div>', unsafe_allow_html=True
                )
        st.markdown('</div>', unsafe_allow_html=True)

    # Engine contribution bars
    if score and score.get("contributions"):
        st.markdown('<div class="titan-card"><h3>ENGINE CONTRIBUTIONS</h3>', unsafe_allow_html=True)
        contribs = score["contributions"]
        max_c = max(contribs.values(), default=1)
        for eng, pts in contribs.items():
            pct = int(pts / max_c * 100)
            st.markdown(
                f'<div style="margin-bottom:6px;">'
                f'<div style="display:flex;justify-content:space-between;margin-bottom:3px;">'
                f'<span style="font-family:Share Tech Mono,monospace;font-size:.75rem;color:#a0c0d0;">{eng}</span>'
                f'<span style="font-family:Orbitron,monospace;font-size:.72rem;color:{sc_color};">{pts:.0f}pts</span>'
                f'</div>'
                f'<div style="background:#060d18;border-radius:3px;height:4px;">'
                f'<div style="background:{sc_color};width:{pct}%;height:4px;border-radius:3px;'
                f'box-shadow:0 0 6px {sc_color}80;"></div></div></div>',
                unsafe_allow_html=True
            )
        st.markdown('</div>', unsafe_allow_html=True)

    # Open ports
    ports = shodan.get("ports", [])
    if ports:
        st.markdown(f'<div class="titan-card"><h3>OPEN PORTS ({len(ports)})</h3>', unsafe_allow_html=True)
        st.markdown(
            " ".join(f'<span style="background:#0d2030;border:1px solid #4488ff40;border-radius:4px;'
                     f'padding:3px 9px;font-family:Share Tech Mono,monospace;font-size:.78rem;color:#4488ff;">{p}</span>'
                     for p in ports[:40]) + '</div>',
            unsafe_allow_html=True
        )

    # CVEs
    vulns = shodan.get("vulns", [])
    if vulns:
        st.markdown(f'<div class="titan-card"><h3>CVEs DETECTED ({len(vulns)})</h3>', unsafe_allow_html=True)
        st.markdown(
            " ".join(f'<span style="background:#1a0505;border:1px solid #ff444440;border-radius:4px;'
                     f'padding:3px 9px;font-family:Share Tech Mono,monospace;font-size:.78rem;color:#ff4444;">{v}</span>'
                     for v in vulns) + '</div>',
            unsafe_allow_html=True
        )

# ══════════════════════════════════════════════════════════════════
# TAB 1 — SIGNALS
# ══════════════════════════════════════════════════════════════════
with tabs[1]:
    signals = []
    def _sig(level, engine, message):
        signals.append({"level": level, "engine": engine, "message": message})

    vt_m = (results.get("VirusTotal",     {}) or {}).get("malicious", 0) or 0
    ab_s = (results.get("AbuseIPDB",      {}) or {}).get("abuseConfidenceScore", 0) or 0
    tf_t = (results.get("ThreatFox",      {}) or {}).get("total", 0) or 0
    uh_c = (results.get("URLhaus",        {}) or {}).get("urls_count", 0) or 0
    otx_p= (results.get("AlienVault OTX", {}) or {}).get("pulse_count", 0) or 0
    hibp_c=(results.get("HaveIBeenPwned", {}) or {}).get("count", 0) or 0

    if vt_m  > 0:  _sig("CRITICAL" if vt_m > 5 else "HIGH", "VirusTotal",      f"{vt_m} malicious detections")
    if ab_s  > 30: _sig("HIGH" if ab_s > 70 else "MEDIUM",  "AbuseIPDB",       f"Abuse score {ab_s}%")
    if tf_t  > 0:  _sig("HIGH",   "ThreatFox",      f"{tf_t} IOC matches")
    if uh_c  > 0:  _sig("HIGH",   "URLhaus",         f"{uh_c} malicious URLs")
    if otx_p > 0:  _sig("MEDIUM", "AlienVault OTX",  f"{otx_p} threat pulses")
    if hibp_c> 0:  _sig("HIGH",   "HaveIBeenPwned",  f"Found in {hibp_c} breaches")

    grey_r = results.get("GreyNoise", {}) or {}
    cip_r  = results.get("CriminalIP",{}) or {}
    ipqs_r = results.get("IPQS",      {}) or {}
    lk_r   = results.get("LeakCheck", {}) or {}

    if grey_r.get("noise"):          _sig("MEDIUM", "GreyNoise",  "Known internet scanner/noise")
    if cip_r.get("is_tor"):          _sig("HIGH",   "CriminalIP", "TOR exit node")
    if cip_r.get("is_scanner"):      _sig("MEDIUM", "CriminalIP", "Active scanner")
    if ipqs_r.get("tor"):            _sig("HIGH",   "IPQS",       "TOR detected")
    if lk_r.get("found") or lk_r.get("result"): _sig("HIGH", "LeakCheck", "Credentials in leak DB")

    LEVEL_CFG = {
        "CRITICAL": ("#ff0000","#1a0000"),
        "HIGH":     ("#ff6b35","#1a0800"),
        "MEDIUM":   ("#ffaa00","#1a0f00"),
        "LOW":      ("#00e5b4","#001510"),
    }

    st.markdown(f'<div class="titan-card"><h3>{T("signals_title")} ({len(signals)})</h3></div>', unsafe_allow_html=True)
    if signals:
        for sig in signals:
            col_s, bg_s = LEVEL_CFG.get(sig["level"], ("#888","#0a0a0a"))
            st.markdown(
                f'<div class="signal-row" style="border-color:{col_s};background:{bg_s};">'
                f'<span style="font-family:Orbitron,monospace;font-size:.65rem;color:{col_s};'
                f'font-weight:700;min-width:70px;">{sig["level"]}</span>'
                f'<span style="font-family:Share Tech Mono,monospace;font-size:.72rem;'
                f'color:#607080;min-width:130px;">{sig["engine"]}</span>'
                f'<span style="font-family:Rajdhani,monospace;font-size:.9rem;color:#c8d8e8;">{sig["message"]}</span>'
                f'</div>', unsafe_allow_html=True
            )
    else:
        st.success(T("no_signals"))

    # IOC table
    st.markdown(f'<div class="titan-card" style="margin-top:18px;"><h3>{T("ioc_title")}</h3></div>', unsafe_allow_html=True)
    if st.session_state.ioc_data and st.session_state.ioc_data["iocs"]:
        ioc_df = pd.DataFrame(st.session_state.ioc_data["iocs"])
        st.dataframe(ioc_df, use_container_width=True, height=260)
    else:
        st.info(T("no_result"))

# ══════════════════════════════════════════════════════════════════
# TAB 2 — TITANAI (GEMINI ANALYST)
# ══════════════════════════════════════════════════════════════════
with tabs[2]:
    st.markdown(f'<div class="titan-card"><h3>{T("ai_title")}</h3></div>', unsafe_allow_html=True)

    if not AI_AVAILABLE:
        st.warning(T("ai_no_key"))
    else:
        # Auto-analyze on first visit
        if not st.session_state.ai_analysis:
            with st.spinner(T("ai_loading")):
                st.session_state.ai_analysis = ai_analyze(target, ttype, results, lang())

        st.markdown(
            f'<div style="background:#060d18;border:1px solid #00e5b430;border-radius:8px;'
            f'padding:20px 24px;font-family:Rajdhani,sans-serif;font-size:.95rem;'
            f'color:#c8d8e8;line-height:1.7;max-height:460px;overflow-y:auto;">'
            f'{st.session_state.ai_analysis.replace(chr(10),"<br>")}</div>',
            unsafe_allow_html=True
        )

        col_ra, col_dl = st.columns([1, 1])
        with col_ra:
            if st.button("🔄 " + ("إعادة التحليل" if is_ar() else "Re-Analyze"), key="reanalyze"):
                with st.spinner(T("ai_loading")):
                    st.session_state.ai_analysis = ai_analyze(target, ttype, results, lang())
                st.rerun()
        with col_dl:
            st.download_button(
                "📄 " + ("تحميل التقرير" if is_ar() else "Download Report"),
                st.session_state.ai_analysis,
                f"{target}_ai_report.txt", "text/plain"
            )

        st.markdown("<hr>", unsafe_allow_html=True)

        # Chat
        st.markdown(
            '<div style="font-family:Orbitron,monospace;font-size:.75rem;color:#00e5b4;'
            'letter-spacing:.14em;margin-bottom:10px;">&#128172; TITANAI CHAT</div>',
            unsafe_allow_html=True
        )

        for msg in st.session_state.chat_history:
            css_cls = "chat-msg-user" if msg["role"] == "user" else "chat-msg-ai"
            prefix  = "🔵 You" if msg["role"] == "user" else "🤖 TitanAI"
            st.markdown(
                f'<div class="{css_cls}"><b>{prefix}:</b><br>{msg["content"]}</div>',
                unsafe_allow_html=True
            )

        ci_col, cs_col = st.columns([5, 1])
        with ci_col:
            chat_input = st.text_input("Chat", placeholder=T("chat_ph"), label_visibility="collapsed", key="chat_in")
        with cs_col:
            chat_send = st.button("▶ " + ("إرسال" if is_ar() else "Send"), key="chat_send", use_container_width=True)

        if chat_send and chat_input.strip():
            ctx = {"target": target, "ttype": ttype,
                   "results": results, "ai_analysis": st.session_state.ai_analysis}
            with st.spinner("TitanAI..."):
                reply = ai_chat(chat_input, ctx, lang())
            st.session_state.chat_history.append({"role": "user",     "content": chat_input})
            st.session_state.chat_history.append({"role": "assistant", "content": reply})
            st.rerun()

        if st.session_state.chat_history:
            if st.button("🗑️ " + ("مسح" if is_ar() else "Clear Chat"), key="clr_chat"):
                st.session_state.chat_history = []
                st.rerun()

# ══════════════════════════════════════════════════════════════════
# TAB 3 — DEVELOPER
# ══════════════════════════════════════════════════════════════════
with tabs[3]:
    st.markdown(f'<div class="titan-card"><h3>{T("dev_title")}</h3></div>', unsafe_allow_html=True)

    gh_d  = results.get("GitHub",  {}) or {}
    cr_d  = results.get("CertSH",  {}) or {}
    wb_d  = results.get("Wayback", {}) or {}
    npm_d = results.get("NPM",     {}) or {}
    py_d  = results.get("PyPI",    {}) or {}

    dc1, dc2 = st.columns(2)

    with dc1:
        if gh_d and "error" not in gh_d and gh_d.get("login"):
            st.markdown('<div class="titan-card"><h3>GITHUB</h3>', unsafe_allow_html=True)
            for k, v in gh_d.items():
                if k == "top_repos":
                    for repo in (v or []):
                        st.markdown(f'`{repo.get("name")}` ⭐{repo.get("stars",0)} [{repo.get("language","?")}]')
                elif v not in ("N/A", None, "", 0):
                    st.markdown(f'**{k}**: `{v}`')
            st.markdown('</div>', unsafe_allow_html=True)

        if npm_d and "error" not in npm_d and npm_d.get("name"):
            st.markdown('<div class="titan-card"><h3>NPM PACKAGE</h3>', unsafe_allow_html=True)
            for k, v in npm_d.items():
                if k == "dependencies_sample":
                    if v: st.markdown(f'**deps**: {", ".join(v[:8])}')
                elif v not in ("N/A", None, ""):
                    st.markdown(f'**{k}**: `{v}`')
            st.markdown('</div>', unsafe_allow_html=True)

        if py_d and "error" not in py_d and py_d.get("name"):
            st.markdown('<div class="titan-card"><h3>PYPI PACKAGE</h3>', unsafe_allow_html=True)
            for k, v in py_d.items():
                if v not in ("N/A", None, ""):
                    st.markdown(f'**{k}**: `{v}`')
            st.markdown('</div>', unsafe_allow_html=True)

    with dc2:
        if cr_d and "error" not in cr_d and cr_d.get("total_certs", 0) > 0:
            st.markdown('<div class="titan-card"><h3>SSL CERTS (crt.sh)</h3>', unsafe_allow_html=True)
            st.markdown(f'Total: `{cr_d.get("total_certs",0)}`  |  Unique domains: `{cr_d.get("unique_domains",0)}`')
            for d in (cr_d.get("sample_domains") or [])[:12]:
                st.markdown(f'`{d}`')
            st.markdown('</div>', unsafe_allow_html=True)

        if wb_d and "error" not in wb_d:
            st.markdown('<div class="titan-card"><h3>WAYBACK MACHINE</h3>', unsafe_allow_html=True)
            st.markdown(f'Available: `{wb_d.get("available","N/A")}`')
            st.markdown(f'Closest snapshot: `{wb_d.get("timestamp","N/A")}`')
            for snap in (wb_d.get("recent_snapshots") or [])[:5]:
                st.markdown(f'`{snap.get("ts","")}` — HTTP {snap.get("status","")}')
            st.markdown('</div>', unsafe_allow_html=True)

    if not any([
        gh_d.get("login"), cr_d.get("total_certs"),
        wb_d.get("available"), npm_d.get("name"), py_d.get("name"),
    ]):
        st.info("لا توجد بيانات مطوّر لهذا النوع من الأهداف." if is_ar()
                else "No developer intelligence for this target type.")

# ══════════════════════════════════════════════════════════════════
# TAB 4 — GEO MAP
# ══════════════════════════════════════════════════════════════════
with tabs[4]:
    ipinf_g  = results.get("IPInfo", {}) or {}
    shodan_g = results.get("Shodan", {}) or {}
    lat = ipinf_g.get("lat") or shodan_g.get("lat")
    lon = ipinf_g.get("lon") or shodan_g.get("lon")

    if lat and lon:
        try:
            import folium
            from streamlit_folium import st_folium
            m = folium.Map(location=[lat, lon], zoom_start=8,
                           tiles="CartoDB dark_matter", width="100%", height=420)
            folium.CircleMarker(
                location=[lat, lon], radius=10,
                color="#00e5b4", fill=True, fill_color="#00e5b4", fill_opacity=0.7,
                popup=f"{target} | {ipinf_g.get('city','')}, {ipinf_g.get('country','')}"
            ).add_to(m)
            folium.Circle(
                location=[lat, lon], radius=50000,
                color="#00e5b440", fill=True, fill_color="#00e5b410"
            ).add_to(m)
            st_folium(m, width="100%", height=430)

            geo_info = {
                "City": ipinf_g.get("city","N/A"), "Region": ipinf_g.get("region","N/A"),
                "Country": ipinf_g.get("country","N/A"), "Org": ipinf_g.get("org","N/A"),
                "Timezone": ipinf_g.get("timezone","N/A"), "Lat/Lon": f"{lat}, {lon}",
            }
            gi = st.columns(3)
            for i, (k, v) in enumerate(geo_info.items()):
                gi[i % 3].metric(k, v)
        except ImportError:
            st.warning("Install: `pip install streamlit-folium folium`")
    else:
        st.info(T("geo_no_data"))

# ══════════════════════════════════════════════════════════════════
# TAB 5 — NETWORK GRAPH
# ══════════════════════════════════════════════════════════════════
with tabs[5]:
    nodes, edges = [{"id": target, "label": target, "color": tc, "size": 30}], []

    connectors = {
        "Shodan":         ("hostnames",     "#4488ff"),
        "SecurityTrails": ("a_records",     "#00cc88"),
        "CertSH":         ("sample_domains","#ffaa44"),
        "Robtex":         ("records",       "#cc88ff"),
    }
    for eng, (field, ecol) in connectors.items():
        vals = (results.get(eng, {}) or {}).get(field, [])
        if not isinstance(vals, list): vals = []
        for v in vals[:5]:
            val = v.get("o") or v.get("ip") or str(v) if isinstance(v, dict) else str(v)
            if val and val != target and len(val) > 2:
                nodes.append({"id": val, "label": val, "color": ecol, "size": 16})
                edges.append({"from": target, "to": val, "label": eng})

    if len(nodes) > 1:
        import math
        node_x, node_y = [], []
        for i, n in enumerate(nodes):
            if i == 0:
                node_x.append(0); node_y.append(0)
            else:
                angle = (i - 1) * (2 * math.pi / (len(nodes) - 1))
                node_x.append(math.cos(angle) * 2)
                node_y.append(math.sin(angle) * 2)

        fig_net = go.Figure()
        for e in edges:
            fi = next((i for i, n in enumerate(nodes) if n["id"] == e["from"]), None)
            ti = next((i for i, n in enumerate(nodes) if n["id"] == e["to"]),   None)
            if fi is not None and ti is not None:
                fig_net.add_trace(go.Scatter(
                    x=[node_x[fi], node_x[ti], None],
                    y=[node_y[fi], node_y[ti], None],
                    mode="lines", line=dict(color="rgba(0,229,180,0.18)", width=1),
                    hoverinfo="none", showlegend=False,
                ))
        fig_net.add_trace(go.Scatter(
            x=node_x, y=node_y, mode="markers+text",
            marker=dict(size=[n["size"] for n in nodes], color=[n["color"] for n in nodes],
                        line=dict(color="rgba(0,229,180,0.25)", width=1)),
            text=[n["label"][:20] for n in nodes],
            textposition="top center",
            textfont=dict(family="Share Tech Mono", size=9, color="#c8d8e8"),
            hovertext=[n["id"] for n in nodes], hoverinfo="text", showlegend=False,
        ))
        fig_net.update_layout(
            paper_bgcolor="#050508", plot_bgcolor="#050508",
            xaxis=dict(showgrid=False, zeroline=False, showticklabels=False),
            yaxis=dict(showgrid=False, zeroline=False, showticklabels=False),
            height=440, margin=dict(t=20, b=20, l=20, r=20),
        )
        st.plotly_chart(fig_net, use_container_width=True)
    else:
        st.info(T("graph_no_data"))

# ══════════════════════════════════════════════════════════════════
# TAB 6 — RAW DATA
# ══════════════════════════════════════════════════════════════════
with tabs[6]:
    st.markdown(f'<div class="titan-card"><h3>{T("engine_results")}</h3></div>', unsafe_allow_html=True)

    flt = st.text_input("Filter", placeholder="🔍 Filter engines...", label_visibility="collapsed", key="raw_flt")

    for eng, data in sorted(results.items()):
        if flt and flt.lower() not in eng.lower():
            continue
        has_err = isinstance(data, dict) and "error" in data
        badge = "ERR" if has_err else "OK"
        badge_col = "#ff4444" if has_err else "#00e5b4"
        with st.expander(f"[{badge}] {eng}", expanded=False):
            st.markdown(
                f'<pre style="background:#060d18;border:1px solid #00e5b420;border-radius:6px;'
                f'padding:12px;font-family:Share Tech Mono,monospace;font-size:.78rem;'
                f'color:#a0c0d0;overflow-x:auto;white-space:pre-wrap;max-height:300px;overflow-y:auto;">'
                f'{json.dumps(data, ensure_ascii=False, indent=2)[:3000]}</pre>',
                unsafe_allow_html=True
            )

    # Notes
    st.markdown("<hr>", unsafe_allow_html=True)
    st.markdown('<div style="font-family:Orbitron,monospace;font-size:.72rem;color:#00e5b4;letter-spacing:.14em;margin-bottom:8px;">ANALYST NOTES</div>', unsafe_allow_html=True)
    for note in get_notes(target):
        st.markdown(
            f'<div style="background:#060d18;border:1px solid #00e5b420;border-radius:6px;'
            f'padding:8px 12px;margin-bottom:6px;font-family:Share Tech Mono,monospace;'
            f'font-size:.8rem;color:#a0c0d0;">{note[2]}</div>',
            unsafe_allow_html=True
        )
    note_txt = st.text_area("Note", placeholder=T("notes_ph"), label_visibility="collapsed", key="note_txt", height=80)
    if st.button(T("save_note"), key="save_note_btn"):
        if note_txt.strip():
            add_note(target, note_txt.strip())
            st.toast(T("note_saved"), icon="💾")
            st.rerun()

# ══════════════════════════════════════════════════════════════════
# TAB 7 — HISTORY / STATS
# ══════════════════════════════════════════════════════════════════
with tabs[7]:
    st.markdown(f'<div class="titan-card"><h3>{T("history_title")}</h3></div>', unsafe_allow_html=True)

    s = stats()
    hm1, hm2, hm3, hm4 = st.columns(4)
    hm1.metric(T("total_scans"),     s.get("total",          0))
    hm2.metric(T("today_scans"),     s.get("today",          0))
    hm3.metric(T("unique_targets"),  s.get("unique_targets", 0))
    hm4.metric(T("critical_alerts"), s.get("critical",       0))

    hist = get_history(limit=50)
    if hist:
        df_h = pd.DataFrame(hist, columns=["ID","Timestamp","Target","Type","Score","Label","Summary"])
        df_h = df_h[["Timestamp","Target","Type","Score","Label"]]
        st.dataframe(df_h, use_container_width=True, height=360)
        st.download_button(T("dl_csv"), df_h.to_csv(index=False), "titan_history.csv", "text/csv")
    else:
        st.info(T("no_history"))

# ══════════════════════════════════════════════════════════════════
# TAB 8 — MITRE ATT&CK
# ══════════════════════════════════════════════════════════════════
with tabs[8]:
    st.markdown(f'<div class="titan-card"><h3>{T("mitre_title")}</h3></div>', unsafe_allow_html=True)

    techniques = []
    if st.session_state.ai_analysis:
        techniques = extract_mitre(st.session_state.ai_analysis)

    for eng in ["ThreatFox", "AlienVault OTX", "Pulsedive"]:
        extra = extract_mitre(json.dumps(results.get(eng, {}) or {}))
        existing = {t["id"] for t in techniques}
        for t in extra:
            if t["id"] not in existing:
                techniques.append(t)

    if techniques:
        for tech in techniques:
            st.markdown(
                f'<div style="display:flex;align-items:center;gap:12px;padding:10px 14px;'
                f'background:#0a1520;border:1px solid #ff6b3540;border-radius:6px;margin-bottom:6px;">'
                f'<span style="font-family:Orbitron,monospace;font-size:.82rem;color:#ff6b35;'
                f'font-weight:700;min-width:90px;">{tech["id"]}</span>'
                f'<a href="{tech["url"]}" target="_blank" style="font-family:Share Tech Mono,monospace;'
                f'font-size:.78rem;color:#4488ff;text-decoration:none;">{tech["url"]}</a>'
                f'</div>', unsafe_allow_html=True
            )

        mitre_csv = "technique_id,url\n" + "\n".join(f'{t["id"]},{t["url"]}' for t in techniques)
        st.download_button(T("dl_mitre"), mitre_csv, f"{target}_mitre.csv", "text/csv")

        if len(techniques) >= 3:
            cats = [t["id"] for t in techniques[:8]]
            fig_r = go.Figure(go.Scatterpolar(
                r=[1]*len(cats) + [1],
                theta=cats + [cats[0]],
                fill="toself",
                fillcolor="rgba(255,107,53,0.12)",
                line=dict(color="#ff6b35", width=2),
            ))
            fig_r.update_layout(
                polar=dict(bgcolor="#060d18",
                           radialaxis=dict(visible=False),
                           angularaxis=dict(tickfont=dict(size=10, color="#c8d8e8"), color="#405060")),
                paper_bgcolor="#050508", plot_bgcolor="#050508",
                height=340, margin=dict(t=20, b=20, l=40, r=40), showlegend=False,
            )
            st.plotly_chart(fig_r, use_container_width=True)
    else:
        if not st.session_state.ai_analysis:
            st.info("قم بفتح تبويب TitanAI أولاً لاستخراج تقنيات MITRE" if is_ar()
                    else "Open the TitanAI tab first to extract MITRE techniques")
        else:
            st.info(T("no_mitre"))
