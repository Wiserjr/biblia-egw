"""Gera posições interativas das sete edições; não incorpora textos dos PDFs."""
import argparse,json,re,hashlib,sys
from pathlib import Path
import fitz
sys.path.insert(0,str(Path(__file__).parent))
from referencias_pt import encontrar
FLAGS=fitz.TEXTFLAGS_RAWDICT & ~fitz.TEXT_PRESERVE_IMAGES
SOURCES={'em-paz-com-deus':'paz.pdf','jesus-restaurador':'jesus.pdf','jesus-restaurador-mulheres':'mulheres.pdf','apocalipse-revelacoes-esperanca':'apocalipse-0.pdf','deus-revela-seu-amor':'amor.pdf','esperanca-para-a-familia':'familia.pdf','guia-estudos-calebe':'calebe-0.pdf'}
STARTS={'em-paz-com-deus':[7,12,18,24,30,35,40,45], 'apocalipse-revelacoes-esperanca':[5,10,14,17,22,26,30,34,38,44,49,54,59,65,70,74,80,85,91,95,100], 'esperanca-para-a-familia':[8,10,12,14,17,19,22,24,26,28,31,34,37,39], 'deus-revela-seu-amor':list(range(2,37,2)), 'guia-estudos-calebe':list(range(3,38,2))}
for k in ['jesus-restaurador','jesus-restaurador-mulheres']:STARTS[k]=list(range(5,63,3))+[71,80,88,96,105,113,121]
def area(rect):return [round(float(x),2) for x in rect]
def union(rects):
 r=fitz.Rect(rects[0])
 for x in rects[1:]:r|=fitz.Rect(x)
 return r

def linhas(page,key):
 clip=page.trimbox if key=='guia-estudos-calebe' else page.rect
 result=[]
 for block in page.get_text('rawdict',flags=FLAGS,clip=clip)['blocks']:
  for line in block.get('lines',[]):
   chars=[c for s in line['spans'] for c in s['chars']];text=''.join(c['c'] for c in chars)
   if not text.strip():continue
   result.append({'t':text,'r':fitz.Rect(line['bbox']),'chars':chars,'bold':any(s['flags']&16 for s in line['spans'])})
 return sorted(result,key=lambda l:(round(l['r'].y0/2)*2,l['r'].x0))

def referencias(ls):
 text='';coords=[]
 for ln in ls:
  text+=ln['t']+'\n';coords.extend([c['bbox'] for c in ln['chars']]+[None])
 # A escrita "1 a 4 e 14" deve continuar distinguindo intervalos separados.
 normalized=re.sub(r'(?<=\d)(\s+)a(\s+)(?=\d)',lambda m:m.group(1)+'-'+m.group(2),text)
 normalized=re.sub(r'(?<=\d)(\s+)e(\s+)(?=\d)',lambda m:m.group(1)+','+m.group(2),normalized)
 groups={}
 for ref in encontrar(normalized):
  groups.setdefault((ref.inicio,ref.final),[]).append(list(ref.tupla()))
 out=[]
 for (a,b),refs in groups.items():
  rects=[fitz.Rect(r) for r in coords[a:b] if r]
  if not rects:continue
  rows=[]
  for r in rects:
   if rows and abs(rows[-1].y0-r.y0)<6:rows[-1]|=r
   else:rows.append(r)
  out.append({'areas':[area(r) for r in rows],'referencias':refs})
 return out

