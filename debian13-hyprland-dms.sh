#!/bin/bash
# ============================================================================
#  debian13-hyprland-dms.sh
#  Escritorio estilo Omarchy 4.5 sobre Debian 13 (Trixie) PURO, sin escritorio
#  previo: Hyprland + Quickshell + DankMaterialShell (dms) + apps de Omarchy.
#  Brave como navegador por defecto, GTK en oscuro, idioma configurable.
#
#  Repos: Debian (backports) + OBS de AvengeMedia/DankLinux (terceros,
#  verificados el 11-nov-2026) + Brave (oficial) y opcionales: Liquorix,
#  WineHQ, MX Linux, deb-multimedia.  Todo con llave firmada y pinning.
#
#  Uso:  sudo bash debian13-hyprland-dms.sh [opciones]
#
#  --idioma CODE        locale del sistema (def: es_MX.UTF-8)
#  --compositor X       hyprland (def) | niri
#  --greeter            instala dms-greeter (greetd) como pantalla de acceso
#
#  POR DEFECTO LO INSTALA TODO: repos (MX, deb-multimedia, backports, OBS,
#  Brave, WineHQ, Liquorix) + escritorio + programas + seguridad + wine +
#  liquorix. Las banderas de abajo sirven para OMITIR lo que no quieras.
#
#  --sin-extras         sin diseno/multimedia (Inkscape, Krita, GIMP, Blender...)
#  --sin-kodi           sin Kodi + RetroArch + OpenRCT2
#  --sin-seguridad      sin wifite, hashcat, hcxdumptool, wireshark, macchanger...
#  --sin-wine           sin WineHQ (no agrega su repo)
#  --sin-liquorix       sin kernel Liquorix (no agrega su repo)
#  --sin-repos-extra    sin MX Linux ni deb-multimedia
#  --sin-brave          sin Brave (y sin ponerlo por defecto)
#  --quickshell-debian  forzar el quickshell de Debian (por defecto gana el mas nuevo)
#  --seco               simulacion: muestra lo que haria, sin tocar nada
#  --si                 desatendido total: sin menu y sin preguntas
#  --ayuda              esta ayuda
#
#  SIN BANDERAS: al arrancar aparece un MENU interactivo (whiptail) donde marcas
#  lo que quieres, eliges idioma y compositor, ves el resumen y puedes volver
#  atras para cambiar algo. Al confirmar, la instalacion sigue DESATENDIDA hasta
#  el final y termina con un reporte de lo que hizo y el aviso de reinicio.
# ============================================================================
set -euo pipefail

VER="2.0"
RED=$'\e[0;31m'; GREEN=$'\e[0;32m'; YELLOW=$'\e[1;33m'; CYAN=$'\e[0;36m'; BOLD=$'\e[1m'; NC=$'\e[0m'
# Todo lo relevante se registra aqui: es la base del reporte final.
LOG="/var/log/debian13-hyprland-dms.log"
PAQ_ANTES="$(dpkg-query -f '.\n' -W 2>/dev/null | wc -l)"
: 2>/dev/null >"$LOG" || LOG="/tmp/debian13-hyprland-dms.log"
log()    { echo "${GREEN}[OK]${NC} $*";    echo "[OK]    $(date +%T) $*" >> "$LOG"; }
warn()   { echo "${YELLOW}[AVISO]${NC} $*"; echo "[AVISO] $(date +%T) $*" >> "$LOG"; }
err()    { echo "${RED}[ERROR]${NC} $*" >&2; echo "[ERROR] $(date +%T) $*" >> "$LOG"; }
header() { echo; echo "${CYAN}============================================================${NC}"; echo "${CYAN}  $*${NC}"; echo "${CYAN}============================================================${NC}"; echo "== $*" >> "$LOG"; }

# ---- valores por defecto (configurables) -----------------------------------
IDIOMA="es_MX.UTF-8"
COMPOSITOR="hyprland"
GREETER="no"
EXTRAS="si"; KODI="si"; SEGURIDAD="si"; WINE="si"; LIQUORIX="si"   # TODO por defecto (criterio de Ricardo)
MULTIREPOS="si"          # MX Linux + deb-multimedia: SIEMPRE, al principio (Ricardo)
BRAVE="si"; SECO="no"; SI="no"
BACKPORTS_PRIO="500"     # 500 = gana la version mas nueva (tambien en backports)
OBS_PRIO="500"           # el OBS de DankLinux solo publica paquetes propios
QSH_PRIO="500"           # quickshell: gana el mas nuevo; -1 = forzar el de Debian
TMPD="$(mktemp -d /tmp/d13dank.XXXXXX)"
trap 'rm -rf "$TMPD"' EXIT

# ---- parser ----------------------------------------------------------------
# Ayuda: desde el archivo se muestra la cabecera; por tuberia, texto embebido
mostrar_ayuda() {
  if [[ -f "$0" && -r "$0" ]] && head -1 "$0" 2>/dev/null | grep -q '^#!'; then
    sed -n '2,42p' "$0"
  else
    cat <<'AYUDA'
Instalador Debian 13 + Hyprland + Quickshell + DankMaterialShell (estilo Omarchy)

  uso: debian13-hyprland-dms.sh [banderas]

  Sin banderas: MENU interactivo (marcas componentes, eliges idioma y compositor,
  ves el resumen y puedes volver a cambiar antes de confirmar). Al confirmar, la
  instalacion sigue desatendida hasta el final y termina con un reporte.

  --idioma CODE                 locale del sistema (defecto es_MX.UTF-8)
  --compositor hyprland|niri    compositor Wayland (defecto hyprland)
  --greeter                     dms-greeter en vez de SDDM
  --sin-extras                  sin diseno/multimedia
  --sin-kodi                    sin Kodi + RetroArch + OpenRCT2
  --sin-seguridad               sin auditoria de redes
  --sin-wine                    sin WineHQ
  --sin-liquorix                sin kernel Liquorix
  --sin-repos-extra             sin MX Linux ni deb-multimedia
  --sin-brave                   sin Brave
  --quickshell-debian           quickshell de Debian (defecto: el mas nuevo)
  --seco                        simulacion (no toca nada)
  --si                          desatendido total (sin menu)
  --ayuda                       esta ayuda
AYUDA
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --idioma)          IDIOMA="${2:?falta el codigo de idioma}"; shift 2 ;;
    --compositor)      COMPOSITOR="${2:?hyprland|niri}"; shift 2 ;;
    --greeter)         GREETER="si"; shift ;;
    --extras)          EXTRAS="si"; shift ;;
    --kodi)            KODI="si"; shift ;;
    --seguridad)       SEGURIDAD="si"; shift ;;
    --wine)            WINE="si"; shift ;;
    --liquorix)        LIQUORIX="si"; shift ;;
    --multimedia-repos) MULTIREPOS="si"; shift ;;   # ya va por defecto
    --sin-repos-extra)  MULTIREPOS="no"; shift ;;
    --sin-extras)       EXTRAS="no"; shift ;;
    --sin-kodi)         KODI="no"; shift ;;
    --sin-seguridad)    SEGURIDAD="no"; shift ;;
    --sin-wine)         WINE="no"; shift ;;
    --sin-liquorix)     LIQUORIX="no"; shift ;;
    --quickshell-debian) QSH_PRIO="-1"; shift ;;
    --sin-brave)       BRAVE="no"; shift ;;
    --seco)            SECO="si"; shift ;;
    --si|--yes|-y)     SI="si"; shift ;;
    --ayuda|-h|--help) mostrar_ayuda; exit 0 ;;
    *) err "Opcion desconocida: $1  (usa --ayuda)"; exit 2 ;;
  esac
