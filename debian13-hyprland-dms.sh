#!/bin/bash
# ============================================================================
#  debian13-hyprland-dms.sh  v2.1
#  Debian 13 (Trixie) PURO -> escritorio estilo Omarchy: Hyprland (config Lua)
#  + Quickshell + DankMaterialShell (dms), Brave por defecto, tema oscuro,
#  idioma y teclado configurables e inicio directo al escritorio.
#
#  Uso:    sudo ./debian13-hyprland-dms.sh [opciones]     (sin opciones: menu)
#  Ayuda:  ./debian13-hyprland-dms.sh --ayuda
#  Repo:   https://github.com/Richiestone18/debian13-hyprland-dms
# ============================================================================
set -Eeuo pipefail
umask 022

VER="2.1"
RUN_TS="$(date +%Y%m%d-%H%M%S)"
LOG="/var/log/debian13-hyprland-dms-${RUN_TS}.log"
LOG_ACTIVO=""
TEE_PID=""
RESPALDO_SIS="/var/backups/debian13-hyprland-dms/${RUN_TS}"

RED=$'\e[0;31m'; GREEN=$'\e[0;32m'; YELLOW=$'\e[1;33m'; CYAN=$'\e[0;36m'; BOLD=$'\e[1m'; NC=$'\e[0m'

# ---- valores por defecto: TODO se instala (criterio de Ricardo) -------------
IDIOMA="es_MX.UTF-8"
TECLADO=""                 # vacio = el elegido al instalar Debian (/etc/default/keyboard)
TECLADO_VAR=""
USUARIO_ARG=""
LOGIN="greetd"             # greetd (ligero, entra solo al escritorio) | sddm
MULTIREPOS="si"; EXTRAS="si"; KODI="si"; SEGURIDAD="si"
WINE="si"; LIQUORIX="si"; BRAVE="si"
QSH_PRIO="500"             # quickshell: gana el mas nuevo; -1 = solo el de Debian
SECO="no"; SI="no"
SECCION="0. Comprobaciones previas"
AVISOS=(); NOTAS=(); RESPALDOS=()
NAVEGADOR=""; FONDO=""; HYPR_ESTADO="sin revisar"; DMS_ESTADO="sin revisar"

export DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none NEEDRESTART_MODE=a NEEDRESTART_SUSPEND=1
# dpkg nunca pregunta por archivos de configuracion y apt espera si otro apt tiene el candado
APT_OPTS=(-y -q -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold -o DPkg::Lock::Timeout=600)

log()    { echo "${GREEN}[OK]${NC} $*"; }
nota()   { echo "${CYAN}[NOTA]${NC} $*"; NOTAS+=("$*"); }
warn()   { echo "${YELLOW}[AVISO]${NC} $*"; AVISOS+=("$*"); }
err()    { echo "${RED}[ERROR]${NC} $*" >&2; }
header() {
  SECCION="$*"
  echo; echo "${CYAN}============================================================${NC}"
  echo "${CYAN}  $*${NC}"; echo "${CYAN}============================================================${NC}"
}
falla() {
  err "$*"
  if [[ -n "$LOG_ACTIVO" ]]; then echo "        Registro completo: $LOG" >&2; fi
  exit 1
}
al_fallar() {
  local rc=$? linea="$1" cmd="$2"
  trap - ERR
  echo
  err "Fallo en la seccion \"$SECCION\" (linea $linea, codigo $rc): $cmd"
  if [[ -n "$LOG_ACTIVO" ]]; then echo "        Registro completo: $LOG" >&2; fi
  echo "        Es seguro volver a ejecutar el script: retoma lo que falte." >&2
  exit "$rc"
}
trap 'al_fallar "$LINENO" "$BASH_COMMAND"' ERR

# /var/tmp (disco): en Debian 13 /tmp es memoria (tmpfs) y en equipos con poca RAM se llena
TMPD="$(mktemp -d /var/tmp/d13hdms.XXXXXX)"
chmod 755 "$TMPD"   # apt lee los .deb locales como el usuario _apt
export GNUPGHOME="$TMPD/gnupg"; mkdir -m 700 "$GNUPGHOME"
al_salir() {
  rm -rf "$TMPD"
  if [[ -n "$TEE_PID" ]]; then exec 1>&- 2>&-; wait "$TEE_PID" 2>/dev/null || true; fi
}
trap al_salir EXIT

texto_ayuda() {
cat <<'AYUDA'
debian13-hyprland-dms.sh v2.1 - Debian 13 + Hyprland + DankMaterialShell (estilo Omarchy)

Uso:  sudo ./debian13-hyprland-dms.sh [opciones]

Sin opciones aparece un MENU: marcas lo que quieres, eliges idioma y teclado,
ves el resumen y puedes volver atras. Al confirmar, todo sigue DESATENDIDO
hasta el final y termina con un reporte. Por tuberia (curl ... | sudo bash)
no hay menu: se instala todo lo de por defecto.

Por defecto lo instala TODO. Estas banderas sirven para OMITIR:
  --sin-repos-extra    sin MX Linux ni deb-multimedia
  --sin-extras         sin diseno y multimedia (Inkscape, Krita, GIMP, Blender, DVDStyler...)
  --sin-kodi           sin Kodi, RetroArch ni OpenRCT2
  --sin-seguridad      sin auditoria de redes (wifite, hashcat, wireshark...)
  --sin-wine           sin WineHQ (solo existe para PC amd64)
  --sin-liquorix       sin kernel Liquorix (solo amd64; se omite solo si hay Secure Boot)
  --sin-brave          sin Brave (el navegador sera Firefox ESR)

Otras opciones:
  --idioma CODIGO      idioma del sistema (defecto es_MX.UTF-8)
  --teclado DISTRIB    teclado (defecto: el que elegiste al instalar Debian, ej. latam)
  --usuario NOMBRE     usuario a configurar (defecto: quien ejecuta sudo)
  --sddm               pantalla de acceso grafica SDDM (defecto: greetd, mas ligero)
  --quickshell-debian  quickshell de Debian (defecto: gana la version mas nueva)
  --seco               solo revisa requisitos y muestra el plan; no cambia nada
  --si                 desatendido total: sin menu ni preguntas
  --ayuda              esta ayuda

Registro: /var/log/debian13-hyprland-dms.log    Reporte: ~/reporte-instalacion-*.txt
AYUDA
}

# ---- banderas ----------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --idioma)            IDIOMA="${2:?falta el codigo de idioma (ej. es_MX.UTF-8)}"; shift 2 ;;
    --teclado)           TECLADO="${2:?falta la distribucion de teclado (ej. latam, es, us)}"; shift 2 ;;
    --usuario)           USUARIO_ARG="${2:?falta el nombre de usuario}"; shift 2 ;;
    --sddm)              LOGIN="sddm"; shift ;;
    --sin-repos-extra)   MULTIREPOS="no"; shift ;;
    --sin-extras)        EXTRAS="no"; shift ;;
    --sin-kodi)          KODI="no"; shift ;;
    --sin-seguridad)     SEGURIDAD="no"; shift ;;
    --sin-wine)          WINE="no"; shift ;;
    --sin-liquorix)      LIQUORIX="no"; shift ;;
    --sin-brave)         BRAVE="no"; shift ;;
    --quickshell-debian) QSH_PRIO="-1"; shift ;;
    --seco)              SECO="si"; shift ;;
    --si|--yes|-y)       SI="si"; shift ;;
    --ayuda|-h|--help)   texto_ayuda; exit 0 ;;
    # compatibilidad con v2.0
    --extras|--kodi|--seguridad|--wine|--liquorix|--multimedia-repos) shift ;;
    --greeter)           echo "Aviso: --greeter (dms-greeter) se retiro en v2.1; se usa greetd con entrada automatica." >&2; shift ;;
    --compositor)
      if [[ "${2:-}" != hyprland ]]; then echo "Error: la v2.1 solo soporta --compositor hyprland" >&2; exit 2; fi
      shift 2 ;;
    *) echo "Opcion desconocida: $1  (usa --ayuda)" >&2; exit 2 ;;
  esac
done

# ============================================================================
# === FUNCIONES ===
# ============================================================================
onoff() { if [[ "$1" == si ]]; then echo ON; else echo OFF; fi; }

