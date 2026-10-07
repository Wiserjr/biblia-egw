"""Acrescenta localizadores e distratores editoriais, sem distribuir o EPUB."""
import hashlib
import html
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET
import zipfile

from referencias_pt import encontrar

# As respostas e os enunciados são lidos apenas da cópia pessoal.
# Não usar sinônimos da resposta correta como distratores.
NOVAS = [
    (32, 6, ['Davi', 'Moisés', 'Salomão']),
    (32, 7, ['Por ser raro', 'Por ser caro', 'Por ser reservado aos sacerdotes']),
    (32, 9, ['Lentilhas e vinho', 'Leite e mel', 'Frutas e carne']),
    (32, 10, ['Isaías', 'Davi', 'Noé']),
    (33, 1, ['A ovelha', 'A cabra', 'O jumento']),
    (58, 4, ['No rio Nilo', 'No rio Eufrates', 'No rio Tigre']),
    (33, 6, ['Os levitas', 'Os benjamitas', 'Os rubenitas']),
    (33, 7, ['Com a abelha', 'Com o gafanhoto', 'Com a borboleta']),
    (33, 8, ['Tiago', 'Pedro', 'Judas']),
    (33, 9, ['Carmelo', 'Gilboa', 'Moriá']),
    (34, 1, ['No deserto de Sin', 'No jardim do Getsêmani', 'No palácio de Herodes']),
    (34, 6, ['Samuel', 'Jonas', 'Ezequiel']),
    (34, 7, ['Gabriel', 'Rafael', 'Uriel']),
    (34, 8, ['Os soldados de Saul', 'Os soldados de Josué', 'Os soldados de Davi']),
    (34, 10, ['Ao redor dos reis', 'Ao redor dos mais ricos', 'Ao redor de todos os templos']),
    (35, 6, ['A figueira', 'A oliveira', 'O cedro']),
    (35, 7, ['Carvalho', 'Palmeira', 'Cedro']),
    (35, 8, ['Oliveira', 'Figueira', 'Cedro']),
    (35, 9, ['Oliveira', 'Palmeira', 'Figueira']),
    (35, 10, ['Figueira', 'Videira', 'Oliveira']),
    (36, 3, ['Gideão, sobre Samaria', 'Samuel, sobre Belém', 'Davi, sobre Hebrom']),
    (36, 4, ['Porque receberão riquezas', 'Porque serão reis', 'Porque viverão sem dificuldades']),
    (36, 7, ['Salomão', 'Saul', 'Absalão']),
    (36, 8, ['Porque serão chamados reis', 'Porque serão chamados profetas', 'Porque serão chamados sacerdotes']),
    (36, 9, ['Ebal', 'Sinai', 'Carmelo']),
    (36, 10, ['Gerizim', 'Moriá', 'Gilboa']),
    (37, 3, ['Isaque', 'José', 'Boaz']),
    (37, 8, ['Neemias', 'Josué', 'Daniel']),
    (37, 9, ['Na sinagoga de Nazaré', 'No templo de Jerusalém', 'Na casa de Pedro']),
    (38, 2, ['Belém', 'Nazaré', 'Betânia']),
    (38, 4, ['Nazaré', 'Betânia', 'Belém']),
    (38, 7, ['Jerusalém', 'Corinto', 'Éfeso']),
    (38, 8, ['Babel', 'Ur', 'Jericó']),
    (38, 9, ['Jericó', 'Hebrom', 'Samaria']),
    (38, 10, ['Nazaré', 'Cafarnaum', 'Belém']),
    (39, 5, ['Na terra do Egito', 'Na terra de Moabe', 'Na terra da Assíria']),
    (39, 7, ['Amnom, filho de Davi', 'Jônatas, filho de Saul', 'Manassés, filho de Ezequias']),
    (39, 9, ['Davi', 'Salomão', 'Ezequias']),
    (39, 10, ['Roboão', 'Josias', 'Saul']),
    (40, 4, ['Um talento de ouro', 'Dez denários', 'Um siclo de prata']),
    (40, 7, ['Uma espada de prata', 'Um anel de ferro', 'Um escudo de bronze']),
    (40, 8, ['12 anos', '15 anos', '30 anos']),
    (40, 9, ['Dois siclos', 'Um talento', 'Dez denários']),
    (40, 10, ['Um', 'Três', 'Cinco']),
    (41, 3, ['Correr apenas pela fama', 'Correr sem objetivo', 'Correr para agradar aos juízes']),
    (41, 6, ['Foi morto por uma pedra', 'Foi envenenado', 'Foi morto por um raio']),
    (41, 7, ['Quando Pedro caiu no mar', 'Quando Paulo naufragou', 'Quando Moisés atravessou o mar']),
    (41, 10, ['Labão', 'Esaú', 'Abimeleque']),
    (42, 1, ['O irmão mais velho', 'O dono dos porcos', 'O juiz da cidade']),
    (42, 7, ['João Batista', 'Herodes', 'Pilatos']),
    (42, 8, ['Festa da Dedicação', 'Festa de Purim', 'Festa dos Tabernáculos']),
    (42, 9, ['Purim', 'Pentecoste', 'Dedicação']),
    (43, 6, ['Bartimeu', 'Nicodemos', 'Jairo']),
    (43, 8, ['Josué', 'Calebe', 'Hur']),
    (43, 9, ['Samuel', 'Saul', 'Sansão']),
    (44, 3, ['Moisés', 'Esdras', 'Ezequiel']),
    (44, 6, ['Josias', 'Ezequias', 'Davi']),
    (44, 9, ['O livro de Ester', 'O livro de Rute', 'O livro de Provérbios']),
    (45, 2, ['A viúva de Sarepta', 'A mulher de Jó', 'A mãe de Samuel']),
    (45, 4, ['Sara', 'Raquel', 'Lia']),
    (45, 6, ['Rute', 'Ester', 'Mical']),
    (45, 8, ['Miriã', 'Ana', 'Noemi']),
    (45, 9, ['Abigail', 'Jezabel', 'Ester']),
    (45, 10, ['Rebeca, mãe de Jacó', 'Ana, mãe de Samuel', 'Maria, mãe de Jesus']),
    (46, 4, ['Josias', 'Samuel', 'Manassés']),
    (46, 6, ['Possuir muitas terras', 'Conhecer todos os reis', 'Falar muitas línguas']),
    (46, 8, ['O filho de Jairo', 'O filho de Eli', 'O filho de Herodes']),
    (46, 9, ['Prata, trigo e azeite', 'Bronze, mel e vinho', 'Linho, sal e madeira']),
    (46, 10, ['Davi', 'José', 'Jeremias']),
    (47, 1, ['Uma pessoa', 'Duas pessoas', 'Sete pessoas']),
    (47, 2, ['Quando Elias subiu ao céu', 'Quando Josué entrou em Canaã', 'Quando Jonas chegou a Nínive']),
    (47, 8, ['Pilatos', 'Faraó', 'Nabucodonosor']),
    (47, 9, ['Paulo e Barnabé', 'Tiago e João', 'Moisés e Arão']),
    (47, 10, ['Priscila', 'Lídia', 'Marta']),
    (48, 4, ['Monte Carmelo', 'Monte Sinai', 'Monte Gilboa']),
    (48, 6, ['Nebo', 'Carmelo', 'Gerizim']),
    (48, 7, ['Gilboa', 'Gerizim', 'Carmelo']),
    (48, 8, ['Sinai', 'Hor', 'Ebal']),
    (48, 9, ['Carmelo', 'Nebo', 'Gerizim']),
    (49, 1, ['Vasti', 'Ester', 'Abigail']),
    (49, 6, ['Lia', 'Sara', 'Rebeca']),
    (49, 9, ['Ester', 'Abigail', 'Rispa']),
    (50, 1, ['Durante o Sermão do Monte', 'Durante o batismo', 'Durante a transfiguração']),
    (50, 2, ['Flautas de prata', 'Harpas de madeira', 'Címbalos de bronze']),
    (50, 3, ['Com uma corrida', 'Com uma coroação', 'Com um casamento']),
    (50, 6, ['Uma harpa', 'Uma flauta', 'Uma trombeta']),
    (50, 9, ['Harpa', 'Flauta', 'Tamborim']),
    (50, 10, ['Trombeta', 'Tamborim', 'Címbalo']),
    (51, 6, ['Zorobabel', 'Absalão', 'Natã']),
    (51, 8, ['Beltessazar', 'Abede-Nego', 'Sesbazar']),
    (51, 9, ['Judá', 'Abraão', 'Efraim']),
    (52, 3, ['Duas', 'Três', 'Oito']),
    (52, 6, ['3', '7', '12']),
    (52, 7, ['12', '30', '40']),
    (52, 8, ['3', '10', '40']),
    (52, 9, ['7', '20', '40']),
    (52, 10, ['10', '12', '30']),
    (53, 1, ['Paulo', 'Pedro', 'Salomão']),
    (53, 3, ['Isaías', 'Jeremias', 'Ezequiel']),
    (53, 5, ['Isaque', 'Boaz', 'José']),
    (53, 8, ['Judá', 'Levi', 'Efraim']),
    (54, 2, ['Sara', 'Lia', 'Raquel']),
    (54, 3, ['Ló era irmão de Abraão', 'Ló era filho de Abraão', 'Ló era primo de Abraão']),
    (54, 6, ['Eram primos', 'Eram pai e filho', 'Eram tio e sobrinho']),
    (54, 7, ['Débora', 'Ester', 'Ana']),
    (54, 8, ['De Josias', 'De Ezequias', 'De Roboão']),
    (54, 9, ['Roboão era irmão de Salomão', 'Roboão era pai de Salomão', 'Roboão era sobrinho de Salomão']),
    (55, 2, ['Dez batos', 'Cem batos', 'Mil batos']),
    (55, 3, ['Caminho de três dias', 'Caminho de sete dias', 'Caminho de quarenta dias']),
    (55, 5, ['10 siclos de prata', '20 siclos de prata', '40 siclos de prata']),
    (55, 6, ['Um talento', 'Um siclo de ouro', 'Um quadrante']),
    (55, 8, ['Como um presente', 'Como uma virtude', 'Como uma bênção']),
    (56, 1, ['Haja firmamento', 'Haja árvores', 'Haja animais']),
    (56, 7, ['Noé', 'Enoque', 'Lameque']),
    (56, 8, ['Sara', 'Rebeca', 'Raquel']),
    (56, 9, ['Caim', 'Abel', 'Sete']),
    (57, 2, ['Ester', 'Vasti', 'Mical']),
    (57, 4, ['Davi', 'Saul', 'Roboão']),
    (57, 5, ['Josias', 'Ezequias', 'Davi']),
    (57, 6, ['Ester da Pérsia', 'Vasti da Pérsia', 'Atalia de Judá']),
]

