codex-auth-transfer.sh

English

Overview

- Purpose: Export Codex CLI authentication data from a machine that can log in with a browser and import it on a headless/remote server.
- Why: Codex CLI sign-in requires a local browser. This script lets you authorize on one host and securely transfer the credentials to another.
- Scope: Only operates on your local user’s Codex CLI data under your home directory.

What It Does

- Export: Collects `~/.config/codex`, `~/.local/share/codex`, and `~/.codex` (if they exist), stages them with restrictive permissions, writes a simple manifest, and packs everything into a tarball.
- Import: Extracts, optionally backs up existing destinations with suffix `.bak-YYYYmmdd-HHMMSS` (when using `--force`), copies directories into `$HOME`, and enforces `700` on folders and `600` on files.
- Detection: When available, uses `codex config path` as an additional hint for where Codex stores data.
- Security: The exported bundle is created with permission `600`. Transport it only over secure channels such as `scp`, `rsync` over SSH, or similar.

Background

- Context: Codex CLI’s sign-in flow requires a local browser, which blocks straightforward installation on headless or remote servers.
- Why this script exists: I authored this script to export Codex CLI auth from a workstation that can complete browser-based login and then import it on a headless server.
- Platforms used in development: Export crafted on Linux Mint; import successfully tested on AlmaLinux.
- Provenance: The script itself was drafted with Codex CLI.

Requirements

- Bash on Linux (tested with Linux Mint as source and AlmaLinux as target).
- Optional: `rsync` for faster and permission-aware copies (falls back to `cp -a`).

Usage

- Export (on the source host already signed in):
  `./codex-auth-transfer.sh export -o codex-auth-bundle.tar.gz`
- Import (on the headless/remote host):
  `./codex-auth-transfer.sh import -f codex-auth-bundle.tar.gz --force`
- Help:
  `./codex-auth-transfer.sh --help`

Notes and Safety

- Never commit or publish the exported bundle. It contains your Codex credentials. Add it to `.gitignore` and store/transfer it securely.
- Some CLIs may bind tokens to a specific machine/hostname. If Codex refuses credentials after transfer, try device-code login or use a secure SSH tunnel to complete login.
- Metadata in bundle: By default, the manifest includes creation time and, unless disabled, `user` and `host` for traceability.
  - To omit user/host metadata, set `CODEX_AUTH_TRANSFER_NO_METADATA=1` when exporting, e.g.:
    `CODEX_AUTH_TRANSFER_NO_METADATA=1 ./codex-auth-transfer.sh export -o codex-auth-bundle.tar.gz`
 - Repository contents: This repository intentionally includes only the script and this README. No exported bundle (e.g., `codex-auth-bundle.tar.gz`) is included.

Português (Brasil)

Visão Geral

- Propósito: Exportar dados de autenticação do Codex CLI de uma máquina com navegador e importar em um servidor remoto/headless.
- Motivo: O login do Codex CLI exige navegador local. Este script permite autorizar em um host e transferir as credenciais com segurança para outro.
- Escopo: Opera apenas nos dados do Codex do usuário local dentro do seu diretório HOME.

O Que Ele Faz

- Exportar: Coleta `~/.config/codex`, `~/.local/share/codex` e `~/.codex` (se existirem), faz staging com permissões restritas, grava um manifesto simples e empacota tudo em um tarball.
- Importar: Extrai, faz backup dos destinos existentes com sufixo `.bak-YYYYmmdd-HHMMSS` (quando `--force`), copia os diretórios para `$HOME` e aplica `700` em pastas e `600` em arquivos.
- Detecção: Quando disponível, usa `codex config path` como dica adicional de onde o Codex guarda dados.
- Segurança: O bundle exportado é criado com permissão `600`. Transporte-o apenas por canais seguros como `scp`, `rsync` via SSH, etc.

Contexto

- Contexto: O fluxo de login do Codex CLI exige um navegador local, o que impede a instalação direta em servidores remotos/headless.
- Por que este script existe: Eu criei este script para exportar a autenticação do Codex CLI de uma máquina que consegue concluir o login via navegador e importar em um servidor headless.
- Plataformas usadas: Exportação criada no Linux Mint; importação testada com sucesso no AlmaLinux.
- Origem: O script foi redigido com apoio do próprio Codex CLI.

Requisitos

- Bash em Linux (testado com Linux Mint como origem e AlmaLinux como destino).
- Opcional: `rsync` para cópias rápidas e com controle de permissões (fallback para `cp -a`).

Uso

- Exportar (no host de origem já logado):
  `./codex-auth-transfer.sh export -o codex-auth-bundle.tar.gz`
- Importar (no host remoto/headless):
  `./codex-auth-transfer.sh import -f codex-auth-bundle.tar.gz --force`
- Ajuda:
  `./codex-auth-transfer.sh --help`

Observações e Segurança

- Nunca commite ou publique o bundle exportado. Ele contém suas credenciais do Codex. Adicione ao `.gitignore` e armazene/transfira com segurança.
- Alguns CLIs podem atrelar tokens a máquina/hostname. Se o Codex recusar após a transferência, tente login via device code ou use um túnel SSH seguro para concluir o login.
- Metadados no bundle: Por padrão, o manifesto inclui data de criação e, a menos que desabilitado, `user` e `host` para rastreabilidade.
  - Para omitir user/host, defina `CODEX_AUTH_TRANSFER_NO_METADATA=1` ao exportar, por exemplo:
    `CODEX_AUTH_TRANSFER_NO_METADATA=1 ./codex-auth-transfer.sh export -o codex-auth-bundle.tar.gz`
 - Conteúdo do repositório: Este repositório inclui intencionalmente apenas o script e este README. Nenhum bundle exportado (ex.: `codex-auth-bundle.tar.gz`) está incluído.

License Suggestion

- Goal: Allow anyone to use, modify, and share the script, but prohibit commercial use.
- Note: This restriction means it is not an OSI-approved “open source” license. If true open source is required, you must allow commercial use.
- Recommended for non-commercial software: PolyForm Noncommercial License 1.0.0.
  - Summary: Permits private/internal use, modification, and distribution; forbids commercial use.
  - How to apply: Add a `LICENSE` file with the PolyForm Noncommercial 1.0.0 text and reference it in this README.
- Alternative (less ideal for code): Creative Commons BY-NC 4.0. Better suited for content, not software.

Sugestão de Licença

- Objetivo: Permitir que qualquer pessoa use, modifique e compartilhe o script, mas proibir uso comercial.
- Observação: Essa restrição significa que não será uma licença “open source” aprovada pela OSI. Se você precisa de open source verdadeiro, o uso comercial deve ser permitido.
- Recomendação para software não comercial: PolyForm Noncommercial License 1.0.0.
  - Resumo: Permite uso privado/interno, modificação e distribuição; proíbe uso comercial.
  - Como aplicar: Adicione um arquivo `LICENSE` com o texto da PolyForm Noncommercial 1.0.0 e referencie-o neste README.
- Alternativa (menos ideal para código): Creative Commons BY-NC 4.0. Mais adequada para conteúdo do que para software.
