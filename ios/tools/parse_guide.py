# Turns the walking guide HTML into bundled app content:
#   Rootwork/Resources/guide.json    articles (one per section) made of typed blocks
#   Rootwork/Resources/moments.json  "Verses for real moments" -> verse refs (the Sword)
# Usage (repo root): python ios/tools/parse_guide.py path/to/walking-guide.html
import html, json, re, sys
from html.parser import HTMLParser

SRC = sys.argv[1] if len(sys.argv) > 1 else 'ios/tools/walking-guide.html'
OUT = 'ios/Rootwork/Resources/'


class Node:
    def __init__(self, tag, attrs, parent=None):
        self.tag, self.attrs, self.parent, self.kids = tag, dict(attrs), parent, []

    def text(self):
        return ''.join(k if isinstance(k, str) else k.text() for k in self.kids)

    def find_all(self, pred):
        for k in self.kids:
            if isinstance(k, Node):
                if pred(k):
                    yield k
                yield from k.find_all(pred)

    @property
    def cls(self):
        return self.attrs.get('class', '').split()


VOID = {'meta', 'link', 'br', 'img', 'input', 'hr'}


class P(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = self.cur = Node('root', [])

    def handle_starttag(self, tag, attrs):
        n = Node(tag, attrs, self.cur)
        self.cur.kids.append(n)
        if tag not in VOID:
            self.cur = n

    def handle_endtag(self, tag):
        n = self.cur
        while n is not self.root and n.tag != tag:
            n = n.parent
        if n is not self.root:
            self.cur = n.parent

    def handle_data(self, data):
        self.cur.kids.append(data)


def clean(s):
    return re.sub(r'\s+', ' ', html.unescape(s)).strip()


def blocks_of(node):
    out = []
    for k in node.kids:
        if not isinstance(k, Node):
            continue
        c = k.cls
        if k.tag == 'h2':
            continue
        if k.tag == 'p' and 'sec-note' in c:
            continue
        if k.tag == 'div' and 's' in c:
            t = next(k.find_all(lambda n: 't' in n.cls))
            r = next(k.find_all(lambda n: 'r' in n.cls))
            out.append({'type': 'scripture', 'ref': k.attrs.get('data-ref', clean(r.text())),
                        'caption': clean(r.text()), 'text': clean(t.text()).strip('"“”'),
                        'lead': 'lead' in c})
        elif k.tag == 'div' and 'note' in c:
            out.append({'type': 'note', 'text': clean(k.text())})
        elif k.tag == 'div' and 'map' in c:
            out.append({'type': 'map', 'text': html.unescape(k.text())})
        elif k.tag == 'div' and 'two' in c:
            for col in k.kids:
                if isinstance(col, Node):
                    out.extend(blocks_of(col))
        elif k.tag in ('h3', 'h4'):
            out.append({'type': 'heading', 'text': clean(k.text())})
        elif k.tag == 'p':
            out.append({'type': 'paragraph', 'text': clean(k.text()), 'dim': 'dim' in c})
        elif k.tag in ('ul', 'ol'):
            items = [clean(li.text()) for li in k.kids if isinstance(li, Node) and li.tag == 'li']
            out.append({'type': 'steps' if k.tag == 'ol' else 'list', 'items': items})
        elif k.tag == 'dl':
            rows = []
            for row in k.find_all(lambda n: 'row' in n.cls):
                dt = next(row.find_all(lambda n: n.tag == 'dt'))
                dd = next(row.find_all(lambda n: n.tag == 'dd'))
                rows.append({'label': clean(dt.text()), 'text': clean(dd.text())})
            out.append({'type': 'rows', 'rows': rows})
    return out


p = P()
p.feed(open(SRC, encoding='utf-8').read())
root = p.root

header = next(root.find_all(lambda n: n.tag == 'header'))
articles = [{'id': 'start-root', 'title': 'The Root Work', 'note': 'Stay connected. The vine does the work.',
             'blocks': [b for b in blocks_of(header) if b['type'] in ('scripture', 'paragraph')]}]
for sec in root.find_all(lambda n: n.tag == 'section'):
    h2 = next(sec.find_all(lambda n: n.tag == 'h2'))
    note = next(sec.find_all(lambda n: 'sec-note' in n.cls), None)
    articles.append({'id': sec.attrs['id'], 'title': clean(h2.text()),
                     'note': clean(note.text()) if note else '', 'blocks': blocks_of(sec)})

# Moments: rows of the "bank" section.
bank = next(a for a in articles if a['id'] == 'bank')
moments = []
for row in bank['blocks'][0]['rows']:
    refs = [r.strip() for r in row['text'].split('·')]
    moments.append({'name': row['label'], 'refs': refs})

json.dump(articles, open(OUT + 'guide.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
pass  # moments are curated in sword.json
# Every scripture the guide quotes, for the verse index.
quoted = {b['ref']: b['text'] for a in articles for b in a['blocks'] if b['type'] == 'scripture'}
json.dump(quoted, open(OUT + 'guide_verses.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(len(articles), 'articles,', len(moments), 'moments,', len(quoted), 'quoted verses')
