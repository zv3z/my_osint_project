"""Titan OSINT — Modern Mobile-First Cyber Intelligence Platform"""
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
                                add_bookmark, add_note, get_notes, stats)
from titan.engines      import run_all
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
    initial_sidebar_state="collapsed",
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
# MODERN MOBILE-FIRST CSS
# ─────────────────────────────────────────────────────────────────────────────
st.markdown("""
<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&family=Space+Grotesk:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap');

:root {
    --bg-primary:    #080b14;
    --bg-secondary:  #0d1121;
    --bg-card:       rgba(255,255,255,0.04);
    --bg-card-hover: rgba(255,255,255,0.07);
    --border:        rgba(255,255,255,0.08);
    --border-accent: rgba(99,102,241,0.4);

    --indigo:        #6366f1;
    --indigo-light:  #818cf8;
    --cyan:          #22d3ee;
    --cyan-glow:     rgba(34,211,238,0.15);
    --green:         #10b981;
    --amber:         #f59e0b;
    --red:           #ef4444;
    --pink:          #ec4899;

    --text-primary:  #f1f5f9;
    --text-secondary:#94a3b8;
    --text-muted:    #475569;

    --radius-sm:     8px;
    --radius-md:     12px;
    --radius-lg:     16px;
    --radius-xl:     24px;

    --shadow-sm:     0 1px 3px rgba(0,0,0,0.5);
    --shadow-md:     0 4px 24px rgba(0,0,0,0.4);
    --shadow-glow:   0 0 30px rgba(99,102,241,0.15);
}

*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

html, body,
[data-testid="stAppViewContainer"],
[data-testid="stApp"] {
    background: var(--bg-primary) !important;
    color: var(--text-primary) !important;
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif !important;
    -webkit-font-smoothing: antialiased !important;
}

/* Animated background mesh */
[data-testid="stAppViewContainer"]::before {
    content: "";
    position: fixed; top: 0; left: 0; right: 0; bottom: 0;
    background:
        radial-gradient(ellipse 80% 50% at 20% 10%, rgba(99,102,241,0.07) 0%, transparent 60%),
        radial-gradient(ellipse 60% 40% at 80% 80%, rgba(34,211,238,0.05) 0%, transparent 60%),
        radial-gradient(ellipse 50% 30% at 50% 50%, rgba(236,72,153,0.03) 0%, transparent 70%);
    pointer-events: none;
    z-index: 0;
    animation: meshMove 20s ease-in-out infinite alternate;
}
@keyframes meshMove {
    0%   { opacity: 0.6; }
    100% { opacity: 1; }
}

/* Hide defaults */
[data-testid="stSidebar"],
[data-testid="stSidebarCollapseButton"],
[data-testid="collapsedControl"],
#MainMenu, footer,
header[data-testid="stHeader"] { display: none !important; }

[data-testid="stMainBlockContainer"] {
    padding: 0.75rem 1rem !important;
    max-width: 1400px !important;
    margin: 0 auto !important;
}

section[data-testid="stMain"] { background: transparent !important; }

/* ── GLASS CARD ─────────────────────────────────────────────────── */
.glass-card {
    background: var(--bg-card);
    backdrop-filter: blur(20px);
    -webkit-backdrop-filter: blur(20px);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg);
    padding: 20px;
    position: relative;
    overflow: hidden;
    transition: border-color 0.2s, transform 0.2s, box-shadow 0.2s;
}
.glass-card:hover {
    border-color: rgba(99,102,241,0.25);
    box-shadow: var(--shadow-glow);
}
.glass-card::before {
    content: "";
    position: absolute; top: 0; left: 0; right: 0; height: 1px;
    background: linear-gradient(90deg, transparent, rgba(255,255,255,0.12), transparent);
}
.glass-card h3 {
    font-family: 'Space Grotesk', sans-serif;
    font-size: 0.72rem;
    font-weight: 600;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--text-muted);
    margin-bottom: 14px;
}

/* ── METRIC CARDS ───────────────────────────────────────────────── */
[data-testid="stMetric"] {
    background: var(--bg-card) !important;
    backdrop-filter: blur(20px) !important;
    border: 1px solid var(--border) !important;
    border-radius: var(--radius-md) !important;
    padding: 16px !important;
    transition: all 0.2s !important;
}
[data-testid="stMetric"]:hover {
    border-color: var(--border-accent) !important;
    transform: translateY(-2px) !important;
}
[data-testid="stMetricValue"] {
    color: var(--indigo-light) !important;
    font-family: 'Space Grotesk', sans-serif !important;
    font-size: 1.8rem !important;
    font-weight: 700 !important;
    line-height: 1 !important;
}
[data-testid="stMetricLabel"] {
    color: var(--text-muted) !important;
    font-size: 0.7rem !important;
    font-weight: 500 !important;
    letter-spacing: 0.06em !important;
    text-transform: uppercase !important;
}

/* ── TABS ───────────────────────────────────────────────────────── */
[data-testid="stTabs"] > div:first-child {
    border-bottom: 1px solid var(--border) !important;
    gap: 2px !important;
    overflow-x: auto !important;
    -webkit-overflow-scrolling: touch !important;
    scrollbar-width: none !important;
    padding-bottom: 0 !important;
}
[data-testid="stTabs"] > div:first-child::-webkit-scrollbar { display: none !important; }

button[data-baseweb="tab"] {
    background: transparent !important;
    border: none !important;
    border-radius: var(--radius-sm) var(--radius-sm) 0 0 !important;
    color: var(--text-muted) !important;
    font-family: 'Inter', sans-serif !important;
    font-weight: 500 !important;
    font-size: 0.78rem !important;
    letter-spacing: 0.02em !important;
    padding: 8px 14px !important;
    white-space: nowrap !important;
    transition: all 0.2s !important;
    min-height: 44px !important;
}
button[data-baseweb="tab"]:hover { color: var(--text-primary) !important; }
button[aria-selected="true"][data-baseweb="tab"] {
    background: rgba(99,102,241,0.12) !important;
    color: var(--indigo-light) !important;
    border-bottom: 2px solid var(--indigo) !important;
}

/* ── INPUTS ─────────────────────────────────────────────────────── */
.stTextInput input, .stTextArea textarea {
    background: var(--bg-card) !important;
    border: 1px solid var(--border) !important;
    border-radius: var(--radius-md) !important;
    color: var(--text-primary) !important;
    font-family: 'JetBrains Mono', monospace !important;
    font-size: 0.9rem !important;
    padding: 12px 16px !important;
    transition: all 0.2s !important;
    min-height: 44px !important;
}
.stTextInput input:focus, .stTextArea textarea:focus {
    border-color: var(--indigo) !important;
    box-shadow: 0 0 0 3px rgba(99,102,241,0.15) !important;
    outline: none !important;
}
.stTextInput input::placeholder, .stTextArea textarea::placeholder {
    color: var(--text-muted) !important;
}

/* ── BUTTONS ─────────────────────────────────────────────────────── */
.stButton > button {
    background: linear-gradient(135deg, rgba(99,102,241,0.15), rgba(34,211,238,0.08)) !important;
    border: 1px solid rgba(99,102,241,0.4) !important;
    border-radius: var(--radius-md) !important;
    color: var(--indigo-light) !important;
    font-family: 'Space Grotesk', sans-serif !important;
    font-size: 0.85rem !important;
    font-weight: 600 !important;
    letter-spacing: 0.03em !important;
    padding: 10px 20px !important;
    min-height: 44px !important;
    transition: all 0.2s ease !important;
    cursor: pointer !important;
    width: 100% !important;
}
.stButton > button:hover {
    background: linear-gradient(135deg, rgba(99,102,241,0.3), rgba(34,211,238,0.15)) !important;
    border-color: var(--indigo) !important;
    color: #fff !important;
    box-shadow: 0 0 20px rgba(99,102,241,0.3) !important;
    transform: translateY(-1px) !important;
}
.stButton > button[kind="primary"] {
    background: linear-gradient(135deg, #6366f1, #4f46e5) !important;
    border-color: transparent !important;
    color: #fff !important;
    font-weight: 700 !important;
}
.stButton > button[kind="primary"]:hover {
    background: linear-gradient(135deg, #818cf8, #6366f1) !important;
    box-shadow: 0 4px 20px rgba(99,102,241,0.5) !important;
}

/* ── PROGRESS ────────────────────────────────────────────────────── */
.stProgress > div > div > div {
    background: linear-gradient(90deg, var(--indigo), var(--cyan)) !important;
    border-radius: 4px !important;
    box-shadow: 0 0 10px rgba(99,102,241,0.5) !important;
}

/* ── EXPANDER ────────────────────────────────────────────────────── */
details {
    background: var(--bg-card) !important;
    border: 1px solid var(--border) !important;
    border-radius: var(--radius-md) !important;
    margin-bottom: 8px !important;
    overflow: hidden !important;
}
summary {
    padding: 12px 16px !important;
    color: var(--text-secondary) !important;
    font-family: 'Inter', sans-serif !important;
    font-weight: 500 !important;
    font-size: 0.85rem !important;
    cursor: pointer !important;
    min-height: 44px !important;
    display: flex !important;
    align-items: center !important;
}
details[open] summary { color: var(--indigo-light) !important; }

/* ── SCROLLBAR ───────────────────────────────────────────────────── */
::-webkit-scrollbar { width: 4px; height: 4px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: rgba(99,102,241,0.3); border-radius: 4px; }
::-webkit-scrollbar-thumb:hover { background: var(--indigo); }

/* ── SIGNAL ROWS ─────────────────────────────────────────────────── */
.signal-row {
    display: flex; align-items: center; gap: 12px;
    padding: 10px 14px; border-radius: var(--radius-md);
    margin-bottom: 8px; border-left: 3px solid;
    background: var(--bg-card);
    transition: transform 0.15s;
}
.signal-row:hover { transform: translateX(3px); }

/* ── CHAT MESSAGES ───────────────────────────────────────────────── */
.chat-msg-user {
    background: rgba(99,102,241,0.12);
    border: 1px solid rgba(99,102,241,0.25);
    border-radius: var(--radius-lg) var(--radius-lg) var(--radius-sm) var(--radius-lg);
    padding: 12px 16px; margin: 8px 0;
    color: var(--text-primary);
    font-size: 0.9rem; text-align: right;
}
.chat-msg-ai {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: var(--radius-lg) var(--radius-lg) var(--radius-lg) var(--radius-sm);
    padding: 12px 16px; margin: 8px 0;
    color: var(--text-primary); font-size: 0.9rem;
}

/* ── TYPE BADGE ──────────────────────────────────────────────────── */
.type-badge {
    display: inline-flex; align-items: center;
    padding: 3px 10px; border-radius: 20px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.7rem; font-weight: 500;
    letter-spacing: 0.06em; border: 1px solid currentColor;
    background: rgba(255,255,255,0.05);
}

/* ── CHECKBOX / RADIO ────────────────────────────────────────────── */
.stCheckbox label span, .stRadio label span {
    color: var(--text-secondary) !important;
    font-size: 0.88rem !important;
}

/* ── SELECT / DATAFRAME ──────────────────────────────────────────── */
.stSelectbox > div > div {
    background: var(--bg-card) !important;
    border: 1px solid var(--border) !important;
    border-radius: var(--radius-md) !important;
    color: var(--text-primary) !important;
    min-height: 44px !important;
}
[data-testid="stDataFrame"] {
    border-radius: var(--radius-md) !important;
    overflow: hidden !important;
    border: 1px solid var(--border) !important;
}

/* ── DOWNLOAD BUTTON ─────────────────────────────────────────────── */
[data-testid="stDownloadButton"] > button {
    background: rgba(16,185,129,0.1) !important;
    border: 1px solid rgba(16,185,129,0.3) !important;
    color: var(--green) !important;
    border-radius: var(--radius-md) !important;
    font-family: 'Space Grotesk', sans-serif !important;
    font-size: 0.82rem !important;
    font-weight: 600 !important;
    min-height: 44px !important;
}
[data-testid="stDownloadButton"] > button:hover {
    background: rgba(16,185,129,0.2) !important;
    border-color: var(--green) !important;
    box-shadow: 0 0 15px rgba(16,185,129,0.25) !important;
}

/* ── HR ──────────────────────────────────────────────────────────── */
hr { border-color: var(--border) !important; margin: 16px 0 !important; }

/* ── MOBILE RESPONSIVE ───────────────────────────────────────────── */
@media (max-width: 768px) {
    [data-testid="stMainBlockContainer"] {
        padding: 0.5rem 0.5rem !important;
    }
    [data-testid="stMetricValue"] { font-size: 1.4rem !important; }
    .glass-card { padding: 14px !important; }
    button[data-baseweb="tab"] {
        font-size: 0.72rem !important;
        padding: 6px 10px !important;
    }
}

/* ── TOAST ───────────────────────────────────────────────────────── */
[data-testid="stToast"] {
    background: var(--bg-secondary) !important;
    border: 1px solid var(--border-accent) !important;
    border-radius: var(--radius-md) !important;
    color: var(--text-primary) !important;
    backdrop-filter: blur(20px) !important;
}

/* ── INFO / WARNING / SUCCESS ────────────────────────────────────── */
[data-testid="stAlert"] {
    background: var(--bg-card) !important;
    border-radius: var(--radius-md) !important;
    border: 1px solid var(--border) !important;
}

/* ── SPINNER ─────────────────────────────────────────────────────── */
.stSpinner > div {
    border-top-color: var(--indigo) !important;
}
</style>
""", unsafe_allow_html=True)

