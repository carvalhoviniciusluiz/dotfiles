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
       apps sublime vscode iterm ghidra ai_memory claude codex github)

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

step_asdf() {
  log "asdf: plugins e versões (~/.tool-versions)"
  asdf_env
  while read -r name url; do
    [[ -z "$name" ]] && continue
    asdf plugin list 2>/dev/null | grep -qx "$name" || asdf plugin add "$name" "$url"
  done < "$DOTFILES/asdf-plugins.txt"
  cp "$DOTFILES/tool-versions" "$HOME/.tool-versions"

  while read -r tool version; do
    [[ -z "$tool" || "$tool" == \#* ]] && continue
    if asdf list "$tool" 2>/dev/null | grep -q "$version"; then ok "$tool $version"; continue; fi
    if [[ "$tool" == "python" ]]; then
      CPPFLAGS="-I/opt/homebrew/opt/xz/include -I/opt/homebrew/opt/zstd/include" \
      LDFLAGS="-L/opt/homebrew/opt/xz/lib -L/opt/homebrew/opt/zstd/lib" \
      asdf install python "$version"
    else
      asdf install "$tool" "$version"
    fi
    ok "$tool $version"
  done < "$HOME/.tool-versions"
  asdf reshim
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
  npm install -g $NPM_GLOBALS --allow-scripts=pnpm,frida
  asdf reshim nodejs
  ok "$NPM_GLOBALS"
}

step_uv() {
  log "Ferramentas Python (uv tool)"
  asdf_env
  uv tool install --force "specify-cli @ git+https://github.com/github/spec-kit.git@$SPEC_KIT_TAG"
  ok "specify $SPEC_KIT_TAG"
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

step_apps() {
  log "Apps"
  install_app_zip "Sublime Text" "https://download.sublimetext.com/sublime_text_build_${SUBLIME_TEXT_BUILD}_mac.zip" "$SUBLIME_TEXT_SHA256"
  install_app_zip "Sublime Merge" "https://download.sublimetext.com/sublime_merge_build_${SUBLIME_MERGE_BUILD}_mac.zip" "$SUBLIME_MERGE_SHA256"
  mkdir -p "$HOME/.local/bin"
  ln -sf "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl" "$HOME/.local/bin/subl"
  ln -sf "/Applications/Sublime Merge.app/Contents/SharedSupport/bin/smerge" "$HOME/.local/bin/smerge"
  ok "subl e smerge no PATH"
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
  if [[ ! -x "$HOME/.local/bin/ai-memory" ]]; then
    curl -fsSL https://github.com/akitaonrails/ai-memory/releases/latest/download/install.sh -o "$WORK/aim.sh"
    sh "$WORK/aim.sh"
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
  claude mcp add --scope user rea -e GHIDRA_INSTALL_DIR="$ghidra" -e JAVA_HOME="$java_home" \
    -- npx -y "rea-agents@${NPM_GLOBALS##*rea-agents@}" mcp
  claude mcp list 2>/dev/null | grep -q '^playwright:' || \
    claude mcp add --scope user playwright -- npx -y "@playwright/mcp@$PLAYWRIGHT_MCP_VERSION"
  claude mcp list 2>/dev/null | grep -q '^context7:' || \
    claude mcp add --scope user --transport http context7 "$CONTEXT7_MCP_URL"
  /usr/bin/python3 -I "$DOTFILES/claude/merge-settings.py" "$DOTFILES/claude/settings.patch.json"
  ok "MCPs: rea (ask), playwright, context7 + hooks de notificação"
}

step_codex() {
  log "Codex (MCPs, notificações)"
  asdf_env
  local java_home ghidra="$HOME/.local/opt/ghidra_${GHIDRA_VERSION}_PUBLIC"
  java_home="$(asdf where java)"
  codex mcp remove rea >/dev/null 2>&1 || true
  codex mcp add rea --env GHIDRA_INSTALL_DIR="$ghidra" --env JAVA_HOME="$java_home" \
    -- npx -y "rea-agents@${NPM_GLOBALS##*rea-agents@}" mcp
  codex mcp remove playwright >/dev/null 2>&1 || true
  codex mcp add playwright -- npx -y "@playwright/mcp@$PLAYWRIGHT_MCP_VERSION"
  grep -q '^\[mcp_servers.context7\]' "$HOME/.codex/config.toml" 2>/dev/null || \
    printf '\n[mcp_servers.context7]\nurl = "%s"\n' "$CONTEXT7_MCP_URL" >> "$HOME/.codex/config.toml"
  /usr/bin/python3 -I "$DOTFILES/codex/merge-config.py"
  rea setup --skill-client codex --yes --json >/dev/null 2>&1 || warn "skill do REA: rode 'rea setup --skill-client codex --yes'"
  ok "MCPs: rea, playwright, context7 + notificações [tui]"
  warn "abra o Codex, rode /hooks e escolha 'Trust all' (hooks do ai-memory)"
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
