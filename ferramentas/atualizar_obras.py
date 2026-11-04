"""Regrava em ``assets/estudo.db.gz`` só o que vem das obras indexadas.

    python ferramentas/indexar_obras.py     (os 106 PDFs, em ferramentas/cache/)
    python ferramentas/atualizar_obras.py

Troca as tabelas ``obra``, ``capitulo``, ``trecho`` e ``ref_obra`` pelas de
``cache/obras.db`` e recalcula o que depende delas: as leituras de Ellen G.
White dos temas e do guia sinótico, as da introdução de cada livro e a
conferência das citações nas notas. Referências cruzadas, mapas e o resto do
banco ficam como estão, sem baixar nada (o ``construir_estudo.py`` refaz o
banco inteiro e baixa as referências cruzadas e os mapas).

Os IDs dos capítulos já existentes não mudam (ver ``indexar_obras.py``): o
progresso do guia de leitura do app é guardado por eles.
"""
import gzip
import os
import shutil
import sqlite3
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import construir_estudo as ce  # noqa: E402


def main():
    tmp = tempfile.mkdtemp()
    try:
        biblia = os.path.join(tmp, "biblia.db")
        with gzip.open(ce.BIBLIA) as g, open(biblia, "wb") as f:
            shutil.copyfileobj(g, f)
        textos, _ = ce._texto_ara(biblia)
        existe = {(l, c * 1000 + v) for (l, c, v) in textos}

        caminho = os.path.join(tmp, "estudo.db")
        with gzip.open(ce.DESTINO) as g, open(caminho, "wb") as f:
            shutil.copyfileobj(g, f)
        con = sqlite3.connect(caminho)
        antes = con.execute("SELECT count(*) FROM capitulo").fetchone()[0]
        for tabela in ("ref_obra", "trecho", "capitulo", "obra", "tema",
                       "tema_ref", "tema_egw", "estudo", "estudo_pergunta",
                       "sinotico_secao", "sinotico_evento", "sinotico_leitura",
                       "sinotico_ref"):
            con.execute("DROP TABLE IF EXISTS %s" % tabela)
        con.execute("DROP INDEX IF EXISTS ix_nota")
        con.execute("DELETE FROM nota")
        con.execute("UPDATE introducao SET egw=NULL")
        con.commit()
        ce.copiar_obras(con)
        ce.introducoes_egw(con)
        ce.notas(con, existe)
        ce.temas(con, existe)
        ce.sinotico(con, existe)
        con.commit()
        con.execute("VACUUM")
        depois = con.execute("SELECT count(*) FROM capitulo").fetchone()[0]
        con.close()

        with open(caminho, "rb") as f, \
                gzip.GzipFile(ce.DESTINO, "wb", compresslevel=9, mtime=0) as g:
            shutil.copyfileobj(f, g)
        print("Regravado %s (%.1f MB; capítulos: %d antes, %d agora)" % (
            ce.DESTINO, os.path.getsize(ce.DESTINO) / 1e6, antes, depois))
    finally:
        shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