# ─────────────────────────────────────────────────────────────────────────────
# ANIMATED HEADER
# ─────────────────────────────────────────────────────────────────────────────
components.html("""
<style>
@import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@700;800&family=Inter:wght@400;500&family=JetBrains+Mono:wght@400&display=swap');

* { box-sizing: border-box; margin: 0; padding: 0; }

#header-wrap {
    position: relative;
    width: 100%;
    height: 80px;
    overflow: hidden;
    background: linear-gradient(135deg, #0d1121 0%, #080b14 100%);
    border-bottom: 1px solid rgba(255,255,255,0.07);
    border-radius: 0 0 16px 16px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 24px;
}

#particle-canvas {
    position: absolute;
    top: 0; left: 0;
    width: 100%; height: 100%;
    opacity: 0.4;
}

#header-left, #header-right { position: relative; z-index: 2; }

#logo-wrap {
    display: flex;
    align-items: center;
    gap: 12px;
}

#logo-icon {
    width: 38px; height: 38px;
    background: linear-gradient(135deg, #6366f1, #22d3ee);
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.2rem;
    box-shadow: 0 0 20px rgba(99,102,241,0.4);
    animation: iconPulse 3s ease-in-out infinite;
}
@keyframes iconPulse {
    0%, 100% { box-shadow: 0 0 20px rgba(99,102,241,0.4); }
    50%       { box-shadow: 0 0 35px rgba(99,102,241,0.7); }
}

#logo-text {
    font-family: 'Space Grotesk', sans-serif;
    font-size: 1.5rem;
    font-weight: 800;
    background: linear-gradient(135deg, #f1f5f9, #818cf8);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    letter-spacing: 0.04em;
}

#logo-sub {
    font-family: 'Inter', sans-serif;
    font-size: 0.62rem;
    color: #475569;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    margin-top: 2px;
}

#status-wrap {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 5px;
}

#status-online {
    display: flex;
    align-items: center;
    gap: 6px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.65rem;
    color: #10b981;
    letter-spacing: 0.08em;
}

#dot-pulse {
    width: 7px; height: 7px;
    border-radius: 50%;
    background: #10b981;
    animation: dotPulse 2s ease-in-out infinite;
}
@keyframes dotPulse {
    0%, 100% { opacity: 1; transform: scale(1); box-shadow: 0 0 6px #10b981; }
    50%       { opacity: 0.5; transform: scale(0.8); box-shadow: none; }
}

#engines-badge {
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.6rem;
    color: #475569;
    letter-spacing: 0.06em;
}

@media (max-width: 480px) {
    #header-wrap { padding: 0 14px; height: 70px; }
    #logo-text { font-size: 1.2rem; }
    #logo-sub { display: none; }
}
</style>

<div id="header-wrap">
    <canvas id="particle-canvas"></canvas>
    <div id="header-left">
        <div id="logo-wrap">
            <div id="logo-icon">⚡</div>
            <div>
                <div id="logo-text">TITAN OSINT</div>
                <div id="logo-sub">Cyber Intelligence Platform</div>
            </div>
        </div>
    </div>
    <div id="header-right">
        <div id="status-wrap">
            <div id="status-online">
                <div id="dot-pulse"></div>
                SYSTEMS ONLINE
            </div>
            <div id="engines-badge">33+ ENGINES • AI FUSION</div>
        </div>
    </div>
</div>

<script>
const canvas = document.getElementById('particle-canvas');
const ctx    = canvas.getContext('2d');

function resize() {
    canvas.width  = canvas.offsetWidth;
    canvas.height = canvas.offsetHeight;
}
resize();

const particles = [];
const colors = ['rgba(99,102,241,', 'rgba(34,211,238,', 'rgba(236,72,153,'];

for (let i = 0; i < 40; i++) {
    particles.push({
        x:  Math.random() * canvas.width,
        y:  Math.random() * canvas.height,
        r:  Math.random() * 1.5 + 0.5,
        vx: (Math.random() - 0.5) * 0.4,
        vy: (Math.random() - 0.5) * 0.4,
        c:  colors[Math.floor(Math.random() * colors.length)],
        o:  Math.random() * 0.5 + 0.2,
    });
}

function animate() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    particles.forEach(p => {
        p.x += p.vx; p.y += p.vy;
        if (p.x < 0 || p.x > canvas.width)  p.vx *= -1;
        if (p.y < 0 || p.y > canvas.height) p.vy *= -1;
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
        ctx.fillStyle = p.c + p.o + ')';
        ctx.fill();
    });
    requestAnimationFrame(animate);
}
animate();
window.addEventListener('resize', resize);
</script>
""", height=85)

