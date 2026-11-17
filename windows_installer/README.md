# Instalador do ComfyUI para Windows (um clique)

Instala o ComfyUI portable oficial no Windows sem precisar de conhecimento técnico.
Projeto não oficial, sem vínculo com a Comfy Org.

## Como usar

1. Baixe o arquivo `Instalar ComfyUI.bat` e salve **em qualquer lugar** (Downloads, Área de Trabalho...). Não precisa criar nenhuma pasta antes.
2. Dê dois cliques nele.
3. Se o Windows exibir o aviso do SmartScreen, clique em **Mais informações** e depois em **Executar assim mesmo**.
4. Se pedir permissão de administrador (só para instalar o Visual C++), clique em **Sim**.
5. Aguarde. Ao terminar, o ComfyUI abre sozinho no navegador (`http://127.0.0.1:8188`).

Depois da instalação o `.bat` pode ser apagado. Para abrir o ComfyUI outra vez, use o atalho **ComfyUI** da Área de Trabalho ou do Menu Iniciar.

## Onde instala

- Padrão: `C:\ComfyUI` (o ComfyUI fica em `C:\ComfyUI\ComfyUI_windows_portable`).
- Se o C: tiver pouco espaço livre, usa o disco com mais espaço.
- Outra pasta: rode o `.bat` com `-InstallDir D:\MinhaPasta`. Evite acentos e espaços no caminho.

## O que o instalador faz

1. Confere o computador: Windows 10/11 64 bits, memória RAM (avisa se tiver menos de 8 GB), acesso à internet e Visual C++ Redistributable (instala se faltar).
2. Detecta a placa de vídeo e escolhe o pacote certo:
   - NVIDIA: pacote CUDA 13 (driver 580 ou mais novo) ou CUDA 12.6.
   - AMD Radeon RX 7000/9000: pacote AMD.
   - Intel Arc: pacote Intel.
   - Outras: roda no processador (CPU), bem mais lento.
3. Baixa o ComfyUI portable oficial (última release do GitHub, ~2 GB).
4. Baixa o 7-Zip (`7zr.exe` 26.06, com checksum SHA256 conferido) para extrair, a menos que o 7-Zip já esteja instalado.
5. Extrai tudo e apaga o arquivo baixado.
6. Baixa o modelo inicial Stable Diffusion 1.5 (~2,1 GB) em `ComfyUI\models\checkpoints`.
7. Cria os atalhos (ComfyUI e pasta de modelos) e abre o ComfyUI.

## Requisitos

- Windows 10 ou 11, 64 bits.
- Internet (cerca de **4 GB** de download, 10 a 60 minutos conforme a conexão).
- Cerca de **12 GB** livres em disco durante a instalação.
- 8 GB de RAM no mínimo (ideal 16 GB). Placa NVIDIA recomendada.

## Dicas

- Se a internet cair, rode o `.bat` de novo: o download continua de onde parou.
- Se o ComfyUI já estiver instalado, rodar de novo só recria os atalhos.
- O Firewall do Windows pode perguntar sobre a rede: pode clicar em Cancelar, o ComfyUI só é acessível neste computador.
- Novos modelos (checkpoints, LoRAs etc.) vão em `ComfyUI\models`, nas subpastas correspondentes (há um atalho na Área de Trabalho).
- Se o ComfyUI não abrir, instale o Visual C++: https://aka.ms/vc14/vc_redist.x64.exe e, em placas NVIDIA, atualize o driver.

## Opções avançadas

Passe depois do nome do arquivo, por exemplo `Instalar ComfyUI.bat -SkipModel`:

| Opção | Efeito |
|---|---|
| `-InstallDir <pasta>` | Pasta de instalação |
| `-Gpu auto\|nvidia\|amd\|intel\|cpu` | Força o tipo de pacote (padrão: detecta) |
| `-LocalArchive <arquivo.7z>` | Usa um `.7z` já baixado |
| `-SkipModel` | Não baixa o modelo inicial |
| `-NoLaunch` | Não abre o ComfyUI no final |
| `-DryRun` | Só confere o computador e mostra o que seria feito |

## Licenças

O modelo Stable Diffusion 1.5 tem licença própria (CreativeML OpenRAIL-M). O ComfyUI é GPL-3.0.
