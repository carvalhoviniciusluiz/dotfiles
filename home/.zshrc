# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=($HOME/.docker/completions $fpath)
autoload -Uz compinit
(( ${+_comps[docker]} )) || compinit
# End of Docker CLI completions

# Homebrew antes de /usr/bin (git do brew no lugar do git do Xcode)
eval "$(/opt/homebrew/bin/brew shellenv)"

# asdf: shims seguem a versão do .tool-versions (global ou do projeto)
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
export PATH="$HOME/.local/bin:$PATH"
# ~/bin: scripts do repositório carvalhoviniciusluiz/dotfiles-bin
# (helpers do iTerm + Claude Code; instalar com ./install.sh --with-bin)
export PATH="$HOME/bin:$PATH"
# Java (Temurin 21 via asdf) e Ghidra para o REA
export JAVA_HOME="$HOME/.asdf/installs/java/temurin-21.0.12+101.0.LTS"
export PATH="$JAVA_HOME/bin:$PATH"
export GHIDRA_INSTALL_DIR="$HOME/.local/opt/ghidra_12.1.4_PUBLIC"

# pnpm: diretório dos binários globais (pnpm add -g)
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac

# Homebrew: macOS 14 é Tier 3 (sem bottles); evita upgrades em cadeia no brew install
export HOMEBREW_NO_INSTALL_UPGRADE=1
export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1

# direnv: carrega o .envrc de cada projeto ao entrar na pasta
eval "$(direnv hook zsh)"

# Histórico: maior, sem duplicados e compartilhado entre abas
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS HIST_IGNORE_SPACE SHARE_HISTORY EXTENDED_HISTORY

# Sugestões do histórico enquanto digita (→ ou End aceita; ⌥→ aceita uma palavra)
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6272a4"
source "$HOME/.local/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

# ↑/↓ buscam no histórico comandos que começam com o que já foi digitado
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

# Edição por palavra: ⌥⌫ apaga a palavra, ⌥←/⌥→ andam por palavra
# (/ . - _ separam palavras, então ⌥⌫ apaga um trecho de caminho por vez)
WORDCHARS='*?[]~=&;!#$%^(){}<>'
bindkey '^[^?' backward-kill-word
bindkey '^[b' backward-word
bindkey '^[f' forward-word
bindkey '^[[1;3D' backward-word
bindkey '^[[1;3C' forward-word

# Completar com Tab: ignora maiúsculas/minúsculas e mostra menu navegável por setas
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# fzf: Ctrl+T procura arquivos (usa fd, respeita .gitignore); Ctrl+R fica com o atuin
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border
  --color=fg:#f8f8f2,bg:-1,hl:#bd93f9,fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
  --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6,marker:#ff79c6,spinner:#ffb86c,header:#6272a4'
source <(fzf --zsh)

# atuin: Ctrl+R busca no histórico (SQLite, com diretório, duração e status de cada
# comando). Carregado depois do fzf para ficar com o Ctrl+R; a seta ↑ continua
# filtrando pelo que foi digitado. Config: ~/.config/atuin/config.toml
eval "$(atuin init zsh --disable-up-arrow)"

# bat (cat com destaque de sintaxe) e eza (ls com status do Git)
# cat/ls só são trocados em terminal de verdade; agentes e scripts recebem os originais
export BAT_THEME="Dracula"
if [[ -t 1 && -z "$CLAUDECODE" && -z "$CODEX_SANDBOX" ]]; then
  alias cat='bat --paging=never --style=plain'
  alias ls='eza --icons=auto --group-directories-first'
fi
alias ll='eza -l --icons=auto --git --group-directories-first --time-style=relative'
alias l='ll'
alias la='eza -la --icons=auto --git --group-directories-first --time-style=relative'
alias lt='eza --tree --icons=auto --level=2 --git-ignore'

# Atalhos de navegação e Git
alias ..='cd ..'
alias ...='cd ../..'
alias dev='cd ~/Development'
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate -20'
alias gd='git diff'
alias gds='git diff --staged'
alias gco='git checkout'
alias gsw='git switch'
alias gp='git pull'
alias lg='lazygit'


# Prompt (config em ~/.config/starship.toml)
eval "$(starship init zsh)"

# zoxide: `z parte-do-nome` pula para pastas frequentes; `zi` escolhe numa lista
eval "$(zoxide init zsh)"

# Destaque de sintaxe enquanto digita (precisa ser o último plugin carregado)
source "$HOME/.local/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