# ─────────────────────────────────────────────────────────────────────────────
# TOP BAR — lang + status
# ─────────────────────────────────────────────────────────────────────────────
tb1, tb2, tb3, tb4 = st.columns([1, 1, 1, 1])
with tb1:
    if st.button(T("lang_btn"), key="lang_toggle", use_container_width=True):
        st.session_state.lang = "en" if is_ar() else "ar"
        st.rerun()
tb2.metric(T("apis_configured"), ACTIVE_ENGINES)
tb3.metric(T("ai_engine"), "Gemini" if CONF["GEMINI_KEY"] else ("OpenAI" if CONF["OPENAI_KEY"] else "OFF"))
with tb4:
    history_quick = get_history(limit=5)
    if history_quick:
        hist_labels = [f"{(r[2] or '')[:20]} [{r[3] or ''}]" for r in history_quick]
        hist_sel = st.selectbox(T("history_section"), ["—"] + hist_labels, label_visibility="collapsed")
        if hist_sel != "—":
            idx = hist_labels.index(hist_sel)
            tgt_h = history_quick[idx][2]
            cached_h = get_cached(tgt_h)
            if cached_h:
                st.session_state.results  = json.loads(cached_h[2])
                st.session_state.target   = tgt_h
                st.session_state.ttype    = history_quick[idx][3]
                st.session_state.score    = compute_score(st.session_state.results)
                st.session_state.ioc_data = extract_iocs(st.session_state.results, tgt_h)
                st.rerun()

st.markdown('<hr>', unsafe_allow_html=True)

