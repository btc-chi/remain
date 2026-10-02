import json,os
sp=os.path.join(os.path.dirname(__file__),'data')+'/'
luke=json.load(open(sp+'luke10.json',encoding='utf-8'))
V=json.load(open(sp+'verses.json',encoding='utf-8'))
t=open('rootwork.template.html',encoding='utf-8').read()
t=t.replace('/*__LUKE10__*/[]',json.dumps(luke,ensure_ascii=False)).replace('/*__VERSES__*/{}',json.dumps(V,ensure_ascii=False))
open('rootwork.html','w',encoding='utf-8').write(t)
