"""Prepara posições do questionário digitalizado, sem distribuir texto ou imagens.

Requer PyMuPDF, rapidocr e numpy. O OCR é apenas ferramenta de localização;
o editor mostra um recorte do PDF pessoal, não o texto reconhecido.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

import fitz
import numpy as np

from indexar_estudos_interativos import area, union, referencias

ID = 'biblia-facil-daniel'
SHA256 = '9a7391eb2cb16c467e88264f794b82bc2b57a31efa1df3034fb155c7edf0e53e'
STARTS = [4, 7, 10, 14, 17, 20, 23, 26, 29, 34, 39, 44, 48, 51, 54, 57]


def reconhecer(doc, cache):
    from rapidocr import RapidOCR
    engine = RapidOCR(params={'EngineConfig.onnxruntime.intra_op_num_threads': 2,
                              'EngineConfig.onnxruntime.inter_op_num_threads': 2})
    result = {}
    for n in range(61, 82):
        path = cache / f'daniel-ocr-{n}.json'
        if path.exists():
            rows = json.loads(path.read_text(encoding='utf-8'))
        else:
            pix = doc[n - 1].get_pixmap(matrix=fitz.Matrix(2, 2), alpha=False)
            output = engine(np.frombuffer(pix.samples, np.uint8).reshape(
                pix.height, pix.width, pix.n), use_cls=False)
            rows = [{'texto': t, 'area': area(fitz.Rect(
                float(b[:, 0].min()) / 2, float(b[:, 1].min()) / 2,
                float(b[:, 0].max()) / 2, float(b[:, 1].max()) / 2))}
                for b, t in zip(output.boxes, output.txts)]
            path.write_text(json.dumps(rows, ensure_ascii=False), encoding='utf-8')
        result[n] = rows
        print('Daniel OCR página', n, flush=True)
    return result


def indexar(doc, recognized):
    pages = [{'pagina': p.number + 1, 'largura': round(p.rect.width, 3),
              'altura': round(p.rect.height, 3), 'perguntas': [],
              'referencias': [], 'linksExtras': []} for p in doc]
    lesson = 0
    questionnaires = [[] for _ in STARTS]
    for n, rows in recognized.items():
        rows = sorted(rows, key=lambda l: (l['area'][1], l['area'][0]))
        # Os quadradinhos laranja antes dos números podem aparecer no OCR.
        anchors = [i for i, row in enumerate(rows) if re.match(
            r'^[\s■▪□口]*\d{1,2}\s*[.)]\s*\D', row['texto'])
            and 60 < row['area'][1] < 735 and row['area'][0] < 110]
        for j, start in enumerate(anchors):
            end = anchors[j + 1] if j + 1 < len(anchors) else len(rows)
            group = [r for r in rows[start:end] if r['area'][1] < 735]
            number = int(re.search(r'\d+', group[0]['texto'])[0])
            if number == 1:
                lesson += 1
            if not 1 <= lesson <= 16:
                raise ValueError(f'Lição não reconhecida na página {n}')
            choices = [i for i, r in enumerate(group) if re.match(
                r'^\s*(?:[（(]\s*[）)]|[）)])', r['texto'])]
            if not choices:
                continue
            for i in range(choices[-1] + 1, len(group)):
                if group[i]['area'][1] - group[i - 1]['area'][3] > 18:
                    group = group[:i]
                    break
            # Corta o cabeçalho da próxima lição ou a antiga promoção impressa.
            for i in range(choices[0] + 1, len(group)):
                text = group[i]['texto'].strip()
                if ('LIÇÃO' in text or 'LICÃO' in text or 'ESCOLHA O SEU' in text
                        or (text.isupper() and len(text) > 12 and not text.startswith('('))):
                    group = group[:i]
                    choices = [k for k in choices if k < i]
                    break
            prompt = group[:choices[0]]
            options = []
            left = min(group[i]['area'][0] for i in choices)
            for k, i in enumerate(choices):
                stop = choices[k + 1] if k + 1 < len(choices) else len(group)
                rect = union([fitz.Rect(r['area']) for r in group[i:stop]])
                options.append({'area': area(fitz.Rect(left, rect.y0,
                                                      left + 12, rect.y0 + 12)),
                                'textoArea': area(rect)})
            qid = f'p{n}-q{j + 1}'
            matching = 'relacione' in group[0]['texto'].lower()
            fields = ([{'id': qid + f'-r{k + 1}', 'tipo': 'texto', 'areas': [o['area']]}
                       for k, o in enumerate(options)] if matching else
                      [{'id': qid + '-opcoes', 'tipo': 'alternativas',
                        'unica': True, 'opcoes': options,
                        'areas': [area(union([fitz.Rect(o['area']) for o in options]))]}])
            pages[n - 1]['perguntas'].append({
                'id': qid, 'licao': lesson, 'numeroOriginal': number,
                'areasTexto': [r['area'] for r in prompt],
                'areaImagem': area(union([fitz.Rect(r['area']) for r in group])),
                'respostas': fields})
            if n not in questionnaires[lesson - 1]:
                questionnaires[lesson - 1].append(n)
        # As referências são posições e números; não se incorpora texto do OCR.
        ls = [{'t': r['texto'], 'chars': [{'bbox': r['area']} for _ in r['texto']]}
              for r in rows if r['area'][1] < 735]
        pages[n - 1]['referencias'] = [dict(r, somenteConsulta=True) for r in referencias(ls)]
    lessons = [{'numero': i + 1, 'inicio': start,
                'fim': STARTS[i + 1] - 1 if i + 1 < len(STARTS) else 59,
                'paginasQuestionario': questionnaires[i], 'complementar': False}
               for i, start in enumerate(STARTS)]
    expected = [9, 8, 6, 9, 7, 9, 9, 7, 4, 8, 10, 10, 8, 9, 10, 7]
    for lesson, total in enumerate(expected, 1):
        numbers = [q['numeroOriginal'] for p in pages for q in p['perguntas']
                   if q['licao'] == lesson]
        if numbers != list(range(1, total + 1)):
            raise ValueError(f'Questionário incompleto da lição {lesson}: {numbers}')
    for p in pages:
        for q in p['perguntas']:
            fields = q['respostas']
            if fields[0]['tipo'] == 'alternativas' and len(fields[0]['opcoes']) != 4:
                raise ValueError(f'Alternativas incompletas: {q["id"]}')
    if [len(q['respostas']) for p in pages for q in p['perguntas']
        if q['respostas'][0]['tipo'] == 'texto'] != [4, 5, 5]:
        raise ValueError('Correspondências incompletas nas atividades de relacionar colunas.')
    return {'id': ID, 'sha256': SHA256, 'licoes': lessons, 'paginas': pages}


def gerar(base, output):
    path = base / 'daniel.pdf'
    if hashlib.sha256(path.read_bytes()).hexdigest() != SHA256:
        raise ValueError('O PDF de Daniel não corresponde à edição preparada.')
    with fitz.open(path) as doc:
        entry = indexar(doc, reconhecer(doc, base))
    index = json.loads(output.read_text(encoding='utf-8'))
    index['estudos'] = [e for e in index['estudos'] if e['id'] != ID] + [entry]
    output.write_text(json.dumps(index, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
    print('Daniel: 16 lições,', sum(len(p['perguntas']) for p in entry['paginas']),
          'perguntas', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--originais', type=Path, default=Path('ferramentas/cache/estudos/oficiais'))
    parser.add_argument('--saida', type=Path, default=Path('assets/estudos_interativos.json'))
    args = parser.parse_args()
    gerar(args.originais, args.saida)