# ─────────────────────────────────────────────────────────────────────────────
# SCAN INPUT
# ─────────────────────────────────────────────────────────────────────────────
if st.session_state.results is None:
    # Hero landing layout
    st.markdown("""
    <div style="text-align:center; padding:40px 20px 24px;">
        <div style="font-family:'Space Grotesk',sans-serif; font-size:clamp(1.6rem,5vw,2.8rem);
             font-weight:800; background:linear-gradient(135deg,#f1f5f9,#818cf8,#22d3ee);
             -webkit-background-clip:text; -webkit-text-fill-color:transparent;
             background-clip:text; margin-bottom:10px; line-height:1.2;">
            Cyber Intelligence Platform
        </div>
        <div style="font-family:'Inter',sans-serif; font-size:0.9rem; color:#475569;
             letter-spacing:0.04em; max-width:400px; margin:0 auto;">
            Powered by 33+ threat intelligence engines &amp; AI fusion
        </div>
    </div>
    """, unsafe_allow_html=True)

    _, col_mid, _ = st.columns([0.5, 5, 0.5])
    with col_mid:
        st.markdown('<div class="glass-card">', unsafe_allow_html=True)
        scan_mode    = st.radio("Scan Mode", [T("mode_single"), T("mode_bulk")],
                                horizontal=True, label_visibility="collapsed")
        bulk_mode    = (scan_mode == T("mode_bulk"))
        if bulk_mode:
            raw_bulk     = st.text_area(T("bulk_ph"), height=120, placeholder=T("bulk_ph"),
                                        label_visibility="collapsed")
            targets_list = [x.strip() for x in raw_bulk.splitlines() if x.strip()]
            single_target = ""
        else:
            single_target = st.text_input("Target", placeholder=T("target_ph"),
                                          label_visibility="collapsed", key="target_input")
            targets_list  = []
        use_cache = st.checkbox(T("cache_chk"), value=True)
        run_btn   = st.button(T("scan_btn"), use_container_width=True, type="primary")
        st.markdown('</div>', unsafe_allow_html=True)

    # Feature chips
    st.markdown("""
    <div style="display:flex; flex-wrap:wrap; gap:8px; justify-content:center; margin-top:20px;">
    """ + "".join(f"""
        <span style="background:rgba(99,102,241,0.1); border:1px solid rgba(99,102,241,0.25);
              border-radius:20px; padding:4px 14px; font-size:0.75rem; color:#818cf8;
              font-family:'Inter',sans-serif;">{chip}</span>
    """ for chip in ["IP Address","Domain","Email","Hash","URL","ASN","GitHub","npm"]) + """
    </div>
    """, unsafe_allow_html=True)

else:
    # Compact scan bar
    with st.expander(T("scan_section"), expanded=False):
        scan_mode    = st.radio("Scan Mode", [T("mode_single"), T("mode_bulk")],
                                horizontal=True, label_visibility="collapsed", key="sm2")
        bulk_mode    = (scan_mode == T("mode_bulk"))
        if bulk_mode:
            raw_bulk     = st.text_area(T("bulk_ph"), height=80, placeholder=T("bulk_ph"),
                                        label_visibility="collapsed", key="rb2")
            targets_list = [x.strip() for x in raw_bulk.splitlines() if x.strip()]
            single_target = ""
        else:
            single_target = st.text_input("Target", placeholder=T("target_ph"),
                                          label_visibility="collapsed", key="target_input2")
            targets_list  = []
        use_cache = st.checkbox(T("cache_chk"), value=True, key="uc2")
        run_btn   = st.button(T("scan_btn"), use_container_width=True, type="primary", key="rb_top")

# ─────────────────────────────────────────────────────────────────────────────
# SCAN EXECUTION
# ─────────────────────────────────────────────────────────────────────────────
if run_btn:
    if bulk_mode:
        if not targets_list:
            st.warning("أدخل أهداف للمسح الجماعي" if is_ar() else "Enter targets for bulk scan")
        else:
            st.markdown('<div class="glass-card"><h3>Bulk Scan Results</h3>', unsafe_allow_html=True)
            prog = st.progress(0)
            bulk_rows = []
            for i, tgt in enumerate(targets_list[:20]):
                ttype_b  = classify(tgt)
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
            st.markdown('</div>', unsafe_allow_html=True)
            st.stop()
    else:
        target_in = single_target.strip()
        if not target_in:
            st.warning("أدخل هدفاً" if is_ar() else "Enter a target")
        else:
            ttype_in  = classify(target_in)
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
                        f'<span style="font-family:JetBrains Mono,monospace;font-size:.75rem;'
                        f'color:#818cf8;">▶ {eng_name}</span>',
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
            st.rerun()

if st.session_state.results is None:
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

# Score color → modern palette mapping
SCORE_GRADIENT = {
    "#00e5b4": ("rgba(16,185,129,0.15)", "#10b981", "rgba(16,185,129,0.4)"),
    "#ffaa00": ("rgba(245,158,11,0.15)", "#f59e0b", "rgba(245,158,11,0.4)"),
    "#ff6b35": ("rgba(249,115,22,0.15)", "#f97316", "rgba(249,115,22,0.4)"),
    "#ff0000": ("rgba(239,68,68,0.15)",  "#ef4444", "rgba(239,68,68,0.4)"),
}
sc_bg, sc_accent, sc_border = SCORE_GRADIENT.get(sc_color,
    ("rgba(99,102,241,0.15)", "#818cf8", "rgba(99,102,241,0.4)"))

hc1, hc2, hc3 = st.columns([3, 1.5, 1.5])

with hc1:
    st.markdown(
        f'<div class="glass-card" style="border-left:3px solid {tc}; padding:20px;">'
        f'<div style="font-family:JetBrains Mono,monospace;font-size:.65rem;'
        f'color:#475569;letter-spacing:.12em;text-transform:uppercase;margin-bottom:6px;">Target</div>'
        f'<div style="font-family:Space Grotesk,sans-serif;font-size:clamp(1rem,3vw,1.4rem);'
        f'color:#f1f5f9;font-weight:700;word-break:break-all;margin-bottom:8px;">{target}</div>'
        f'<div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;">'
        f'<span class="type-badge" style="color:{tc};border-color:{tc}60;">{ttype}</span>'
        f'<span style="font-family:JetBrains Mono,monospace;font-size:.65rem;color:#475569;">'
        f'{st.session_state.scan_ts or ""}</span></div></div>',
        unsafe_allow_html=True
    )

with hc2:
    st.markdown(
        f'<div class="glass-card" style="background:{sc_bg};border-color:{sc_border};'
        f'text-align:center;padding:20px;">'
        f'<div style="font-family:JetBrains Mono,monospace;font-size:.6rem;'
        f'color:#475569;letter-spacing:.12em;margin-bottom:6px;">THREAT SCORE</div>'
        f'<div style="font-family:Space Grotesk,sans-serif;font-size:3.5rem;font-weight:800;'
        f'color:{sc_accent};line-height:1;">{sc_val}</div>'
        f'<div style="font-family:Space Grotesk,sans-serif;font-size:.85rem;font-weight:600;'
        f'color:{sc_accent};margin-top:4px;letter-spacing:.08em;">{sc_icon} {sc_label}</div>'
        f'</div>',
        unsafe_allow_html=True
    )