done

# ---- run(): respeta la simulacion ------------------------------------------
run() { if [[ "$SECO" == "si" ]]; then echo "${YELLOW}[seco]${NC} $*"; else "$@"; fi; }
apti() {   # los paquetes criticos: si fallan, se aborta (y queda en el registro)
  if [[ "$SECO" == "si" ]]; then echo "${YELLOW}[seco]${NC} apt-get install -y $*"; return 0; fi
  env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" 2>&1 | tee -a "$LOG"
  return "${PIPESTATUS[0]}"
}

# ============================================================================
#  MENU INTERACTIVO  (se muestra si hay terminal; --si lo salta)
# ============================================================================
resumen_opciones() {
  echo
  echo "${BOLD}Resumen de lo que se va a instalar:${NC}"
  echo "  Compositor ..... $COMPOSITOR + Quickshell + DankMaterialShell (dms)"
  echo "  Idioma ......... $IDIOMA"
  echo "  Navegador ...... $( [[ $BRAVE == si ]] && echo 'Brave (repo oficial, por defecto)' || echo 'no se toca' )"
  echo "  Repos extra .... $MULTIREPOS   (MX Linux + deb-multimedia, al principio)"
  echo "  Programas ...... Extras: $EXTRAS    Kodi: $KODI    Seguridad: $SEGURIDAD"
  echo "  Otros .......... Wine: $WINE   Liquorix: $LIQUORIX   Greeter: $GREETER"
  echo "  Politica ....... gana la version MAS NUEVA de todos los repos (MX, dmo, OBS, backports)"
}

aplicar_seleccion() {   # $1 = lista de elementos marcados (con o sin comillas)
  local sel="$1"
  marcado() { [[ "$sel" == *"$1"* ]] && echo si || echo no; }
  MULTIREPOS="$(marcado repos_extra)"
  EXTRAS="$(marcado extras)"
  KODI="$(marcado kodi)"
  SEGURIDAD="$(marcado seguridad)"
  WINE="$(marcado wine)"
  LIQUORIX="$(marcado liquorix)"
  BRAVE="$(marcado brave)"
  GREETER="$(marcado greeter)"
}

menu_interactivo() {
  local sel="" idioma="" comp=""
  if command -v whiptail >/dev/null 2>&1; then
    while true; do
      sel=$(whiptail --title "Debian 13 estilo Omarchy — componentes" --checklist \
        "Marca lo que quieras instalar  (ESPACIO = marcar / desmarcar, TAB = aceptar)" \
        24 84 12 \
        "repos_extra" "MX Linux + deb-multimedia (codecs, extras, firmware completo)" ON \
        "extras"      "Diseno y multimedia (Inkscape, Krita, GIMP, Scribus, Blender...)" ON \
        "kodi"        "Kodi + RetroArch + OpenRCT2 (con backports)" ON \
        "seguridad"   "Auditoria de redes (wifite, hashcat, hcxdumptool, wireshark...)" "${SEGURIDAD^^}" \
        "wine"        "Wine (repo oficial WineHQ, con i386)" ON \
        "liquorix"    "Kernel Liquorix (baja latencia)" ON \
        "brave"       "Brave (repo oficial) + navegador por defecto" ON \
        "greeter"     "Pantalla de acceso dms-greeter (si no: SDDM clasico)" OFF \
        3>&1 1>&2 2>&3) || return 1
      aplicar_seleccion "$sel"
      idioma=$(whiptail --title "Idioma del sistema" --inputbox \
        "Codigo de locale (ej: es_MX.UTF-8, en_US.UTF-8, pt_BR.UTF-8, ja_JP.UTF-8)" \
        10 66 "$IDIOMA" 3>&1 1>&2 2>&3) || return 1
      [[ -n "$idioma" ]] && IDIOMA="$idioma"
      comp=$(whiptail --title "Compositor" --menu "Elige el compositor Wayland:" \
        12 66 2 "hyprland" "El de Omarchy (recomendado)" "niri" "Scrollable, alternativa moderna" \
        3>&1 1>&2 2>&3) || return 1
      [[ -n "$comp" ]] && COMPOSITOR="$comp"
      resumen_opciones
      if whiptail --title "Confirmar" --yesno \
"$(resumen_opciones | sed 's/\x1b\[[0-9;]*m//g')\n\n¿Empezar la instalacion DESATENDIDA con esta seleccion?\n\n(No = volver al menu para cambiar algo)" 24 84; then
        return 0
      fi
    done
  else
    # Respaldo sin whiptail: preguntas simples
    echo "${BOLD}Seleccion de componentes (s/n)${NC}"
    resp() { local q="$1" d="$2" r; read -rp "$q [${d}] " r; r="${r:-$d}"; [[ "$r" =~ ^[sSyY]$ ]] && echo si || echo no; }
    MULTIREPOS="$(resp 'MX Linux + deb-multimedia?' si)"
    EXTRAS="$(resp 'Diseno y multimedia?' si)"
    KODI="$(resp 'Kodi + RetroArch?' si)"
    SEGURIDAD="$(resp 'Auditoria de redes?' si)"
    WINE="$(resp 'Wine?' si)"
    LIQUORIX="$(resp 'Kernel Liquorix?' si)"
    BRAVE="$(resp 'Brave por defecto?' si)"
    GREETER="$(resp 'dms-greeter (s) o SDDM (n)?' n)"
    read -rp "Idioma [$IDIOMA]: " r; [[ -n "$r" ]] && IDIOMA="$r"
    read -rp "Compositor [hyprland/niri] (hyprland): " r; [[ -n "$r" ]] && COMPOSITOR="$r"
    read -rp "¿Empezar la instalacion desatendida? [s/N] " r
    [[ "$r" =~ ^[sSyY]$ ]] || return 1
  fi
}

# Asegura un TERM valido para whiptail (por si se lanza desde un entorno raro)
asegurar_term() { [[ -n "${TERM:-}" ]] || export TERM=xterm; }

# ============================================================================
header "0. Comprobaciones previas  (v$VER)"
# ============================================================================
[[ $EUID -eq 0 ]] || { err "Ejecuta como root:  sudo bash $0 $*"; exit 1; }
USUARIO="${SUDO_USER:-}"
[[ -n "$USUARIO" && "$USUARIO" != "root" ]] || { err "No pude detectar el usuario real. Usa sudo desde tu usuario."; exit 1; }
HOME_USR="$(getent passwd "$USUARIO" | cut -d: -f6)"
log "Usuario: $USUARIO  (home: $HOME_USR)"

. /etc/os-release
if [[ "${VERSION_CODENAME:-}" != "trixie" ]]; then
  err "Este script es para Debian 13 (trixie). Detectado: ${PRETTY_NAME:-desconocido}"
  exit 1
fi
ARQ="$(dpkg --print-architecture)"
case "$ARQ" in amd64|arm64) log "Debian 13 (trixie) en $ARQ" ;; *) warn "Arquitectura no probada: $ARQ" ;; esac

ping -c1 -W3 deb.debian.org >/dev/null 2>&1 || { err "Sin conexion a internet."; exit 1; }
log "Internet OK"

