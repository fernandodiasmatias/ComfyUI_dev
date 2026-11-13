# ComfyUI Linux Portable — contexto do projeto

## Objetivo
Gerar a versão **portable para Linux** do ComfyUI, equivalente ao `ComfyUI_windows_portable`: pasta autocontida com Python embarcado, sem depender de Python/pip do sistema.

## Alvo
- Distro: **Rocky Linux 8** (glibc 2.28), x86_64
- Backend: **CPU-only** (torch do índice `https://download.pytorch.org/whl/cpu`)
- Python: **3.13.14** (igual ao Windows portable v0.45.0), torch **2.14.1+cpu**

## Ambiente de build
- WSL2 com a distro **`Rocky8`** (Rocky Linux 8.10, importada da imagem oficial `Rocky-8-Container-Base`), disco em `D:\WSL\Rocky8`. Não usa o Docker de produção.
- Acesso: `wsl -d Rocky8 -u root`. O projeto aparece em `/mnt/d/ComfyUI_dev`.
- O build roda em `/root/build` (ext4 nativo, por causa de symlinks/chmod) e o `.tar.xz` final é copiado para `ComfyUI_linux/`.
- Para remover: `wsl --unregister Rocky8` e apagar `D:\WSL\Rocky8`.
- O `curl` do Rocky 8 é antigo (7.61): não usar `--retry-all-errors`.

## Layout
- `ComfyUI_source/` — source upstream do ComfyUI. **Não editar** (só ler/copiar). Seu `AGENTS.md` é o guia de contribuição upstream.
- `ComfyUI_windows/` — Windows portable oficial v0.45.0 (`.7z` + pasta extraída), para manter compatibilidade com o Linux.
- `ComfyUI_linux/` — saída: `ComfyUI_linux_portable_cpu.tar.xz` (~700 MB).
- `linux_base_files/` — arquivos copiados para a raiz do portable (`run_cpu.sh`, `README_VERY_IMPORTANT.txt`, `update/*.sh`).
- `build_linux_portable.sh` — script de build, rodar dentro do Rocky 8.
- `scripts/` — wrappers para rodar no WSL: `run_build.sh` (build em `/root/build`, log em `/root/build.log`), `run_tests.sh` (extrai o `.tar.xz`, testa update e quick-test) e `run_workflow.sh` (sobe o servidor e roda um workflow SD1.5 em CPU usando o checkpoint de `D:\models` via `extra_model_paths.yaml` numa cópia de teste).

## Windows portable de referência
- `ComfyUI_windows/ComfyUI_windows_portable_nvidia_v0.45.0.7z` — release oficial v0.45.0 (1.976 MB, não há versão só CPU; roda sem GPU por `advanced\run_cpu.bat`). Extraído em `ComfyUI_windows/ComfyUI_windows_portable/` (o `tar.exe` do Windows não abre o 7z; foi extraído com 7-Zip).
- Versões confirmadas: ComfyUI 0.45.0, Python **3.13.14**, torch `2.14.1+cu130`, comfy-aimdo 0.6.0, comfy-kitchen 0.2.41, comfy-angle 0.1.1, frontend 1.58.5, `.comfy_environment` = `local-portable`.
- O Linux foi igualado a ele: Python 3.13.14 (`PBS_TAG=20260610`) e `torch==2.14.1 torchvision==0.29.1 torchaudio==2.11.0` do índice CPU (`TORCH_PINS`). Resta a diferença CPU x CUDA, que pode alterar levemente o resultado numérico.
- `update_comfyui_and_python_dependencies.sh` tem o torch fixo em `torch==2.14.1 torchvision==0.29.1 torchaudio==2.11.0` (o do Windows faz `--upgrade` sem pin). Ao mudar `TORCH_PINS` no `build_linux_portable.sh`, atualizar também esse script.
- Workflows são JSON e só referenciam nomes de modelos: manter os mesmos nomes/subpastas em `models/`. Custom nodes dependentes de CUDA ou de wheels do Windows precisam ser reinstalados/podem não existir no Linux.

## Como o Windows portable é montado (referência)
- `ComfyUI_source/.github/workflows/stable-release.yml` e `windows_release_dependencies.yml`: zip embed do python.org + get-pip + `._pth` (`import site`, `../ComfyUI`) + pip install + 7z.
- `ComfyUI_source/.ci/windows_nvidia_base_files/` (`run_nvidia_gpu.bat`, README) e `.ci/update_windows/` (`update.py`, `update_comfyui.bat`).
- `.comfy_environment` contém `local-portable`.

## Decisões
- Python embarcado = **python-build-standalone** (astral-sh, `install_only`, `x86_64-unknown-linux-gnu`), pois o Linux não tem "embeddable zip". Compatível com glibc ≥ 2.17.
- `PBS_TAG` fixo em **`20260610`** (build do Python 3.13.14, mesma data do Python do Windows; 3.13.11 era a `20260127`). A listagem `releases?per_page=30` da API do GitHub dá 504 e a release `latest` só tem 3.13.18; por isso o script consulta só `releases/tags/$PBS_TAG`.
- Pasta do Python chama-se `python_embeded` (mesmo nome do Windows) para reaproveitar `update.py`.
- Sempre chamar `python -s -m pip` / `python -s ...` (isola do user site), como nos `.bat`.
- `update.py` é reaproveitado do source sem modificação. Ele exige um repo git: o build faz `git init -b master` em `ComfyUI/`, `remote add origin` (ComfyUI oficial), `fetch --depth 150 origin master` e `reset origin/master` (como o CI do Windows, que clona com `fetch-depth: 150`).
- `update_comfyui.sh` exporta `SSL_CERT_FILE` apontando para o `certifi` embarcado: o libgit2 do pygit2 não acha o bundle de CA do Rocky (`/etc/pki/...`) e falha com `CertificateError`.
- Os pacotes `comfyui-workflow-templates-media-{image,video,other}` são desinstalados no build (como no Windows) para reduzir o tamanho (971 MB → 701 MB). O update os reinstala, pois o `requirements.txt` novo os exige.
- Empacotamento `tar | xz -9e -T0` (equivale ao 7z lzma2).