def pagina(page,key):
 ls=linhas(page,key);w,h=page.rect.width,page.rect.height;n=page.number+1
 blanks=[];boxes=[]
 for ln in ls:
  for m in re.finditer(r'[_\.·…]{5,}',ln['t']):
   chars=ln['chars'][m.start():m.end()];r=union([c['bbox'] for c in chars])
   if r.width>12 and not re.search(r'(SUMÁRIO|SEMANA|ESTUDO \d)',ln['t']) and not re.search(r'[_\.]{5,}\s+\d+\s*$',ln['t']):
    blanks.append(fitz.Rect(r.x0,max(r.y0,r.y1-13),r.x1,r.y1))
  for m in re.finditer(r'\[\s*\]',ln['t']):
   r=union([c['bbox'] for c in ln['chars'][m.start():m.end()]]);boxes.append(r)
 for draw in page.get_drawings():
  r=draw['rect']
  if not page.rect.contains(r):continue
  if r.height<=1.1 and r.width>45 and r.y0>35 and r.y0<h-45:
   # Só linhas de resposta sem texto por cima (descarta bordas e sublinhados).
   above=fitz.Rect(r.x0,r.y0-10,r.x1,r.y0-.5)
   overlaps=[ln for ln in ls if (ln['r']&above).get_area()>ln['r'].get_area()*.4 and ln['t'].strip()!='R:']
   if not overlaps: blanks.append(fitz.Rect(r.x0,r.y0-11,r.x1,r.y0+1))
  if draw['type']=='s' and 4<r.width<13 and 4<r.height<13 and abs(r.width-r.height)<.3:
   boxes.append(r)
 # Deduplicação das duas partes que compõem uma mesma linha pontilhada.
 unique=[]
 for r in sorted(blanks,key=lambda r:(r.y0,r.x0)):
  if not any(abs(r.y1-q.y1)<2 and abs(r.x0-q.x0)<3 for q in unique):unique.append(r)
 blanks=unique
 # Agrupa as várias linhas de uma resposta, conservando lacunas inline separadas.
 groups=[]
 for r in blanks:
  if groups and abs(groups[-1][-1].x0-r.x0)<5 and abs(groups[-1][-1].width-r.width)<10 and 0<r.y0-groups[-1][-1].y0<24 and not any(ln['t'].strip(' _.·…') and groups[-1][-1].y1<ln['r'].y0<r.y0 for ln in ls):groups[-1].append(r)
  else:groups.append([r])
 anchors=[]
 for i,ln in enumerate(ls):
  t=ln['t'].strip();r=ln['r'];numbered=bool(re.match(r'^\d{1,2}\s*[.|)]\s*\D',t))
  if key=='deus-revela-seu-amor':candidate='Pesquise na Bíblia' in page.get_text() and '?' in t and r.y0<340
  elif key=='esperanca-para-a-familia':candidate='?' in t and (any(0<q.y0-r.y1<55 for q in blanks) or any(l['t'].strip()=='R:' and 0<l['r'].y0-r.y1<55 for l in ls))
  elif key=='apocalipse-revelacoes-esperanca':candidate=numbered
  elif key=='em-paz-com-deus':candidate=numbered
  elif key=='guia-estudos-calebe':candidate=numbered and ('?' in t or any(0<q.y0-r.y1<45 for q in blanks))
  else:candidate=numbered or ('?' in t and ln['bold'] and r.y0>250 and (any(0<q.y0-r.y1<50 for q in blanks)))
  if not candidate:continue
  prompt=[r];tt=t
  for nextln in ls[i+1:i+4]:
   nr=nextln['r'];nt=nextln['t'].strip()
   if nr.y0-r.y1>35 or nr.x0<r.x0-8 or re.match(r'^\d+\s*[.|)]',nt) or re.match(r'^[_\.]{5}',nt):break
   if '?' not in tt or (encontrar(nt) and nr.y0-prompt[-1].y1<9):prompt.append(nr);tt+=' '+nt
   else:break
  anchors.append({'r':union(prompt),'t':tt,'areas':[area(x) for x in prompt]})
 if n<STARTS[key][0]:anchors=[];boxes=[]
 # O PDF oficial tem enunciados ausentes na página 17; conserva os oito espaços.
 if key=='deus-revela-seu-amor' and n==17:
  for ln in ls:
   if re.fullmatch('[4-8]',ln['t']) and ln['r'].x0<30 and ln['r'].y0<330:
    r=fitz.Rect(36.8,ln['r'].y0+6.5,345,ln['r'].y0+18)
    original=[l['r'] for l in ls if l['r'].x0>30 and abs(l['r'].y0-r.y0)<3]
    anchors.append({'r':r,'t':'','areas':[area(x) for x in original], 'semEnunciado':True})
  anchors.sort(key=lambda a:a['r'].y0)
 if key.startswith('jesus-restaurador') and n in range(7,65,3):
  dias=[l for l in ls if re.fullmatch('[1-7]',l['t']) and 50<l['r'].x0<80 and 130<l['r'].y0<350]
  if dias:
   top=min(l['r'].y0 for l in dias)-30;bottom=max(l['r'].y1 for l in dias)+4
   groups=[g for g in groups if not top<g[0].y0<bottom]
 # Campos que não são perguntas numeradas: reflexões, nome, data e assinatura.
 qs=[]
 for j,a in enumerate(anchors):
  end=anchors[j+1]['r'].y0 if j+1<len(anchors) else h-30
  cabecalhos=[l['r'].y0 for l in ls if a['r'].y1<l['r'].y0<end and re.search(r'MINHA DECISÃO|Minha Decisão|Meu compromisso|Pense Nisto|Para pensar|Compromisso de fé|Decisão em família|Nome:|Data:|Algum desses|O que mais chamou',l['t'])]
  if cabecalhos:end=min(cabecalhos)
  assigned=[g for g in groups if a['r'].y1-4<=g[0].y0<end and g[0].x0>=a['r'].x0-15]
  # A pergunta só recebe campos anteriores à próxima reflexão/cabeçalho.
  assigned=[g for g in assigned if not any(a['r'].y1<l['r'].y0<g[0].y0 and re.search(r'MINHA DECISÃO|Minha Decisão|Meu compromisso|Nome:|Data:|Algum desses|O que mais chamou',l['t']) for l in ls)]
  q={'id':f'p{n}-q{j+1}','areasTexto':a['areas'],'respostas':[]}
  if a.get('semEnunciado'):q['semEnunciado']=True
  for idx,g in enumerate(assigned):
   q['respostas'].append({'id':q['id']+f'-r{idx+1}','tipo':'texto','areas':[area(union(g))]})
   groups.remove(g)
  opts=[r for r in boxes if a['r'].y1-3<r.y0<end and r.x0>a['r'].x0-8]
  if opts:
   options=[]
   for r in sorted(opts,key=lambda r:(round(r.y0/3),r.x0)):
    limit=min([z.x0 for z in opts if abs(z.y0-r.y0)<4 and z.x0>r.x1]+[w-32])
    options.append({'area':area(r),'textoArea':area(fitz.Rect(r.x1+2,r.y0-4,limit-2,r.y1+4))})
    boxes.remove(r)
   q['respostas'].append({'id':q['id']+'-opcoes','tipo':'alternativas','unica':not re.search(r'quais|assinale|marque|duas|três',a['t'],re.I),'opcoes':options,'areas':[area(union(opts))]})
  if not q['respostas'] and '?' not in a['t'] and not a.get('semEnunciado'):continue
  if not q['respostas']:
   q['respostas'].append({'id':q['id']+'-r1','tipo':'texto','areas':[]})
  qs.append(q)
 for idx,g in enumerate(groups):
  rect=union(g)
  if rect.y0<(35 if key=='em-paz-com-deus' else 60) or n<STARTS[key][0]:continue
  # Tabelas e separadores coloridos fora das áreas de escrita não viram campos.
  before=[l for l in ls if 0<=rect.y0-l['r'].y1<22 and l['r'].x0<rect.x1 and any(c.isalnum() for c in l['t'])]
  if not before:before=[l for l in ls if 0<=l['r'].y0-rect.y1<22 and rect.x0<=l['r'].x0<rect.x1 and re.search(r'Amigos|Necessidades',l['t'])]
  if not before and not (key=='em-paz-com-deus' and rect.y0<200) and not re.search(r'Nome|Data|assinatura',page.get_text()):continue
  prompt=before[-2:] if before else []
  qs.append({'id':f'p{n}-reflexao{idx+1}','areasTexto':[area(l['r']) for l in prompt],'respostas':[{'id':f'p{n}-reflexao{idx+1}-r1','tipo':'texto','areas':[area(rect)]}]})
 # Sim/Não nas decisões é uma escolha explícita e independente das respostas.
 if boxes:
  for idx,r in enumerate(sorted(boxes,key=lambda r:(r.y0,r.x0))):
   if not any(l['r'].y0<r.y1 and l['r'].y1>r.y0 and ('Sim' in l['t'] or 'Não' in l['t']) for l in ls):continue
   same=[z for z in boxes if abs(z.y0-r.y0)<4]
   if r!=min(same,key=lambda z:z.x0):continue
   options=[]
   for z in sorted(same,key=lambda z:z.x0):
    limit=min([v.x0 for v in same if v.x0>z.x1]+[w-25])
    options.append({'area':area(z),'textoArea':area(fitz.Rect(z.x1,z.y0-3,limit-1,z.y1+3))})
   prompt=[l['r'] for l in ls if r.y0-55<l['r'].y0<r.y1 and l['r'].x0<r.x0]
   qs.append({'id':f'p{n}-decisao','areasTexto':[area(v) for v in prompt],'respostas':[{'id':f'p{n}-decisao-opcoes','tipo':'alternativas','unica':True,'opcoes':options,'areas':[area(union(same))]}]})
 # Os sete espaços de meditação do estudo adicional de Jesus Restaurador.
 if key.startswith('jesus-restaurador') and n in range(7,65,3):
  for ln in ls:
   if re.fullmatch('[1-7]',ln['t']) and 50<ln['r'].x0<80 and 130<ln['r'].y0<350:
    y=ln['r'].y0;rect=fitz.Rect(162,y-1,w-38,ln['r'].y1+1)
    qs.append({'id':f'p{n}-dia{ln["t"]}','areasTexto':[area(fitz.Rect(80,y-2,160,ln['r'].y1+2))],'respostas':[{'id':f'p{n}-dia{ln["t"]}-r1','tipo':'texto','areas':[area(rect)]}]})
 qs=sorted(qs,key=lambda q:(q['areasTexto'][0][1] if q['areasTexto'] else q['respostas'][0]['areas'][0][1],q['id']))
 return {'pagina':n,'largura':round(w,3),'altura':round(h,3),'perguntas':qs,'referencias':referencias(ls)}

