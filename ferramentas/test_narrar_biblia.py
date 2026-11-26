import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import narrar_biblia as nb  # noqa: E402

# Um quadro MPEG-2 Layer III, 24 kHz, 48 kbps, mono: 144 bytes, 24 ms.
QUADRO = bytes([0xFF, 0xF3, 0x64, 0xC4]) + bytes(140)


def mp3(quadros: int, id3: bool = False) -> bytes:
    cabeca = b"ID3\x04\x00\x00\x00\x00\x00\x05" + b"x" * 5 if id3 else b""
    return cabeca + QUADRO * quadros


class TesteMp3(unittest.TestCase):
    def test_conta_quadros_e_tira_etiqueta(self):
        qs = nb.quadros_mp3(mp3(3, id3=True))
        self.assertEqual([(a, t) for a, t, _ in qs], [(15, 144), (159, 144), (303, 144)])
        limpo, dur = nb.limpar_mp3(mp3(3, id3=True) + b"lixo")
        self.assertEqual(limpo, QUADRO * 3)
        self.assertEqual(dur, 72_000)

    def test_recusa_o_que_nao_e_mp3(self):
        with self.assertRaises(ValueError):
            nb.limpar_mp3(b"<html>erro</html>")

    def test_monta_o_capitulo_com_os_tempos(self):
        audio, tempos = nb.montar_capitulo([(0, mp3(50)), (1, mp3(100)), (2, mp3(25))])
        self.assertEqual(len(audio), 175 * 144)
        self.assertEqual(tempos, {"versiculos": [[1, 1200], [2, 3600]], "duracao": 4200})


class TesteTexto(unittest.TestCase):
    def test_texto_e_nomes(self):
        self.assertEqual(nb.texto_falado("<J>Eu sou</J>  o <i>caminho</i>"), "Eu sou o caminho")
        self.assertEqual(nb.texto_falado("O SENHOR DEUS é o meu pastor"), "O Senhor Deus é o meu pastor")
        self.assertEqual(nb.anuncio("Gênesis", 1), "Gênesis, capítulo 1.")
        self.assertEqual(nb.sem_acento("Cântico dos Cânticos"), "canticodoscanticos")


class TestePublicacao(unittest.TestCase):
    def test_prepara_so_os_livros_completos(self):
        import json
        import tempfile

        db = nb.abrir_banco()
        with tempfile.TemporaryDirectory() as d:
            saida = Path(d)
            # Obadias (31) tem um capítulo; Jonas (32), quatro, e só um pronto.
            for livro, cap in [(31, 1), (32, 1)]:
                mp3 = nb.arquivo_capitulo(saida, livro, cap)
                mp3.parent.mkdir(parents=True, exist_ok=True)
                mp3.write_bytes(QUADRO)
                mp3.with_suffix(".json").write_text(
                    json.dumps({"versiculos": [[1, 2000]], "duracao": 5000, "voz": "x"})
                )
            completos = nb.preparar(db, saida)
            self.assertEqual([n for n, _, _ in completos], [31])
            tempos = json.loads((saida / "publicar" / "tempos-31.json").read_text())
            self.assertEqual(tempos["capitulos"], {"1": {"versiculos": [[1, 2000]], "duracao": 5000}})
        self.assertEqual(nb.tag_do_livro(39), "narracao-ara-at")
        self.assertEqual(nb.tag_do_livro(40), "narracao-ara-nt")
        self.assertEqual(nb.nome_publicado(19, 119), "19-119.mp3")


if __name__ == "__main__":
    unittest.main()