normalizar_idioma() {
  local l="${1// /}"
  if [[ "$l" != *.* ]]; then l="${l}.UTF-8"; fi
  case "$l" in *.utf8|*.utf-8|*.UTF8|*.Utf-8) l="${l%.*}.UTF-8" ;; esac
  printf '%s' "$l"
}
idioma_valido() {   # existe en la lista de glibc (si la lista esta instalada); sin modificadores @
  [[ "$1" =~ ^[A-Za-z]{2,3}(_[A-Z]{2})?\.UTF-8$ ]] || return 1
  if [[ -r /usr/share/i18n/SUPPORTED ]]; then grep -qx -- "$1 UTF-8" /usr/share/i18n/SUPPORTED; fi
}
teclado_por_idioma() {
  case "$1" in
    es_ES*) echo es ;; es_*) echo latam ;; en_GB*) echo gb ;; en_*) echo us ;;
    pt_BR*) echo br ;; pt_*) echo pt ;; fr_CA*) echo ca ;; fr_*) echo fr ;;
    de_*) echo de ;; it_*) echo it ;; ru_*) echo ru ;; ja_*) echo jp ;; ko_*) echo kr ;;
    *) echo us ;;
  esac
}
teclado_valido() {  # cada distribucion (separadas por coma) existe en xkb
  local lst=/usr/share/X11/xkb/rules/evdev.lst l
  [[ "$1" =~ ^[a-z0-9_,()-]+$ ]] || return 1
  [[ -r "$lst" ]] || return 0
  for l in ${1//,/ }; do
    awk -v l="$l" '/^! layout/{f=1;next} /^!/{f=0} f && $1==l {ok=1} END{exit !ok}' "$lst" || return 1
  done
}
secure_boot_activo() {
  local f
  for f in /sys/firmware/efi/efivars/SecureBoot-*; do
    [[ -r "$f" ]] || continue
    if [[ "$(od -An -t u1 -j4 -N1 "$f" 2>/dev/null | tr -d ' ')" == 1 ]]; then return 0; fi
  done
  return 1
}
en_bateria() {
  local ps bat=no ac=no
  for ps in /sys/class/power_supply/*; do
    [[ -r "$ps/type" ]] || continue
    case "$(cat "$ps/type")" in
      Battery) bat=si ;;
      Mains) if [[ "$(cat "$ps/online" 2>/dev/null)" == 1 ]]; then ac=si; fi ;;
    esac
  done
  [[ $bat == si && $ac == no ]]
}
descargar() {   # descargar <url> <destino>
  curl -fsSL --retry 3 --retry-delay 3 --connect-timeout 20 --max-time 900 -o "$2" "$1"
}
instalar_llave() {   # instalar_llave <url> <destino>: acepta llave armada o binaria
  local tmp="$TMPD/llave.$RANDOM"
  descargar "$1" "$tmp" || return 1
  if grep -q -- '-----BEGIN PGP' "$tmp"; then gpg --batch --yes --dearmor -o "$2" "$tmp" || return 1
  else install -m 0644 "$tmp" "$2" || return 1; fi
  chmod 0644 "$2"
}
ultimo_deb() {   # ultimo_deb <url_carpeta> <prefijo> <respaldo>: el .deb mas nuevo de un pool
  local ultimo
  ultimo="$(curl -fsSL --max-time 30 "$1" 2>/dev/null | grep -oE "${2}[A-Za-z0-9.+~-]*_all\.deb" | sort -uV | tail -1 || true)"
  printf '%s%s' "$1" "${ultimo:-$3}"
}
respaldar() {   # copia un archivo antes de cambiarlo (una vez por corrida)
  local f="$1" dst
  [[ -e "$f" || -L "$f" ]] || return 0
  if [[ "$f" == "$HOME_USR"/* ]]; then dst="$f.bak-$RUN_TS"; else dst="$RESPALDO_SIS$f"; fi
  [[ -e "$dst" || -L "$dst" ]] && return 0
  mkdir -p "$(dirname "$dst")"
  cp -a -- "$f" "$dst"
  RESPALDOS+=("$dst")
}
escribir_sistema() {   # escribir_sistema <archivo>  (contenido por stdin; respalda solo si cambia)
  mkdir -p "$(dirname "$1")"
  cat > "$TMPD/nuevo"
  if [[ -f "$1" && ! -L "$1" ]] && cmp -s "$TMPD/nuevo" "$1"; then return 0; fi
  respaldar "$1"
  rm -f "$1"
  cat "$TMPD/nuevo" > "$1"
}
como_usuario() {   # ejecuta como el usuario real, con su HOME y su PATH
  local rt="/run/user/$UID_USR" extra=()
  if [[ -d "$rt" ]]; then extra+=(XDG_RUNTIME_DIR="$rt"); fi
  if [[ -S "$rt/bus" ]]; then extra+=(DBUS_SESSION_BUS_ADDRESS="unix:path=$rt/bus"); fi
  runuser -u "$USUARIO" -- env HOME="$HOME_USR" USER="$USUARIO" LOGNAME="$USUARIO" \
    PATH="$HOME_USR/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" "${extra[@]}" "$@"
}
escribir_usuario() {   # escribir_usuario <archivo> [modo]  (contenido por stdin, dueno: el usuario)
  local f="$1" modo="${2:-644}"
  como_usuario mkdir -p -- "$(dirname -- "$f")"
  cat > "$TMPD/nuevo"
  if [[ -f "$f" && ! -L "$f" ]] && cmp -s "$TMPD/nuevo" "$f"; then return 0; fi
  respaldar "$f"
  rm -f -- "$f"
  cat "$TMPD/nuevo" > "$f"
  chown "$USUARIO:$USUARIO" "$f"
  chmod "$modo" "$f"
}
marca_v20() {   # el archivo lo genero la v2.0 de este script?
  [[ -f "$1" ]] && grep -qE "$2" "$1"
}
retirar() {   # respalda y quita un archivo
  respaldar "$1"
  rm -f -- "$1"
}

# ---- apt ----------------------------------------------------------------------
instalar() { apt-get "${APT_OPTS[@]}" install "$@"; }
reparar_dpkg() {   # deja dpkg/apt consistentes despues de un fallo
  local rotos
  dpkg --configure -a >/dev/null 2>&1 || true
  rotos="$(dpkg-query -W -f='${db:Status-Abbrev} ${binary:Package}\n' 2>/dev/null | awk '$1 !~ /^(ii|rc|un|pn)/ {print $2}' || true)"
  if [[ -n "$rotos" ]]; then
    warn "Paquetes que quedaron a medias y se quitan: $(echo "$rotos" | tr '\n' ' ')"
    # shellcheck disable=SC2086
    dpkg --purge --force-remove-reinstreq $rotos >/dev/null 2>&1 || true
  fi
  apt-get "${APT_OPTS[@]}" -f install >/dev/null 2>&1 || true
}
apti() {   # imprescindible: si falla dos veces, el script se detiene con un mensaje claro
  if instalar "$@"; then return 0; fi
  reparar_dpkg
  instalar "$@" || falla "No se pudo instalar algo imprescindible: $*"
}
filtrar_existentes() {   # imprime los paquetes que tienen version candidata
  local out
  out="$(apt-cache policy "$@" 2>/dev/null || true)"
  awk '/^[^ ].*:$/ {p=substr($0, 1, length($0)-1)} /^  Candidate:/ { if ($2 != "(none)") print p }' <<< "$out"
}
apti_try() {   # instala lo que exista; lo que falte o falle se avisa y se salta. NUNCA aborta.
  local opts=() p
  while [[ "${1:-}" == -* ]]; do opts+=("$1"); shift; done
  local -a existen=() faltan=()
  local -A hay=()
  mapfile -t existen < <(filtrar_existentes "$@")
  for p in "${existen[@]}"; do hay["$p"]=1; done
  for p in "$@"; do if [[ -z "${hay[$p]:-}" ]]; then faltan+=("$p"); fi; done
  if (( ${#faltan[@]} )); then warn "No estan en los repos (se saltan): ${faltan[*]}"; fi
  if (( ${#existen[@]} == 0 )); then return 0; fi
  if instalar "${opts[@]}" "${existen[@]}"; then return 0; fi
  warn "Fallo la instalacion en grupo; reintento paquete por paquete"
  reparar_dpkg
  for p in "${existen[@]}"; do
    if ! instalar "${opts[@]}" "$p"; then warn "No se pudo instalar: $p (se salta)"; reparar_dpkg; fi
  done
  return 0
}
instalado() { [[ "$(dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null)" == ii* ]]; }
version_de() {
  if instalado "$1"; then dpkg-query -W -f='${Version}' "$1"; else echo "(no instalado)"; fi
}

# --- INICIO MODULO FUENTES ---
APT_DIR="${APT_DIR:-/etc/apt}"
TERCEROS_RE='(mxrepo|deb-multimedia|opensuse|brave|liquorix|winehq)'
SUITE_DEBIAN_RE='^(trixie|stable)(-updates|-security|-backports)?$'

archivos_fuentes() {   # todas las listas de fuentes que existan
  local f
  for f in "$APT_DIR/sources.list" "$APT_DIR"/sources.list.d/*.list "$APT_DIR"/sources.list.d/*.sources; do
    if [[ -f "$f" ]]; then printf '%s\n' "$f"; fi
  done
}
fuentes_apt() {   # "uri suite firma componentes..." de cada fuente deb ACTIVA (clasico y deb822)
  local f
  while read -r f; do
    case "$f" in
      *.sources)
        awk 'BEGIN { RS = "" } {
          n = split($0, L, "\n"); t = ""; u = ""; s = ""; c = ""; k = "-"; e = "yes"
          for (i = 1; i <= n; i++) {
            if (L[i] ~ /^#/) continue
            v = L[i]; sub(/^[^:]*:[ \t]*/, "", v)
            if (L[i] ~ /^Types:/) t = v
            else if (L[i] ~ /^URIs:/) u = v
            else if (L[i] ~ /^Suites:/) s = v
            else if (L[i] ~ /^Components:/) c = v
            else if (L[i] ~ /^Signed-By:/) k = (v == "" ? "bloque" : v)
            else if (L[i] ~ /^Enabled:/) e = tolower(v)
          }
          if (t !~ /(^|[ \t])deb([ \t]|$)/ || e == "no") next
          nu = split(u, U, /[ \t]+/); ns = split(s, S, /[ \t]+/)
          for (a = 1; a <= nu; a++) for (b = 1; b <= ns; b++) print U[a], S[b], k, c
        }' "$f" ;;
      *)
        awk '/^[ \t]*deb[ \t]/ {
          l = $0; sub(/^[ \t]*deb[ \t]+/, "", l); k = "-"
          if (l ~ /^\[/) {
            o = substr(l, 2, index(l, "]") - 2); l = substr(l, index(l, "]") + 1); sub(/^[ \t]+/, "", l)
            if (match(o, /signed-by=[^ \t]+/)) k = substr(o, RSTART + 10, RLENGTH - 10)
          }
          split(l, P, /[ \t]+/); c = l; sub(/^[^ \t]+[ \t]+[^ \t]+[ \t]*/, "", c)
          print P[1], P[2], k, c
        }' "$f" ;;
    esac
  done < <(archivos_fuentes)
}
es_de_debian() {   # $1 uri  $2 firma: Debian oficial o espejo (sin llave propia de un tercero)
  [[ "$1" == *debian* && ! "$1" =~ $TERCEROS_RE && "$1" != cdrom:* ]] || return 1
  [[ "$2" == "-" || "$2" == *debian-archive-keyring* ]]
}
hay_fuente_debian() {   # $1 = regex de suite (ej. '^(trixie|stable)$')
  local uri suite firma
  while read -r uri suite firma _; do
    if [[ "$suite" =~ $1 ]] && es_de_debian "$uri" "$firma"; then return 0; fi
  done < <(fuentes_apt)
  return 1
}
desactivar_cdrom() {   # comenta las fuentes cdrom: (sin el disco puesto rompen apt update)
  local f cambio=1
  while read -r f; do
    [[ "$f" == *.sources ]] && continue
    if grep -qE '^[[:space:]]*deb(-src)?[[:space:]]+cdrom:' "$f"; then
      respaldar "$f"
      sed -i -E 's/^([[:space:]]*deb(-src)?[[:space:]]+cdrom:)/# \1/' "$f"
      cambio=0
    fi
  done < <(archivos_fuentes)
  return $cambio
}
completar_componentes() {   # Debian oficial: main contrib non-free non-free-firmware. 0 = cambio algo
  local f tmp="$TMPD/fuente.tmp" cambio=1
  while read -r f; do
    case "$f" in
      *.sources)
        awk -v re="$TERCEROS_RE" -v sre="$SUITE_DEBIAN_RE" 'BEGIN { RS = ""; ORS = "\n\n" } {
          n = split($0, L, "\n"); u = ""; s = ""; k = "-"
          for (i = 1; i <= n; i++) {
            if (L[i] ~ /^URIs:/) u = L[i]
            if (L[i] ~ /^Suites:/) s = L[i]
            if (L[i] ~ /^Signed-By:/) k = L[i]
          }
          sub(/^Suites:[ \t]*/, "", s); ok = 0; m = split(s, S, /[ \t]+/)
          for (j = 1; j <= m; j++) if (S[j] ~ sre) ok = 1
          if (ok && u ~ /debian/ && u !~ re && (k == "-" || k ~ /debian-archive-keyring/ || k ~ /^Signed-By:[ \t]*$/))
            for (i = 1; i <= n; i++)
              if (L[i] ~ /^Components:/ && L[i] ~ /[ \t]main([ \t]|$)/) L[i] = "Components: main contrib non-free non-free-firmware"
          o = L[1]; for (i = 2; i <= n; i++) o = o "\n" L[i]
          print o
        }' "$f" > "$tmp" ;;
      *)
        awk -v re="$TERCEROS_RE" -v sre="$SUITE_DEBIAN_RE" '{
          if ($0 ~ /^[ \t]*deb(-src)?[ \t]/) {
            l = $0; ind = l; sub(/[^ \t].*$/, "", ind); sub(/^[ \t]+/, "", l)
            tipo = l; sub(/[ \t].*$/, "", tipo); l = substr(l, length(tipo) + 1); sub(/^[ \t]+/, "", l)
            op = ""; k = "-"
            if (l ~ /^\[/) {
              op = substr(l, 1, index(l, "]")); l = substr(l, index(l, "]") + 1); sub(/^[ \t]+/, "", l)
              if (match(op, /signed-by=[^] \t]+/)) k = substr(op, RSTART + 10, RLENGTH - 10)
              op = op " "
            }
            n = split(l, P, /[ \t]+/)
            if (n >= 3 && P[2] ~ sre && P[1] ~ /debian/ && P[1] !~ re && P[1] !~ /^cdrom:/ && \
                (k == "-" || k ~ /debian-archive-keyring/) && (" " l " ") ~ /[ \t]main[ \t]/)
              $0 = ind tipo " " op P[1] " " P[2] " main contrib non-free non-free-firmware"
          }
          print
        }' "$f" > "$tmp" ;;
    esac
    if [[ "$f" == *.sources ]]; then   # el modo parrafo de awk agrega un salto final: normalizar
      sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$tmp"
    fi
    if ! diff -qB "$f" "$tmp" >/dev/null; then
      respaldar "$f"
      cat "$tmp" > "$f"
      cambio=0
    fi
  done < <(archivos_fuentes)
  return $cambio
}
# --- FIN MODULO FUENTES ---