with hc3:
    ioc_total = st.session_state.ioc_data["summary"]["total"] if st.session_state.ioc_data else 0
    eng_ok    = sum(1 for v in results.values() if isinstance(v, dict) and "error" not in v)
    st.markdown(
        f'<div class="glass-card" style="padding:20px;">'
        f'<div style="margin-bottom:14px;">'
        f'<div style="font-family:JetBrains Mono,monospace;font-size:.6rem;color:#475569;'
        f'letter-spacing:.1em;text-transform:uppercase;">Engines OK</div>'
        f'<div style="font-family:Space Grotesk,sans-serif;font-size:1.8rem;'
        f'color:#818cf8;font-weight:700;">{eng_ok}<span style="font-size:1rem;'
        f'color:#475569;">/{len(results)}</span></div>'
        f'</div>'
        f'<div style="font-family:JetBrains Mono,monospace;font-size:.6rem;color:#475569;'
        f'letter-spacing:.1em;text-transform:uppercase;">IOCs Found</div>'
        f'<div style="font-family:Space Grotesk,sans-serif;font-size:1.8rem;'
        f'color:#f59e0b;font-weight:700;">{ioc_total}</div>'
        f'</div>',
        unsafe_allow_html=True
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
        st.download_button(T("dl_ioc"), iocs_to_csv(st.session_state.ioc_data),
                           f"{target}_iocs.csv", "text/csv")

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

    col_gauge, col_info = st.columns([1.2, 2])
    with col_gauge:
        fig_g = go.Figure(go.Indicator(
            mode="gauge+number",
            value=sc_val,
            number={"font": {"family": "Space Grotesk", "color": sc_accent, "size": 48}},
            gauge={
                "axis": {"range": [0, 100],
                         "tickcolor": "#475569",
                         "tickfont": {"size": 9, "color": "#475569"}},
                "bar": {"color": sc_accent, "thickness": 0.22},
                "bgcolor": "rgba(0,0,0,0)", "bordercolor": "rgba(255,255,255,0.08)", "borderwidth": 1,
                "steps": [
                    {"range": [0,  20], "color": "rgba(16,185,129,0.08)"},
                    {"range": [20, 45], "color": "rgba(245,158,11,0.08)"},
                    {"range": [45, 70], "color": "rgba(249,115,22,0.08)"},
                    {"range": [70,100], "color": "rgba(239,68,68,0.08)"},
                ],
                "threshold": {"line": {"color": sc_accent, "width": 2},
                              "thickness": .75, "value": sc_val},
            },
            title={"text": T("threat_score"),
                   "font": {"family": "Space Grotesk", "size": 11, "color": "#475569"}},
        ))
        fig_g.update_layout(
            paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
            font_color="#94a3b8", height=240,
            margin=dict(t=40, b=20, l=20, r=20)
        )
        st.plotly_chart(fig_g, use_container_width=True)

    with col_info:
        st.markdown('<div class="glass-card"><h3>Infrastructure</h3>', unsafe_allow_html=True)
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
                    f'<div style="display:flex;gap:12px;padding:6px 0;'
                    f'border-bottom:1px solid rgba(255,255,255,0.05);">'
                    f'<span style="font-family:JetBrains Mono,monospace;font-size:.68rem;'
                    f'color:#475569;min-width:100px;text-transform:uppercase;">{lbl}</span>'
                    f'<span style="font-family:Inter,sans-serif;font-size:.82rem;'
                    f'color:#e2e8f0;">{val}</span>'
                    f'</div>', unsafe_allow_html=True
                )
        st.markdown('</div>', unsafe_allow_html=True)

    if score and score.get("contributions"):
        st.markdown('<div class="glass-card"><h3>Engine Contributions</h3>', unsafe_allow_html=True)
        contribs = score["contributions"]
        max_c = max(contribs.values(), default=1)
        for eng, pts in contribs.items():
            pct = int(pts / max_c * 100)
            st.markdown(
                f'<div style="margin-bottom:10px;">'
                f'<div style="display:flex;justify-content:space-between;margin-bottom:4px;">'
                f'<span style="font-family:Inter,sans-serif;font-size:.78rem;color:#94a3b8;">{eng}</span>'
                f'<span style="font-family:Space Grotesk,sans-serif;font-size:.72rem;'
                f'color:{sc_accent};font-weight:600;">{pts:.0f}pts</span>'
                f'</div>'
                f'<div style="background:rgba(255,255,255,0.06);border-radius:4px;height:5px;">'
                f'<div style="background:linear-gradient(90deg,{sc_accent},{sc_accent}88);'
                f'width:{pct}%;height:5px;border-radius:4px;'
                f'box-shadow:0 0 8px {sc_accent}60;transition:width 0.4s ease;"></div>'
                f'</div></div>',
                unsafe_allow_html=True
            )
        st.markdown('</div>', unsafe_allow_html=True)

    ports = shodan.get("ports", [])
    if ports:
        st.markdown(
            f'<div class="glass-card"><h3>Open Ports ({len(ports)})</h3>'
            + " ".join(
                f'<span style="background:rgba(34,211,238,0.08);border:1px solid rgba(34,211,238,0.2);'
                f'border-radius:8px;padding:4px 10px;font-family:JetBrains Mono,monospace;'
                f'font-size:.78rem;color:#22d3ee;display:inline-block;margin:3px;">{p}</span>'
                for p in ports[:40]
            ) + '</div>',
            unsafe_allow_html=True
        )

    vulns = shodan.get("vulns", [])
    if vulns:
        st.markdown(
            f'<div class="glass-card"><h3>CVEs Detected ({len(vulns)})</h3>'
            + " ".join(
                f'<span style="background:rgba(239,68,68,0.08);border:1px solid rgba(239,68,68,0.25);'
                f'border-radius:8px;padding:4px 10px;font-family:JetBrains Mono,monospace;'
                f'font-size:.78rem;color:#ef4444;display:inline-block;margin:3px;">{v}</span>'
                for v in vulns
            ) + '</div>',
            unsafe_allow_html=True
        )