if [[ "$SECO" == "si" ]]; then
  resumen_opciones
  echo
  log "Modo seco: comprobaciones correctas. NO se va a modificar nada."
  echo "  Quita --seco para lanzar la instalacion completa."
  exit 0
fi

if [[ "$SI" == "si" ]]; then
  # Desatendido total: usa los valores por defecto (o las banderas que se pasaron)
  resumen_opciones
  log "Modo desatendido (--si): sin preguntas, empezando."
elif [[ -t 0 ]]; then
  # MENU: elegir -> confirmar (o volver a cambiar) -> instalacion desatendida
  echo "${BOLD}Menu de instalacion${NC}  (--si = desatendido | --ayuda = banderas)"
  asegurar_term
  menu_interactivo || { echo "Cancelado por el usuario."; exit 0; }
  echo
  log "Seleccion confirmada. A partir de aqui TODO es desatendido."
else
  # Sin terminal (ej.: curl ... | sudo bash): se instala todo por defecto
  resumen_opciones
  warn "Sin terminal interactiva: se instala TODO por defecto (equivale a --si)."
  log "Modo desatendido (sin TTY): continuo con la seleccion por defecto."
fi

# ============================================================================
header "1. Repositorios de terceros (con llave firmada y pinning)"
# ============================================================================
mkdir -p /etc/apt/keyrings /etc/apt/sources.list.d /etc/apt/preferences.d
chmod 0755 /etc/apt/keyrings /etc/apt/preferences.d 2>/dev/null || true
export DEBIAN_FRONTEND=noninteractive

# --- 1.0 MX Linux + deb-multimedia: VAN PRIMERO Y SIEMPRE -------------------
# Como en el script original: tenerlos desde el principio hace que aparezcan
# todos los paquetes, los codecs y los firmware completos.
if [[ "$MULTIREPOS" == "si" ]]; then
  run bash -c "curl -fsSLo /tmp/mxkey.deb https://mxrepo.com/mx/repo/pool/main/m/mx25-archive-keyring/mx25-archive-keyring_2025.03_all.deb && dpkg -i /tmp/mxkey.deb && rm -f /tmp/mxkey.deb"
  cat > /etc/apt/sources.list.d/mx.sources <<'EOF'
Types: deb
Enabled: yes
URIs: https://mxrepo.com/mx/repo/
Suites: trixie
Components: main non-free ahs
Signed-By: /usr/share/keyrings/mx-25-archive-keyring.gpg
EOF
  run bash -c "curl -fsSLo /tmp/dmo.deb https://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/deb-multimedia-keyring_2024.9.1_all.deb && dpkg -i /tmp/dmo.deb && rm -f /tmp/dmo.deb"
  cat > /etc/apt/sources.list.d/dmo.sources <<'EOF'
Types: deb
URIs: https://www.deb-multimedia.org
Suites: trixie
Components: main non-free
Signed-By: /usr/share/keyrings/deb-multimedia-keyring.pgp
Enabled: yes

Types: deb
URIs: https://www.deb-multimedia.org
Suites: trixie-backports
Components: main
Signed-By: /usr/share/keyrings/deb-multimedia-keyring.pgp
Enabled: yes
EOF
  run apt-get update || warn "apt update con los repos extra fallo; sigo con Debian"
  log "Repos de MX Linux y deb-multimedia agregados AL PRINCIPIO (codecs y firmware completos)"
else
  warn "MX Linux y deb-multimedia desactivados (--sin-repos-extra)"
fi

# --- 1.1 Debian backports (fuente de hyprland y quickshell) -----------------
if ! grep -Rqs 'trixie-backports' /etc/apt/sources.list /etc/apt/sources.list.d/; then
  echo "deb http://deb.debian.org/debian trixie-backports main contrib non-free non-free-firmware" \
    > /etc/apt/sources.list.d/trixie-backports.list
  log "Repositorio trixie-backports agregado"
else
  log "trixie-backports ya presente"
fi

# --- 1.2 OBS de AvengeMedia / DankLinux (dms, matugen, ghostty, niri...) ----
add_obs_repo() {   # add_obs_repo <proyecto> <nombre-llave>
  local proj="$1" nombre="$2" base="https://download.opensuse.org/repositories/${1}/Debian_13"
  run curl -fsSL "$base/Release.key" | gpg --dearmor --yes -o "/etc/apt/keyrings/${nombre}.gpg"
  echo "deb [signed-by=/etc/apt/keyrings/${nombre}.gpg] $base/ /" \
    > "/etc/apt/sources.list.d/${nombre}.list"
  log "Repo OBS listo: $proj"
}
add_obs_repo "home:/AvengeMedia:/danklinux" "danklinux"
add_obs_repo "home:/AvengeMedia:/dms"       "avengemedia-dms"

# --- 1.3 Brave (navegador por defecto, repositorio oficial) -----------------
if [[ "$BRAVE" == "si" ]]; then
  run curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
    > /etc/apt/sources.list.d/brave-browser-release.list
  log "Repo oficial de Brave listo"
fi

# --- 1.4 Kernel Liquorix (opcional) ----------------------------------------
if [[ "$LIQUORIX" == "si" ]]; then
  run curl -fsSL https://liquorix.net/liquorix-keyring.gpg | gpg --dearmor --yes -o /etc/apt/keyrings/liquorix.gpg
  echo "deb [signed-by=/etc/apt/keyrings/liquorix.gpg] https://liquorix.net/debian trixie main" \
    > /etc/apt/sources.list.d/liquorix.list
  log "Repo de Liquorix listo"
fi

# --- 1.5 WineHQ (opcional) --------------------------------------------------
if [[ "$WINE" == "si" ]]; then
  run bash -c 'curl -fsSL https://dl.winehq.org/wine-builds/winehq.key | gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key'
  cat > /etc/apt/sources.list.d/winehq-trixie.sources <<'EOF'
Types: deb
URIs: https://dl.winehq.org/wine-builds/debian
Suites: trixie
Components: main
Architectures: amd64 i386
Signed-By: /etc/apt/keyrings/winehq-archive.key
EOF
  log "Repo de WineHQ listo"
fi

# --- 1.7 Pinning: que los terceros no secuestren el sistema -----------------
cat > /etc/apt/preferences.d/99-danklinux.pref <<EOF
# Repositorios de terceros: se usan, pero Debian manda.
# quickshell: por defecto gana la VERSION MAS NUEVA (incluido el del OBS).
# Con --quickshell-debian se bloquea el del OBS y se usa siempre el de Debian
# (mas conservador: su doc dice que el paquete del OBS esta deprecado).
Package: quickshell
Pin: origin download.opensuse.org
Pin-Priority: $QSH_PRIO

# El resto del OBS: prioridad normal para que dms/matugen/ghostty se actualicen.
Package: *
Pin: origin download.opensuse.org
Pin-Priority: $OBS_PRIO

# Brave, WineHQ y Liquorix: misma politica, prioridad normal (gana el mas nuevo)
Package: *
Pin: origin brave-browser-apt-release.s3.brave.com
Pin-Priority: 500

Package: *
Pin: origin dl.winehq.org
Pin-Priority: 500

Package: *
Pin: origin liquorix.net
Pin-Priority: 500

# MX y deb-multimedia: prioridad 500 = si traen una version MAS NUEVA, ganan.
# (criterio de Ricardo: los usa siempre y nunca le han dado problemas; quiere
#  lo mas nuevo de cualquiera de los repos).
Package: *
Pin: origin mxrepo.com
Pin-Priority: 500