adoptar_repo() {   # adoptar_repo <regex de la URI> <archivo propio>: una sola definicion por repo
  # si otra lista ya define el mismo repo con otra llave (la v2.0, la guia oficial de DMS o de
  # Brave), apt se niega a leer TODAS las fuentes: "Conflicting values set for option Signed-By"
  local re="$1" propio="$2" f
  while read -r f; do
    [[ "$f" == "$propio" ]] && continue
    case "$f" in
      *.sources)
        if grep -qE "^URIs:.*${re}" "$f"; then retirar "$f"; nota "Fuente duplicada retirada: $f"; fi ;;
      *)
        if grep -qE "^[[:space:]]*deb(-src)?[[:space:]].*${re}" "$f"; then
          respaldar "$f"
          sed -i -E "\\#^[[:space:]]*deb(-src)?[[:space:]].*${re}#s/^/# (duplicada, la maneja debian13-hyprland-dms) /" "$f"
          nota "Fuente duplicada desactivada en $f"
        fi ;;
    esac
  done < <(archivos_fuentes)
}

espacio_critico() {   # imprime los puntos de montaje con menos de 100 MB libres
  df -P -k / /var /tmp 2>/dev/null | awk 'NR > 1 && $4 < 102400 && !v[$6]++ {printf "%s (%d MB libres) ", $6, $4 / 1024}'
}
apt_update() {   # apt update que desactiva un repo OPCIONAL caido en vez de abortar
  local salida="$TMPD/apt-update.txt" intento host f quitados=no lleno
  for intento in 1 2; do
    if apt-get update > "$salida" 2>&1; then cat "$salida"; return 0; fi
    cat "$salida" 2>/dev/null || true
    lleno="$(espacio_critico)"
    if [[ -n "$lleno" ]] || grep -qs 'No space left on device' "$salida"; then
      falla "Sin espacio libre: ${lleno:-revisa df -h}. Libera espacio y vuelve a ejecutar el script."
    fi
    warn "apt update fallo (intento $intento)"
    sleep 8
  done
  # si tambien fallan los repos de Debian, el problema es general (red, fecha y hora, proxy):
  # no se culpa a un repo de terceros
  if grep -E '^(Err:[0-9]+|E:)' "$salida" | grep -vE "$TERCEROS_RE" | grep -q 'debian'; then
    falla "apt update falla tambien con los repos de Debian: revisa la red, la fecha y hora del equipo y el proxy (detalle en el registro)."
  fi
  while read -r host; do
    case "$host" in
      *mxrepo.com*)         f=/etc/apt/sources.list.d/mx.sources ;;
      *deb-multimedia.org*) f=/etc/apt/sources.list.d/dmo.sources ;;
      *brave*)              f=/etc/apt/sources.list.d/brave-browser-release.sources ;;
      *liquorix.net*)       f=/etc/apt/sources.list.d/liquorix.list ;;
      *winehq.org*)         f=/etc/apt/sources.list.d/winehq-trixie.sources ;;
      *) continue ;;
    esac
    if [[ -e "$f" ]]; then
      mkdir -p "$RESPALDO_SIS"
      mv -f "$f" "$RESPALDO_SIS/$(basename "$f").desactivado"
      warn "Repo con errores desactivado: $host (se guardo en $RESPALDO_SIS)"
      quitados=si
    fi
  done < <(grep -E '^(Err|E):' "$salida" | grep -oE 'https?://[^/ ]+' | sort -u || true)
  if [[ $quitados == si ]] && apt-get update; then return 0; fi
  falla "apt update sigue fallando: revisa la red o las fuentes de Debian/OBS (detalle en el registro)."
}

resumen_texto() {
  echo "Resumen de la instalacion (v$VER):"
  echo "  Usuario ........ $USUARIO"
  echo "  Escritorio ..... Hyprland (config Lua) + Quickshell + DankMaterialShell"
  if [[ $LOGIN == sddm ]]; then echo "  Inicio ......... SDDM, entrando directo al escritorio"
  else echo "  Inicio ......... greetd, entrando directo al escritorio (ligero)"; fi
  echo "  Idioma ......... $IDIOMA    Teclado: ${TECLADO}${TECLADO_VAR:+ ($TECLADO_VAR)}"
  if [[ $BRAVE == si ]]; then echo "  Navegador ...... Brave (repo oficial, por defecto)"
  else echo "  Navegador ...... Firefox ESR"; fi
  echo "  Repos extra .... $MULTIREPOS   (MX Linux + deb-multimedia, al principio)"
  echo "  Programas ...... extras=$EXTRAS  kodi=$KODI  seguridad=$SEGURIDAD"
  echo "  Otros .......... wine=$WINE  liquorix=$LIQUORIX  (equipo: $ARQ)"
  echo "  Politica ....... gana la version MAS NUEVA de todos los repos"
  echo "  Disco libre .... ${LIBRE_GB} GB en /  (se recomiendan 15 GB o mas)"
}