# ══════════════════════════════════════════════════════════════════
# TAB 1 — SIGNALS
# ══════════════════════════════════════════════════════════════════
with tabs[1]:
    signals = []
    def _sig(level, engine, message):
        signals.append({"level": level, "engine": engine, "message": message})

    vt_m  = (results.get("VirusTotal",     {}) or {}).get("malicious", 0) or 0
    ab_s  = (results.get("AbuseIPDB",      {}) or {}).get("abuseConfidenceScore", 0) or 0
    tf_t  = (results.get("ThreatFox",      {}) or {}).get("total", 0) or 0
    uh_c  = (results.get("URLhaus",        {}) or {}).get("urls_count", 0) or 0
    otx_p = (results.get("AlienVault OTX", {}) or {}).get("pulse_count", 0) or 0
    hibp_c= (results.get("HaveIBeenPwned", {}) or {}).get("count", 0) or 0

    if vt_m   > 0:  _sig("CRITICAL" if vt_m > 5 else "HIGH", "VirusTotal",    f"{vt_m} malicious detections")
    if ab_s   > 30: _sig("HIGH" if ab_s > 70 else "MEDIUM",  "AbuseIPDB",     f"Abuse score {ab_s}%")
    if tf_t   > 0:  _sig("HIGH",   "ThreatFox",    f"{tf_t} IOC matches")
    if uh_c   > 0:  _sig("HIGH",   "URLhaus",       f"{uh_c} malicious URLs")
    if otx_p  > 0:  _sig("MEDIUM", "AlienVault OTX", f"{otx_p} threat pulses")
    if hibp_c > 0:  _sig("HIGH",   "HaveIBeenPwned", f"Found in {hibp_c} breaches")

    grey_r = results.get("GreyNoise", {}) or {}
    cip_r  = results.get("CriminalIP",{}) or {}
    ipqs_r = results.get("IPQS",      {}) or {}
    lk_r   = results.get("LeakCheck", {}) or {}

    if grey_r.get("noise"):      _sig("MEDIUM", "GreyNoise",  "Known internet scanner/noise")
    if cip_r.get("is_tor"):      _sig("HIGH",   "CriminalIP", "TOR exit node")
    if cip_r.get("is_scanner"):  _sig("MEDIUM", "CriminalIP", "Active scanner")
    if ipqs_r.get("tor"):        _sig("HIGH",   "IPQS",       "TOR detected")
    if lk_r.get("found") or lk_r.get("result"):
        _sig("HIGH", "LeakCheck", "Credentials in leak DB")

    LEVEL_CFG = {
        "CRITICAL": ("#ef4444", "rgba(239,68,68,0.08)"),
        "HIGH":     ("#f97316", "rgba(249,115,22,0.08)"),
        "MEDIUM":   ("#f59e0b", "rgba(245,158,11,0.08)"),
        "LOW":      ("#10b981", "rgba(16,185,129,0.08)"),
    }

    LEVEL_ICONS = {
        "CRITICAL": "🔴", "HIGH": "🟠", "MEDIUM": "🟡", "LOW": "🟢"
    }

    st.markdown(
        f'<div class="glass-card"><h3>{T("signals_title")} ({len(signals)})</h3></div>',
        unsafe_allow_html=True
    )
    if signals:
        for sig in signals:
            col_s, bg_s = LEVEL_CFG.get(sig["level"], ("#888", "rgba(128,128,128,0.05)"))
            icon = LEVEL_ICONS.get(sig["level"], "⚪")
            st.markdown(
                f'<div class="signal-row" style="border-color:{col_s};background:{bg_s};">'
                f'<span style="font-size:1rem;">{icon}</span>'
                f'<span style="font-family:Space Grotesk,sans-serif;font-size:.72rem;'
                f'color:{col_s};font-weight:700;min-width:72px;">{sig["level"]}</span>'
                f'<span style="font-family:JetBrains Mono,monospace;font-size:.7rem;'
                f'color:#475569;min-width:120px;">{sig["engine"]}</span>'
                f'<span style="font-family:Inter,sans-serif;font-size:.88rem;'
                f'color:#e2e8f0;">{sig["message"]}</span>'
                f'</div>', unsafe_allow_html=True
            )
    else:
        st.success(T("no_signals"))

    st.markdown(
        f'<div class="glass-card" style="margin-top:16px;"><h3>{T("ioc_title")}</h3></div>',
        unsafe_allow_html=True
    )
    if st.session_state.ioc_data and st.session_state.ioc_data["iocs"]:
        ioc_df = pd.DataFrame(st.session_state.ioc_data["iocs"])
        st.dataframe(ioc_df, use_container_width=True, height=260)
    else:
        st.info(T("no_result"))

