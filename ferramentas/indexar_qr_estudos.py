import fitz,cv2,numpy as np,json
from pathlib import Path
from indexar_estudos_interativos import SOURCES
base=Path('ferramentas/cache/estudos/oficiais');path=Path('assets/estudos_interativos.json');index=json.loads(path.read_text(encoding='utf-8'));detector=cv2.QRCodeDetector()
for e in index['estudos']:
 doc=fitz.open(base/SOURCES[e['id']]);cache={};count=0
 for p in doc:
  extras=[]
  for img in p.get_images(full=True):
   xref,width,height=img[0],img[2],img[3]
   if min(width,height)<35 or max(width,height)>900 or abs(width/height-1)>.15:continue
   if xref not in cache:
    text=''
    for r in p.get_image_rects(xref):
     if not p.rect.contains(r):continue
     pix=p.get_pixmap(matrix=fitz.Matrix(5,5),clip=r,alpha=False)
     im=np.frombuffer(pix.samples,np.uint8).reshape(pix.height,pix.width,pix.n)
     im=cv2.cvtColor(im,cv2.COLOR_RGB2GRAY)
     im=cv2.copyMakeBorder(im,40,40,40,40,cv2.BORDER_CONSTANT,value=255)
     text,points,_=detector.detectAndDecode(im)
     if not text:
      _,inverted=cv2.threshold(im,200,255,cv2.THRESH_BINARY_INV)
      inverted=cv2.copyMakeBorder(inverted[40:-40,40:-40],40,40,40,40,cv2.BORDER_CONSTANT,value=255)
      text,points,_=detector.detectAndDecode(inverted)
     if text:break
    cache[xref]=text
   text=cache[xref]
   if text.startswith(('http://','https://')):
    for r in p.get_image_rects(xref):
     if p.rect.contains(r):extras.append({'area':[round(float(v),2) for v in r],'url':text.replace('&amp;','&')});count+=1
  # Os QR Codes de Em Paz com Deus são vetoriais; a URL está impressa.
  if e['id']=='em-paz-com-deus':
   for word in p.get_text('words'):
    if word[4].startswith('http://adv.st/'):
     extras.append({'area':[round(float(v),2) for v in word[:4]],'url':word[4]});count+=1
  e['paginas'][p.number]['linksExtras']=extras
 print(e['id'],'links QR',count,flush=True)
path.write_text(json.dumps(index,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