## Build e teste
```
# no PowerShell (no Git Bash o /mnt/d é reescrito e quebra)
wsl -d Rocky8 -u root -- bash /mnt/d/ComfyUI_dev/scripts/run_build.sh
wsl -d Rocky8 -u root -- bash /mnt/d/ComfyUI_dev/scripts/run_tests.sh
wsl -d Rocky8 -u root -- bash /mnt/d/ComfyUI_dev/scripts/run_workflow.sh
```
Equivale a `WORK_DIR=/root/build bash build_linux_portable.sh` e depois, na pasta extraída:
```
./python_embeded/bin/python -s ComfyUI/main.py --quick-test-for-ci --cpu
./update/update_comfyui.sh
./update/update_comfyui_and_python_dependencies.sh
./run_cpu.sh   # http://127.0.0.1:8188
```
Variáveis do script: `PY_VERSION` (3.13.14), `PBS_TAG` (20260610), `TORCH_PINS` (torch/torchvision/torchaudio pinados), `WORK_DIR` (padrão `ComfyUI_linux/`).

## Repositório e releases
- Repositório **privado**: `https://github.com/fernandodiasmatias/ComfyUI_dev` (branch `main`, remote `origin`). Versionados só os arquivos do projeto; `ComfyUI_source/`, `ComfyUI_windows/`, `ComfyUI_linux/` e `.claude/` estão no `.gitignore`. `.gitattributes` força LF em `.sh`/`.md`/`.txt`.
- `user.name`/`user.email` locais = `Fernando Matias` / noreply do GitHub (o global é um e-mail pessoal usado como nome).
- Release: `v0.45.0-linux-cpu` com `ComfyUI_linux_portable_cpu.tar.xz` (697.623.092 bytes, SHA256 `E2EDD53425CFBA87D0507478B927D0C373A73FBAAEA40611688BE13EE9D9D108`, Python 3.13.14, torch 2.14.1+cpu). O limite do GitHub é 2 GB por arquivo.
- GitHub CLI 2.104.0 instalado e logado (`fernandodiasmatias`), em `C:\Program Files\GitHub CLI\gh.exe` (pode não estar no PATH de sessões já abertas). Nova release: `gh release create <tag> <arquivo> --repo fernandodiasmatias/ComfyUI_dev --notes-file <notas>`.
- Não fazer push, criar repositório ou release sem pedido explícito do usuário.

## Licenças e preparação para ficar público
- Licença do projeto: **GPL-3.0** (`LICENSE`, copiado do ComfyUI); README em pt-BR (`README.md`) e inglês (`README.en.md`).
- O portable gerado inclui na raiz: `LICENSE`, `SOURCE_OFFER.txt` (fontes dos componentes GPL/LGPL + oferta escrita de 3 anos, via issues do repo), `BUILD_INFO.txt`, `requirements-freeze.txt` e `THIRD_PARTY_LICENSES/` (gerado por `scripts/collect_licenses.py` no build; 86 pacotes, nenhum `UNKNOWN`).
- Pacotes sem licença na metadata, verificados nos repositórios upstream: `comfyui-frontend-package` e `comfy-aimdo` são GPL-3.0 (tabela `GPL3_OVERRIDES` no coletor; ao trocar versões, rever pacotes `UNKNOWN`).
- Pontos de atenção: o PyAV traz FFmpeg com x264/x265 (GPL; patentes de H.264/H.265 variam por país); a oferta de código aponta para os repositórios upstream e não hospeda os fontes (anexar um arquivo de fontes à release seria mais seguro); o bundle JS do frontend traz libs npm sem textos de licença; modelos baixados têm licenças próprias. Não é aconselhamento jurídico.
- Projeto não oficial: não usar o nome/logo do ComfyUI como marca própria; o README declara que não há vínculo com a Comfy Org.
- Privacidade: o histórico foi reescrito para o autor `Fernando Matias <25366190+fernandodiasmatias@users.noreply.github.com>` (e-mail pessoal removido) com push forçado; `user.email` local aponta para o noreply. A release/tag foram recriadas porque a tag antiga mantinha o commit com o e-mail.

## Convenções
- Scripts `.sh` com final de linha **LF** e `chmod +x`.
- Não modificar `ComfyUI_source`.
- Comandos `wsl ...` via PowerShell, não Git Bash (reescrita de caminhos `/mnt/...`).

## Status dos testes (Rocky 8)
Passaram: extrair e abrir (Python 3.13.14, torch `2.14.1+cpu`), `--quick-test-for-ci --cpu`, mover a pasta e subir o servidor (`/`, `/system_stats`, `/object_info/KSampler`), `update_comfyui.sh` e `update_comfyui_and_python_dependencies.sh`, e um workflow real SD1.5 (256x256, 4 steps) em CPU, ~51 s, imagem salva (`ComfyUI_linux/cpu_test.png`).