# ══════════════════════════════════════════════════════════════════
# TAB 2 — TITANAI
# ══════════════════════════════════════════════════════════════════
with tabs[2]:
    st.markdown(
        f'<div class="glass-card"><h3>{T("ai_title")}</h3></div>',
        unsafe_allow_html=True
    )

    if not AI_AVAILABLE:
        st.warning(T("ai_no_key"))
    else:
        if not st.session_state.ai_analysis:
            with st.spinner(T("ai_loading")):
                st.session_state.ai_analysis = ai_analyze(target, ttype, results, lang())

        st.markdown(
            f'<div style="background:rgba(99,102,241,0.06);border:1px solid rgba(99,102,241,0.18);'
            f'border-radius:12px;padding:20px 24px;font-family:Inter,sans-serif;font-size:.92rem;'
            f'color:#e2e8f0;line-height:1.75;max-height:460px;overflow-y:auto;">'
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

        st.markdown(
            '<div style="font-family:Space Grotesk,sans-serif;font-size:.78rem;font-weight:600;'
            'color:#818cf8;letter-spacing:.08em;text-transform:uppercase;margin-bottom:12px;">'
            '💬 TitanAI Chat</div>',
            unsafe_allow_html=True
        )

        for msg in st.session_state.chat_history:
            css_cls = "chat-msg-user" if msg["role"] == "user" else "chat-msg-ai"
            prefix  = "You" if msg["role"] == "user" else "🤖 TitanAI"
            st.markdown(
                f'<div class="{css_cls}"><b style="font-size:.75rem;color:#818cf8;">{prefix}</b>'
                f'<br><span style="font-family:Inter,sans-serif;">{msg["content"]}</span></div>',
                unsafe_allow_html=True
            )

        ci_col, cs_col = st.columns([5, 1])
        with ci_col:
            chat_input = st.text_input("Chat", placeholder=T("chat_ph"),
                                       label_visibility="collapsed", key="chat_in")
        with cs_col:
            chat_send = st.button("Send", key="chat_send", use_container_width=True)

        if chat_send and chat_input.strip():
            ctx = {"target": target, "ttype": ttype,
                   "results": results, "ai_analysis": st.session_state.ai_analysis}
            with st.spinner("TitanAI..."):
                reply = ai_chat(chat_input, ctx, lang())
            st.session_state.chat_history.append({"role": "user",      "content": chat_input})
            st.session_state.chat_history.append({"role": "assistant",  "content": reply})
            st.rerun()

        if st.session_state.chat_history:
            if st.button("🗑️ " + ("مسح" if is_ar() else "Clear Chat"), key="clr_chat"):
                st.session_state.chat_history = []
                st.rerun()

# ══════════════════════════════════════════════════════════════════
# TAB 3 — DEVELOPER
# ══════════════════════════════════════════════════════════════════
with tabs[3]:
    st.markdown(
        f'<div class="glass-card"><h3>{T("dev_title")}</h3></div>',
        unsafe_allow_html=True
    )

    gh_d  = results.get("GitHub",  {}) or {}
    cr_d  = results.get("CertSH",  {}) or {}
    wb_d  = results.get("Wayback", {}) or {}
    npm_d = results.get("NPM",     {}) or {}
    py_d  = results.get("PyPI",    {}) or {}

    dc1, dc2 = st.columns(2)

    with dc1:
        if gh_d and "error" not in gh_d and gh_d.get("login"):
            st.markdown('<div class="glass-card"><h3>GitHub</h3>', unsafe_allow_html=True)
            for k, v in gh_d.items():
                if k == "top_repos":
                    for repo in (v or []):
                        st.markdown(
                            f'<div style="padding:6px 0;border-bottom:1px solid rgba(255,255,255,0.05);">'
                            f'<code style="color:#818cf8;">{repo.get("name")}</code> '
                            f'⭐{repo.get("stars",0)} '
                            f'<span style="color:#475569;font-size:.75rem;">[{repo.get("language","?")}]</span>'
                            f'</div>', unsafe_allow_html=True
                        )
                elif v not in ("N/A", None, "", 0):
                    st.markdown(
                        f'<div style="display:flex;gap:8px;padding:4px 0;">'
                        f'<span style="color:#475569;font-size:.75rem;min-width:90px;">{k}</span>'
                        f'<code style="color:#e2e8f0;font-size:.8rem;">{v}</code>'
                        f'</div>', unsafe_allow_html=True
                    )
            st.markdown('</div>', unsafe_allow_html=True)

        if npm_d and "error" not in npm_d and npm_d.get("name"):
            st.markdown('<div class="glass-card"><h3>NPM Package</h3>', unsafe_allow_html=True)
            for k, v in npm_d.items():
                if k == "dependencies_sample":
                    if v:
                        st.markdown(
                            f'<span style="color:#475569;font-size:.75rem;">deps</span> '
                            f'<code style="color:#22d3ee;">{", ".join(v[:8])}</code>',
                            unsafe_allow_html=True
                        )
                elif v not in ("N/A", None, ""):
                    st.markdown(
                        f'<div style="display:flex;gap:8px;padding:4px 0;">'
                        f'<span style="color:#475569;font-size:.75rem;min-width:90px;">{k}</span>'
                        f'<code style="color:#e2e8f0;font-size:.8rem;">{v}</code>'
                        f'</div>', unsafe_allow_html=True
                    )
            st.markdown('</div>', unsafe_allow_html=True)

        if py_d and "error" not in py_d and py_d.get("name"):
            st.markdown('<div class="glass-card"><h3>PyPI Package</h3>', unsafe_allow_html=True)
            for k, v in py_d.items():
                if v not in ("N/A", None, ""):
                    st.markdown(
                        f'<div style="display:flex;gap:8px;padding:4px 0;">'
                        f'<span style="color:#475569;font-size:.75rem;min-width:90px;">{k}</span>'
                        f'<code style="color:#e2e8f0;font-size:.8rem;">{v}</code>'
                        f'</div>', unsafe_allow_html=True
                    )
            st.markdown('</div>', unsafe_allow_html=True)

    with dc2:
        if cr_d and "error" not in cr_d and cr_d.get("total_certs", 0) > 0:
            st.markdown('<div class="glass-card"><h3>SSL Certs (crt.sh)</h3>', unsafe_allow_html=True)
            st.markdown(
                f'<div style="display:flex;gap:16px;margin-bottom:10px;">'
                f'<span style="color:#475569;font-size:.78rem;">Total</span>'
                f'<code style="color:#818cf8;">{cr_d.get("total_certs",0)}</code>'
                f'<span style="color:#475569;font-size:.78rem;">Unique domains</span>'
                f'<code style="color:#818cf8;">{cr_d.get("unique_domains",0)}</code>'
                f'</div>', unsafe_allow_html=True
            )
            for d in (cr_d.get("sample_domains") or [])[:12]:
                st.markdown(
                    f'<code style="color:#22d3ee;font-size:.78rem;display:block;'
                    f'padding:2px 0;">{d}</code>',
                    unsafe_allow_html=True
                )
            st.markdown('</div>', unsafe_allow_html=True)

        if wb_d and "error" not in wb_d:
            st.markdown('<div class="glass-card"><h3>Wayback Machine</h3>', unsafe_allow_html=True)
            st.markdown(
                f'<div style="margin-bottom:8px;">'
                f'<span style="color:#475569;font-size:.75rem;">Available: </span>'
                f'<code style="color:#10b981;">{wb_d.get("available","N/A")}</code>'
                f'</div>', unsafe_allow_html=True
            )
            for snap in (wb_d.get("recent_snapshots") or [])[:5]:
                st.markdown(
                    f'<div style="padding:4px 0;border-bottom:1px solid rgba(255,255,255,0.05);">'
                    f'<code style="color:#818cf8;font-size:.72rem;">{snap.get("ts","")}</code>'
                    f' <span style="color:#475569;font-size:.72rem;">HTTP {snap.get("status","")}</span>'
                    f'</div>', unsafe_allow_html=True
                )
            st.markdown('</div>', unsafe_allow_html=True)

    if not any([gh_d.get("login"), cr_d.get("total_certs"),
                wb_d.get("available"), npm_d.get("name"), py_d.get("name")]):
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
                color="#6366f1", fill=True, fill_color="#818cf8", fill_opacity=0.7,
                popup=f"{target} | {ipinf_g.get('city','')}, {ipinf_g.get('country','')}"
            ).add_to(m)
            folium.Circle(
                location=[lat, lon], radius=50000,
                color="rgba(99,102,241,0.3)", fill=True, fill_color="rgba(99,102,241,0.05)"
            ).add_to(m)
            st_folium(m, width="100%", height=430)

            geo_info = {
                "City":     ipinf_g.get("city",    "N/A"),
                "Region":   ipinf_g.get("region",  "N/A"),
                "Country":  ipinf_g.get("country", "N/A"),
                "Org":      ipinf_g.get("org",     "N/A"),
                "Timezone": ipinf_g.get("timezone","N/A"),
                "Lat/Lon":  f"{lat}, {lon}",
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
    nodes = [{"id": target, "label": target, "color": tc, "size": 30}]
    edges = []

    connectors = {
        "Shodan":         ("hostnames",     "#818cf8"),
        "SecurityTrails": ("a_records",     "#22d3ee"),
        "CertSH":         ("sample_domains","#f59e0b"),
        "Robtex":         ("records",       "#ec4899"),
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
                    mode="lines",
                    line=dict(color="rgba(99,102,241,0.2)", width=1.5),
                    hoverinfo="none", showlegend=False,
                ))
        fig_net.add_trace(go.Scatter(
            x=node_x, y=node_y, mode="markers+text",
            marker=dict(
                size=[n["size"] for n in nodes],
                color=[n["color"] for n in nodes],
                line=dict(color="rgba(255,255,255,0.1)", width=1),
                opacity=0.9,
            ),
            text=[n["label"][:20] for n in nodes],
            textposition="top center",
            textfont=dict(family="Inter", size=10, color="#94a3b8"),
            hovertext=[n["id"] for n in nodes], hoverinfo="text", showlegend=False,
        ))
        fig_net.update_layout(
            paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
            xaxis=dict(showgrid=False, zeroline=False, showticklabels=False),
            yaxis=dict(showgrid=False, zeroline=False, showticklabels=False),
            height=460, margin=dict(t=20, b=20, l=20, r=20),
        )
        st.plotly_chart(fig_net, use_container_width=True)
    else:
        st.info(T("graph_no_data"))

