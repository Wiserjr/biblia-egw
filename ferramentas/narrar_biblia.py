"""Gera a narração da Bíblia (ARA) com voz neural e publica nas releases.

Roda no PC do dono (precisa de internet e de ``pip install edge-tts``):

    python ferramentas/narrar_biblia.py --amostra            # Salmo 23, para ouvir
    python ferramentas/narrar_biblia.py --vozes              # vozes em português
    python ferramentas/narrar_biblia.py Gênesis Salmos       # alguns livros
    python ferramentas/narrar_biblia.py --tudo               # a Bíblia inteira
    python ferramentas/narrar_biblia.py --tudo --publicar    # e envia ao GitHub

A voz é a do edge-tts (as vozes neurais do Microsoft Edge), sem chave de API.
Cada capítulo vira um MP3 (o nome do livro e o capítulo, depois os
versículos, um a um) e um JSON com o início de cada versículo em
milissegundos, que o app usa para acompanhar a leitura. Com --publicar, os
livros completos vão para as releases "narracao-ara-at" e "narracao-ara-nt"
do Wiserjr/biblia-egw (NN-CCC.mp3 e tempos-NN.json), de onde o app toca
pela internet (lib/dados/narracao.dart). Só o que mudou é enviado de novo.

Pode parar e rodar de novo: o que já foi gerado fica em
ferramentas/cache/narracao e não é refeito (a não ser com --refazer).
"""

from __future__ import annotations

import argparse
import asyncio
import gzip
import hashlib
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unicodedata
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
BANCO = RAIZ / "assets" / "biblia.db.gz"
SAIDA = RAIZ / "ferramentas" / "cache" / "narracao"

VERSAO = 2  # ARA no biblia.db
SIGLA = "ARA"
VOZ_PADRAO = "pt-BR-AntonioNeural"
REPO = "Wiserjr/biblia-egw"
TAG_AT = "narracao-ara-at"
TAG_NT = "narracao-ara-nt"
GH_WINDOWS = r"C:\Program Files\GitHub CLI\gh.exe"

# Pedidos à voz ao mesmo tempo, dentro de um capítulo.
PARALELOS = 6
TENTATIVAS = 6


# --- MP3 ---------------------------------------------------------------------

