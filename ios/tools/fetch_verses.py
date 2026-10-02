# Builds Rootwork/Resources/verses.json: WEB text for every ref the app ships with.
import json, os, time, urllib.parse, urllib.request
R = 'ios/Rootwork/Resources/'
votd = ["John 15:4","John 15:5","Psalm 119:105","Matthew 11:28","Lamentations 3:22-23","Isaiah 41:10","Philippians 4:6-7",
 "Romans 8:28","2 Corinthians 5:17","Romans 5:8","Psalm 23:1","Isaiah 26:3","John 14:27","John 16:33","Matthew 6:33",
 "Micah 6:8","James 1:22","Romans 12:2","Galatians 5:22-23","John 14:6","Psalm 139:14","Mark 1:35",
 "1 Thessalonians 5:16-18","Galatians 6:9","Philippians 1:6","2 Corinthians 12:9","Psalm 46:10","Joshua 1:9",
 "Proverbs 3:5-6","Matthew 5:16","John 1:14","Psalm 118:24","Psalm 34:18","Revelation 21:4","John 11:25",
 "Psalm 46:1","Isaiah 40:31","1 Peter 5:7","Mark 9:24","Psalm 119:18","Psalm 119:11","John 15:11","John 15:16",
 "Hebrews 4:16","Psalm 51:10","Matthew 6:34","Romans 8:1","Psalm 139:8","John 3:16","Luke 9:23"]
moments = [r for m in json.load(open(R+'moments.json',encoding='utf-8')) for r in m['refs']]
old = json.load(open('prototype/data/verses.json',encoding='utf-8'))
out = json.load(open(R+'verses.json',encoding='utf-8')) if os.path.exists(R+'verses.json') else {}
out.update({k:v for k,v in old.items() if k not in out})
need = [r for r in dict.fromkeys(votd+moments) if r not in out]
print(len(need), 'to fetch')
for r in need:
    for attempt in range(8):
        try:
            d = json.load(urllib.request.urlopen("https://bible-api.com/"+urllib.parse.quote(r)+"?translation=web"))
            break
        except Exception as e:
            time.sleep(10)
    else:
        print('FAILED', r); continue
    t = ' '.join(d['text'].split())
    if t.count('“') != t.count('”'):
        if t.startswith('“') and t.count('“') > t.count('”'): t = t[1:]
        elif t.endswith('”') and t.count('”') > t.count('“'): t = t[:-1]
    out[r] = t
    json.dump(out, open(R+'verses.json','w',encoding='utf-8'), ensure_ascii=False, indent=1)
    time.sleep(3)
json.dump(votd, open(R+'votd.json','w',encoding='utf-8'), indent=1)
print(len(out), 'verses total')
