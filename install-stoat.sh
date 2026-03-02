#!/usr/bin/env bash
# ============================================================
#  install-stoat.sh — Installe Stoat Chat sur Debian
#  Usage : bash install-stoat.sh
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[*]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
die()     { echo -e "${RED}[✗]${NC} $*" >&2; exit 1; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }

# ─── Détection utilisateur session graphique ─────────────────
get_graphical_user() {
    local user
    user=$(loginctl list-sessions --no-legend 2>/dev/null \
        | awk '$3 != "root" {print $3}' | head -1)
    [[ -n "$user" ]] && echo "$user" && return

    user=$(stat -c '%U' /tmp/.X0-lock 2>/dev/null)
    [[ -n "$user" && "$user" != "root" ]] && echo "$user" && return

    user=$(who | awk '/:/ && $1 != "root" {print $1}' | head -1)
    [[ -n "$user" ]] && echo "$user" && return

    [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]] \
        && echo "$SUDO_USER" && return

    echo "$USER"
}

ME=$(get_graphical_user)
info "Utilisateur détecté : $ME"

DOWNLOADS="/home/$ME/Téléchargements"
WORK_DIR="${DOWNLOADS}/stoat-build"
REPO_URL="https://github.com/stoatchat/for-desktop"
ASSETS_URL="https://github.com/stoatchat/assets"

# ─── 1. Dépendances système ───────────────────────────────────
info "Installation des dépendances système..."
sudo apt-get update -qq
sudo apt-get install -y \
    git curl flatpak-builder elfutils python3 \
    libgtk-3-0 libnotify4 libnss3 libxss1 \
    libxtst6 xdg-utils libatspi2.0-0 libuuid1

# ─── 2. Node.js ──────────────────────────────────────────────
if ! command -v node &>/dev/null; then
    info "Installation de Node.js 22..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    success "Node.js déjà présent : $(node -v)"
fi

# ─── 3. pnpm ─────────────────────────────────────────────────
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

if ! command -v pnpm &>/dev/null; then
    info "Installation de pnpm..."
    curl -fsSL https://get.pnpm.io/install.sh | sh -
    source "$HOME/.bashrc" 2>/dev/null || true
    export PATH="$PNPM_HOME:$PATH"
else
    success "pnpm déjà présent : $(pnpm -v)"
fi

command -v pnpm &>/dev/null || die "pnpm introuvable après installation, relance le script dans un nouveau terminal."

# ─── 4. Clone du repo ────────────────────────────────────────
info "Clonage de stoat-for-desktop dans $WORK_DIR..."
rm -rf "$WORK_DIR"
git clone --recursive "$REPO_URL" "$WORK_DIR"
cd "$WORK_DIR"

# ─── 5. Submodule assets ─────────────────────────────────────
info "Récupération des assets..."
rm -rf assets
git clone "$ASSETS_URL" assets
success "Assets clonés."

# ─── 6. Patch forge.config.ts — supprime MakerFlatpak ────────
info "Patch de forge.config.ts pour désactiver MakerFlatpak..."

sed -i 's|^import { MakerFlatpak }|// import { MakerFlatpak }|' forge.config.ts
sed -i 's|^import { MakerFlatpakOptionsConfig }|// import { MakerFlatpakOptionsConfig }|' forge.config.ts

python3 - <<'PYEOF'
import pathlib

p = pathlib.Path("forge.config.ts")
src = p.read_text()

result = []
skip = False
depth = 0
lines = src.splitlines(keepends=True)
i = 0

while i < len(lines):
    line = lines[i]
    if not skip and "new MakerFlatpak(" in line:
        skip = True
        depth = 0

    if skip:
        depth += line.count("{") - line.count("}")
        if depth <= 0 and (")" in line):
            skip = False
            i += 1
            continue
    else:
        result.append(line)
    i += 1

p.write_text("".join(result))
print("Patch appliqué.")
PYEOF

success "forge.config.ts patché."

# ─── 7. Dépendances Node ─────────────────────────────────────
info "Installation des dépendances Node..."
pnpm i --frozen-lockfile

# ─── 8. Build .deb ───────────────────────────────────────────
info "Build & packaging (.deb)..."
pnpm run make

# ─── 9. Installation ─────────────────────────────────────────
DEB_OUT="$WORK_DIR/out/make/deb/x64"
DEB_FILE=$(find "$DEB_OUT" -name "*.deb" 2>/dev/null | head -1)

if [[ -n "$DEB_FILE" ]]; then
    success "Paquet .deb généré : $DEB_FILE"
    info "Installation du .deb..."
    sudo dpkg -i "$DEB_FILE"
    sudo apt-get install -f -y
    success "Stoat installé !"
else
    warn "Pas de .deb trouvé. Contenu de out/make :"
    find "$WORK_DIR/out/make" -type f
    die "Le build a échoué."
fi