# ---- menu interactivo ---------------------------------------------------------
aplicar_seleccion() {   # $1 = un elemento marcado por linea (whiptail --separate-output)
  local sel="$1"
  marcado() { if grep -qx -- "$1" <<< "$sel"; then echo si; else echo no; fi; }
  MULTIREPOS="$(marcado repos_extra)"; EXTRAS="$(marcado extras)"; KODI="$(marcado kodi)"
  SEGURIDAD="$(marcado seguridad)"; BRAVE="$(marcado brave)"
  if [[ $ARQ == amd64 ]]; then WINE="$(marcado wine)"; fi
  if [[ $ARQ == amd64 && $SB == no ]]; then LIQUORIX="$(marcado liquorix)"; fi
  if [[ "$(marcado sddm)" == si ]]; then LOGIN=sddm; else LOGIN=greetd; fi
}
menu_interactivo() {
  local sel idioma tecl items
  if ! command -v whiptail >/dev/null 2>&1; then menu_texto; return; fi
  while true; do
    items=(repos_extra "MX Linux + deb-multimedia (codecs, firmware completo)" "$(onoff "$MULTIREPOS")"
           extras      "Diseno y multimedia (Inkscape, Krita, GIMP, Blender, DVDStyler...)" "$(onoff "$EXTRAS")"
           kodi        "Kodi + RetroArch + OpenRCT2" "$(onoff "$KODI")"
           seguridad   "Auditoria de redes (wifite, hashcat, wireshark...)" "$(onoff "$SEGURIDAD")")
    if [[ $ARQ == amd64 ]]; then items+=(wine "Wine (repo oficial WineHQ)" "$(onoff "$WINE")"); fi
    if [[ $ARQ == amd64 && $SB == no ]]; then items+=(liquorix "Kernel Liquorix (baja latencia)" "$(onoff "$LIQUORIX")"); fi
    items+=(brave "Brave (repo oficial) como navegador por defecto" "$(onoff "$BRAVE")"
            sddm  "Pantalla de acceso grafica SDDM (si no: greetd, mas ligero)" "$(if [[ $LOGIN == sddm ]]; then echo ON; else echo OFF; fi)")
    sel=$(whiptail --title "Debian 13 estilo Omarchy v$VER - componentes" --separate-output --checklist \
      "ESPACIO marca o desmarca, TAB cambia a los botones, ENTER acepta" 20 86 $(( ${#items[@]} / 3 )) \
      "${items[@]}" 3>&1 1>&2 2>&3) || return 1
    aplicar_seleccion "$sel"
    while true; do
      idioma=$(whiptail --title "Idioma del sistema" --inputbox \
        "Codigo de idioma (ej: es_MX.UTF-8, es_ES.UTF-8, en_US.UTF-8, pt_BR.UTF-8)" 10 72 "$IDIOMA" 3>&1 1>&2 2>&3) || return 1
      idioma="$(normalizar_idioma "$idioma")"
      if idioma_valido "$idioma"; then IDIOMA="$idioma"; break; fi
      whiptail --title "Idioma no valido" --msgbox "\"$idioma\" no existe. Usa un codigo como es_MX.UTF-8" 8 66
    done
    while true; do
      tecl=$(whiptail --title "Teclado" --inputbox \
        "Distribucion de teclado (latam, es, us, br...). Detectada: ${TECLADO}" 10 72 "$TECLADO" 3>&1 1>&2 2>&3) || return 1
      if [[ -z "$tecl" ]]; then break; fi
      if teclado_valido "$tecl"; then
        if [[ "$tecl" != "$TECLADO" ]]; then TECLADO_VAR=""; fi
        TECLADO="$tecl"; break
      fi
      whiptail --title "Teclado no valido" --msgbox "\"$tecl\" no existe. Prueba con latam, es o us" 8 66
    done
    if whiptail --title "Confirmar" --yesno \
      "$(resumen_texto)\n\nEmpezar la instalacion DESATENDIDA con esta seleccion?\n(No = volver al menu para cambiar algo)" 24 86; then
      return 0
    fi
  done
}
menu_texto() {   # respaldo sin whiptail
  resp() {
    local r
    read -rp "$1 [$(if [[ $2 == si ]]; then echo S/n; else echo s/N; fi)] " r || r=""
    r="${r:-$2}"; r="${r,,}"
    if [[ "$r" =~ ^(s|si|sí|y|yes)$ ]]; then echo si; else echo no; fi
  }
  echo "${BOLD}Seleccion de componentes (Enter = valor entre corchetes)${NC}"
  MULTIREPOS="$(resp 'MX Linux + deb-multimedia?' "$MULTIREPOS")"
  EXTRAS="$(resp 'Diseno y multimedia?' "$EXTRAS")"
  KODI="$(resp 'Kodi + RetroArch?' "$KODI")"
  SEGURIDAD="$(resp 'Auditoria de redes?' "$SEGURIDAD")"
  if [[ $ARQ == amd64 ]]; then WINE="$(resp 'Wine?' "$WINE")"; fi
  if [[ $ARQ == amd64 && $SB == no ]]; then LIQUORIX="$(resp 'Kernel Liquorix?' "$LIQUORIX")"; fi
  BRAVE="$(resp 'Brave por defecto?' "$BRAVE")"
  if [[ "$(resp 'SDDM grafico en vez de greetd?' no)" == si ]]; then LOGIN=sddm; fi
  local r
  read -rp "Idioma [$IDIOMA]: " r || r=""
  if [[ -n "$r" ]]; then
    r="$(normalizar_idioma "$r")"
    if idioma_valido "$r"; then IDIOMA="$r"; else echo "Idioma no valido; sigo con $IDIOMA"; fi
  fi
  read -rp "Teclado [$TECLADO]: " r || r=""
  if [[ -n "$r" ]]; then
    if teclado_valido "$r"; then TECLADO="$r"; TECLADO_VAR=""; else echo "Teclado no valido; sigo con $TECLADO"; fi
  fi
  echo; resumen_texto
  read -rp "Empezar la instalacion desatendida? [s/N] " r || r=""
  [[ "${r,,}" =~ ^(s|si|sí|y|yes)$ ]]
}

iniciar_log() {
  mkdir -p /var/log
  : > "$LOG"; chmod 640 "$LOG"
  ln -sfn "$LOG" /var/log/debian13-hyprland-dms.log
  exec > >(tee >(sed -u 's/\x1b\[[0-9;]*m//g' >> "$LOG")) 2>&1
  TEE_PID=$!
  LOG_ACTIVO=si
}
# === FIN FUNCIONES ===

# ============================================================================
header "0. Comprobaciones previas  (v$VER)"
# ============================================================================
[[ $EUID -eq 0 ]] || falla "Ejecuta como root:  sudo $0"
USUARIO="${USUARIO_ARG:-${SUDO_USER:-}}"
if [[ -z "$USUARIO" || "$USUARIO" == root ]]; then USUARIO="$(logname 2>/dev/null || true)"; fi
if [[ -z "$USUARIO" || "$USUARIO" == root ]]; then
  # como root directo (su -): si hay un solo usuario normal, es el
  mapfile -t CANDIDATOS < <(awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ {print $1}' /etc/passwd)
  if (( ${#CANDIDATOS[@]} == 1 )); then USUARIO="${CANDIDATOS[0]}"; fi
fi
if [[ -z "$USUARIO" || "$USUARIO" == root ]]; then
  falla "No pude detectar tu usuario normal. Usa:  sudo $0   o   $0 --usuario TU_USUARIO"
fi
getent passwd "$USUARIO" >/dev/null || falla "El usuario $USUARIO no existe"
HOME_USR="$(getent passwd "$USUARIO" | cut -d: -f6)"
UID_USR="$(id -u "$USUARIO")"
[[ -n "$HOME_USR" && -d "$HOME_USR" ]] || falla "No existe la carpeta personal de $USUARIO"
CFG="$HOME_USR/.config"
log "Usuario: $USUARIO  (home: $HOME_USR)"

# shellcheck source=/dev/null
. /etc/os-release
[[ "${VERSION_CODENAME:-}" == trixie ]] || falla "Este script es para Debian 13 (trixie). Detectado: ${PRETTY_NAME:-desconocido}"
ARQ="$(dpkg --print-architecture)"
case "$ARQ" in
  amd64) log "Debian 13 (trixie) en amd64" ;;
  arm64)
    log "Debian 13 (trixie) en arm64 (ARM)"
    if [[ $WINE == si ]]; then WINE="no"; nota "ARM: WineHQ no existe para arm64; se omite"; fi
    if [[ $LIQUORIX == si ]]; then LIQUORIX="no"; nota "ARM: el kernel Liquorix es solo para PC (amd64); se omite"; fi ;;
  *) falla "Arquitectura no soportada: $ARQ (solo amd64 o arm64)" ;;
esac
SB="no"
if secure_boot_activo; then SB="si"; fi
if [[ $SB == si && $LIQUORIX == si ]]; then
  LIQUORIX="no"
  warn "Secure Boot activo: Liquorix no esta firmado y no arrancaria; se omite (desactiva Secure Boot y repite si lo quieres)"
fi

if command -v curl >/dev/null 2>&1; then
  curl -fsS -o /dev/null --max-time 25 https://deb.debian.org/debian/dists/trixie/Release \
    || falla "Sin conexion a internet: no llego a deb.debian.org por HTTPS"
else
  getent hosts deb.debian.org >/dev/null || falla "Sin conexion a internet: no resuelvo deb.debian.org"
fi
log "Internet OK"

LIBRE_GB="$(df -BG --output=avail / | tail -1 | tr -dc '0-9')"
if (( LIBRE_GB < 10 )); then falla "Solo hay ${LIBRE_GB} GB libres en /. La instalacion completa necesita unos 15 GB."; fi
if (( LIBRE_GB < 15 )); then warn "Hay ${LIBRE_GB} GB libres en /: puede quedar justo (se recomiendan 15 GB)"; fi
if en_bateria; then warn "El equipo esta con bateria: conecta el cargador (la instalacion tarda)"; fi

if [[ -z "$TECLADO" && -r /etc/default/keyboard ]]; then
  # shellcheck source=/dev/null
  TECLADO="$(. /etc/default/keyboard; echo "${XKBLAYOUT:-}")"
  # shellcheck source=/dev/null
  TECLADO_VAR="$(. /etc/default/keyboard; echo "${XKBVARIANT:-}")"
fi
if [[ -z "$TECLADO" ]]; then TECLADO="$(teclado_por_idioma "$IDIOMA")"; fi
IDIOMA="$(normalizar_idioma "$IDIOMA")"
idioma_valido "$IDIOMA" || falla "Idioma no valido: $IDIOMA (ejemplos: es_MX.UTF-8, es_ES.UTF-8, en_US.UTF-8)"
teclado_valido "$TECLADO" || falla "Distribucion de teclado no valida: $TECLADO (ejemplos: latam, es, us)"
[[ "$TECLADO_VAR" =~ ^[a-z0-9_,-]*$ ]] || TECLADO_VAR=""

if [[ $SECO == si ]]; then
  echo; resumen_texto; echo
  log "Modo seco: los requisitos se cumplen. NO se modifico nada."
  echo "  Quita --seco para instalar."
  exit 0
fi

if [[ $SI == si ]]; then
  resumen_texto
  log "Modo desatendido (--si): sin preguntas."
elif [[ -t 0 && -t 1 ]]; then
  echo "${BOLD}Menu de instalacion${NC}  (--si = desatendido | --ayuda = banderas)"
  [[ -n "${TERM:-}" ]] || export TERM=xterm
  menu_interactivo || { echo "Cancelado. No se cambio nada."; exit 0; }
else
  resumen_texto
  warn "Sin terminal interactiva (curl | sudo bash): se instala todo lo de por defecto (equivale a --si)"
fi

iniciar_log
echo "debian13-hyprland-dms.sh v$VER  -  $(date '+%F %T')  -  usuario $USUARIO  -  $ARQ"
resumen_texto
if (( ${#AVISOS[@]} )); then printf '[AVISO] %s\n' "${AVISOS[@]}"; fi
log "Seleccion confirmada. Desde aqui TODO es desatendido. Registro: $LOG"

# ============================================================================
header "1. Fuentes de software y repositorios (llave firmada + pinning)"
# ============================================================================
install -d -m 0755 /etc/apt/keyrings /etc/apt/sources.list.d /etc/apt/preferences.d

# --- 1.0 Una sola definicion por cada repo que maneja este script (antes de usar apt) ---
D=/etc/apt/sources.list.d
if [[ $MULTIREPOS == si ]]; then
  adoptar_repo 'mxrepo\.com' "$D/mx.sources"
  adoptar_repo 'deb-multimedia\.org' "$D/dmo.sources"
fi
adoptar_repo 'AvengeMedia:/?danklinux' "$D/avengemedia-danklinux.sources"
adoptar_repo 'AvengeMedia:/?dms/' "$D/avengemedia-dms.sources"
if [[ $BRAVE == si ]]; then adoptar_repo 'brave-browser-apt-release' "$D/brave-browser-release.sources"; fi
if [[ $LIQUORIX == si ]]; then adoptar_repo 'liquorix\.net' "$D/liquorix.list"; fi
if [[ $WINE == si ]]; then adoptar_repo 'dl\.winehq\.org' "$D/winehq-trixie.sources"; fi

# --- 1.0b Fuentes oficiales de Debian sanas -------------------------------
if desactivar_cdrom; then log "Fuente cdrom desactivada (sin el disco puesto rompe apt update)"; fi
if ! hay_fuente_debian '^(trixie|stable)$'; then
  escribir_sistema /etc/apt/sources.list.d/debian.sources <<'EOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
  log "No habia fuentes de red de Debian: creadas en /etc/apt/sources.list.d/debian.sources"
fi
# firmware y codecs viven en contrib, non-free y non-free-firmware
if completar_componentes; then log "Fuentes de Debian completadas con contrib, non-free y non-free-firmware"; fi
# aqui solo hace falta Debian: un repo de terceros roto (p.ej. de una corrida anterior)
# se reescribe mas abajo y se vuelve a comprobar con apt_update
if ! apt-get update; then nota "apt update inicial con errores en algun repo de terceros: se rehacen a continuacion"; fi
# gpgv: lo exigen las llaves de MX y deb-multimedia (Debian 13 ya no lo trae: apt usa sqv)
apti curl ca-certificates gnupg gpgv

# --- 1.1 MX Linux + deb-multimedia: VAN PRIMERO (codecs y firmware completos) ---
if [[ $MULTIREPOS == si ]]; then
  URL="$(ultimo_deb https://mxrepo.com/mx/repo/pool/main/m/mx25-archive-keyring/ mx25-archive-keyring_ mx25-archive-keyring_2025.03_all.deb)"
  if descargar "$URL" "$TMPD/mx-llave.deb" && instalar "$TMPD/mx-llave.deb" && [[ -s /usr/share/keyrings/mx-25-archive-keyring.gpg ]]; then
    escribir_sistema /etc/apt/sources.list.d/mx.sources <<'EOF'
Types: deb
URIs: https://mxrepo.com/mx/repo/
Suites: trixie
Components: main non-free ahs
Signed-By: /usr/share/keyrings/mx-25-archive-keyring.gpg
EOF
    log "Repo de MX Linux agregado ($(basename "$URL"))"
  else
    rm -f /etc/apt/sources.list.d/mx.sources
    warn "No pude instalar la llave de MX Linux: el repo de MX se omite"
  fi
  URL="$(ultimo_deb https://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/ deb-multimedia-keyring_ deb-multimedia-keyring_2024.9.1_all.deb)"
  if descargar "$URL" "$TMPD/dmo-llave.deb" && instalar "$TMPD/dmo-llave.deb" && [[ -s /usr/share/keyrings/deb-multimedia-keyring.pgp ]]; then
    escribir_sistema /etc/apt/sources.list.d/dmo.sources <<'EOF'
Types: deb
URIs: https://www.deb-multimedia.org
Suites: trixie
Components: main non-free
Signed-By: /usr/share/keyrings/deb-multimedia-keyring.pgp

Types: deb
URIs: https://www.deb-multimedia.org
Suites: trixie-backports
Components: main
Signed-By: /usr/share/keyrings/deb-multimedia-keyring.pgp
EOF
    log "Repo de deb-multimedia agregado ($(basename "$URL"))"
  else
    rm -f /etc/apt/sources.list.d/dmo.sources
    warn "No pude instalar la llave de deb-multimedia: ese repo se omite"
  fi
else
  nota "MX Linux y deb-multimedia desactivados (--sin-repos-extra)"
fi

# --- 1.2 Backports OFICIALES de Debian (de aqui salen Hyprland y sus piezas) ---
if hay_fuente_debian '^(trixie|stable)-backports$'; then
  log "Backports de Debian ya presentes"
else
  escribir_sistema /etc/apt/sources.list.d/debian-backports.sources <<'EOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
  log "Backports de Debian agregados"
fi

# --- 1.3 OBS de AvengeMedia (DankMaterialShell, matugen, ghostty...) --------
# restos de la v2.0: los mismos repos en formato viejo (la llave avengemedia-dms.gpg
# se reutiliza con el mismo nombre: NO se borra)
for F in /etc/apt/sources.list.d/danklinux.list /etc/apt/sources.list.d/avengemedia-dms.list \
         /etc/apt/keyrings/danklinux.gpg; do
  if [[ -e "$F" ]]; then retirar "$F"; fi
done
for REPO in danklinux dms; do
  BASE="https://download.opensuse.org/repositories/home:/AvengeMedia:/${REPO}/Debian_13/"
  instalar_llave "${BASE}Release.key" "/etc/apt/keyrings/avengemedia-${REPO}.gpg" \
    || falla "No pude bajar la llave del OBS ($REPO). Sin ella no hay DankMaterialShell."
  escribir_sistema "/etc/apt/sources.list.d/avengemedia-${REPO}.sources" <<EOF
Types: deb
URIs: ${BASE}
Suites: /
Signed-By: /etc/apt/keyrings/avengemedia-${REPO}.gpg
EOF
done
log "Repos del OBS de AvengeMedia listos (danklinux + dms)"

# --- 1.4 Brave (repositorio oficial) -------------------------------------------
if [[ $BRAVE == si ]]; then
  if instalar_llave https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
       /usr/share/keyrings/brave-browser-archive-keyring.gpg; then
    if [[ -e /etc/apt/sources.list.d/brave-browser-release.list ]]; then retirar /etc/apt/sources.list.d/brave-browser-release.list; fi
    escribir_sistema /etc/apt/sources.list.d/brave-browser-release.sources <<'EOF'
Types: deb
URIs: https://brave-browser-apt-release.s3.brave.com/
Suites: stable
Components: main
Architectures: amd64 arm64
Signed-By: /usr/share/keyrings/brave-browser-archive-keyring.gpg
EOF
    log "Repo oficial de Brave listo"
  else
    BRAVE="no"; warn "No pude bajar la llave de Brave: se instalara Firefox ESR"
  fi
fi

# --- 1.5 Liquorix (solo amd64; mismos nombres que su instalador oficial) -------
if [[ $LIQUORIX == si ]]; then
  if instalar_llave https://liquorix.net/liquorix-keyring.gpg /etc/apt/keyrings/liquorix-keyring.gpg; then
    escribir_sistema /etc/apt/sources.list.d/liquorix.list <<'EOF'
deb [arch=amd64 signed-by=/etc/apt/keyrings/liquorix-keyring.gpg] https://liquorix.net/debian trixie main
EOF
    if [[ -e /etc/apt/keyrings/liquorix.gpg ]]; then retirar /etc/apt/keyrings/liquorix.gpg; fi
    log "Repo de Liquorix listo"
  else
    LIQUORIX="no"; warn "No pude bajar la llave de Liquorix: se omite"
  fi
fi

# --- 1.6 WineHQ (solo amd64, con i386) -----------------------------------------
if [[ $WINE == si ]]; then
  if instalar_llave https://dl.winehq.org/wine-builds/winehq.key /etc/apt/keyrings/winehq-archive.key; then
    escribir_sistema /etc/apt/sources.list.d/winehq-trixie.sources <<'EOF'
Types: deb
URIs: https://dl.winehq.org/wine-builds/debian
Suites: trixie
Components: main
Architectures: amd64 i386
Signed-By: /etc/apt/keyrings/winehq-archive.key
EOF
    dpkg --add-architecture i386
    log "Repo de WineHQ listo (arquitectura i386 agregada)"
  else
    WINE="no"; warn "No pude bajar la llave de WineHQ: Wine se omite"
  fi
fi

# --- 1.7 Pinning: gana la version MAS NUEVA de cualquier repo -------------------
escribir_sistema /etc/apt/preferences.d/99-danklinux.pref <<EOF
# Generado por debian13-hyprland-dms.sh v$VER
# Politica (criterio de Ricardo): todos los repos a 500 = gana la version MAS NUEVA.
# Backports: se usa el codename (n=); en Debian 13 su "archive" es stable-backports,
# asi que "a=trixie-backports" NO coincidiria y backports se quedaria en 100.

Package: quickshell
Pin: origin download.opensuse.org
Pin-Priority: $QSH_PRIO

Package: *
Pin: origin download.opensuse.org
Pin-Priority: 500

Package: *
Pin: release n=trixie-backports
Pin-Priority: 500

Package: *
Pin: origin mxrepo.com
Pin-Priority: 500

Package: *
Pin: origin www.deb-multimedia.org
Pin-Priority: 500

Package: *
Pin: origin brave-browser-apt-release.s3.brave.com
Pin-Priority: 500

Package: *
Pin: origin dl.winehq.org
Pin-Priority: 500

Package: *
Pin: origin liquorix.net
Pin-Priority: 500
EOF
log "Pinning escrito en /etc/apt/preferences.d/99-danklinux.pref"

# --- 1.8 Respuestas para paquetes que preguntan -----------------------------
debconf-set-selections <<'EOF'
wireshark-common wireshark-common/install-setuid boolean true
macchanger macchanger/automatically_run boolean false
EOF

apt_update
if ! apt-get "${APT_OPTS[@]}" dist-upgrade; then
  reparar_dpkg
  apt-get "${APT_OPTS[@]}" dist-upgrade || warn "La actualizacion inicial (dist-upgrade) tuvo errores; sigo"
fi
log "Sistema al dia con todos los repos"

# ============================================================================
header "2. Base del sistema: firmware, utilidades, fuentes y temas"
# ============================================================================
FIRMWARE=(firmware-linux-nonfree firmware-misc-nonfree firmware-realtek firmware-amd-graphics
  firmware-ath9k-htc firmware-atheros firmware-b43-installer firmware-b43legacy-installer
  firmware-bnx2 firmware-bnx2x firmware-brcm80211 firmware-intel-sound firmware-iwlwifi
  firmware-libertas firmware-myricom firmware-netronome firmware-qlogic firmware-samsung
  firmware-siano firmware-sof-signed firmware-ti-connectivity firmware-zd1211 firmware-ast
  firmware-cavium firmware-mediatek firmware-marvell-prestera firmware-nvidia-gsp)
if [[ $ARQ == amd64 ]]; then FIRMWARE+=(amd64-microcode intel-microcode); fi
apti_try "${FIRMWARE[@]}"
log "Firmware procesado"

apti_try sudo git curl wget rsync htop btop net-tools gdebi unzip zip p7zip-full build-essential \
  pkg-config cmake python3 python3-pip pipx xdg-utils xdg-user-dirs jq yq man-db \
  bash-completion acl dconf-cli
apti_try ripgrep fzf bat eza zoxide fd-find tree ncdu duf fastfetch gum alacritty kitty neovim \
  vim tmux lazygit git-delta wl-clipboard cliphist grim slurp swappy brightnessctl playerctl \
  pavucontrol network-manager network-manager-gnome blueman
apti_try fonts-noto fonts-noto-color-emoji fonts-noto-cjk fonts-jetbrains-mono fonts-font-awesome \
  fonts-materialdesignicons-webfont fonts-firacode fonts-inter papirus-icon-theme arc-theme \
  bibata-cursor-theme adwaita-icon-theme gnome-themes-extra
log "Utilidades, fuentes, temas, iconos y cursor procesados"

# Material Symbols: la fuente de iconos de DankMaterialShell
install -d -m 0755 /usr/share/fonts/truetype/material-symbols
for V in Rounded Outlined; do
  if descargar "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbols${V}%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" \
       "/usr/share/fonts/truetype/material-symbols/MaterialSymbols${V}.ttf"; then
    log "Fuente Material Symbols $V instalada"
  else
    warn "No pude bajar Material Symbols $V (algunos iconos de DMS saldrian vacios)"
  fi
done
fc-cache -f >/dev/null 2>&1 || true

# ============================================================================
header "3. Audio: PipeWire + WirePlumber"
# ============================================================================
apti_try pipewire pipewire-alsa pipewire-audio pipewire-bin pipewire-pulse pipewire-jack \
  pipewire-v4l2 wireplumber libspa-0.2-bluetooth libspa-0.2-jack libspa-0.2-modules qpwgraph
if instalado pipewire-pulse; then log "PipeWire listo ($(version_de pipewire))"; else warn "PipeWire no quedo instalado"; fi

# ============================================================================
header "4. Idioma ($IDIOMA) y teclado ($TECLADO)"
# ============================================================================
apti_try locales
if ! idioma_valido "$IDIOMA"; then warn "El idioma $IDIOMA no existe; uso es_MX.UTF-8"; IDIOMA="es_MX.UTF-8"; fi
LANG_BASE="${IDIOMA%%.*}"; LANG_ISO="${LANG_BASE%%_*}"
IDIOMA_RE="${IDIOMA//./\\.}"
if grep -qE "^#[[:space:]]*${IDIOMA_RE} UTF-8" /etc/locale.gen; then
  sed -i -E "s/^#[[:space:]]*(${IDIOMA_RE} UTF-8)/\1/" /etc/locale.gen
elif ! grep -qE "^${IDIOMA_RE} UTF-8" /etc/locale.gen; then
  echo "$IDIOMA UTF-8" >> /etc/locale.gen
fi
locale-gen
update-locale "LANG=$IDIOMA" "LANGUAGE=${LANG_BASE}:${LANG_ISO}"
log "Idioma $IDIOMA generado y fijado (vale desde el proximo inicio de sesion)"

mapfile -t DICC < <(filtrar_existentes "hunspell-${LANG_ISO}" "hunspell-$(tr '[:upper:]_' '[:lower:]-' <<< "$LANG_BASE")")
if (( ${#DICC[@]} )); then apti_try "${DICC[@]}"; fi
case "$LANG_ISO" in
  ja) apti_try ibus ibus-mozc mozc-utils-gui ;;
  ko) apti_try ibus ibus-hangul ;;
  zh) apti_try ibus ibus-libpinyin ibus-chewing ;;
esac

# teclado de la consola y de greetd: el mismo que tendra Hyprland
if [[ -f /etc/default/keyboard ]]; then
  # shellcheck source=/dev/null
  TEC_ACTUAL="$(. /etc/default/keyboard; echo "${XKBLAYOUT:-}|${XKBVARIANT:-}")"
  if [[ "$TEC_ACTUAL" != "$TECLADO|$TECLADO_VAR" ]]; then
    respaldar /etc/default/keyboard
    sed -i -E -e "s/^XKBLAYOUT=.*/XKBLAYOUT=\"$TECLADO\"/" -e "s/^XKBVARIANT=.*/XKBVARIANT=\"$TECLADO_VAR\"/" /etc/default/keyboard
    log "Teclado del sistema cambiado a $TECLADO (consola y pantalla de acceso)"
  fi
fi
nota "DankMaterialShell trae sus propias traducciones (incluye espanol): se elige en Ajustes de DMS -> Idioma. Brave, GTK, Qt y las carpetas personales siguen el idioma del sistema."

# ============================================================================
header "5. Escritorio: Hyprland + Quickshell + DankMaterialShell"
# ============================================================================
apti hyprland quickshell dms
apti_try hyprland-guiutils xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-desktop-portal \
  matugen hyprland-backgrounds hyprpicker xwayland ghostty dgop danksearch dankcalendar dux-files \
  cava upower power-profiles-daemon gnome-keyring libpam-gnome-keyring qt6-wayland qt6-svg-plugins \
  qt6-gtk-platformtheme qt5-gtk-platformtheme nautilus desktop-file-utils shared-mime-info \
  mesa-utils mesa-vulkan-drivers vulkan-tools libgl1-mesa-dri
if [[ $BRAVE == si ]]; then apti_try brave-browser; fi
if ! instalado brave-browser; then
  BRAVE="no"
  apti_try firefox-esr
  mapfile -t FFL10N < <(filtrar_existentes "firefox-esr-l10n-$(tr '[:upper:]_' '[:lower:]-' <<< "$LANG_BASE")" "firefox-esr-l10n-${LANG_ISO}")
  if (( ${#FFL10N[@]} )); then apti_try "${FFL10N[0]}"; fi
fi
log "Hyprland $(version_de hyprland), DMS $(version_de dms), Quickshell $(version_de quickshell)"

# --- Inicio de sesion: directo al escritorio ---------------------------------
SESION_CMD="/usr/bin/start-hyprland"
[[ -x "$SESION_CMD" ]] || SESION_CMD="/usr/bin/Hyprland"
if [[ $LOGIN == sddm ]]; then
  echo "sddm shared/default-x-display-manager select sddm" | debconf-set-selections
  apti sddm
  escribir_sistema /etc/sddm.conf.d/10-debian13-hyprland-dms.conf <<EOF
# Generado por debian13-hyprland-dms.sh v$VER: entra directo al escritorio
[Autologin]
User=$USUARIO
Session=hyprland.desktop
Relogin=false
EOF
  if [[ -e /etc/sddm.conf.d/01-autologin.conf ]]; then retirar /etc/sddm.conf.d/01-autologin.conf; fi
else
  apti greetd
  if ! getent passwd _greetd >/dev/null; then warn "No existe el usuario _greetd que crea el paquete greetd"; fi
  escribir_sistema /etc/greetd/config.toml <<EOF
# Generado por debian13-hyprland-dms.sh v$VER
# Al encender entra solo al escritorio ([initial_session]). Si cierras sesion
# aparece el acceso de texto de greetd (agreety); al entrar vuelve Hyprland.
[terminal]
vt = 7

[default_session]
command = "/usr/sbin/agreety --cmd $SESION_CMD"
user = "_greetd"

[initial_session]
command = "$SESION_CMD"
user = "$USUARIO"
EOF
fi
for DM in gdm3 lightdm sddm greetd lxdm xdm slim nodm; do
  if [[ $DM != "$LOGIN" ]]; then systemctl disable "$DM" >/dev/null 2>&1 || true; fi
done
systemctl enable "$LOGIN" || warn "No pude habilitar $LOGIN (revisalo con: systemctl status $LOGIN)"
systemctl set-default graphical.target >/dev/null 2>&1 || true
log "Inicio de sesion: $LOGIN, entrando directo como $USUARIO"

# ============================================================================
header "6. Herramientas: Docker, gh, lazydocker, mise, tte y Flatpak"
# ============================================================================
apti_try docker.io docker-compose gh flatpak
if getent group docker >/dev/null; then usermod -aG docker "$USUARIO"; fi
# instaladores web como el usuario, trabajando en disco (no en /tmp, que en Debian 13 es RAM:
# el de mise extrae ~200 MB) y en una carpeta suya (el de lazydocker descarga en la actual)
TMPU="$TMPD/usuario"; install -d -o "$USUARIO" -g "$USUARIO" -m 0700 "$TMPU"
instalador_web() {   # instalador_web <nombre> <binario que debe quedar> <comando>
  local nombre="$1" bin="$2" cmd="$3"
  if timeout 900 runuser -u "$USUARIO" -- env HOME="$HOME_USR" USER="$USUARIO" TMPDIR="$TMPU" \
       PATH="$HOME_USR/.local/bin:/usr/local/bin:/usr/bin:/bin" \
       bash -c "set -o pipefail; cd \"\$TMPDIR\" && $cmd" > "$TMPD/$nombre.txt" 2>&1 \
     && [[ -x "$HOME_USR/.local/bin/$bin" ]]; then
    log "$nombre instalado"
  else
    warn "$nombre no se pudo instalar (opcional): $(tail -2 "$TMPD/$nombre.txt" 2>/dev/null | tr '\n' ' ')"
  fi
}
instalador_web lazydocker lazydocker 'curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash'
instalador_web mise mise 'curl -fsSL https://mise.run | sh'
instalador_web tte tte 'pipx install --force terminaltexteffects'
if command -v flatpak >/dev/null; then
  if TMPDIR="$TMPD" flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo > "$TMPD/flathub.txt" 2>&1; then
    log "Flathub agregado"
  else
    warn "No pude agregar Flathub (opcional): $(tail -1 "$TMPD/flathub.txt" | tr '\n' ' ')"
  fi
fi

# ============================================================================
header "7. Programas opcionales"
# ============================================================================
if [[ $MULTIREPOS == si ]]; then apti_try libdvdcss2; fi
if [[ $EXTRAS == si ]]; then
  EXT=(inkscape krita krita-l10n gimp gimp-data-extras scribus scribus-template darktable
       openshot-qt audacity simplescreenrecorder guvcview amule filezilla qbittorrent blender
       yt-dlp devede)
  # DVDStyler y ClipGrab no estan en Debian, pero si en MX Linux
  if [[ $MULTIREPOS == si ]]; then EXT+=(dvdstyler clipgrab); fi
  apti_try "${EXT[@]}"
  log "Diseno y multimedia procesados"
fi
if [[ $KODI == si ]]; then
  apti_try kodi kodi-audiodecoder-modplug kodi-audiodecoder-openmpt kodi-audioencoder-flac \
    kodi-audioencoder-lame kodi-audioencoder-vorbis kodi-inputstream-adaptive \
    kodi-inputstream-ffmpegdirect kodi-inputstream-rtmp kodi-peripheral-joystick \
    kodi-pvr-iptvsimple kodi-vfs-libarchive kodi-vfs-rar kodi-vfs-sftp retroarch openrct2
  log "Kodi, RetroArch y OpenRCT2 procesados"
fi
if [[ $SEGURIDAD == si ]]; then
  apti_try wifite bully hashcat hcxdumptool hcxtools wireshark macchanger aircrack-ng
  if getent group wireshark >/dev/null; then usermod -aG wireshark "$USUARIO"; fi
  log "Auditoria de redes procesada ($USUARIO puede capturar con Wireshark sin root)"
fi
if [[ $WINE == si ]]; then
  if instalar --install-recommends winehq-stable; then log "Wine $(version_de winehq-stable) instalado"
  else reparar_dpkg; warn "winehq-stable no se pudo instalar"; fi
fi
if [[ $LIQUORIX == si ]]; then
  apti_try linux-image-liquorix-amd64 linux-headers-liquorix-amd64
  if instalado linux-image-liquorix-amd64; then log "Kernel Liquorix instalado (arranca por defecto tras reiniciar)"; fi
fi

# ============================================================================
header "8. Configuracion del usuario ($USUARIO)"
# ============================================================================
# 8.1 Carpetas de usuario sanas (la v2.0 podia dejar ~/.config y otras como root)
for D in .config .local .local/bin .local/share .local/state .cache; do
  if [[ ! -d "$HOME_USR/$D" ]]; then install -d -o "$USUARIO" -g "$USUARIO" -m 0755 "$HOME_USR/$D"; fi
done
ARREGLADOS="$(find "$CFG" "$HOME_USR/.local" "$HOME_USR/Pictures" -xdev -user root -print -exec chown -h "$USUARIO:$USUARIO" {} + 2>/dev/null | wc -l || true)"
if (( ARREGLADOS > 0 )); then warn "Se devolvieron a $USUARIO $ARREGLADOS archivos/carpetas que eran de root (restos de una version anterior)"; fi
como_usuario env LANG="$IDIOMA" xdg-user-dirs-update >/dev/null 2>&1 || true
IMAGENES="$(como_usuario env LANG="$IDIOMA" xdg-user-dir PICTURES 2>/dev/null || true)"
if [[ -z "$IMAGENES" || "$IMAGENES" == "$HOME_USR" ]]; then IMAGENES="$HOME_USR/Pictures"; fi
FONDOS="$IMAGENES/Fondos"
ESTADO="$CFG/debian13-hyprland-dms"
como_usuario mkdir -p "$FONDOS" "$ESTADO" "$HOME_USR/.local/state/debian13-hyprland-dms"
log "Carpetas personales en $IDIOMA (imagenes: $IMAGENES)"

# 8.2 Restos de la v2.0 que chocan con DMS (se respaldan junto al original).
#     Cada archivo con la marca que SOLO tenia la version 2.0.
HY="$CFG/hypr"
while IFS='|' read -r F MARCA; do
  if marca_v20 "$CFG/$F" "$MARCA"; then retirar "$CFG/$F"; fi
done <<'EOF'
hypr/hyprland.conf|Generado por debian13-hyprland-dms
hypr/hyprpaper.conf|fondo-actual
hypr/hyprlock.conf|fondo-actual
hypr/colores.conf|.
ghostty/config|matugen\.conf
kitty/kitty.conf|matugen\.conf
environment.d/10-dank.conf|.
gtk-3.0/gtk.css|^@import url\("matugen\.css"\);$
gtk-4.0/gtk.css|^@import url\("matugen\.css"\);$
EOF
if marca_v20 "$HOME_USR/.local/bin/tema-desde-fondo" 'matugen image'; then retirar "$HOME_USR/.local/bin/tema-desde-fondo"; fi
if [[ -d "$CFG/matugen" ]] && marca_v20 "$CFG/matugen/config.toml" 'templates\.hyprland'; then
  respaldar "$CFG/matugen"; rm -rf -- "$CFG/matugen"
fi

# 8.3 Fondos de pantalla de Hyprland (paquete hyprland-backgrounds)
while read -r W; do
  if [[ -f "$W" ]]; then install -o "$USUARIO" -g "$USUARIO" -m 0644 "$W" "$FONDOS/hyprland-$(basename "$W")"; fi
done < <(dpkg -L hyprland-backgrounds 2>/dev/null | grep -E '\.(png|jpe?g)$' || true)
for W in "$FONDOS"/*.png "$FONDOS"/*.jpg; do
  if [[ -f "$W" ]]; then FONDO="$W"; break; fi
done
if [[ -n "$FONDO" ]]; then
  escribir_usuario "$ESTADO/fondo" <<< "$FONDO"
  log "Fondos en $FONDOS (inicial: $(basename "$FONDO"))"
else
  warn "No encontre fondos de Hyprland: elige uno en DMS (Super+Y)"
fi

# 8.4 Navegador por defecto
if [[ $BRAVE == si ]] && instalado brave-browser; then NAVEGADOR=brave-browser; NAV_DESKTOP=brave-browser.desktop
elif instalado firefox-esr; then NAVEGADOR=firefox-esr; NAV_DESKTOP=firefox-esr.desktop
else NAVEGADOR=""; NAV_DESKTOP=""; warn "No quedo ningun navegador instalado"; fi
if [[ -n "$NAVEGADOR" ]]; then
  for ALT in x-www-browser gnome-www-browser; do
    update-alternatives --install "/usr/bin/$ALT" "$ALT" "/usr/bin/$NAVEGADOR" 250 >/dev/null
    update-alternatives --set "$ALT" "/usr/bin/$NAVEGADOR" >/dev/null
  done
  escribir_usuario "$CFG/mimeapps.list" <<EOF
[Default Applications]
text/html=$NAV_DESKTOP
application/xhtml+xml=$NAV_DESKTOP
x-scheme-handler/http=$NAV_DESKTOP
x-scheme-handler/https=$NAV_DESKTOP
x-scheme-handler/about=$NAV_DESKTOP
x-scheme-handler/unknown=$NAV_DESKTOP
EOF
  log "Navegador por defecto: $NAVEGADOR"
fi
ARCHIVOS="nautilus"
if ! instalado nautilus; then ARCHIVOS="dux-files"; fi

# 8.5 Hyprland + DankMaterialShell con la configuracion OFICIAL de DMS
#     (dms setup headless: hyprland.lua + ~/.config/hypr/dms/*.lua + arranque por systemd)
SETUP=(dms setup headless --compositor hyprland --terminal ghostty --skip-existing)
if como_usuario "${SETUP[@]}" > "$TMPD/dms-setup.txt" 2>&1; then
  DMS_ESTADO="configurado (dms setup)"
elif como_usuario "${SETUP[@]}" --no-systemd > "$TMPD/dms-setup.txt" 2>&1; then
  DMS_ESTADO="configurado (dms setup, sin systemd)"
else
  DMS_ESTADO="ERROR en dms setup"
  warn "dms setup fallo: $(tail -3 "$TMPD/dms-setup.txt" | tr '\n' ' ')"
fi
sed 's/^/    dms: /' "$TMPD/dms-setup.txt" | tail -25
if [[ ! -f "$HY/hyprland.lua" ]]; then
  falla "No quedo ~/.config/hypr/hyprland.lua (dms setup). Detalle arriba y en el registro."
fi
# teclado: es la base de hyprland.lua; los Ajustes de DMS (dms/input.lua) siguen mandando
if grep -qE '^[[:space:]]*kb_layout[[:space:]]*=' "$HY/hyprland.lua"; then
  sed -i -E "0,/^([[:space:]]*kb_layout[[:space:]]*=[[:space:]]*)\"[^\"]*\"/s//\1\"$TECLADO\"/" "$HY/hyprland.lua"
  if [[ -n "$TECLADO_VAR" ]] && ! grep -qE '^[[:space:]]*kb_variant[[:space:]]*=' "$HY/hyprland.lua"; then
    sed -i -E "0,/^([[:space:]]*)kb_layout([[:space:]]*=.*)$/s//&\n\1kb_variant = \"$TECLADO_VAR\",/" "$HY/hyprland.lua"
  fi
  log "Teclado de Hyprland: $TECLADO${TECLADO_VAR:+ ($TECLADO_VAR)}"
else
  warn "No encontre kb_layout en hyprland.lua: elige el teclado en Ajustes de DMS"
fi
# cursor Bibata como base (dms/cursor.lua se carga despues: lo que elijas en DMS manda)
if ! grep -q 'XCURSOR_THEME' "$HY/hyprland.lua" && grep -qE '^require\("dms\.colors"\)' "$HY/hyprland.lua"; then
  sed -i -E '0,/^require\("dms\.colors"\)/s//hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")\nhl.env("XCURSOR_SIZE", "24")\n&/' "$HY/hyprland.lua"
fi
# lo propio de esta instalacion va en un archivo aparte que se carga al final
escribir_usuario "$HY/debian13.lua" < <(sed -e "s|@@NAVEGADOR@@|${NAVEGADOR:-xdg-open}|" -e "s|@@ARCHIVOS@@|$ARCHIVOS|" <<'LUA'
-- ~/.config/hypr/debian13.lua  -  generado por debian13-hyprland-dms.sh v2.1
-- Extras estilo Omarchy sobre la configuracion oficial de DankMaterialShell.
-- Los atajos de DMS (Super+Espacio, Super+Enter, volumen, brillo...) estan en
-- dms/binds.lua; los tuyos van en dms/binds-user.lua o aqui.

local browser = "@@NAVEGADOR@@"
local files   = "@@ARCHIVOS@@"

hl.env("BROWSER", browser)
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_QPA_PLATFORMTHEME_QT6", "gtk3")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.bind("SUPER + B", hl.dsp.exec_cmd(browser))
hl.bind("SUPER + E", hl.dsp.exec_cmd(files))
hl.bind("SUPER + C", hl.dsp.exec_cmd("dms ipc call settings focusOrToggle"))
-- (Impr, Ctrl+Impr y Alt+Impr para capturas ya vienen en dms/binds.lua)

-- primer inicio: fondo de pantalla (DMS saca de el los colores) y bienvenida
hl.on("hyprland.start", function()
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/primer-inicio-dms")
end)
LUA
)
if ! grep -qE '^[[:space:]]*require\("debian13"\)' "$HY/hyprland.lua"; then
  printf '\n-- extras de debian13-hyprland-dms.sh\nrequire("debian13")\n' >> "$HY/hyprland.lua"
fi
chown "$USUARIO:$USUARIO" "$HY/hyprland.lua"

# 8.6 Validar con el propio Hyprland
VRT="$TMPD/xdg-runtime"; install -d -m 0700 -o "$USUARIO" -g "$USUARIO" "$VRT"
if runuser -u "$USUARIO" -- env HOME="$HOME_USR" XDG_RUNTIME_DIR="$VRT" PATH="/usr/bin:/bin" \
     Hyprland --verify-config --config "$HY/hyprland.lua" > "$TMPD/verify.txt" 2>&1; then
  HYPR_ESTADO="valida (Hyprland --verify-config)"
  log "hyprland.lua validado por el propio Hyprland"
else
  HYPR_ESTADO="CON ERRORES (ver registro)"
  warn "Hyprland reporta errores en su configuracion: $(grep -iE 'error|fail' "$TMPD/verify.txt" | head -5 | tr '\n' ' ')"
  sed 's/^/    hyprland: /' "$TMPD/verify.txt" | tail -20
fi

# 8.7 Apariencia: GTK oscuro, iconos Papirus, cursor Bibata y fuente Inter
escribir_usuario "$CFG/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-font-name=Inter 11
gtk-application-prefer-dark-theme=1
EOF
escribir_usuario "$CFG/gtk-4.0/settings.ini" <<'EOF'
[Settings]
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-font-name=Inter 11
EOF
# valores por defecto del sistema en dconf (no necesita la sesion grafica abierta)
install -d -m 0755 /etc/dconf/profile /etc/dconf/db/local.d
if [[ ! -f /etc/dconf/profile/user ]]; then
  escribir_sistema /etc/dconf/profile/user <<'EOF'
user-db:user
system-db:local
EOF
elif ! grep -qs '^system-db:local' /etc/dconf/profile/user; then
  respaldar /etc/dconf/profile/user
  echo 'system-db:local' >> /etc/dconf/profile/user
fi
escribir_sistema /etc/dconf/db/local.d/00-debian13-hyprland-dms <<'EOF'
[org/gnome/desktop/interface]
color-scheme='prefer-dark'
gtk-theme='Arc-Dark'
icon-theme='Papirus-Dark'
cursor-theme='Bibata-Modern-Classic'
cursor-size=24
font-name='Inter 11'
document-font-name='Inter 11'
monospace-font-name='JetBrains Mono 11'

[org/gnome/desktop/wm/preferences]
titlebar-font='Inter Bold 11'
EOF
if command -v dconf >/dev/null; then dconf update || warn "dconf update fallo"; fi
if [[ -d /usr/share/icons/Bibata-Modern-Classic ]]; then
  escribir_usuario "$HOME_USR/.icons/default/index.theme" <<'EOF'
[Icon Theme]
Inherits=Bibata-Modern-Classic
EOF
fi
escribir_usuario "$CFG/environment.d/10-debian13-hyprland-dms.conf" <<EOF
QT_QPA_PLATFORMTHEME=gtk3
QT_QPA_PLATFORMTHEME_QT6=gtk3
BROWSER=${NAVEGADOR:-xdg-open}
EOF
log "Apariencia: Arc-Dark + Papirus-Dark + cursor Bibata + fuente Inter (modo oscuro)"

# 8.8 Terminales con los colores que DMS saca del fondo
if [[ ! -f "$CFG/ghostty/config" ]]; then
  escribir_usuario "$CFG/ghostty/config" <<'EOF'
# Colores: los genera DankMaterialShell desde el fondo
theme = dankcolors
font-family = JetBrains Mono
font-size = 11
app-notifications = no-clipboard-copy,no-config-reload
EOF
fi
if [[ ! -f "$CFG/kitty/kitty.conf" ]]; then
  escribir_usuario "$CFG/kitty/kitty.conf" <<'EOF'
# Colores de DankMaterialShell
include dank-tabs.conf
include dank-theme.conf
font_family JetBrains Mono
font_size 11
EOF
fi

# 8.9 Ayudantes: primer inicio, "tema desde un fondo" y llavero
escribir_usuario "$HOME_USR/.local/bin/primer-inicio-dms" 755 <<'EOF'
#!/bin/bash
# Se ejecuta al iniciar Hyprland; solo actua la primera vez: pone el fondo en DMS
# (que saca los colores de el) y da la bienvenida.
MARCA="$HOME/.local/state/debian13-hyprland-dms/primer-inicio"
[[ -e "$MARCA" ]] && exit 0
FONDO="$(cat "$HOME/.config/debian13-hyprland-dms/fondo" 2>/dev/null)"
for _ in $(seq 1 90); do
  if dms ipc call wallpaper get >/dev/null 2>&1; then
    if [[ -f "$FONDO" ]]; then dms ipc call wallpaper set "$FONDO" >/dev/null 2>&1; fi
    dms ipc call toast info "Bienvenido: Super+Espacio abre el menu, Super+Enter la terminal" >/dev/null 2>&1
    mkdir -p "$(dirname "$MARCA")" && date > "$MARCA"
    exit 0
  fi
  sleep 1
done
EOF
escribir_usuario "$HOME_USR/.local/bin/tema-desde-fondo" 755 <<'EOF'
#!/bin/bash
# Uso: tema-desde-fondo /ruta/imagen
# Pone la imagen de fondo en DankMaterialShell, que recalcula los colores de todo
# (barra, bordes, GTK, Qt y terminales). Tambien se puede con Super+Y.
set -e
IMG="$(readlink -f "${1:?uso: tema-desde-fondo /ruta/imagen}")"
[[ -f "$IMG" ]] || { echo "no existe: $IMG" >&2; exit 1; }
mkdir -p "$HOME/.config/debian13-hyprland-dms"
printf '%s\n' "$IMG" > "$HOME/.config/debian13-hyprland-dms/fondo"
dms ipc call wallpaper set "$IMG"
echo "Listo: fondo y colores actualizados."
EOF
# llavero sin contrasena (como Omarchy): con la entrada automatica no hay contrasena
# que lo desbloquee y Brave pediria una en cada inicio
KR="$HOME_USR/.local/share/keyrings"
if [[ ! -d "$KR" || -z "$(ls -A "$KR" 2>/dev/null)" ]]; then
  escribir_usuario "$KR/Default_keyring.keyring" 600 < <(printf '[keyring]\ndisplay-name=Default keyring\nctime=%s\nmtime=0\nlock-on-idle=false\nlock-after=false\n' "$(date +%s)")
  escribir_usuario "$KR/default" 644 <<< "Default_keyring"
  chmod 700 "$KR"
  log "Llavero por defecto sin contrasena (para la entrada automatica)"
fi
if [[ -x "$HOME_USR/.local/bin/mise" ]] && ! grep -qs 'mise activate bash' "$HOME_USR/.bashrc"; then
  # shellcheck disable=SC2016
  printf '\n# mise (gestor de versiones, como en Omarchy)\neval "$(~/.local/bin/mise activate bash)"\n' >> "$HOME_USR/.bashrc"
  chown "$USUARIO:$USUARIO" "$HOME_USR/.bashrc"
fi
log "Configuracion de $USUARIO lista (DMS, Hyprland, apariencia, terminales, navegador y ayudantes)"

# ============================================================================
header "9. Red: que NetworkManager la administre (WiFi y red desde DMS)"
# ============================================================================
# Debian instalado sin escritorio deja la red en /etc/network/interfaces (ifupdown) y
# NetworkManager ignora esas interfaces: DMS no podria cambiar de WiFi. Se pasan a
# NetworkManager; la conexion actual no se corta (el cambio vale al reiniciar).
IFZ=/etc/network/interfaces
if instalado network-manager && [[ -f "$IFZ" ]]; then
  mapfile -t IFACES < <(awk '$1=="iface" && $2!="lo" {print $2}' "$IFZ" | sort -u)
  if (( ${#IFACES[@]} == 0 )); then
    log "Nada que migrar: NetworkManager ya administra la red"
  elif grep -qE '^[[:space:]]*iface[[:space:]]+[^[:space:]]+[[:space:]]+inet6?[[:space:]]+(static|manual)' "$IFZ" \
       || grep -qE '^[[:space:]]*(wpa-conf|wpa-roam|bridge_ports|bond-|vlan-raw-device|pre-up|post-up|up[[:space:]])' "$IFZ"; then
    warn "La red usa IP fija u opciones especiales en $IFZ: no la toco (para manejarla desde DMS, configurala con nmcli)"
  else
    respaldar "$IFZ"
    WIFI_OK=si
    while IFS=$'\x1f' read -r IFACE SSID PSK; do
      [[ -n "$SSID" ]] || continue
      NOMBRE="${SSID//[^A-Za-z0-9._-]/_}"
      if nmcli --offline connection add type wifi con-name "$SSID" ssid "$SSID" \
           wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PSK" > "$TMPD/wifi.nmconnection" 2>/dev/null; then
        install -m 600 "$TMPD/wifi.nmconnection" "/etc/NetworkManager/system-connections/$NOMBRE.nmconnection"
        log "WiFi \"$SSID\" ($IFACE) pasa a NetworkManager"
      else
        WIFI_OK=no
        warn "No pude convertir el WiFi \"$SSID\" ($IFACE): la red se queda como estaba"
      fi
    done < <(awk '$1=="iface"{i=$2} $1=="wpa-ssid"{v=$0; sub(/^[ \t]*wpa-ssid[ \t]+/,"",v); gsub(/^"|"$/,"",v); s[i]=v}
                  $1=="wpa-psk"{v=$0; sub(/^[ \t]*wpa-psk[ \t]+/,"",v); gsub(/^"|"$/,"",v); p[i]=v}
                  END{for (k in s) printf "%s\037%s\037%s\n", k, s[k], p[k]}' "$IFZ")
    if [[ $WIFI_OK == si ]]; then
      escribir_sistema "$IFZ" <<'EOF'
# Generado por debian13-hyprland-dms.sh: la red la administra NetworkManager
# (respaldo del archivo anterior en /var/backups/debian13-hyprland-dms/)
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback
EOF
      log "Interfaces ${IFACES[*]} pasan a NetworkManager al reiniciar (la conexion actual sigue igual)"
    fi
  fi
fi

# ============================================================================
header "10. Ultima pasada: lo mas nuevo de todos los repos y limpieza"
# ============================================================================
apt_update
if ! apt-get "${APT_OPTS[@]}" full-upgrade; then reparar_dpkg; warn "full-upgrade final con errores; revisa el registro"; fi
apt-get "${APT_OPTS[@]}" autoremove || true
apt-get -q autoclean || true

# ============================================================================
header "11. Verificacion final"
# ============================================================================
v() { printf '  %-30s %s\n' "$1" "$2"; }
DUENO_CFG="$(stat -c %U "$CFG" 2>/dev/null || echo '?')"
ROTOS="$(dpkg --audit 2>/dev/null | head -3 || true)"
{
  v "Hyprland"                 "$(version_de hyprland)"
  v "DankMaterialShell (dms)"  "$(version_de dms)"
  v "Quickshell"               "$(version_de quickshell)"
  v "matugen"                  "$(version_de matugen)"
  v "Configuracion de DMS"     "$DMS_ESTADO"
  v "Config de Hyprland (Lua)" "$HYPR_ESTADO"
  v "Navegador por defecto"    "${NAVEGADOR:-ninguno}"
  v "Inicio de sesion"         "$LOGIN ($(systemctl is-enabled "$LOGIN" 2>/dev/null || echo '?'))"
  v "Idioma del sistema"       "$(grep -E '^LANG=' /etc/default/locale 2>/dev/null | cut -d= -f2 || echo '?')"
  v "Teclado"                  "${TECLADO}${TECLADO_VAR:+ ($TECLADO_VAR)}"
  v "Dueno de ~/.config"       "$DUENO_CFG"
  v "PipeWire"                 "$(version_de pipewire)"
  v "Kernels instalados"       "$(find /boot -maxdepth 1 -name 'vmlinuz-*' -printf '%f ' 2>/dev/null | sed 's/vmlinuz-//g')"
  v "dpkg (paquetes a medias)" "$(if [[ -z "$ROTOS" ]]; then echo ninguno; else echo "HAY: revisa dpkg --audit"; fi)"
} | tee "$TMPD/verificacion.txt"
if [[ "$DUENO_CFG" != "$USUARIO" ]]; then warn "$CFG no es de $USUARIO"; fi
if [[ -n "$ROTOS" ]]; then warn "dpkg reporta paquetes a medias: ejecuta sudo dpkg --configure -a"; fi
for P in hyprland dms quickshell; do instalado "$P" || warn "Falta $P"; done

# ============================================================================
header "REPORTE DE LA INSTALACION"
# ============================================================================
REPORTE="$HOME_USR/reporte-instalacion-${RUN_TS}.txt"
{
  echo "Debian 13 + Hyprland + Quickshell + DankMaterialShell  (script v$VER)"
  echo "Fecha: $(date '+%Y-%m-%d %H:%M')    Equipo: $ARQ    Usuario: $USUARIO"
  echo
  resumen_texto
  echo
  echo "Verificacion:"
  cat "$TMPD/verificacion.txt"
  echo
  echo "Paquetes instalados: $(dpkg-query -W -f='${db:Status-Abbrev}\n' 2>/dev/null | grep -c '^ii' || true)"
  echo "Espacio usado en /:  $(df -h / | awk 'NR==2{print $3" de "$2" ("$5")"}')"
  echo "Repositorios:        $(find /etc/apt/sources.list.d -maxdepth 1 \( -name '*.list' -o -name '*.sources' \) -printf '%f ' 2>/dev/null)"
  echo
  echo "Avisos (${#AVISOS[@]}):"
  if (( ${#AVISOS[@]} )); then printf '  - %s\n' "${AVISOS[@]}"; else echo "  (ninguno)"; fi
  if (( ${#NOTAS[@]} )); then echo "Notas:"; printf '  - %s\n' "${NOTAS[@]}"; fi
  if (( ${#RESPALDOS[@]} )); then echo "Respaldos de lo que se cambio:"; printf '  - %s\n' "${RESPALDOS[@]}"; fi
  echo
  echo "Registro completo: $LOG"
} > "$REPORTE"
chown "$USUARIO:$USUARIO" "$REPORTE"
cat "$REPORTE"

header "LISTO"
if (( ${#AVISOS[@]} == 0 )); then log "Instalacion completada sin avisos."
else echo "${YELLOW}Instalacion completada con ${#AVISOS[@]} aviso(s): estan en el reporte.${NC}"; fi
cat <<EOF

${BOLD}Siguiente paso:${NC}  sudo reboot   (entras directo al escritorio)

${BOLD}Atajos principales (DankMaterialShell):${NC}
  Super+Espacio  menu de apps              Super+Enter   terminal (Ghostty)
  Super+B        navegador                 Super+E       archivos
  Super+V        portapapeles              Super+C       ajustes de DMS
  Super+Y        fondos de pantalla        Super+X       apagar / reiniciar
  Super+Alt+L    bloquear                  Super+Q       cerrar ventana
  Super+1..9     escritorios               Impr          captura de pantalla
  Super+Shift+/  todos los atajos

${BOLD}Una sola vez, si quieres:${NC}
  - Idioma de la barra: Ajustes de DMS (Super+C) -> Idioma.
  - Colores en apps GTK: Ajustes de DMS -> Tema -> aplicar temas GTK.
  - Si pediste chino, japones o coreano: ibus-setup para el metodo de entrada.

Reporte: $REPORTE
EOF
