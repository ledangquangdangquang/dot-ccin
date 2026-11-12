#!/usr/bin/env python3
"""Static server for the new tab page, plus /feeds.json (news fetched server-side: the feeds send no CORS headers)."""
import html
import json
import os
import re
import sys
import threading
import time
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from email.utils import parsedate_to_datetime
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get("NEWTAB_PORT", "8918"))
DIRECTORY = os.environ.get("NEWTAB_DIR", os.path.expanduser("~/.config/newtab"))
UA = "newtab-feed/1.0 (personal start page)"
TTL = 15 * 60  # seconds a fetched set of feeds is reused


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=10) as res:
        return res.read().decode("utf-8", "replace")


def text(markup):
    return " ".join(html.unescape(re.sub(r"<[^>]+>", " ", markup or "")).split())


def timestamp(value):
    try:
        return int(parsedate_to_datetime(value).timestamp())  # RSS: RFC 822
    except (TypeError, ValueError):
        try:
            return int(datetime.fromisoformat(value).timestamp())  # Atom: ISO 8601
        except (TypeError, ValueError):
            return None


def rss(url, limit, desc=False):
    """Items of an RSS 2.0 or Atom feed."""
    items = []
    for node in ET.fromstring(get(url)).iter():
        if node.tag.rsplit("}", 1)[-1] not in ("item", "entry"):
            continue
        field = {child.tag.rsplit("}", 1)[-1]: child for child in node}
        link = field.get("link")
        item = {
            "title": text(field["title"].text),
            "url": (link.text or link.get("href") or "").strip(),
            "ts": timestamp(next((field[k].text for k in ("pubDate", "updated", "published") if k in field), None)),
        }
        if desc and "description" in field:
            item["desc"] = text(field["description"].text)
        items.append(item)
        if len(items) == limit:
            break
    return items


def github():
    # shortcut: scrapes the trending page (no API exists), breaks if GitHub changes its markup
    def find(pattern, block):
        match = re.search(pattern, block, re.S)
        return text(match.group(1)) if match else ""

    items = []
    for block in re.findall(r'<article class="Box-row">(.*?)</article>', get("https://github.com/trending?since=daily"), re.S):
        block = re.sub(r"<svg.*?</svg>", "", block, flags=re.S)
        repo = find(r'<h2[^>]*>\s*<a[^>]*href="/([^"]+)"', block)
        if repo:
            items.append({
                "title": repo,
                "url": "https://github.com/" + repo,
                "desc": find(r'<p class="col-9[^>]*>(.*?)</p>', block),
                "lang": find(r'itemprop="programmingLanguage">([^<]+)', block),
                "stars": find(r'/stargazers"[^>]*>\s*([\d,]+)', block),
                "today": find(r"([\d,]+) stars today", block),
            })
    return items[:10]


def hackernews():
    hits = json.loads(get("https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage=30"))["hits"]
    hits.sort(key=lambda hit: hit.get("points") or 0, reverse=True)
    return [
        {
            "title": hit.get("title") or "",
            "discuss": "https://news.ycombinator.com/item?id=" + hit["objectID"],
            "url": hit.get("url") or "https://news.ycombinator.com/item?id=" + hit["objectID"],
            "points": hit.get("points"),
            "comments": hit.get("num_comments"),
        }
        for hit in hits[:12]
    ]


def trendshift():
    # shortcut: scrapes the home page (no feed exists), breaks if Trendshift changes its markup
    items = []
    for block in get("https://trendshift.io/").split('<div class="hover:bg-accent group relative')[1:]:
        match = re.search(r'href="/repositories/\d+">([\w.-]+/[\w.-]+)<', block)
        stars = re.search(r'font-medium">([\d.,]+[kKmM]?)</span>', block)
        if match and all(item["title"] != match.group(1) for item in items):
            items.append({
                "title": match.group(1),
                "url": "https://github.com/" + match.group(1),
                "stars": stars.group(1) if stars else "",
            })
    return items[:10]


def world():
    items = rss("https://news.google.com/rss/headlines/section/topic/WORLD?hl=en-US&gl=US&ceid=US:en", 12)
    for item in items:  # Google News titles end in " - Publisher"
        item["title"], _, item["source"] = item["title"].rpartition(" - ") if " - " in item["title"] else (item["title"], "", "")
    return items


SOURCES = {
    "vnexpress": lambda: rss("https://vnexpress.net/rss/khoa-hoc-cong-nghe.rss", 7, desc=True),
    "hn": hackernews,
    "github": github,
    # Google News stands in for r/worldnews: Reddit refuses both this server and cross-origin browser requests
    "world": world,
    "trendshift": trendshift,
    "arch": lambda: rss("https://archlinux.org/feeds/news/", 5),
}

cache = {name: {"items": [], "error": None} for name in SOURCES}
fetched_at = 0
lock = threading.Lock()


def refresh(name):
    try:
        items = SOURCES[name]()
        if not items:
            raise ValueError("no items parsed")
        cache[name] = {"items": items, "error": None}
    except Exception as error:  # one dead source must not blank the page: keep its last good items
        cache[name]["error"] = f"{type(error).__name__}: {error}"


def feeds():
    global fetched_at
    with lock:
        if time.time() - fetched_at > TTL:
            with ThreadPoolExecutor(len(SOURCES)) as pool:
                list(pool.map(refresh, SOURCES))
            fetched_at = time.time()
        return {"at": int(fetched_at), "feeds": cache}


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        if self.path.split("?")[0] != "/feeds.json":
            return super().do_GET()
        body = json.dumps(feeds(), ensure_ascii=False).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


if __name__ == "__main__":
    if sys.argv[1:] == ["--check"]:  # self-check: every source should parse into titled http(s) links
        for name, feed in feeds()["feeds"].items():
            ok = all(item["title"] and item["url"].startswith("http") for item in feed["items"])
            print(f"{name:10} {len(feed['items']):2} items  {'ok' if ok and feed['items'] else 'FAIL'}  {feed['error'] or ''}")
        sys.exit(0)
    os.chdir(DIRECTORY)
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
