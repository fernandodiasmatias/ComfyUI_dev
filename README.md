# ComfyUI Linux Portable (CPU)

**Português** | [English](README.en.md)

Scripts para gerar uma versão **portable para Linux** do [ComfyUI](https://github.com/comfyanonymous/ComfyUI), equivalente ao `ComfyUI_windows_portable`: pasta autocontida com Python embarcado (`python_embeded/`), sem depender do Python do sistema.

- Alvo: Linux x86_64 com glibc 2.28 ou mais novo (testado no **Rocky Linux 8.10**), **somente CPU**
- Python 3.13.14 ([python-build-standalone](https://github.com/astral-sh/python-build-standalone)) e torch 2.14.1+cpu, iguais ao Windows portable v0.45.0
- ComfyUI 0.45.0

> **Projeto não oficial.** Não tem relação com a Comfy Org nem é endossado por ela. "ComfyUI" é o nome do projeto upstream.

## Usar o pacote pronto
Baixe `ComfyUI_linux_portable_cpu.tar.xz` na página de [Releases](../../releases):
```
tar -xJf ComfyUI_linux_portable_cpu.tar.xz
cd ComfyUI_linux_portable
./run_cpu.sh        # http://127.0.0.1:8188
```
Atualizar: `./update/update_comfyui.sh`. Modelos não vêm no pacote: coloque-os em `ComfyUI/models/`.

## Gerar você mesmo
Precisa do código-fonte do ComfyUI em `ComfyUI_source/` (não versionado aqui) e de uma máquina Rocky Linux 8:
```
bash build_linux_portable.sh
```
Detalhes do ambiente WSL, decisões e testes estão em [AGENTS.md](AGENTS.md); scripts de teste em `scripts/`.

## Licença
Os arquivos deste repositório são distribuídos sob a **GNU GPL v3.0** (ver [LICENSE](LICENSE)), a mesma licença do ComfyUI.

O pacote gerado reúne o ComfyUI (GPL-3.0), o Python e dezenas de bibliotecas, cada uma com sua licença. O pacote traz dentro dele:
- `LICENSE` e `SOURCE_OFFER.txt`: licença, onde obter o código-fonte e oferta escrita para componentes GPL/LGPL;
- `THIRD_PARTY_LICENSES/`: textos de licença e resumo de todas as dependências;
- `requirements-freeze.txt` e `BUILD_INFO.txt`: versões exatas usadas no build.

## Avisos
- O PyAV instalado no pacote inclui bibliotecas FFmpeg com codecs como H.264 e H.265 (x264/x265, GPL). O uso desses codecs pode envolver licenças de patentes em alguns países; isso é responsabilidade de quem usa e redistribui.
- Modelos baixados por você têm licenças e termos próprios e **não** fazem parte deste projeto.
- Sem garantia de qualquer tipo, conforme a GPL-3.0.