Package: *
Pin: origin www.deb-multimedia.org
Pin-Priority: 500

# Backports: $BACKPORTS_PRIO (500 = la version mas nueva gana tambien aqui)
Package: *
Pin: release a=trixie-backports
Pin-Priority: $BACKPORTS_PRIO
EOF
log "Pinning escrito en /etc/apt/preferences.d/99-danklinux.pref"
if [[ $BACKPORTS_PRIO -eq 100 ]]; then
  warn "Con backports a 100, para actualizar Hyprland/Quickshell: apt install -t trixie-backports <paquete>"
fi

# --- 1.8 Preseed de paquetes que preguntan ---------------------------------
echo "ttf-mscorefonts-installer msttcorefonts/accept-mscorefonts-eula select true" | debconf-set-selections || true
echo "wireshark-common wireshark-common/install-setuid boolean false" | debconf-set-selections || true
echo "winehq-stable winehq-stable/install-recommends boolean true" | debconf-set-selections || true

run apt-get update
log "Repositorios actualizados"

# Todo al dia con TODOS los repos presentes: gana siempre la version mas nueva
run env DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y || warn "dist-upgrade inicial fallo; sigo adelante"
log "Sistema al dia con todos los repos (dist-upgrade)"

# ============================================================================
header "2. Base del sistema (firmware, utilidades y CLI)"
# ============================================================================
apti_try() {   # instala lo que exista, avisa de lo que no (no aborta)
  for p in "$@"; do
    if apt-cache show "$p" >/dev/null 2>&1; then apti "$p"; else warn "no esta en los repos: $p (se salta)"; fi
  done
}

# --- Firmware: la lista completa (de tu script), tolerante a fallos ---------
apti_try firmware-linux-nonfree firmware-misc-nonfree firmware-realtek firmware-amd-graphics \
     firmware-ath9k-htc firmware-atheros firmware-b43-installer firmware-b43legacy-installer \
     firmware-bnx2 firmware-bnx2x firmware-brcm80211 firmware-intel-sound firmware-iwlwifi \
     firmware-libertas firmware-myricom firmware-netronome firmware-netxone firmware-qlogic \
     firmware-samsung firmware-siano firmware-sof-signed firmware-ti-connectivity \
     firmware-zd1211 firmware-ast firmware-cavium firmware-mediatek firmware-ralink \
     firmware-realtek-rtl88xxau firmware-rtl-nic firmware-rtw88 firmware-rtw89 \
     firmware-marvell-prestera firmware-nvidia-gsp
log "Firmware procesado (se instalo todo lo que existe en los repos)"

apti_try git curl wget rsync htop btop btop net-tools gdebi unzip zip p7zip-full \
     build-essential pkg-config cmake python3 python3-pip pipx pipx xdg-utils xdg-user-dirs \
     jq yq man-db bash-completion

apti_try ripgrep fzf bat eza zoxide fd-find tree ncdu duf fastfetch gum \
     alacritty kitty neovim vim tmux lazygit git-delta wl-clipboard cliphist \
     grim slurp swappy brightnessctl playerctl pavucontrol network-manager-gnome blueman

# --- Fuentes -----------------------------------------------------------------
apti_try fonts-noto fonts-noto-color-emoji fonts-noto-cjk fonts-jetbrains-mono \
     fonts-font-awesome fonts-materialdesignicons-webfont fonts-firacode \
     papirus-icon-theme arc-theme
log "Fuentes, temas e iconos base instalados"

# Material Symbols (la que usa DankMaterialShell para los iconos)
if [[ "$SECO" != "si" ]]; then
  mkdir -p /usr/share/fonts/truetype/material-symbols
  for v in Rounded Outlined; do
    curl -fsSL -o "/usr/share/fonts/truetype/material-symbols/MaterialSymbols${v}.ttf" \
      "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbols${v}%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" \
      && log "Material Symbols $v instalada" || warn "no se pudo bajar Material Symbols $v"
  done
  fc-cache -f >/dev/null 2>&1 || true
  fc-list | grep -qi "Material Symbols" && log "fuente Material Symbols detectada por fontconfig" \
    || warn "fontconfig no ve Material Symbols (los iconos de dms saldrian vacios)"
fi

# ============================================================================
header "3. Audio: PipeWire + WirePlumber"
# ============================================================================
apti pipewire pipewire-alsa pipewire-audio pipewire-bin pipewire-pulse pipewire-jack \
     pipewire-v4l2 wireplumber libspa-0.2-bluetooth libspa-0.2-jack libspa-0.2-modules qpwgraph
run apt-get install -y -t trixie-backports pipewire pipewire-audio pipewire-pulse wireplumber \
  || warn "no se pudo subir PipeWire desde backports (se queda el estable)"

# ============================================================================
header "4. Idioma del sistema: $IDIOMA"
# ============================================================================
LANG_BASE="${IDIOMA%%.*}"          # es_MX  -> es_MX
LANG_ISO="${LANG_BASE%%_*}"        # es_MX  -> es

# 4.1 Generar el locale
if [[ "$SECO" != "si" ]]; then
  if ! grep -qE "^[[:space:]]*${LANG_BASE}\.UTF-8" /etc/locale.gen; then
    if grep -qE "^# *${LANG_BASE}\.UTF-8 UTF-8" /etc/locale.gen; then
      sed -i "s/^# *${LANG_BASE}\.UTF-8 UTF-8/${LANG_BASE}.UTF-8 UTF-8/" /etc/locale.gen
    else
      echo "${LANG_BASE}.UTF-8 UTF-8" >> /etc/locale.gen
    fi
  fi
  grep -qE "^[[:space:]]*${LANG_ISO}\.UTF-8" /etc/locale.gen || \
    { grep -qE "^# *${LANG_ISO}\.UTF-8 UTF-8" /etc/locale.gen \
        && sed -i "s/^# *${LANG_ISO}\.UTF-8 UTF-8/${LANG_ISO}.UTF-8 UTF-8/" /etc/locale.gen \
        || echo "${LANG_ISO}.UTF-8 UTF-8" >> /etc/locale.gen; }
  locale-gen
  localectl set-locale "LANG=${IDIOMA}" "LC_MESSAGES=${IDIOMA}" "LC_TIME=${IDIOMA}" \
                       "LC_NUMERIC=${IDIOMA}" "LC_MONETARY=${IDIOMA}" 2>/dev/null || \
    warn "localectl fallo; revisa /etc/default/locale"
  log "Locale ${IDIOMA} generado y fijado (surte efecto en el proximo inicio de sesion)"
fi

# 4.2 Paquetes de traduccion y diccionarios del idioma
apti_try "libreoffice-l10n-${LANG_ISO}" "libreoffice-help-${LANG_ISO}" \
         "hunspell-${LANG_ISO}" "hyphen-${LANG_ISO}" "mythes-${LANG_ISO}" \
         "firefox-esr-l10n-${LANG_ISO}" "thunderbird-l10n-${LANG_ISO}" \
         "task-${LANG_ISO}-desktop" "console-data"

# 4.3 Metodos de entrada para CJK (como hace Omarchy en su instalador)
case "$LANG_ISO" in
  ja) apti_try fonts-noto-cjk ibus ibus-mozc mozc-utils-gui ;; 
  ko) apti_try fonts-noto-cjk ibus ibus-hangul ;;
  zh) apti_try fonts-noto-cjk ibus ibus-libpinyin ibus-chewing ;;
  *)  : ;;
