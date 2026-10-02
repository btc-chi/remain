# Inlines the art as data URIs (artifact pages can't load external images).
import base64, os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
t = open('today.template.html', encoding='utf-8').read()
for k in ('verse', 'father', 'son', 'spirit'):
    b = base64.b64encode(open(f'art/{k}.jpg', 'rb').read()).decode()
    t = t.replace('{{IMG_%s}}' % k, 'data:image/jpeg;base64,' + b)
open('today.html', 'w', encoding='utf-8').write(t)
print(len(t) // 1024, 'KB')
