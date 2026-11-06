#!/usr/bin/env python3
"""Keep hosted community disclosures identical to the in-app policy copy."""
import argparse
import html
import re
from pathlib import Path


def paragraphs(text: str) -> str:
    def escape(value: str) -> str:
        value = html.escape(value)
        value = value.replace('https://canturhan.github.io/watchloom/community.html',
                              '<a href="community.html">Community guidelines / Topluluk kuralları</a>')
        return value.replace('can.turhan.web@gmail.com',
                             '<a href="mailto:can.turhan.web@gmail.com">can.turhan.web@gmail.com</a>')
    return '\n'.join(f'<p>{escape(p)}</p>' for p in text.split('\n\n'))


def update_block(text: str, marker: str, body: str, anchor: str) -> str:
    pattern = re.compile(rf'<!-- {marker}:start -->.*?<!-- {marker}:end -->\n?', re.S)
    block = f'<!-- {marker}:start -->\n{body}\n<!-- {marker}:end -->\n'
    if pattern.search(text):
        return pattern.sub(lambda _: block, text)
    if anchor not in text:
        raise ValueError(f'Missing legal-page anchor for {marker}')
    return text.replace(anchor, block + anchor, 1)


def generated(project: Path) -> dict[Path, str]:
    source = (project / 'lib/core/legal/community_policy.dart').read_text()
    copy = dict(re.findall(r"static const (privacyEn|privacyTr|termsEn|termsTr) = '''(.*?)''';", source, re.S))
    if len(copy) != 4:
        raise ValueError('All four in-app community notices must be present')
    outputs = {}
    privacy_path = project / 'docs/privacy.html'
    privacy = privacy_path.read_text()
    for language, label, anchor in [('En', 'Community discussions', '<p>Watchloom is not directed at children'),
                                    ('Tr', 'Topluluk tartışmaları', '<p>Watchloom 13 yaş altındaki')]:
        privacy = update_block(privacy, f'community-privacy-{language.lower()}',
                               f'<h2>{label}</h2>\n{paragraphs(copy["privacy" + language])}', anchor)
    outputs[privacy_path] = privacy
    terms_path = project / 'docs/terms.html'
    terms = terms_path.read_text()
    for language, label, anchor in [('En', 'Community', '<p>Apple Standard EULA:'),
                                    ('Tr', 'Topluluk', '<p>Apple Standart EULA:')]:
        terms = update_block(terms, f'community-terms-{language.lower()}',
                             f'<h2>{label}</h2>\n{paragraphs(copy["terms" + language])}', anchor)
    outputs[terms_path] = terms
    body = '\n'.join(f'<section class="section" lang="{lang}"><h2>{title}</h2>'
                     f'{paragraphs(copy["terms" + key])}<h3>{privacy_title}</h3>'
                     f'{paragraphs(copy["privacy" + key])}</section>'
                     for lang, key, title, privacy_title in [('en', 'En', 'Community guidelines', 'Privacy'),
                       ('tr', 'Tr', 'Topluluk kuralları', 'Gizlilik')])
    outputs[project / 'docs/community.html'] = '''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Community guidelines — Watchloom</title><link rel="stylesheet" href="styles.css"></head>
<body><header><nav><a class="brand" href="./">Watchloom</a><div class="nav-links">
<a href="support.html">Support</a><a href="privacy.html">Privacy</a><a href="terms.html">Terms</a></div></nav></header>
<main><div class="page-title"><h1>Community / Topluluk</h1><p>2026-11-05</p></div>''' + body + '''</main>
<footer><a href="support.html">Report a safety concern / Güvenlik bildirimi</a> · <a href="licenses.html">Software notices</a></footer></body></html>
'''
    return outputs


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    for path, content in generated(project).items():
        if args.check:
            if not path.exists() or path.read_text() != content:
                raise SystemExit(f'Community legal notice is stale: {path.relative_to(project)}')
        else:
            path.write_text(content)
    print('In-app and hosted community notices match.')


if __name__ == '__main__':
    main()