esac
if [[ "$LANG_ISO" =~ ^(ja|ko|zh)$ ]]; then
  warn "Para CJK: activa el metodo de entrada en Ajustes de Ibus (ibus-setup) tras reiniciar."
fi

# 4.4 Nota honesta sobre las traducciones del shell
cat <<'EONOTA'
[NOTA] Omarchy traduce su propio shell a 50 idiomas con catalogos JSON suyos; eso no
se puede inyectar en DankMaterialShell. DMS trae sus traducciones (21 idiomas, entre
ellos es) y se cambian en su propia interfaz:  Ajustes (dms) -> Locale.
Este script deja el locale del sistema correcto, que es lo que siguen las apps
(Brave, LibreOffice, GTK, GTK/Qt, xdg-user-dirs). Si tu idioma no esta en DMS, sus
cadenas se quedan en ingles; el resto del sistema si se traduce.
EONOTA

# ============================================================================
header "5. Escritorio: $COMPOSITOR + Quickshell + DankMaterialShell"
# ============================================================================
# Hyprland y Quickshell SIEMPRE desde backports de Debian (son los oficiales).
apti -t trixie-backports hyprland quickshell hyprpaper hypridle hyprlock \
     hyprland-guiutils hyprland-protocols hyprsunset uwsm waybar swaybg wlogout
apti xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-desktop-portal \
     polkit-kde-agent-1 mate-polkit gnome-keyring libpam-gnome-keyring \
     qt6ct qt6-wayland qml6-module-qtquick qml6-module-qtquick-controls \
     qml6-module-qtquick-layouts qml6-module-qtquick-templates \
     qml6-module-qtquick-window qml6-module-qtquick-effects qt6-svg-dev \
     pipewire-audio desktop-file-utils shared-mime-info mesa-utils vulkan-tools \
     libgl1-mesa-dri libglx-mesa0 mesa-vulkan-drivers
log "Base grafica y de portales instalada"

# --- Compositor alternativo (niri) si se pidio ------------------------------
if [[ "$COMPOSITOR" == "niri" ]]; then
  apti niri xwayland-satellite || warn "niri no se pudo instalar desde el OBS"
  log "Compositor niri instalado"
fi

# --- DankMaterialShell y su ecosistema (repo OBS verificado) ----------------
apti dms matugen ghostty
apti_try dankcalendar danksearch dgop dux-files xwayland-satellite
log "DankMaterialShell, matugen y ghostty instalados"

# --- Pantalla de acceso ----------------------------------------------------
if [[ "$GREETER" == "si" ]]; then
  apti greetd dms-greeter
  cat > /etc/greetd/config.toml <<EOF
[terminal]
vt = 1

[default_session]
command = "dms-greeter --command ${COMPOSITOR}"
user = "greeter"
EOF
  run systemctl enable greetd
  log "greetd + dms-greeter configurados (pantalla de acceso con el estilo del shell)"
else
  # sin greeter: SDDM como acceso clasico, con sesion Hyprland disponible
  apti sddm
  run systemctl enable sddm
  log "SDDM instalado (elige la sesion '$COMPOSITOR' en el menu)"
fi

# --- Herramientas de desarrollo del stack Omarchy --------------------------
apti docker.io docker-compose gh
run usermod -aG docker "$USUARIO" || true
log "Docker, docker-compose y gh instalados ($USUARIO agregado al grupo docker)"

if [[ "$SECO" != "si" ]]; then
  # lazydocker (binario Go, no esta en Debian) con su instalador oficial
  su - "$USUARIO" -c 'curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash' \
    && log "lazydocker instalado" || warn "lazydocker fallo (opcional)"
  # mise (gestor de runtimes, como en Omarchy)
  su - "$USUARIO" -c 'curl -fsSL https://mise.run | sh' && log "mise instalado" || warn "mise fallo (opcional)"
  # tte (efectos de texto para la terminal, via pipx)
  su - "$USUARIO" -c 'pipx install terminaltexteffects' && log "tte instalado" || warn "tte fallo (opcional)"
fi

# --- Flatpak (para lo que no exista en Debian, como hace Omarchy con AUR) ---
apti flatpak
run flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
log "Flatpak + Flathub listos"

# ============================================================================
header "6. Configuracion del usuario ($USUARIO)"
# ============================================================================
CFG="$HOME_USR/.config"
run install -d -o "$USUARIO" -g "$USUARIO" "$CFG/hypr" "$CFG/environment.d" "$CFG/gtk-3.0" "$CFG/gtk-4.0" "$CFG/dms"

# --- 6.1 Variables de entorno de la sesion ---------------------------------
cat > "$CFG/environment.d/10-dank.conf" <<'EOF'
BROWSER=brave-browser
QT_QPA_PLATFORMTHEME=qt6ct
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
MOZ_ENABLE_WAYLAND=1
XDG_CURRENT_DESKTOP=Hyprland
XDG_SESSION_TYPE=wayland
GTK_USE_PORTAL=1
EOF
log "Variables de entorno escritas (environment.d)"

# --- 6.2 hyprland.conf base, con atajos estilo Omarchy ---------------------
cat > "$CFG/hypr/hyprland.conf" <<'EOF'
# Generado por debian13-hyprland-dms.sh  (Debian 13 + Hyprland + DankMaterialShell)
$mod        = SUPER
$terminal   = ghostty
$browser    = brave-browser
$menu       = fuzzel
$files      = nautilus

# --- arranque -------------------------------------------------------------
exec-once = uwsm app -- hyprpaper
exec-once = dms run
exec-once = /usr/lib/polkit-kde-authentication-agent-1
exec-once = gnome-keyring-daemon --start --components=secrets
exec-once = wl-paste --watch cliphist store

# --- pantallas e input ----------------------------------------------------
monitor = , preferred, auto, auto
input {
    kb_layout  = latam
    follow_mouse = 1
    touchpad { natural_scroll = true }
}
general {
    gaps_in = 4
    gaps_out = 8
    border_size = 2
    allow_tearing = false
}
decoration { rounding = 8 }
misc { force_default_wallpaper = 0 }

# --- atajos (la barra y los menus viven en dms) ---------------------------
bind = $mod, RETURN, exec, $terminal
bind = $mod, SPACE,  exec, $menu
bind = $mod, B,      exec, $browser
bind = $mod, E,      exec, $files
bind = $mod, Q,      killactive,
bind = $mod SHIFT, Q, exit,
bind = $mod, L,      exec, hyprlock
bind = $mod, V,      exec, cliphist list | fuzzel -d | cliphist decode | wl-copy
bind = $mod, S,      exec, grim -g "$(slurp)" - | swappy -f -
bind = $mod, P,      exec, hyprpicker -a
bind = $mod, C,      exec, dms ipc call settings toggle
bind = $mod, TAB,    cyclenext,
bind = $mod SHIFT, F, togglefloating,
bind = $mod, F,      fullscreen,
bind = $mod, 1, workspace, 1
bind = $mod, 2, workspace, 2
bind = $mod, 3, workspace, 3
bind = $mod SHIFT, 1, movetoworkspace, 1
bind = $mod SHIFT, 2, movetoworkspace, 2
bind = $mod SHIFT, 3, movetoworkspace, 3
bindm = $mod, mouse:272, movewindow
bindm = $mod, mouse:273, resizewindow
EOF
chown "$USUARIO":"$USUARIO" "$CFG/hypr/hyprland.conf"
log "hyprland.conf creado (Super+Space menu, Super+Return terminal, Super+B Brave, Super+C ajustes dms)"