_BITRATES = {
    # (MPEG-1?) -> índice -> kbps, para Layer III
    True: [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320],
    False: [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
}
_TAXAS = {3: [44100, 48000, 32000], 2: [22050, 24000, 16000], 0: [11025, 12000, 8000]}


def _pular_id3(dados: bytes) -> int:
    if dados[:3] == b"ID3" and len(dados) >= 10:
        tam = 0
        for b in dados[6:10]:
            tam = (tam << 7) | (b & 0x7F)
        return 10 + tam
    return 0


def quadros_mp3(dados: bytes) -> list[tuple[int, int, int]]:
    """Os quadros MPEG Layer III de ``dados``: (início, tamanho, duração em
    microssegundos). Para no primeiro trecho que não for um quadro."""
    quadros = []
    i = _pular_id3(dados)
    while i + 4 <= len(dados):
        h = int.from_bytes(dados[i : i + 4], "big")
        if (h >> 21) & 0x7FF != 0x7FF:
            break
        versao = (h >> 19) & 3  # 3 = MPEG-1, 2 = MPEG-2, 0 = MPEG-2.5
        camada = (h >> 17) & 3  # 1 = Layer III
        ib = (h >> 12) & 0xF
        it = (h >> 10) & 3
        pad = (h >> 9) & 1
        if versao == 1 or camada != 1 or ib in (0, 15) or it == 3:
            break
        mpeg1 = versao == 3
        kbps = _BITRATES[mpeg1][ib]
        taxa = _TAXAS[versao][it]
        amostras = 1152 if mpeg1 else 576
        tam = (144000 if mpeg1 else 72000) * kbps // taxa + pad
        if i + tam > len(dados):
            break
        quadros.append((i, tam, amostras * 1_000_000 // taxa))
        i += tam
    return quadros


def limpar_mp3(dados: bytes) -> tuple[bytes, int]:
    """Só os quadros de áudio de ``dados`` (sem etiquetas) e a duração em
    microssegundos."""
    qs = quadros_mp3(dados)
    if not qs:
        raise ValueError("a voz não devolveu um MP3")
    return b"".join(dados[a : a + t] for a, t, _ in qs), sum(d for _, _, d in qs)


# --- texto ---------------------------------------------------------------------


def texto_falado(texto: str) -> str:
    """O versículo sem a marcação (<J>, <i>), como o app fala, e com
    "SENHOR" e "DEUS" (versaletes na ARA) escritos normalmente, para a voz
    não soletrar."""
    t = re.sub(r"\s+", " ", re.sub(r"<[^>]*>", "", texto)).strip()
    return re.sub(r"\b[A-ZÀ-Ý]{2,}\b", lambda m: m.group(0).capitalize(), t)


def anuncio(nome_livro: str, capitulo: int) -> str:
    return f"{nome_livro}, capítulo {capitulo}."


def sem_acento(s: str) -> str:
    s = unicodedata.normalize("NFD", s.lower())
    return "".join(c for c in s if unicodedata.category(c) != "Mn").replace(" ", "")


def abrir_banco() -> sqlite3.Connection:
    tmp = Path(tempfile.gettempdir()) / "biblia-narracao.db"
    if not tmp.exists() or tmp.stat().st_mtime < BANCO.stat().st_mtime:
        with gzip.open(BANCO) as g, open(tmp, "wb") as f:
            shutil.copyfileobj(g, f)
    return sqlite3.connect(tmp)


def livros(db: sqlite3.Connection) -> list[tuple[int, str, int]]:
    return list(db.execute("SELECT numero, nome, capitulos FROM livro ORDER BY numero"))


def versiculos(db: sqlite3.Connection, livro: int, cap: int) -> list[tuple[int, str]]:
    linhas = db.execute(
        "SELECT versiculo, texto FROM versiculo WHERE versao=? AND livro=? "
        "AND capitulo=? ORDER BY versiculo",
        (VERSAO, livro, cap),
    )
    return [(v, t) for v, t in ((v, texto_falado(t)) for v, t in linhas) if t]


def escolher_livros(db, nomes: list[str]) -> list[int]:
    todos = livros(db)
    escolhidos = []
    for n in nomes:
        if n.isdigit() and 1 <= int(n) <= 66:
            escolhidos.append(int(n))
            continue
        alvo = sem_acento(n)
        achados = [num for num, nome, _ in todos if sem_acento(nome) == alvo]
        if not achados:
            achados = [num for num, nome, _ in todos if sem_acento(nome).startswith(alvo)]
        if len(achados) != 1:
            sys.exit(f"Livro não reconhecido: {n}")
        escolhidos.append(achados[0])
    return sorted(set(escolhidos))


# --- voz -------------------------------------------------------------------------


async def falar(texto: str, voz: str, taxa: str) -> bytes:
    import edge_tts

    espera = 2.0
    for tentativa in range(TENTATIVAS):
        try:
            audio = bytearray()
            async for parte in edge_tts.Communicate(texto, voz, rate=taxa).stream():
                if parte["type"] == "audio":
                    audio += parte["data"]
            if audio:
                return bytes(audio)
            raise ValueError("áudio vazio")
        except Exception as e:  # noqa: BLE001 - a rede falha de vários jeitos
            if tentativa == TENTATIVAS - 1:
                raise
            print(f"    tentando de novo ({e.__class__.__name__}: {e})")
            await asyncio.sleep(espera)
            espera *= 2
    raise AssertionError


def montar_capitulo(partes: list[tuple[int, bytes]]) -> tuple[bytes, dict]:
    """Junta os áudios de (versículo, mp3) num MP3 só, com o início de cada
    versículo em milissegundos. O versículo 0 é o anúncio do capítulo."""
    audio = bytearray()
    tempos = []
    agora = 0
    for v, mp3 in partes:
        limpo, dur = limpar_mp3(mp3)
        if v > 0:
            tempos.append([v, agora // 1000])
        audio += limpo
        agora += dur
    return bytes(audio), {"versiculos": tempos, "duracao": agora // 1000}


async def narrar_capitulo(db, livro: int, nome: str, cap: int, voz: str, taxa: str, destino: Path):
    textos = [(0, anuncio(nome, cap))] + versiculos(db, livro, cap)
    limite = asyncio.Semaphore(PARALELOS)

    async def um(v: int, t: str) -> tuple[int, bytes]:
        async with limite:
            return v, await falar(t, voz, taxa)

    partes = await asyncio.gather(*(um(v, t) for v, t in textos))
    audio, tempos = montar_capitulo(list(partes))
    tempos["voz"] = voz
    destino.parent.mkdir(parents=True, exist_ok=True)
    tmp = destino.with_suffix(".tmp")
    tmp.write_bytes(audio)
    destino.with_suffix(".json").write_text(json.dumps(tempos), encoding="utf-8")
    os.replace(tmp, destino)


def pasta_livro(saida: Path, livro: int) -> Path:
    return saida / SIGLA / f"{livro:02d}"


def arquivo_capitulo(saida: Path, livro: int, cap: int) -> Path:
    return pasta_livro(saida, livro) / f"{cap:03d}.mp3"


def capitulo_pronto(saida: Path, livro: int, cap: int) -> bool:
    mp3 = arquivo_capitulo(saida, livro, cap)
    return mp3.exists() and mp3.with_suffix(".json").exists()


async def narrar_livros(db, nums: list[int], voz: str, taxa: str, saida: Path, refazer: bool):
    info = {n: (nome, caps) for n, nome, caps in livros(db)}
    for n in nums:
        nome, caps = info[n]
        for c in range(1, caps + 1):
            if not refazer and capitulo_pronto(saida, n, c):
                continue
            print(f"  {nome} {c}/{caps}")
            await narrar_capitulo(db, n, nome, c, voz, taxa, arquivo_capitulo(saida, n, c))
        print(f"{nome}: pronto")


# --- publicação -------------------------------------------------------------------


def sha256(caminho: Path) -> str:
    h = hashlib.sha256()
    with open(caminho, "rb") as f:
        for bloco in iter(lambda: f.read(1 << 20), b""):
            h.update(bloco)
    return h.hexdigest()


def tag_do_livro(livro: int) -> str:
    """O GitHub aceita até 1.000 arquivos por release: o Antigo Testamento
    (929 capítulos) fica numa, o Novo (260) noutra."""
    return TAG_AT if livro <= 39 else TAG_NT


def nome_publicado(livro: int, cap: int) -> str:
    return f"{livro:02d}-{cap:03d}.mp3"


def tempos_do_livro(saida: Path, livro: int, caps: int) -> dict:
    capitulos = {}
    for c in range(1, caps + 1):
        t = json.loads(arquivo_capitulo(saida, livro, c).with_suffix(".json").read_text("utf-8"))
        capitulos[str(c)] = {"versiculos": t["versiculos"], "duracao": t["duracao"]}
    return {"versao": VERSAO, "livro": livro, "capitulos": capitulos}


def preparar(db, saida: Path) -> list[tuple[int, str, int]]:
    """Os livros completos, com o tempos-NN.json de cada um em saida/publicar."""
    pronta = saida / "publicar"
    pronta.mkdir(parents=True, exist_ok=True)
    completos = []
    horas = 0.0
    for n, nome, caps in livros(db):
        if not all(capitulo_pronto(saida, n, c) for c in range(1, caps + 1)):
            continue
        tempos = tempos_do_livro(saida, n, caps)
        (pronta / f"tempos-{n:02d}.json").write_text(json.dumps(tempos), encoding="utf-8")
        horas += sum(c["duracao"] for c in tempos["capitulos"].values()) / 3_600_000
        completos.append((n, nome, caps))
    print(f"{len(completos)} de 66 livros prontos ({horas:.1f} h de áudio)")
    return completos


def gh() -> str:
    if os.name == "nt" and Path(GH_WINDOWS).exists():
        return GH_WINDOWS
    achado = shutil.which("gh")
    if not achado:
        sys.exit("Não achei o gh (GitHub CLI). Instale e rode: gh auth login")
    return achado


def _garantir_release(exe: str, tag: str):
    if subprocess.run([exe, "release", "view", tag, "--repo", REPO], capture_output=True).returncode == 0:
        return
    parte = "Antigo" if tag == TAG_AT else "Novo"
    subprocess.run(
        [exe, "release", "create", tag, "--repo", REPO, "--latest=false",
         "--title", f"Narração da Bíblia (ARA), {parte} Testamento",
         "--notes", "Áudio da Bíblia narrada com voz neural, um MP3 por capítulo, "
         "e os tempos de cada versículo. O app toca daqui pela internet."],
        check=True,
    )


def publicar(db, saida: Path):
    exe = gh()
    completos = preparar(db, saida)
    pronta = saida / "publicar"
    enviados_path = saida / "enviados.json"
    enviados = json.loads(enviados_path.read_text("utf-8")) if enviados_path.exists() else {}

    def enviar(tag: str, arquivos: list[tuple[Path, str]]):
        # Em lotes: o gh aceita vários arquivos por chamada. O nome do asset
        # é o do arquivo, por isso os MP3 vão copiados com o nome publicado.
        for i in range(0, len(arquivos), 20):
            lote = arquivos[i : i + 20]
            subprocess.run(
                [exe, "release", "upload", tag, *[str(a) for a, _ in lote], "--repo", REPO, "--clobber"],
                check=True,
            )
            for a, chave in lote:
                enviados[chave] = sha256(a)
            enviados_path.write_text(json.dumps(enviados, indent=1), encoding="utf-8")

    for n, nome, caps in completos:
        tag = tag_do_livro(n)
        _garantir_release(exe, tag)
        faltam = []
        for c in range(1, caps + 1):
            mp3 = arquivo_capitulo(saida, n, c)
            chave = f"{tag}/{nome_publicado(n, c)}"
            if enviados.get(chave) == sha256(mp3):
                continue
            copia = pronta / nome_publicado(n, c)
            shutil.copyfile(mp3, copia)
            faltam.append((copia, chave))
        tempos = pronta / f"tempos-{n:02d}.json"
        chave_t = f"{tag}/{tempos.name}"
        if faltam or enviados.get(chave_t) != sha256(tempos):
            print(f"Enviando {nome} ({len(faltam)} capítulos)...")
            enviar(tag, faltam)
            # Por último: o app só toca um livro depois de achar os tempos.
            enviar(tag, [(tempos, chave_t)])
            for copia, _ in faltam:
                copia.unlink(missing_ok=True)
    print("Publicado. Quem tem o app já ouve os livros prontos.")


async def listar_vozes():
    import edge_tts

    for v in await edge_tts.list_voices():
        if v["Locale"].startswith("pt"):
            print(f"{v['ShortName']:28} {v['Gender']}")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("livros", nargs="*", help="nomes ou números dos livros")
    ap.add_argument("--tudo", action="store_true", help="a Bíblia inteira")
    ap.add_argument("--amostra", action="store_true", help="só o Salmo 23, em amostra.mp3")
    ap.add_argument("--vozes", action="store_true", help="lista as vozes em português")
    ap.add_argument("--voz", default=VOZ_PADRAO)
    ap.add_argument("--taxa", default="+0%", help='velocidade da voz, ex.: "-5%%"')
    ap.add_argument("--refazer", action="store_true", help="gera de novo o que já existe")
    ap.add_argument("--publicar", action="store_true", help="envia os livros prontos ao GitHub")
    ap.add_argument("--saida", type=Path, default=SAIDA)
    a = ap.parse_args(argv)

    if a.vozes:
        asyncio.run(listar_vozes())
        return
    try:
        import edge_tts  # noqa: F401
    except ImportError:
        if a.amostra or a.tudo or a.livros:
            sys.exit("Instale primeiro: pip install edge-tts")
    db = abrir_banco()
    if a.amostra:
        destino = a.saida / "amostra.mp3"
        asyncio.run(narrar_capitulo(db, 19, "Salmo", 23, a.voz, a.taxa, destino))
        print(f"Ouça: {destino}")
        return
    nums = list(range(1, 67)) if a.tudo else escolher_livros(db, a.livros)
    if nums:
        asyncio.run(narrar_livros(db, nums, a.voz, a.taxa, a.saida, a.refazer))
    if a.publicar:
        publicar(db, a.saida)
    else:
        preparar(db, a.saida)


if __name__ == "__main__":
    main()
