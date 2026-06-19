#!/usr/bin/env python3
"""Render GO_LIVE_RUNBOOK.md into a self-contained GO_LIVE_RUNBOOK.html.

Same minimal black-and-white style as scripts/md_to_html.py: the markdown is
embedded and rendered client-side with marked.js, with an auto-built table of
contents from the H2/H3 headings.

Usage:  python3 scripts/gen_runbook_html.py
"""
from __future__ import annotations

import html
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "GO_LIVE_RUNBOOK.md"
OUT = ROOT / "GO_LIVE_RUNBOOK.html"
TITLE = "Cashie - Go-Live Runbook"

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>__TITLE__</title>
<style>
  html { -webkit-text-size-adjust: 100%; scroll-behavior: smooth; }
  body {
    margin: 0; background: #fff; color: #000;
    font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Helvetica Neue", Arial, sans-serif;
  }
  main { max-width: 900px; margin: 0 auto; padding: 32px 24px 96px; }
  @media (max-width: 720px) { main { padding: 24px 16px 64px; } }

  .toc { border: 1px solid #000; padding: 18px 20px 20px; margin: 0 0 36px; }
  .toc > summary {
    list-style: none; cursor: pointer; font-weight: 700; font-size: 13px;
    letter-spacing: 0.08em; text-transform: uppercase;
  }
  .toc > summary::-webkit-details-marker { display: none; }
  .toc > summary::after { content: " [hide]"; font-weight: 400; color: #666; font-size: 11px; letter-spacing: 0; text-transform: none; }
  .toc:not([open]) > summary::after { content: " [show]"; }
  .toc-inner { columns: 2 280px; column-gap: 28px; margin-top: 16px; font-size: 13px; line-height: 1.5; }
  .toc-group { break-inside: avoid-column; page-break-inside: avoid; margin-bottom: 12px; }
  .toc-inner a { display: block; text-decoration: none; color: #000; padding: 1px 0; }
  .toc-inner a:hover { text-decoration: underline; }
  .toc-l2 { font-weight: 700; }
  .toc-l3 { padding-left: 12px; color: #333; }

  h1, h2, h3, h4 { font-weight: 700; line-height: 1.25; margin: 1.6em 0 0.6em; }
  h1 { font-size: 28px; margin-top: 0; }
  h2 { font-size: 22px; border-top: 1px solid #000; padding-top: 1em; }
  h3 { font-size: 18px; }
  h4 { font-size: 16px; }
  p, ul, ol, blockquote, table, pre { margin: 0 0 1em; }
  ul, ol { padding-left: 1.4em; }
  li { margin: 0.2em 0; }
  blockquote { border-left: 2px solid #000; padding: 0 0 0 16px; color: #333; margin: 1em 0; }
  hr { border: 0; border-top: 1px solid #000; margin: 2em 0; }
  a { color: #000; }
  code { font: 13px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace; background: #f2f2f2; padding: 1px 5px; border-radius: 2px; }
  pre { background: #f2f2f2; padding: 14px 16px; overflow-x: auto; border-radius: 2px; }
  pre code { background: transparent; padding: 0; }
  table { width: 100%; border-collapse: collapse; font-size: 14px; }
  th, td { border: 1px solid #000; padding: 8px 10px; text-align: left; vertical-align: top; }
  th { font-weight: 700; }
  /* GitHub-style task list checkboxes render as plain list items via marked */
  input[type=checkbox] { margin-right: 6px; }
  img { max-width: 100%; }
  strong { font-weight: 700; }
  em { font-style: italic; }
</style>
</head>
<body>
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

    const walker = document.querySelectorAll('#content h2, #content h3');
    const tocInner = document.getElementById('toc-inner');
    let html = '';
    let group = '';
    const flush = () => { if (group) { html += '<div class="toc-group">' + group + '</div>'; group = ''; } };
    walker.forEach(el => {
      const text = el.textContent.trim();
      if (el.tagName === 'H2') { flush(); group = '<a class="toc-l2" href="#' + el.id + '">' + text + '</a>'; }
      else { if (!group) group = ''; group += '<a class="toc-l3" href="#' + el.id + '">' + text + '</a>'; }
    });
    flush();
    tocInner.innerHTML = html || '<em>No sections found.</em>';
  </script>
</body>
</html>
"""


def main() -> None:
    src = SRC.read_text(encoding="utf-8")
    safe = src.replace("</script", "<\\/script")
    page = PAGE.replace("__TITLE__", html.escape(TITLE)).replace("__SOURCE__", safe)
    OUT.write_text(page, encoding="utf-8")
    print(f"Wrote {OUT} ({len(src)} chars of markdown)")


if __name__ == "__main__":
    main()
