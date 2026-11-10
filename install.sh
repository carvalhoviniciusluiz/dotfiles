#!/usr/bin/env bash
# Recria o ambiente de desenvolvimento deste Mac (Apple Silicon).
#
# Uso:
#   ./install.sh                 # tudo, na ordem
#   ./install.sh --only links    # só uma etapa (veja a lista em STEPS)
#   ./install.sh --list          # lista as etapas
#   ./install.sh --with-bin      # também clona carvalhoviniciusluiz/dotfiles-bin em ~/bin
#   ./install.sh --macos-tweaks  # também desliga Teams/AutoUpdate/DockerHelper no login
#
# Idempotente: pode rodar de novo; arquivos existentes vão para ~/.dotfiles-backup/<data>/.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=versions.env disable=SC1091
source "$DOTFILES/versions.env"

BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

WITH_BIN=0
MACOS_TWEAKS=0
ONLY=""

STEPS=(preflight brew asdf links git npm uv binaries fonts zsh_plugins
       apps sublime vscode iterm ghidra ai_memory skills video claude codex craft github)

log()  { printf '\n\033[1;35m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '    \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\033[31merro:\033[0m %s\n' "$*" >&2; exit 1; }

# Baixa $1 para $2 e confere o SHA-256 $3.
fetch() {
  curl -fsSL --proto '=https' --tlsv1.2 -o "$2" "$1"
  echo "$3  $2" | shasum -a 256 -c - >/dev/null || die "checksum não confere: $1"
}

# Liga $DOTFILES/home/<rel> em ~/<rel>, guardando o original em backup.
link_home() {
  local rel="$1" src="$DOTFILES/home/$1" dst="$HOME/$1"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then return; fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    mv "$dst" "$BACKUP_DIR/$rel"
  fi
  ln -s "$src" "$dst"
}

# Liga um arquivo fora de home/ (apps) em um destino absoluto.
link_file() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then return; fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    local rel="${dst#"$HOME"/}"
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    mv "$dst" "$BACKUP_DIR/$rel"
  fi
  ln -s "$src" "$dst"
}

asdf_env() {
  export PATH="$HOME/.asdf/shims:/opt/homebrew/bin:$HOME/.local/bin:$PATH"
}

# Instala um app .zip assinado em /Applications, conferindo checksum e assinatura.
install_app_zip() {
  local name="$1" url="$2" sha="$3"
  if [[ -d "/Applications/$name.app" ]]; then ok "$name já instalado"; return; fi
  fetch "$url" "$WORK/$name.zip" "$sha"
  mkdir -p "$WORK/$name"
  ditto -x -k "$WORK/$name.zip" "$WORK/$name"
  codesign --verify --deep --strict "$WORK/$name/$name.app" || die "assinatura inválida: $name"
  spctl -a "$WORK/$name/$name.app" || die "Gatekeeper recusou: $name"
  ditto "$WORK/$name/$name.app" "/Applications/$name.app"
  ok "$name instalado"
}

# ---------------------------------------------------------------- etapas

step_preflight() {
  log "Verificações"
  [[ "$(uname -s)" == "Darwin" ]] || die "somente macOS"
  [[ "$(uname -m)" == "arm64" ]] || die "somente Apple Silicon (arm64)"
  ok "macOS $(sw_vers -productVersion) arm64"
  if ! xcode-select -p >/dev/null 2>&1; then
    warn "instalando Command Line Tools (aceite a janela e rode o install.sh de novo)"
    xcode-select --install || true
    exit 1
  fi
  ok "Command Line Tools: $(xcode-select -p)"
}

step_brew() {
  log "Homebrew (mínimo)"
  if [[ ! -x /opt/homebrew/bin/brew ]]; then
    warn "instalando Homebrew (pede a senha de administrador)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
  export HOMEBREW_NO_INSTALL_UPGRADE=1 HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
  brew bundle --file="$DOTFILES/Brewfile" --no-upgrade
  ok "brew: $(brew list --formula | tr '\n' ' ')"
}

# PHP: o plugin do asdf compila com uma dúzia de pacotes do brew (horas no macOS 14).
# Usa o binário estático do static-php-cli (conjunto "common") dentro do asdf.
install_php_static() {
  local version="$1" dest="$HOME/.asdf/installs/php/$1"
  [[ "$version" == "$PHP_STATIC_VERSION" ]] || die "php $version difere de PHP_STATIC_VERSION ($PHP_STATIC_VERSION)"
  fetch "https://dl.static-php.dev/static-php-cli/common/php-$version-cli-macos-aarch64.tar.gz" \
    "$WORK/php.tar.gz" "$PHP_STATIC_SHA256"
  mkdir -p "$dest/bin"
  tar -xzf "$WORK/php.tar.gz" -C "$dest/bin"
  chmod +x "$dest/bin/php"
}

# PHP 7.x: sem binário pronto para arm64; compila com php/build-legacy.sh (sem brew).
install_php_legacy() {
  [[ "$1" == "$PHP_LEGACY_VERSION" ]] || die "php $1 difere de PHP_LEGACY_VERSION ($PHP_LEGACY_VERSION)"
  "$DOTFILES/php/build-legacy.sh" "$PHP_LEGACY_VERSION" "$PHP_LEGACY_SHA256" \
    "$OPENSSL_LEGACY_VERSION" "$OPENSSL_LEGACY_SHA256" "$WORK/php-legacy"
}

step_asdf() {
  log "asdf: plugins e versões (~/.tool-versions)"
  asdf_env
  while read -r name url; do
    [[ -z "$name" ]] && continue
    asdf plugin list 2>/dev/null | grep -qx "$name" || asdf plugin add "$name" "$url"
  done < "$DOTFILES/asdf-plugins.txt"
  cp "$DOTFILES/tool-versions" "$HOME/.tool-versions"

  local tool versions version
  while read -r tool versions; do
    [[ -z "$tool" || "$tool" == \#* ]] && continue
    for version in $versions; do
      if asdf list "$tool" 2>/dev/null | grep -q "$version"; then ok "$tool $version"; continue; fi
      if [[ "$tool" == "php" && "$version" == 7.* ]]; then
        install_php_legacy "$version"
      elif [[ "$tool" == "php" ]]; then
        install_php_static "$version"
      elif [[ "$tool" == "python" ]]; then
        CPPFLAGS="-I/opt/homebrew/opt/xz/include -I/opt/homebrew/opt/zstd/include" \
        LDFLAGS="-L/opt/homebrew/opt/xz/lib -L/opt/homebrew/opt/zstd/lib" \
        asdf install python "$version"
      else
        asdf install "$tool" "$version"
      fi
      ok "$tool $version"
    done
  done < "$HOME/.tool-versions"
  install_rust_std_x86_64
  asdf reshim
}

# Alvo x86_64-apple-darwin na Rust do asdf, que não tem rustup: o rust-std oficial no mesmo rustlib.
install_rust_std_x86_64() {
  local version="$RUST_STD_X86_64_VERSION" prefix="$HOME/.asdf/installs/rust/$RUST_STD_X86_64_VERSION"
  [[ -d "$prefix" ]] || { warn "rust $version ausente: alvo x86_64 não instalado"; return; }
  if [[ -d "$prefix/lib/rustlib/x86_64-apple-darwin" ]]; then ok "rust-std x86_64 $version"; return; fi
  local tmp; tmp=$(mktemp -d)
  local file="rust-std-$version-x86_64-apple-darwin.tar.xz"
  fetch "https://static.rust-lang.org/dist/$file" "$tmp/$file" "$RUST_STD_X86_64_SHA256"
  tar -xJf "$tmp/$file" -C "$tmp"
  "$tmp/rust-std-$version-x86_64-apple-darwin/install.sh" --prefix="$prefix" --disable-ldconfig >/dev/null
  rm -rf "$tmp"
  ok "rust-std x86_64 $version"
}

step_links() {
  log "Arquivos de configuração (links para o repositório)"
  local rel
  while IFS= read -r rel; do
    link_home "$rel"
  done < <(cd "$DOTFILES/home" && find . -type f ! -name '.DS_Store' | sed 's#^\./##' | sort)
  chmod +x "$DOTFILES"/home/.local/bin/*
  ok "links criados (backups em $BACKUP_DIR, se houve)"
}

step_git() {
  log "Git (configuração global)"
  git config --global user.name "Vinicius Carvalho"
  git config --global user.email "viniciuseng84@gmail.com"
  git config --global init.defaultBranch main
  git config --global core.pager delta
  git config --global interactive.diffFilter "delta --color-only"
  git config --global delta.navigate true
  git config --global delta.line-numbers true
  git config --global delta.syntax-theme Dracula
  git config --global merge.conflictStyle zdiff3
  git config --global --replace-all url."https://github.com/".insteadOf "git@github.com:"
  git config --global --add url."https://github.com/".insteadOf "ssh://git@github.com/"
  # remove duplicatas da regra acima em reexecuções
  local v; v="$(git config --global --get-all url."https://github.com/".insteadOf | sort -u)"
  git config --global --unset-all url."https://github.com/".insteadOf
  while IFS= read -r line; do git config --global --add url."https://github.com/".insteadOf "$line"; done <<< "$v"
  ok "user, delta, zdiff3, main, SSH→HTTPS"
}

step_npm() {
  log "Pacotes globais do npm"
  asdf_env
  # shellcheck disable=SC2086
  npm install -g $NPM_GLOBALS --allow-scripts=pnpm,frida,agent-desktop
  asdf reshim nodejs
  ok "$NPM_GLOBALS"
}

step_uv() {
  log "Ferramentas Python (uv tool)"
  asdf_env
  uv tool install --force "specify-cli @ git+https://github.com/github/spec-kit.git@$SPEC_KIT_TAG"
  uv tool install --force "cmake==$CMAKE_VERSION"
  # OCR local de PDFs e imagens; modelos (~73 MB) vão para ~/.cache/huggingface no primeiro uso
  uv tool install --force "indra-ocr==$INDRA_OCR_VERSION"
  ok "specify $SPEC_KIT_TAG, cmake $CMAKE_VERSION, indra-ocr $INDRA_OCR_VERSION"
}

install_bin() {
  local name="$1" version="$2" url="$3" sha="$4" member="$5"
  local dest="$HOME/.local/opt/$name-$version"
  if [[ -x "$dest/$member" ]]; then ok "$name $version"; return; fi
  fetch "$url" "$WORK/$name.archive" "$sha"
  mkdir -p "$WORK/$name" "$dest" "$HOME/.local/bin"
  tar -xf "$WORK/$name.archive" -C "$WORK/$name"
  cp "$(find "$WORK/$name" -type f -name "$member" | head -1)" "$dest/$member"
  chmod +x "$dest/$member"
  ln -sf "$dest/$member" "$HOME/.local/bin/$member"
  ok "$name $version"
}

step_binaries() {
  log "Binários oficiais (~/.local/opt)"
  install_bin watchexec "$WATCHEXEC_VERSION" \
    "https://github.com/watchexec/watchexec/releases/download/v$WATCHEXEC_VERSION/watchexec-$WATCHEXEC_VERSION-aarch64-apple-darwin.tar.xz" \
    "$WATCHEXEC_SHA256" watchexec
  install_bin zoxide "$ZOXIDE_VERSION" \
    "https://github.com/ajeetdsouza/zoxide/releases/download/v$ZOXIDE_VERSION/zoxide-$ZOXIDE_VERSION-aarch64-apple-darwin.tar.gz" \
    "$ZOXIDE_SHA256" zoxide
  install_bin tlrc "$TLRC_VERSION" \
    "https://github.com/tldr-pages/tlrc/releases/download/v$TLRC_VERSION/tlrc-v$TLRC_VERSION-aarch64-apple-darwin.tar.gz" \
    "$TLRC_SHA256" tldr
  "$HOME/.local/bin/tldr" --update >/dev/null 2>&1 || true
  install_bin atuin "$ATUIN_VERSION" \
    "https://github.com/atuinsh/atuin/releases/download/v$ATUIN_VERSION/atuin-aarch64-apple-darwin.tar.gz" \
    "$ATUIN_SHA256" atuin
  install_bin ipsw "$IPSW_VERSION" \
    "https://github.com/blacktop/ipsw/releases/download/v$IPSW_VERSION/ipsw_${IPSW_VERSION}_macOS_arm64.tar.gz" \
    "$IPSW_SHA256" ipsw
  install_bin ismc "$ISMC_VERSION" \
    "https://github.com/dkorunic/iSMC/releases/download/v$ISMC_VERSION/iSMC_Darwin_all.tar.gz" \
    "$ISMC_SHA256" iSMC
  install_bin macmon "$MACMON_VERSION" \
    "https://github.com/vladkens/macmon/releases/download/v$MACMON_VERSION/macmon-v$MACMON_VERSION-aarch64-apple-darwin.tar.gz" \
    "$MACMON_SHA256" macmon
  # importa o histórico existente do zsh uma vez (sincronização fica desligada)
  if [[ ! -f "$HOME/.atuin/data/history.db" ]]; then
    "$HOME/.local/bin/atuin" import zsh >/dev/null 2>&1 || true
  fi
}

step_fonts() {
  log "Fontes (Fira Code + FiraCode Nerd Font Mono)"
  local fonts="$HOME/Library/Fonts"
  if [[ ! -f "$fonts/FiraCode-Regular.ttf" ]]; then
    fetch "https://github.com/tonsky/FiraCode/releases/download/$FIRACODE_VERSION/Fira_Code_v$FIRACODE_VERSION.zip" \
      "$WORK/fira.zip" "$FIRACODE_SHA256"
    unzip -q "$WORK/fira.zip" -d "$WORK/fira"
    cp "$WORK"/fira/ttf/*.ttf "$fonts/"
  fi
  ok "Fira Code $FIRACODE_VERSION"
  if [[ ! -f "$fonts/FiraCodeNerdFontMono-Regular.ttf" ]]; then
    fetch "https://github.com/ryanoasis/nerd-fonts/releases/download/v$NERDFONT_VERSION/FiraCode.zip" \
      "$WORK/nerd.zip" "$NERDFONT_FIRACODE_SHA256"
    unzip -q "$WORK/nerd.zip" -d "$WORK/nerd"
    cp "$WORK"/nerd/FiraCodeNerdFontMono-*.ttf "$fonts/"
  fi
  ok "FiraCode Nerd Font Mono $NERDFONT_VERSION"
}

clone_pinned() {
  local repo="$1" tag="$2" commit="$3" dest="$4"
  if [[ -d "$dest" && "$(git -C "$dest" rev-parse HEAD)" == "$commit" ]]; then ok "$(basename "$dest") $tag"; return; fi
  rm -rf "$dest"
  git -c advice.detachedHead=false clone -q --depth 1 --branch "$tag" "https://github.com/$repo" "$dest"
  [[ "$(git -C "$dest" rev-parse HEAD)" == "$commit" ]] || die "commit inesperado em $repo@$tag"
  ok "$(basename "$dest") $tag"
}

step_zsh_plugins() {
  log "Plugins do zsh"
  local base="$HOME/.local/share/zsh/plugins"
  mkdir -p "$base"
  clone_pinned zsh-users/zsh-autosuggestions "$ZSH_AUTOSUGGESTIONS_TAG" "$ZSH_AUTOSUGGESTIONS_COMMIT" "$base/zsh-autosuggestions"
  clone_pinned zsh-users/zsh-syntax-highlighting "$ZSH_SYNTAX_HIGHLIGHTING_TAG" "$ZSH_SYNTAX_HIGHLIGHTING_COMMIT" "$base/zsh-syntax-highlighting"
}

# App distribuído em .dmg com assinatura ad hoc (sem notarização): o SHA-256 fixado é a garantia.
install_app_dmg() {
  local name="$1" url="$2" sha="$3" mnt
  if [[ -d "/Applications/$name.app" ]]; then ok "$name já instalado"; return; fi
  fetch "$url" "$WORK/$name.dmg" "$sha"
  mnt="$(hdiutil attach -nobrowse -readonly "$WORK/$name.dmg" | awk -F'\t' '/\/Volumes\//{print $NF}')"
  codesign --verify --deep --strict "$mnt/$name.app" || { hdiutil detach "$mnt" -quiet; die "assinatura inválida: $name"; }
  ditto "$mnt/$name.app" "/Applications/$name.app"
  hdiutil detach "$mnt" -quiet
  ok "$name instalado"
}

step_apps() {
  log "Apps"
  install_app_zip "Sublime Text" "https://download.sublimetext.com/sublime_text_build_${SUBLIME_TEXT_BUILD}_mac.zip" "$SUBLIME_TEXT_SHA256"
  install_app_zip "Sublime Merge" "https://download.sublimetext.com/sublime_merge_build_${SUBLIME_MERGE_BUILD}_mac.zip" "$SUBLIME_MERGE_SHA256"
  mkdir -p "$HOME/.local/bin"
  ln -sf "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" "$HOME/.local/bin/subl"
  ln -sf "/Applications/Sublime Merge.app/Contents/SharedSupport/bin/smerge" "$HOME/.local/bin/smerge"
  ok "subl e smerge no PATH"
  install_app_dmg "Mister Download Manager" \
    "https://github.com/anefzaoui/misterdownloadmanager/releases/download/v$MDM_VERSION/MisterDownloadManager-$MDM_VERSION-macos-arm64-experimental.dmg" \
    "$MDM_SHA256"
  ln -sf "/Applications/Mister Download Manager.app/Contents/MacOS/misterdownloadmanager-cli" "$HOME/.local/bin/mdm"
  ok "mdm (CLI do Mister Download Manager) no PATH"
  local app step
  for app in "iTerm:iterm" "Visual Studio Code:vscode"; do
    step="${app##*:}"; app="${app%%:*}"
    if [[ -d "/Applications/$app.app" ]]; then
      ok "$app presente"
    else
      warn "$app não encontrado: instale pelo site oficial e rode ./install.sh --only $step"
    fi
  done
  if [[ -d "/Applications/Docker.app" ]]; then
    ok "Docker presente (abre só sob demanda)"
  else
    warn "Docker Desktop não instalado (opcional)"
  fi
}

step_sublime() {
  log "Sublime Text e Sublime Merge (configurações e pacotes)"
  asdf_env
  local st="$HOME/Library/Application Support/Sublime Text"
  mkdir -p "$st/Installed Packages" "$st/Packages/User"
  if [[ ! -f "$st/Installed Packages/Package Control.sublime-package" ]]; then
    fetch "https://github.com/sublimehq/package_control/releases/download/$PACKAGE_CONTROL_VERSION/Package.Control.sublime-package" \
      "$st/Installed Packages/Package Control.sublime-package" "$PACKAGE_CONTROL_SHA256"
  fi
  link_file "$DOTFILES/apps/sublime-text/Preferences.sublime-settings" "$st/Packages/User/Preferences.sublime-settings"
  # Package Control reescreve este arquivo; copiar (não linkar) evita sujar o repositório
  cp "$DOTFILES/apps/sublime-text/Package Control.sublime-settings" "$st/Packages/User/"
  local node_bin; node_bin="$(asdf where nodejs)/bin"
  sed "s#{{NODE_BIN}}#$node_bin#g" "$DOTFILES/apps/sublime-text/JsPrettier.sublime-settings.tpl" \
    > "$st/Packages/User/JsPrettier.sublime-settings"
  local sm="$HOME/Library/Application Support/Sublime Merge/Packages/User"
  link_file "$DOTFILES/apps/sublime-merge/Preferences.sublime-settings" "$sm/Preferences.sublime-settings"
  ok "pacotes instalam sozinhos ao abrir o Sublime (Dracula, LSP, Terminus...)"
}

step_vscode() {
  log "VS Code"
  local code_bin="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  [[ -x "$code_bin" ]] || { warn "VS Code não instalado; pulando"; return; }
  link_file "$DOTFILES/apps/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
  while read -r ext; do
    [[ -n "$ext" ]] && "$code_bin" --install-extension "$ext" --force >/dev/null
  done < "$DOTFILES/apps/vscode/extensions.txt"
  ln -sf "$code_bin" "$HOME/.local/bin/code"
  ok "settings, extensões e comando code"
}

step_iterm() {
  log "iTerm2 (perfil Dotfiles: Dracula, Nerd Font, atalhos de edição)"
  local dyn="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  mkdir -p "$dyn"
  cp "$DOTFILES/apps/iterm2/Dotfiles.json" "$dyn/Dotfiles.json"
  # janela que desce do topo com ⌃` (Control + crase), herdando o perfil Dotfiles
  cp "$DOTFILES/apps/iterm2/Hotkey.json" "$dyn/Hotkey.json"
  open -g "$DOTFILES/apps/iterm2/Dracula.itermcolors" 2>/dev/null || true
  # pgrep não enxerga o iTerm em alguns contextos (sandbox); ps enxerga
  # shellcheck disable=SC2009
  if ps -Ao comm | grep -q "/iTerm.app/Contents/MacOS/iTerm2$"; then
    warn "iTerm aberto: em Ajustes → Perfis, selecione 'Dotfiles' e use 'Outras ações… → Definir como padrão'"
  else
    defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "D07F11E5-0000-4000-8000-000000000001"
    ok "perfil Dotfiles definido como padrão"
  fi
}

step_ghidra() {
  log "Ghidra $GHIDRA_VERSION (para o REA)"
  asdf_env
  local dest="$HOME/.local/opt/ghidra_${GHIDRA_VERSION}_PUBLIC"
  if [[ ! -d "$dest" ]]; then
    fetch "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_${GHIDRA_VERSION}_build/$GHIDRA_FILE" \
      "$WORK/ghidra.zip" "$GHIDRA_SHA256"
    mkdir -p "$HOME/.local/opt"
    unzip -q "$WORK/ghidra.zip" -d "$HOME/.local/opt"
  fi
  if [[ ! -x "$dest/Ghidra/Features/Decompiler/build/os/mac_arm_64/decompile" ]]; then
    warn "compilando natives mac_arm_64 (alguns minutos)"
    JAVA_HOME="$(asdf where java)" bash -c "cd '$dest/support/gradle' && ./gradlew -q buildNatives"
  fi
  ok "Ghidra em $dest"
}

step_ai_memory() {
  log "ai-memory"
  if ! "$HOME/.local/bin/ai-memory" --version 2>/dev/null | grep -q " $AI_MEMORY_VERSION\$"; then
    fetch "https://github.com/akitaonrails/ai-memory/releases/download/v${AI_MEMORY_VERSION}/install.sh" \
      "$WORK/aim.sh" "$AI_MEMORY_INSTALL_SHA256"
    AI_MEMORY_VERSION="$AI_MEMORY_VERSION" sh "$WORK/aim.sh"
  fi
  "$HOME/.local/bin/ai-memory" setup --yes --agent claude-code --agent codex
}

step_claude() {
  log "Claude Code (MCPs, permissão do REA, notificações)"
  asdf_env
  command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash
  export PATH="$HOME/.local/bin:$PATH"
  local java_home ghidra="$HOME/.local/opt/ghidra_${GHIDRA_VERSION}_PUBLIC"
  java_home="$(asdf where java)"
  claude mcp remove rea --scope user >/dev/null 2>&1 || true
  local hopper="$HOME/Applications/Hopper Disassembler.app/Contents/MacOS/hopper" hopper_env=()
  [[ -x "$hopper" ]] && hopper_env=(-e "HOPPER_LAUNCHER_PATH=$hopper")
  claude mcp add --scope user rea -e GHIDRA_INSTALL_DIR="$ghidra" -e JAVA_HOME="$java_home" ${hopper_env[@]+"${hopper_env[@]}"} \
    -- npx -y "rea-agents@${NPM_GLOBALS##*rea-agents@}" mcp
  # remove e registra de novo: assim uma versão nova em versions.env chega ao Claude Code
  claude mcp remove playwright --scope user >/dev/null 2>&1 || true
  claude mcp add --scope user playwright -- npx -y "@playwright/mcp@$PLAYWRIGHT_MCP_VERSION"
  claude mcp list 2>/dev/null | grep -q '^context7:' || \
    claude mcp add --scope user --transport http context7 "$CONTEXT7_MCP_URL"
  claude mcp list 2>/dev/null | grep -q '^mister-download-manager:' || \
    claude mcp add --scope user mister-download-manager -- "/Applications/Mister Download Manager.app/Contents/MacOS/misterdownloadmanager-mcp"
  /usr/bin/python3 -I "$DOTFILES/claude/merge-settings.py" "$DOTFILES/claude/settings.patch.json"
  # plugin oficial: LSP do Swift (sourcekit-lsp do Xcode) para projetos Swift
  claude plugin list 2>/dev/null | grep -q 'swift-lsp@claude-plugins-official' || \
    claude plugin install swift-lsp@claude-plugins-official >/dev/null 2>&1 || warn "plugin swift-lsp: rode 'claude plugin install swift-lsp@claude-plugins-official'"
  ok "MCPs: rea (ask), playwright, context7, mister-download-manager + plugin swift-lsp + hooks de notificação"
}

step_codex() {
  log "Codex (MCPs, notificações)"
  asdf_env
  local java_home ghidra="$HOME/.local/opt/ghidra_${GHIDRA_VERSION}_PUBLIC"
  java_home="$(asdf where java)"
  codex mcp remove rea >/dev/null 2>&1 || true
  local hopper="$HOME/Applications/Hopper Disassembler.app/Contents/MacOS/hopper" hopper_env=()
  [[ -x "$hopper" ]] && hopper_env=(--env "HOPPER_LAUNCHER_PATH=$hopper")
  # remover e registrar de novo apaga as aprovações por ferramenta do REA feitas no Codex
  codex mcp add rea --env GHIDRA_INSTALL_DIR="$ghidra" --env JAVA_HOME="$java_home" ${hopper_env[@]+"${hopper_env[@]}"} \
    -- npx -y "rea-agents@${NPM_GLOBALS##*rea-agents@}" mcp
  codex mcp remove playwright >/dev/null 2>&1 || true
  codex mcp add playwright -- npx -y "@playwright/mcp@$PLAYWRIGHT_MCP_VERSION"
  grep -q '^\[mcp_servers.context7\]' "$HOME/.codex/config.toml" 2>/dev/null || \
    printf '\n[mcp_servers.context7]\nurl = "%s"\n' "$CONTEXT7_MCP_URL" >> "$HOME/.codex/config.toml"
  codex mcp remove mister-download-manager >/dev/null 2>&1 || true
  codex mcp add mister-download-manager -- "/Applications/Mister Download Manager.app/Contents/MacOS/misterdownloadmanager-mcp"
  /usr/bin/python3 -I "$DOTFILES/codex/merge-config.py"
  link_home .local/bin/codex
  rea setup --skill-client codex --skill-client claude_code --yes --json >/dev/null 2>&1 || warn "skill do REA: rode 'rea setup --skill-client codex --skill-client claude_code --yes'"
  ok "MCPs: rea, playwright, context7, mister-download-manager + notificações [tui]"
  warn "abra o Codex, rode /hooks e escolha 'Trust all' (hooks do ai-memory)"
}

step_skills() {
  log "Skills dos agentes (/commit, /pr, /review-changes) no Claude Code e no Codex"
  local skill name
  for skill in "$DOTFILES"/skills/*/; do
    name="$(basename "$skill")"
    for dir in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
      mkdir -p "$dir"
      ln -sfn "${skill%/}" "$dir/$name"
    done
    ok "$name"
  done
}

step_video() {
  log "video-to-skill (agentes analisam vídeos: frames, transcrição, cenas)"
  local data="$HOME/Library/Application Support/video-to-skill"
  local bin="$data/bin/vts-extract-$VTS_VERSION"
  local skill="$HOME/.local/opt/video-to-skill-$VTS_VERSION"
  # a skill (SKILL.md + references/) e o código-fonte vêm do tag, conferido pelo commit
  clone_pinned brenoepics/video-to-skill "v$VTS_VERSION" "$VTS_COMMIT" "$skill"
  if ! "$bin" --version >/dev/null 2>&1; then
    mkdir -p "$data/bin"
    if [[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 15 ]]; then
      fetch "https://github.com/brenoepics/video-to-skill/releases/download/v$VTS_VERSION/vts-extract-macos-arm64.tar.gz" \
        "$WORK/vts.tar.gz" "$VTS_SHA256"
      mkdir -p "$WORK/vts"
      tar -xzf "$WORK/vts.tar.gz" -C "$WORK/vts"
      install -m 755 "$WORK/vts/vts-extract" "$bin"
    else
      # o binário da release usa Metal do macOS 15 (MTLResidencySet) e aborta no 14:
      # compila do fonte para o 14 (precisa de Rust do asdf e cmake do uv)
      asdf_env
      (cd "$skill" && MACOSX_DEPLOYMENT_TARGET=14.0 CARGO_TARGET_DIR="$WORK/vts-target" \
        nice -n 19 cargo build --release --locked -j 2)
      install -m 755 "$WORK/vts-target/release/vts-extract" "$bin"
    fi
  fi
  "$bin" --version >/dev/null || die "vts-extract $VTS_VERSION não executa"
  mkdir -p "$HOME/.local/bin"
  ln -sf "$bin" "$HOME/.local/bin/vts-extract"
  for dir in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
    mkdir -p "$dir"
    ln -sfn "$skill" "$dir/video-to-skill"
  done
  # ffmpeg, ffprobe, yt-dlp e o modelo whisper base (~140 MB) vão para "$data";
  # URLs e SHA-256 fixados no próprio vts-extract (veja: vts-extract check --print-downloads)
  "$bin" check --fix --yes >/dev/null || warn "dependências do vts-extract: rode 'vts-extract check --fix'"
  ok "vts-extract $VTS_VERSION + skill /video-to-skill"
}

step_craft() {
  log "Craft Anything $CRAFT_ANYTHING_VERSION (alfa, em observação: captura e comparação de sites)"
  local v="$CRAFT_ANYTHING_VERSION" dest="$HOME/.local/opt/craft-anything-$CRAFT_ANYTHING_VERSION"
  if ! "$dest/craft-anything-cli" --version >/dev/null 2>&1; then
    fetch "https://github.com/storytold/craft-anything/releases/download/v$v/craft-anything-cli-$v-macos-universal.zip" \
      "$WORK/craft.zip" "$CRAFT_ANYTHING_SHA256"
    ditto -x -k "$WORK/craft.zip" "$WORK/craft"
    mkdir -p "$dest"
    cp -R "$WORK/craft/craft-anything-cli-$v-macos-universal/." "$dest/"
  fi
  codesign --verify --strict "$dest/craft-anything-cli" || die "assinatura do craft-anything-cli não confere"
  mkdir -p "$HOME/.local/bin"
  ln -sf "$dest/craft-anything-cli" "$HOME/.local/bin/craft-anything-cli"
  # 8 GB de RAM: um build por vez; sem Ghidra (pede 4 GB+ de heap e tiraria a "segunda opinião" do REA)
  "$dest/craft-anything-cli" settings-set --key build.parallel --value 1 >/dev/null
  # MCP só no Claude Code (que carrega as ferramentas sob demanda); sem a skill, que disputaria pedidos com a do REA.
  # No Codex ele anunciaria ~100 ferramentas em toda sessão.
  "$dest/craft-anything-cli" --format text setup --yes --no-skill --client claude_code >/dev/null \
    || warn "rode: craft-anything-cli setup --no-skill --client claude_code"
  ok "craft-anything-cli $v + MCP craft-anything (Claude Code)"
}

step_github() {
  log "GitHub CLI"
  asdf_env
  if gh auth status >/dev/null 2>&1; then
    ok "já autenticado"
  else
    warn "login interativo: escolha GitHub.com → HTTPS → navegador"
    gh auth login --hostname github.com --git-protocol https --web
  fi
  for h in https://github.com https://gist.github.com; do
    git config --global --replace-all "credential.$h.helper" "" 2>/dev/null || true
    git config --global --add "credential.$h.helper" "!$HOME/.asdf/shims/gh auth git-credential"
  done
  ok "git usa o login do gh (HTTPS)"
  if [[ "$WITH_BIN" == 1 && ! -d "$HOME/bin/.git" ]]; then
    gh repo clone carvalhoviniciusluiz/dotfiles-bin "$HOME/bin"
    ok "dotfiles-bin em ~/bin"
  fi
}

# ---------------------------------------------------------------- main

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) ONLY="$2"; shift 2 ;;
    --list) printf '%s\n' "${STEPS[@]}"; exit 0 ;;
    --with-bin) WITH_BIN=1; shift ;;
    --macos-tweaks) MACOS_TWEAKS=1; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) die "opção desconhecida: $1" ;;
  esac
done

if [[ -n "$ONLY" ]]; then
  declare -F "step_$ONLY" >/dev/null || die "etapa desconhecida: $ONLY (veja --list)"
  "step_$ONLY"
else
  for s in "${STEPS[@]}"; do "step_$s"; done
  [[ "$MACOS_TWEAKS" == 1 ]] && bash "$DOTFILES/macos/tweaks.sh"
fi

log "Concluído"
cat <<'EOF'
    Passos manuais (veja README.md):
      - Abrir um terminal novo (ou: exec zsh)
      - iTerm: perfil "Dotfiles" como padrão; Ajustes → Perfis → Terminal → Shell Integration
      - Codex: /hooks → Trust all
      - Ajustes do Sistema: FileVault, Firewall, Spotlight → Privacidade (~/.asdf, ~/.local)
EOF
