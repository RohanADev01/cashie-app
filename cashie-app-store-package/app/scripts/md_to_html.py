#!/usr/bin/env python3
"""Render the marketing markdown set into self-contained HTML pages + a small index.
Minimal black-and-white style with an auto-generated table of contents."""
import html
import sys
from pathlib import Path

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>__TITLE__</title>
<style>
  html { -webkit-text-size-adjust: 100%; scroll-behavior: smooth; }
  body {
    margin: 0;
    background: #fff;
    color: #000;
    font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif;
  }
  .nav {
    border-bottom: 1px solid #000;
    padding: 16px 48px;
    display: flex; gap: 18px; flex-wrap: wrap;
    font-size: 13px;
  }
  .nav a { color: #000; text-decoration: none; }
  .nav a.current { text-decoration: underline; }
  .nav a:hover { text-decoration: underline; }

  main { max-width: none; margin: 0; padding: 32px 48px 96px; }
  @media (max-width: 720px) {
    .nav { padding: 12px 16px; }
    main { padding: 24px 16px 64px; }
  }

  /* Table of contents */
  .toc {
    border: 1px solid #000;
    padding: 18px 20px 20px;
    margin: 0 0 36px;
  }
  .toc > summary {
    list-style: none;
    cursor: pointer;
    font-weight: 700;
    font-size: 13px;
    letter-spacing: 0.08em;
    text-transform: uppercase;
  }
  .toc > summary::-webkit-details-marker { display: none; }
  .toc > summary::after {
    content: " [hide]";
    font-weight: 400;
    color: #666;
    font-size: 11px;
    letter-spacing: 0;
    text-transform: none;
  }
  .toc:not([open]) > summary::after { content: " [show]"; }
  .toc-inner {
    columns: 3 280px;
    column-gap: 28px;
    margin-top: 16px;
    font-size: 13px;
    line-height: 1.5;
  }
  .toc-group {
    break-inside: avoid-column;
    page-break-inside: avoid;
    margin-bottom: 14px;
  }
  .toc-inner a {
    display: block;
    text-decoration: none;
    color: #000;
    padding: 1px 0;
  }
  .toc-inner a:hover { text-decoration: underline; }
  .toc-l2 { font-weight: 700; }
  .toc-l3 { padding-left: 12px; color: #333; }
  .toc-l4 { padding-left: 24px; color: #555; font-size: 12px; }

  /* Markdown body */
  h1, h2, h3, h4, h5, h6 { font-weight: 700; line-height: 1.25; margin: 1.6em 0 0.6em; }
  h1 { font-size: 28px; margin-top: 0; }
  h2 { font-size: 22px; border-top: 1px solid #000; padding-top: 1em; }
  h3 { font-size: 18px; }
  h4 { font-size: 16px; }
  p, ul, ol, blockquote, table, pre { margin: 0 0 1em; }
  ul, ol { padding-left: 1.4em; }
  li { margin: 0.2em 0; }
  blockquote {
    border-left: 2px solid #000;
    padding: 0 0 0 16px;
    color: #333;
    margin: 1em 0;
  }
  hr { border: 0; border-top: 1px solid #000; margin: 2em 0; }
  a { color: #000; }
  code {
    font: 13px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace;
    background: #f2f2f2;
    padding: 1px 5px;
    border-radius: 2px;
  }
  pre {
    background: #f2f2f2;
    padding: 14px 16px;
    overflow-x: auto;
    border-radius: 2px;
  }
  pre code { background: transparent; padding: 0; }
  table { width: 100%; border-collapse: collapse; font-size: 14px; }
  th, td { border: 1px solid #000; padding: 8px 10px; text-align: left; vertical-align: top; }
  th { font-weight: 700; }
  img { max-width: 100%; }
  strong { font-weight: 700; }
  em { font-style: italic; }
</style>
</head>
<body>
  <div class="nav">__NAV__</div>
  <main>
    <details id="toc" class="toc" open>
      <summary>Contents</summary>
      <div id="toc-inner" class="toc-inner"></div>
    </details>
    <article id="content">Loading...</article>
  </main>
  <script id="md-source" type="text/markdown">__SOURCE__</script>
  <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
  <script>
    const src = document.getElementById('md-source').textContent;
    marked.setOptions({ gfm: true, breaks: false, headerIds: true, mangle: false });
    document.getElementById('content').innerHTML = marked.parse(src);

    // Tag concept entries (bold leading like "A1.", "X1.") with stable IDs.
    document.querySelectorAll('#content li > strong:first-child').forEach(s => {
      const m = s.textContent.trim().match(/^([A-Z]\\d+)\\./);
      if (m) {
        const li = s.parentElement;
        if (li && !li.id) li.id = 'c-' + m[1].toLowerCase();
      }
    });

    // Build TOC: H2 = section, H3 = subsection, concept-li = leaf.
    const walker = document.querySelectorAll('#content h2, #content h3, #content li[id^="c-"]');
    const tocInner = document.getElementById('toc-inner');
    let html = '';
    let group = '';
    const flush = () => { if (group) { html += '<div class="toc-group">' + group + '</div>'; group = ''; } };
    walker.forEach(el => {
      const text = el.tagName === 'LI'
        ? el.querySelector(':scope > strong:first-child').textContent.trim()
        : el.textContent.trim();
      if (el.tagName === 'H2') {
        flush();
        group = '<a class="toc-l2" href="#' + el.id + '">' + text + '</a>';
      } else if (el.tagName === 'H3') {
        if (!group) group = '';
        group += '<a class="toc-l3" href="#' + el.id + '">' + text + '</a>';
      } else if (el.tagName === 'LI') {
        if (!group) group = '';
        group += '<a class="toc-l4" href="#' + el.id + '">' + text + '</a>';
      }
    });
    flush();
    tocInner.innerHTML = html || '<em>No sections found.</em>';
  </script>
</body>
</html>
"""

INDEX = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Cashie Marketing</title>
<style>
  body {
    margin: 0;
    background: #fff;
    color: #000;
    font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif;
  }
  main { max-width: none; margin: 0; padding: 48px 48px 96px; }
  @media (max-width: 720px) { main { padding: 32px 16px 64px; } }
  h1 { font-size: 28px; margin: 0 0 8px; }
  .lede { margin: 0 0 40px; color: #333; }
  ul { list-style: none; padding: 0; margin: 0; }
  li { border-top: 1px solid #000; }
  li:last-child { border-bottom: 1px solid #000; }
  a {
    display: block;
    padding: 18px 0;
    color: #000;
    text-decoration: none;
  }
  a:hover { background: #f2f2f2; padding-left: 8px; padding-right: 8px; }
  .title { font-weight: 700; font-size: 17px; }
  .summary { color: #333; font-size: 14px; margin-top: 4px; }
  .meta { color: #888; font-size: 12px; margin-top: 6px; }
  footer { margin-top: 48px; color: #888; font-size: 12px; }
</style>
</head>
<body>
  <main>
    <h1>Cashie Marketing</h1>
    <p class="lede">Three docs. Each page has a table of contents at the top.</p>
    <ul>__CARDS__</ul>
    <footer>Generated 2026-05-18. Regenerate with <code>scripts/md_to_html.py</code>.</footer>
  </main>
</body>
</html>
"""

DOCS = [
    {
        "src": "CMO_BRIEF.md",
        "out": "CMO_BRIEF.html",
        "title": "CMO Operating Brief",
        "summary": "ICP, creative principles, analytics blueprint, 53 Higgsfield reel concepts.",
    },
    {
        "src": "MARKETING_GAMEPLAN.md",
        "out": "MARKETING_GAMEPLAN.html",
        "title": "Marketing Game Plan",
        "summary": "90-day plan: goals, channels, budget, calendar, decision rules, risks.",
    },
    {
        "src": "SESSION_PROMPT.md",
        "out": "SESSION_PROMPT.html",
        "title": "Session Prompt",
        "summary": "The kickoff brief that produced everything else.",
    },
]

def nav_for(current: str) -> str:
    parts = ['<a href="index.html">Index</a>']
    for d in DOCS:
        cls = " class=\"current\"" if d["out"] == current else ""
        parts.append(f'<a href="{d["out"]}"{cls}>{html.escape(d["title"])}</a>')
    return "".join(parts)

def render_doc(base: Path, doc: dict) -> None:
    src = (base / doc["src"]).read_text(encoding="utf-8")
    safe = src.replace("</script", "<\\/script")
    page = (PAGE
            .replace("__TITLE__", html.escape(doc["title"]))
            .replace("__NAV__", nav_for(doc["out"]))
            .replace("__SOURCE__", safe))
    (base / doc["out"]).write_text(page, encoding="utf-8")
    print(f"wrote {base / doc['out']}")

def render_index(base: Path) -> None:
    cards = []
    for d in DOCS:
        path = base / d["src"]
        lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
        meta = f"{len(lines)} lines · {d['src']}"
        cards.append(
            f'<li><a href="{d["out"]}">'
            f'<div class="title">{html.escape(d["title"])}</div>'
            f'<div class="summary">{html.escape(d["summary"])}</div>'
            f'<div class="meta">{meta}</div>'
            f'</a></li>'
        )
    page = INDEX.replace("__CARDS__", "".join(cards))
    (base / "index.html").write_text(page, encoding="utf-8")
    print(f"wrote {base / 'index.html'}")

if __name__ == "__main__":
    base = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "marketing"
    for d in DOCS:
        render_doc(base, d)
    render_index(base)