def ampliar(caminho):
    destino = Path('assets/quiz_indice_cpb.json')
    indice = json.loads(destino.read_text(encoding='utf-8'))
    raw = Path(caminho).read_bytes()
    if hashlib.sha256(raw).hexdigest() != indice['sha256Epub']:
        raise ValueError('Edição incompatível')
    existentes = {p['id'] for p in indice['perguntas']}
    with zipfile.ZipFile(caminho) as z:
        for i, (cap, numero, distratores) in enumerate(NOVAS):
            ident = f'cpb-{cap}-{numero}'
            if ident in existentes:
                continue
            fonte = z.read(f'OEBPS/Text/Curiosidades_Miolo-{cap + 53}.xhtml').decode()
            fonte = re.sub(r'&([A-Za-z]+);', lambda m: m[0] if m[1] in ['amp', 'lt', 'gt', 'quot', 'apos'] else ''.join(f'&#{ord(c)};' for c in html.unescape(m[0])), fonte)
            raiz = ET.fromstring(fonte)
            resposta = next(' '.join(''.join(p.itertext()).split()) for p in raiz.iter() if p.tag.endswith('}p') and re.match(rf'^0*{numero}\.\s', ' '.join(''.join(p.itertext()).split())))
            refs = encontrar(resposta)
            if not refs:
                raise ValueError(f'Sem referência: {ident}')
            indice['perguntas'].append({'id': ident, 'capitulo': cap, 'numero': numero, 'dificuldade': i % 3 + 1, 'distratores': distratores, 'referencias': [list(r.tupla()) for r in refs]})
    indice['versao'] = 2
    destino.write_text(json.dumps(indice, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Perguntas:', len(indice['perguntas']))

if __name__ == '__main__':
    ampliar(sys.argv[1])