# ══════════════════════════════════════════════════════════════════
# TAB 6 — RAW DATA
# ══════════════════════════════════════════════════════════════════
with tabs[6]:
    st.markdown(
        f'<div class="glass-card"><h3>{T("engine_results")}</h3></div>',
        unsafe_allow_html=True
    )

    flt = st.text_input("Filter", placeholder="🔍 Filter engines...",
                        label_visibility="collapsed", key="raw_flt")

    for eng, data in sorted(results.items()):
        if flt and flt.lower() not in eng.lower():
            continue
        has_err   = isinstance(data, dict) and "error" in data
        badge_col = "#ef4444" if has_err else "#10b981"
        badge_bg  = "rgba(239,68,68,0.1)" if has_err else "rgba(16,185,129,0.1)"
        badge_txt = "ERR" if has_err else "OK"
        with st.expander(f"  {eng}", expanded=False):
            st.markdown(
                f'<div style="display:flex;align-items:center;gap:8px;margin-bottom:8px;">'
                f'<span style="background:{badge_bg};border:1px solid {badge_col}40;'
                f'border-radius:6px;padding:2px 8px;font-family:JetBrains Mono,monospace;'
                f'font-size:.65rem;color:{badge_col};">{badge_txt}</span>'
                f'<span style="font-family:Inter,sans-serif;font-size:.8rem;color:#94a3b8;">{eng}</span>'
                f'</div>', unsafe_allow_html=True
            )
            st.markdown(
                f'<pre style="background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.06);'
                f'border-radius:10px;padding:14px;font-family:JetBrains Mono,monospace;font-size:.76rem;'
                f'color:#94a3b8;overflow-x:auto;white-space:pre-wrap;max-height:300px;overflow-y:auto;">'
                f'{json.dumps(data, ensure_ascii=False, indent=2)[:3000]}</pre>',
                unsafe_allow_html=True
            )

    st.markdown("<hr>", unsafe_allow_html=True)
    st.markdown(
        '<div style="font-family:Space Grotesk,sans-serif;font-size:.78rem;font-weight:600;'
        'color:#818cf8;letter-spacing:.08em;text-transform:uppercase;margin-bottom:10px;">'
        '📝 Analyst Notes</div>',
        unsafe_allow_html=True
    )
    for note in get_notes(target):
        st.markdown(
            f'<div style="background:rgba(99,102,241,0.06);border:1px solid rgba(99,102,241,0.15);'
            f'border-radius:10px;padding:10px 14px;margin-bottom:8px;font-family:Inter,sans-serif;'
            f'font-size:.85rem;color:#cbd5e1;">{note[2]}</div>',
            unsafe_allow_html=True
        )
    note_txt = st.text_area("Note", placeholder=T("notes_ph"),
                            label_visibility="collapsed", key="note_txt", height=80)
    if st.button(T("save_note"), key="save_note_btn"):
        if note_txt.strip():
            add_note(target, note_txt.strip())
            st.toast(T("note_saved"), icon="💾")
            st.rerun()

# ══════════════════════════════════════════════════════════════════
# TAB 7 — HISTORY / STATS
# ══════════════════════════════════════════════════════════════════
with tabs[7]:
    st.markdown(
        f'<div class="glass-card"><h3>{T("history_title")}</h3></div>',
        unsafe_allow_html=True
    )

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
    st.markdown(
        f'<div class="glass-card"><h3>{T("mitre_title")}</h3></div>',
        unsafe_allow_html=True
    )

    techniques = []
    if st.session_state.ai_analysis:
        techniques = extract_mitre(st.session_state.ai_analysis)

    for eng in ["ThreatFox", "AlienVault OTX", "Pulsedive"]:
        extra    = extract_mitre(json.dumps(results.get(eng, {}) or {}))
        existing = {t["id"] for t in techniques}
        for t in extra:
            if t["id"] not in existing:
                techniques.append(t)

    if techniques:
        for tech in techniques:
            st.markdown(
                f'<div style="display:flex;align-items:center;gap:12px;padding:10px 14px;'
                f'background:rgba(249,115,22,0.06);border:1px solid rgba(249,115,22,0.2);'
                f'border-radius:var(--radius-md);margin-bottom:8px;">'
                f'<span style="font-family:Space Grotesk,sans-serif;font-size:.82rem;'
                f'color:#f97316;font-weight:700;min-width:90px;">{tech["id"]}</span>'
                f'<a href="{tech["url"]}" target="_blank" style="font-family:JetBrains Mono,monospace;'
                f'font-size:.75rem;color:#818cf8;text-decoration:none;'
                f'word-break:break-all;">{tech["url"]}</a>'
                f'</div>', unsafe_allow_html=True
            )

        mitre_csv = "technique_id,url\n" + "\n".join(f'{t["id"]},{t["url"]}' for t in techniques)
        st.download_button(T("dl_mitre"), mitre_csv, f"{target}_mitre.csv", "text/csv")

        if len(techniques) >= 3:
            cats  = [t["id"] for t in techniques[:8]]
            fig_r = go.Figure(go.Scatterpolar(
                r=[1] * len(cats) + [1],
                theta=cats + [cats[0]],
                fill="toself",
                fillcolor="rgba(249,115,22,0.1)",
                line=dict(color="#f97316", width=2),
            ))
            fig_r.update_layout(
                polar=dict(
                    bgcolor="rgba(0,0,0,0)",
                    radialaxis=dict(visible=False),
                    angularaxis=dict(
                        tickfont=dict(size=10, color="#94a3b8"),
                        color="#475569"
                    )
                ),
                paper_bgcolor="rgba(0,0,0,0)", plot_bgcolor="rgba(0,0,0,0)",
                height=360, margin=dict(t=20, b=20, l=40, r=40), showlegend=False,
            )
            st.plotly_chart(fig_r, use_container_width=True)
    else:
        if not st.session_state.ai_analysis:
            st.info("قم بفتح تبويب TitanAI أولاً لاستخراج تقنيات MITRE" if is_ar()
                    else "Open the TitanAI tab first to extract MITRE techniques")
        else:
            st.info(T("no_mitre"))