def gerar(base,output):
 catalog=json.loads(Path('assets/catalogo_estudos.json').read_text(encoding='utf-8'));result={'versao':1,'estudos':[]}
 for item in catalog['estudos']:
  key=item['id'];path=base/SOURCES[key]
  assert hashlib.sha256(path.read_bytes()).hexdigest()==item['sha256'],key
  doc=fitz.open(path);pages=[pagina(p,key) for p in doc]
  # Uma mesma pergunta pode começar numa página e ter linhas na seguinte.
  if key=='em-paz-com-deus':
   for previous,current in zip(pages,pages[1:]):
    if not previous['perguntas'] or not current['perguntas']:continue
    q=previous['perguntas'][-1];nextq=current['perguntas'][0]
    if q['respostas'][0]['areas']==[] and '-reflexao' in nextq['id']:
     nextq['areasTexto']=q['areasTexto'];nextq['paginaEnunciado']=previous['pagina']
     nextq['respostas'][0]['id']=q['respostas'][0]['id'];nextq['respostas'][0]['continuacao']=True
  # Migração do piloto: preserva escolhas e respostas da primeira lição.
  if key=='jesus-restaurador':
   for q in pages[5]['perguntas']:
    m=re.fullmatch('p6-q([1-8])',q['id'])
    if m:
     n=int(m[1])-1
     for field in q['respostas']:
      if field['tipo']=='alternativas':field['legadoEscolha']=n
      elif n>=4:field['legadoResposta']=n
  if key=='jesus-restaurador':
   for idx,qid in enumerate(['p6-reflexao1','p6-reflexao2','p6-reflexao3','p6-reflexao4']):
    for q in pages[5]['perguntas']:
     if q['id']==qid:q['respostas'][0]['legadoResposta']=8+idx
  starts=STARTS[key];lessons=[]
  for i,start in enumerate(starts):
   end=(starts[i+1]-1) if i+1<len(starts) else len(doc)
   if key.startswith('jesus-restaurador') and i==19:end=64
   lessons.append({'numero':i+1,'inicio':start,'fim':end,'complementar':key.startswith('jesus-restaurador') and i>=20})
  entry={'id':key,'sha256':item['sha256'],'licoes':lessons,'paginas':pages};result['estudos'].append(entry)
  print(key,'lições',len(lessons),'perguntas/campos',sum(len(p['perguntas']) for p in pages),'refs',sum(len(p['referencias']) for p in pages),flush=True)
 output.write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--originais',type=Path,default=Path('ferramentas/cache/estudos/oficiais'));parser.add_argument('--saida',type=Path,default=Path('assets/estudos_interativos.json'));args=parser.parse_args();gerar(args.originais,args.saida)
