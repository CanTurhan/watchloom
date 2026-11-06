#!/usr/bin/env python3
"""Publish complete runtime dependency notices, preserving bundled originals.

Run after `flutter pub get` and sync_ios_licenses.py. No license text is shortened
or translated. Paths, credentials and application source are never published.
"""
import argparse
import html
import json
from pathlib import Path
from urllib.parse import unquote, urlparse


def collect(project: Path) -> list[dict[str, str]]:
    config_path = project / '.dart_tool/package_config.json'
    config = json.loads(config_path.read_text())
    graph = json.loads((project / '.dart_tool/package_graph.json').read_text())
    packages = {p['name']: p for p in graph['packages']}
    pending = list(packages[graph['roots'][0]]['dependencies'])
    runtime = set()
    while pending:
        name = pending.pop()
        if name in runtime:
            continue
        runtime.add(name)
        pending.extend(packages[name]['dependencies'])
    locations = {p['name']: p['rootUri'] for p in config['packages']}
    sdk = Path(unquote(urlparse(config['flutterRoot']).path))
    records = []
    for name in sorted(runtime):
        uri = locations[name]
        root = (Path(unquote(urlparse(uri).path)) if uri.startswith('file:')
                else (config_path.parent / unquote(uri)).resolve())
        notices = sorted(p for p in root.iterdir() if p.is_file()
                         and p.name.upper().split('.')[0] in ('LICENSE', 'LICENCE', 'NOTICE', 'COPYING'))
        if not notices and root.is_relative_to(sdk / 'packages'):
            notices = [sdk / 'LICENSE']
        if not notices:
            raise ValueError(f'Missing license notice for runtime package {name}')
        for notice in notices:
            text = notice.read_text(encoding='utf-8')
            if not text.strip():
                raise ValueError(f'Empty license notice for {name}')
            records.append({'name': name, 'version': packages[name]['version'],
                            'source': notice.name, 'text': text})
    for record in json.loads((project / 'assets/legal/ios_licenses.json').read_text()):
        records.append({'name': record['name'], 'version': 'iOS native SDK',
                        'source': 'CocoaPods acknowledgement', 'text': record['text']})
    return records


def render(records: list[dict[str, str]]) -> str:
    sections = []
    for index, record in enumerate(records):
        sections.append(f'<details id="notice-{index}"><summary>{html.escape(record["name"])} '
                        f'<small>{html.escape(record["version"])}</small></summary>'
                        f'<pre>{html.escape(record["text"])}</pre></details>')
    return '''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Software notices — Watchloom</title><link rel="stylesheet" href="styles.css">
<style>details{margin:12px 0;border:1px solid var(--border);border-radius:14px;padding:16px}
summary{cursor:pointer;font-weight:700}small{color:var(--muted);margin-left:10px}
pre{white-space:pre-wrap;overflow-wrap:anywhere;font:12px/1.7 ui-monospace,monospace;color:var(--muted)}
@media print{details{break-inside:avoid}details>pre{display:block!important}}</style></head>
<body><header><nav><a class="brand" href="./">Watchloom</a><div class="nav-links">
<a href="support.html">Support</a><a href="privacy.html">Privacy</a><a href="terms.html">Terms</a></div></nav></header>
<main><section class="section"><h1>Software notices</h1>
<p>Third-party licenses and acknowledgements for the Watchloom iOS application. Original notices are reproduced below without translation or abbreviation. The app also retains bundled notices for offline access.</p>
<p lang="tr">Watchloom iOS uygulamasının üçüncü taraf yazılım lisansları ve bildirimleri. Aşağıdaki özgün metinler çevrilmeden veya kısaltılmadan sunulur. Çevrimdışı erişim için uygulamayla dağıtılan bildirimler de korunur.</p>
<p><a href="software-notices.txt" download>Download full notices / Tüm bildirimleri indir</a></p>
<p>TVmaze metadata attribution is described in the <a href="terms.html">Terms</a>. These notices do not grant rights to television artwork or change the Watchloom application license.</p>
</section><section class="section">''' + '\n'.join(sections) + '''</section></main>
<footer><a href="./">Watchloom</a> · <a href="community.html">Community guidelines</a> · <a href="support.html">Support</a></footer></body></html>
'''


def outputs(project: Path) -> dict[Path, str]:
    records = collect(project)
    text = '\n\n'.join(f'{"=" * 72}\n{r["name"]} — {r["version"]}\n{r["text"]}' for r in records) + '\n'
    return {project / 'docs/licenses.html': render(records),
            project / 'docs/software-notices.txt': text}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    for target, content in outputs(project).items():
        if args.check:
            if not target.exists() or target.read_text() != content:
                raise SystemExit(f'Hosted license notices are stale: {target.relative_to(project)}')
        else:
            target.write_text(content, encoding='utf-8')
    print('Complete runtime/native license notices verified.' if args.check else
          'Complete runtime/native license notices generated; bundled notices retained.')


if __name__ == '__main__':
    main()