# --- 6.3 GTK oscuro (como en tu otra maquina) ------------------------------
for g in 3.0 4.0; do
cat > "$CFG/gtk-$g/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 11
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintfull
gtk-xft-rgba=rgb
EOF
done
chown -R "$USUARIO":"$USUARIO" "$CFG/gtk-3.0" "$CFG/gtk-4.0"
log "settings.ini de GTK3/GTK4 en modo oscuro (Arc-Dark + Papirus-Dark)"

# gsettings (necesita el bus del usuario; si no hay sesion, se avisa)
gs() { run su - "$USUARIO" -c "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u "$USUARIO")/bus gsettings set $1 $2 '$3'" || warn "gsettings $1 $2 (sin sesion grafica activa?)"; }
if [[ "$SECO" != "si" ]]; then
  CURSOR_TEMA=""
  for d in /usr/share/icons/*[Bb]ibata*; do [ -d "$d" ] && CURSOR_TEMA="$(basename "$d")" && break; done
  CURSOR_TEMA="${CURSOR_TEMA:-Adwaita}"
  gs org.gnome.desktop.interface color-scheme prefer-dark
  gs org.gnome.desktop.interface gtk-theme Arc-Dark
  gs org.gnome.desktop.interface icon-theme Papirus-Dark
  gs org.gnome.desktop.interface cursor-theme "$CURSOR_TEMA"
  gs org.gnome.desktop.interface font-name "Inter 11"
  gs org.gnome.desktop.interface document-font-name "Inter 11"
  gs org.gnome.desktop.interface monospace-font-name "JetBrains Mono 11"
  gs org.gnome.desktop.wm.preferences titlebar-font "Inter Bold 11"
  log "Apariencia aplicada: Arc-Dark + Papirus-Dark + cursor $CURSOR_TEMA + fuente Inter"
fi

# --- 6.4 Brave como navegador por defecto ---------------------------------
if [[ "$BRAVE" == "si" ]]; then
  apti brave-browser
  run update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/brave-browser 200
  run update-alternatives --install /usr/bin/gnome-www-browser gnome-www-browser /usr/bin/brave-browser 200
  run update-alternatives --set x-www-browser /usr/bin/brave-browser || true
  cat > "$CFG/mimeapps.list" <<'EOF'
[Default Applications]
text/html=brave-browser.desktop
application/xhtml+xml=brave-browser.desktop
x-scheme-handler/http=brave-browser.desktop
x-scheme-handler/https=brave-browser.desktop
x-scheme-handler/about=brave-browser.desktop
x-scheme-handler/unknown=brave-browser.desktop
EOF
  chown "$USUARIO":"$USUARIO" "$CFG/mimeapps.list"
  if [[ "$SECO" != "si" ]]; then
    su - "$USUARIO" -c 'xdg-settings set default-web-browser brave-browser.desktop' 2>/dev/null \
      && log "Brave fijado como navegador por defecto (xdg)" || warn "xdg-settings fallo; mimeapps.list ya lo cubre"
  fi
  log "Brave instalado y fijado como navegador por defecto"
fi

# --- 6.5 Carpetas de usuario en el idioma elegido --------------------------
run su - "$USUARIO" -c 'LANG='"$IDIOMA"' xdg-user-dirs-update' || true

# ============================================================================
header "7. Paquetes opcionales"
# ============================================================================
if [[ "$MULTIREPOS" == "si" ]]; then
  apti_try libdvdcss2 libdvd-pkg w64codecs || warn "codecs de deb-multimedia: algunos no estaban"
  log "Codecs extra (deb-multimedia) intentados"
fi

if [[ "$EXTRAS" == "si" ]]; then
  header "7.1 Diseno grafico y multimedia"
  apti_try inkscape krita krita-l10n gimp gimp-data-extras scribus scribus-template \
           darktable openshot-qt audacity simplescreenrecorder guvcview \
           amule filezilla qbittorrent blender yt-dlp
  # dvdstyler y clipgrab no existen en Debian 13: se avisa y se sustituye
  apt-cache show dvdstyler >/dev/null 2>&1 || warn "dvdstyler no esta en Debian 13 (activar --multimedia-repos o usar devede)"
  apti_try devede
  apt-cache show clipgrab >/dev/null 2>&1 || warn "clipgrab no esta en Debian 13: se instalo yt-dlp como sustituto"
  log "Paquete de diseno y multimedia procesado"
fi

if [[ "$KODI" == "si" ]]; then
  header "7.2 Kodi + RetroArch"
  apti -t trixie-backports kodi kodi-audiodecoder-modplug kodi-audiodecoder-openmpt \
       kodi-audioencoder-flac kodi-audioencoder-lame kodi-audioencoder-vorbis \
       kodi-inputstream-adaptive kodi-inputstream-ffmpegdirect kodi-inputstream-rtmp \
       kodi-peripheral-joystick kodi-pvr-iptvsimple kodi-vfs-libarchive kodi-vfs-rar \
       kodi-vfs-sftp retroarch || warn "algo de Kodi no se instalo (revisa backports)"
  apti_try openrct2
  log "Kodi, RetroArch y OpenRCT2 procesados"
fi

if [[ "$SEGURIDAD" == "si" ]]; then
  header "7.3 Auditoria de redes"
  apti_try wifite bully hashcat hcxdumptool hcxtools wireshark macchanger aircrack-ng
  warn "Wireshark: los usuarios deben estar en el grupo 'wireshark' para capturar sin root"
  run usermod -aG wireshark "$USUARIO" || true
fi

if [[ "$WINE" == "si" ]]; then
  header "7.4 Wine (repo oficial)"
  run dpkg --add-architecture i386
  run apt-get update
  apti --install-recommends winehq-stable || warn "winehq-stable fallo (¿el repo esta arriba?)"
fi

if [[ "$LIQUORIX" == "si" ]]; then
  header "7.5 Kernel Liquorix"
  if ! dpkg -l 2>/dev/null | grep -q liquorix; then
    run bash -c "curl -fsSL 'https://liquorix.net/install-liquorix.sh' | bash" \
      && log "Kernel Liquorix instalado (se usara tras reiniciar)" \
      || warn "Liquorix fallo; sigue con el kernel de Debian (no es bloqueante)"
  else
    log "Liquorix ya estaba instalado"
  fi
fi

# ============================================================================
header "8. Sesion, limpieza y verificacion"
# ============================================================================
# 8.1 Sesion de Hyprland visible en el menu de acceso
if [[ "$SECO" != "si" ]]; then
  if [[ ! -f /usr/share/wayland-sessions/hyprland.desktop ]]; then
    cat > /usr/share/wayland-sessions/hyprland.desktop <<EOF
[Desktop Entry]
Name=Hyprland
Comment=Compositor Wayland (Debian + DankMaterialShell)
Exec=${COMPOSITOR}
Type=Application
DesktopNames=Hyprland
EOF
    log "Sesion 'Hyprland' creada en /usr/share/wayland-sessions"
  else
    log "Sesion 'Hyprland' ya la aporta el paquete"
  fi
fi

# 8.1b Autologin: arrancar DIRECTO al escritorio (como termina tu script)
if [[ "$SECO" != "si" ]]; then
  if [[ "$GREETER" == "si" ]]; then
    log "greetd + dms-greeter ya autentican: la sesion $COMPOSITOR arranca sola"
  else
    mkdir -p /etc/sddm.conf.d
    cat > /etc/sddm.conf.d/01-autologin.conf <<EOF
[Autologin]
User=$USUARIO
Session=$COMPOSITOR
Relogin=false
EOF
    log "Autologin en SDDM: entras directo a la sesion $COMPOSITOR"
  fi
fi

# 8.2 Ultima pasada: lo mas nuevo de todos los repos + limpieza
run env DEBIAN_FRONTEND=noninteractive apt-get update || true
run env DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y || warn "full-upgrade final fallo; revisa a mano"
run apt-get autoremove -y
run apt-get autoclean
run apt-get update

# 8.3 Verificacion (tolerante: nada de esto aborta el script)
# ============================================================================
header "9. Apariencia: fondo, paleta, tema, iconos y cursor"
# ============================================================================
# --- 9.1 Paquetes de apariencia -------------------------------------------
apti -t trixie-backports hyprland-backgrounds        # fondos oficiales de Hyprland
apti_try bibata-cursor-theme fonts-inter fonts-jetbrains-mono fonts-firacode \
         papirus-icon-theme arc-theme numix-icon-theme-circle adwaita-icon-theme \
         gnome-themes-extra qt6ct qt6-wayland

# --- 9.2 Fondo de pantalla ------------------------------------------------
WALL_DIR="$HOME_USR/Pictures/Wallpapers"
FONDO="$WALL_DIR/fondo-actual.jpg"
install -d -o "$USUARIO" -g "$USUARIO" "$WALL_DIR" "$CFG/matugen/templates" 2>/dev/null || true
if [[ "$SECO" != "si" ]]; then
  ORIGEN="$(find /usr/share/backgrounds -type f \( -iname '*.jpg' -o -iname '*.png' \) 2>/dev/null | head -1)"
  if [[ -n "$ORIGEN" ]]; then
    cp -f "$ORIGEN" "$FONDO"
    chown "$USUARIO":"$USUARIO" "$FONDO"
    log "Fondo puesto: $(basename "$ORIGEN")  ->  $FONDO"
  else
    warn "sin fondos en /usr/share/backgrounds; copia uno a $WALL_DIR"
  fi
  printf '%s\n' "$FONDO" > "$CFG/matugen/fondo"
  chown -R "$USUARIO":"$USUARIO" "$CFG/matugen"
fi

cat > "$CFG/hypr/hyprpaper.conf" <<EOF
# Fondo del escritorio (lo cambia: tema-desde-fondo /ruta/imagen.jpg)
preload = $FONDO
wallpaper = ,$FONDO
splash = false
EOF
cat > "$CFG/hypr/hyprlock.conf" <<EOF
# Pantalla de bloqueo con el mismo fondo
background {
    monitor =
    path = $FONDO
    blur_passes = 2
    blur_size = 6
}
input-field {
    size = 320 50
    outline_thickness = 2
    dots_size = 0.25
}
EOF
chown "$USUARIO":"$USUARIO" "$CFG/hypr/hyprpaper.conf" "$CFG/hypr/hyprlock.conf"
log "hyprpaper y hyprlock configurados con el mismo fondo"

# --- 9.3 Cambiar el fondo = cambiar TODO el tema (helper de bolsillo) ------
install -d -o "$USUARIO" -g "$USUARIO" "$HOME_USR/.local/bin" 2>/dev/null || true
cat > "$HOME_USR/.local/bin/tema-desde-fondo" <<'EOF'
#!/bin/bash
# Uso:  tema-desde-fondo /ruta/imagen.jpg
# Pone el fondo y REGENERA la paleta de todo el escritorio (GTK, terminales, Hyprland).
set -e
IMG="${1:?uso: tema-desde-fondo /ruta/imagen.jpg}"
[[ -f "$IMG" ]] || { echo "no existe: $IMG" >&2; exit 1; }
DEST="$HOME/Pictures/Wallpapers/fondo-actual.jpg"
mkdir -p "$(dirname "$DEST")"
cp -f "$IMG" "$DEST"
printf '%s\n' "$DEST" > "$HOME/.config/matugen/fondo"
sed -i "s|^preload = .*|preload = $DEST|; s|^wallpaper = ,.*|wallpaper = ,$DEST|" \
       "$HOME/.config/hypr/hyprpaper.conf" 2>/dev/null || true
sed -i "s|    path = .*|    path = $DEST|" "$HOME/.config/hypr/hyprlock.conf" 2>/dev/null || true
matugen image "$DEST" --mode dark
hyprctl hyprpaper reload ,"$DEST" 2>/dev/null || { pkill hyprpaper || true; (hyprpaper >/dev/null 2>&1 &) ; }
dms ipc call wallpaper set "$DEST" 2>/dev/null || true
echo "Fondo y paleta actualizados desde $IMG"
EOF
chmod 755 "$HOME_USR/.local/bin/tema-desde-fondo" 2>/dev/null || true
chown "$USUARIO":"$USUARIO" "$HOME_USR/.local/bin/tema-desde-fondo" 2>/dev/null || true
log "Helper 'tema-desde-fondo' instalado: cambia el fondo y regenera todos los colores"

# ============================================================================
header "10. Paleta automatica desde el fondo (matugen) + tema e iconos"
# ============================================================================
# --- 10.1 Plantillas oficiales de matugen ---------------------------------
TPL_BASE="https://raw.githubusercontent.com/InioX/matugen-themes/main/templates"
if [[ "$SECO" != "si" ]]; then
  for t in gtk-colors.css ghostty kitty-colors.conf hyprland-colors.conf; do
    if curl -fsSL -o "$CFG/matugen/templates/$t" "$TPL_BASE/$t"; then
      log "plantilla matugen: $t"
    else
      warn "no se pudo bajar la plantilla $t (esa app se queda con el tema de respaldo)"
    fi
  done
  chown -R "$USUARIO":"$USUARIO" "$CFG/matugen/templates"
fi

# --- 10.2 config.toml: que cada app reciba los colores del fondo -----------
cat > "$CFG/matugen/config.toml" <<'EOF'
[config]
version_check = false
fallback_color = "#ffbf9b"
prefer = "closest-to-fallback"

# GTK 3 y GTK 4 (todas las apps GTK: Nautilus, GIMP, Inkscape, Brave en GTK...)
[templates.gtk3]
input_path  = '~/.config/matugen/templates/gtk-colors.css'
output_path = '~/.config/gtk-3.0/matugen.css'
post_hook   = 'touch ~/.config/gtk-3.0/gtk.css'

[templates.gtk4]
input_path  = '~/.config/matugen/templates/gtk-colors.css'
output_path = '~/.config/gtk-4.0/matugen.css'
post_hook   = 'touch ~/.config/gtk-4.0/gtk.css'

# Terminal Ghostty
[templates.ghostty]
input_path  = '~/.config/matugen/templates/ghostty'
output_path = '~/.config/ghostty/matugen.conf'

# Terminal Kitty
[templates.kitty]
input_path  = '~/.config/matugen/templates/kitty-colors.conf'
output_path = '~/.config/kitty/matugen.conf'
post_hook   = 'pkill -SIGUSR1 kitty || true'

# Hyprland (bordes, colores de ventana activa)
[templates.hyprland]
input_path  = '~/.config/matugen/templates/hyprland-colors.conf'
output_path = '~/.config/hypr/colores.conf'
post_hook   = 'hyprctl reload || true'
EOF
chown "$USUARIO":"$USUARIO" "$CFG/matugen/config.toml"
log "config.toml de matugen escrito"

# --- 10.3 Que las app importen el archivo generado -------------------------
for g in 3.0 4.0; do
  echo '@import url("matugen.css");' > "$CFG/gtk-$g/gtk.css"
done
cat > "$CFG/ghostty/config" <<'EOF'
# Colores generados desde el fondo por matugen
config-file = matugen.conf
font-family = JetBrains Mono
font-size = 11
EOF
cat > "$CFG/kitty/kitty.conf" <<'EOF'
include matugen.conf
font_family JetBrains Mono
font_size 11
EOF
mkdir -p "$CFG/kitty" "$CFG/ghostty" 2>/dev/null || true
chown -R "$USUARIO":"$USUARIO" "$CFG/gtk-3.0" "$CFG/gtk-4.0" "$CFG/kitty" "$CFG/ghostty"
# Hyprland: que lea los colores generados
grep -q "colores.conf" "$CFG/hypr/hyprland.conf" 2>/dev/null || \
  echo 'source = ~/.config/hypr/colores.conf' >> "$CFG/hypr/hyprland.conf"

# --- 10.4 Generar la paleta ahora mismo ------------------------------------
if [[ "$SECO" != "si" && -f "$FONDO" ]]; then
  if su - "$USUARIO" -c "matugen image '$FONDO' --mode dark" >>"$LOG" 2>&1; then
    log "Paleta generada desde el fondo: GTK, Ghostty, Kitty y Hyprland ya tienen sus colores"
  else
    warn "matugen fallo; el escritorio usa el tema de respaldo (Arc-Dark + Papirus-Dark)"
  fi
fi
# ============================================================================
header "11. Verificacion final"
# ============================================================================
v() { printf "  %-34s %s\n" "$1" "$(eval "$2" 2>/dev/null || echo '(no disponible)')"; }
v "compositor instalado"        "dpkg -l $COMPOSITOR 2>/dev/null | awk '/^ii/{print \$3}'"
v "quickshell (Debian bpo)"     "qs --version 2>/dev/null | head -1"
v "dankmaterialshell (OBS)"     "dms --version 2>/dev/null | head -1"
v "matugen (OBS)"               "matugen --version 2>/dev/null | head -1"
v "brave"                       "brave-browser --version 2>/dev/null | head -1"
v "navegador por defecto"       "update-alternatives --query x-www-browser 2>/dev/null | awk '/^Value/{print \$2}'"
v "locale del sistema"          "localectl status 2>/dev/null | awk -F: '/System Locale/{print \$2}'"
v "Material Symbols"            "fc-list 2>/dev/null | grep -ci 'Material Symbols' | xargs -I{} echo '{} variantes'"
v "pipewire activo (usuario)"   "su - $USUARIO -c 'systemctl --user is-active pipewire' 2>/dev/null"
v "kernel en uso"               "uname -r"
v "grupos de $USUARIO"          "groups $USUARIO 2>/dev/null"
echo

# ---- REPORTE FINAL --------------------------------------------------------
header "REPORTE DE LA INSTALACION"
PAQ_DESPUES="$(dpkg-query -f '.\n' -W 2>/dev/null | wc -l)"
PAQ_NUEVOS=$(( PAQ_DESPUES - PAQ_ANTES ))
REPORTE="$HOME_USR/reporte-instalacion-$(date +%Y%m%d-%H%M).txt"

{
  echo "Debian 13 + $COMPOSITOR + Quickshell + DankMaterialShell  (script $VER)"
  echo "Fecha: $(date '+%Y-%m-%d %H:%M')"
  echo
  echo "Paquetes instalados en esta corrida : $PAQ_NUEVOS"
  echo "Paquetes totales del sistema        : $PAQ_DESPUES"
  echo "Espacio usado en /                  : $(df -h / | awk 'NR==2{print $3" de "$2" ("$5")"}')"
  echo
  echo "Repositorios agregados:"
  for f in /etc/apt/sources.list.d/*; do [ -e "$f" ] && echo "  - $(basename "$f")"; done
  echo
  echo "Escritorio:"
  echo "  compositor ....... $COMPOSITOR"
  echo "  shell ............ DankMaterialShell $(dms --version 2>/dev/null | head -1)"
  echo "  quickshell ....... $(qs --version 2>/dev/null | head -1)"
  echo "  matugen .......... $(matugen --version 2>/dev/null | head -1)"
  echo "  navegador ........ $(brave-browser --version 2>/dev/null | head -1)"
  echo "  idioma ........... $IDIOMA"
  echo "  autologin ........ $([[ $GREETER == si ]] && echo 'greetd + dms-greeter' || echo "SDDM -> sesion $COMPOSITOR")"
  echo "  kernel ........... $(uname -r)"
  echo "  apariencia ....... Arc-Dark + Papirus-Dark + cursor ${CURSOR_TEMA:-Adwaita}"
  echo "  fondo ............ $(cat "$HOME_USR/.config/matugen/fondo" 2>/dev/null || echo '(sin definir)')"
  echo "  paleta matugen ... $( [ -f "$HOME_USR/.config/hypr/colores.conf" ] && echo 'generada desde el fondo' || echo 'NO generada (revisa el log)' )"
  echo
  echo "Componentes: repos_extra=$MULTIREPOS  extras=$EXTRAS  kodi=$KODI  seguridad=$SEGURIDAD  wine=$WINE  liquorix=$LIQUORIX  brave=$BRAVE"
  echo
  echo "Avisos y errores registrados:"
  grep -E "^\[(AVISO|ERROR)\]" "$LOG" | tail -15 || echo "  (ninguno)"
  echo
  echo "Registro completo: $LOG"
} | tee "$REPORTE"
chown "$USUARIO":"$USUARIO" "$REPORTE" 2>/dev/null || true
log "Reporte guardado en $REPORTE"

header "INSTALACION COMPLETADA"
log "Todo instalado correctamente."
echo
warn "Reinicia para entrar al escritorio (el autologin ya queda configurado)."
echo
echo "  sudo reboot"
echo
cat <<EOF
${BOLD}Pendientes a mano (una sola vez):${NC}
 1) Reinicia:                sudo reboot
 2) Entra con la sesion "$COMPOSITOR" y abre los ajustes del shell:
       Super+C  ->  en dms: Settings -> Locale  (para el idioma del shell)
 3) Si pediste CJK: ibus-setup y añade tu metodo de entrada.
 4) Brave: primera vez pide importar perfil; ya es el navegador por defecto.
 5) Actualizaciones del escritorio (estan en backports):
       sudo apt update && sudo apt install -t trixie-backports $COMPOSITOR quickshell
 6) Logs del shell si algo falla:  journalctl --user -u dms -n 50   (o: dms run)

${YELLOW}Notas:${NC}
 - backports: prioridad $BACKPORTS_PRIO en /etc/apt/preferences.d/99-danklinux.pref
 - quickshell del OBS queda bloqueado (prioridad -1): se usa el de Debian, como pide su doc.
 - dvdstyler y clipgrab no existen en Debian 13 (sustitutos: devede / yt-dlp).
 - Este script no toca la BIOS ni el bootloader; si quieres el escritorio sin
   pantalla de acceso, arranca Hyprland con:  uwsm start hyprland.desktop
EOF
