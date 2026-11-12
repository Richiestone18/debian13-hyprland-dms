# debian13-hyprland-dms

Instalador para dejar **Debian 13 (Trixie) puro** con un escritorio estilo **Omarchy**:
**Hyprland + Quickshell + DankMaterialShell (DMS)**, con menú interactivo, instalación
desatendida, reporte final y entrada directa al escritorio.

**Versión 2.1** — corrige los fallos de la 2.0 (ver [Cambios](#cambios-en-la-21)) y se
probó con una instalación real (ver [Cómo se probó](#cómo-se-probó)).

## ¿Qué hace?

- **Menú interactivo** (`whiptail`): marcas los componentes, eliges idioma y teclado,
  ves el resumen y puedes **volver atrás** antes de confirmar. Después todo es
  **desatendido** y termina con un **reporte** (`~/reporte-instalacion-<fecha>.txt`).
- **Escritorio**: Hyprland 0.55 (backports de Debian) con configuración **Lua**, Quickshell y
  DankMaterialShell desplegado con su configurador oficial (`dms setup headless`): barra,
  lanzador, notificaciones, portapapeles, bloqueo, fondos y colores Material You sacados
  del fondo. La configuración se **valida con el propio Hyprland** (`--verify-config`).
- **Inicio directo al escritorio** con `greetd` (ligero). Opcional: SDDM gráfico (`--sddm`).
- **Repositorios** con llave firmada y la política **"gana la versión más nueva"**:
  MX Linux y deb-multimedia (al principio), backports de Debian, OBS de AvengeMedia (DMS,
  matugen, ghostty), Brave, WineHQ y Liquorix. Completa las fuentes de Debian con
  `contrib non-free non-free-firmware` (firmware y codecs) y desactiva la fuente `cdrom`.
- **Apariencia**: tema oscuro Arc-Dark, iconos Papirus-Dark, cursor Bibata, fuentes Inter y
  JetBrains Mono, fondos oficiales de Hyprland. `tema-desde-fondo /ruta/imagen` cambia el
  fondo y DMS recalcula los colores de todo.
- **Programas** (todo por defecto; las banderas sirven para omitir): diseño y multimedia
  (Inkscape, Krita, GIMP, Blender, DVDStyler, ClipGrab...), Kodi + RetroArch + OpenRCT2,
  auditoría de redes, Wine y kernel Liquorix (estos dos solo en PC amd64), Docker, gh,
  lazydocker, mise, tte y Flatpak.
- **Red**: si Debian se instaló con la red en `/etc/network/interfaces`, la pasa a
  NetworkManager (al reiniciar) para manejar el WiFi desde DMS. No toca IP fija.
- **Seguro de re-ejecutar**: respalda cada archivo que cambia, repara paquetes a medias y
  retoma donde se quedó. Si algo imprescindible falla, dice en qué sección y línea.

## Requisitos

- Debian 13 (Trixie) recién instalado **sin escritorio**, en **PC (amd64)** o **ARM (arm64)**
- Internet y unos **15 GB** libres
- Ejecutarlo con `sudo` desde tu usuario (o como root con `--usuario TU_USUARIO`)

## Uso

```bash
curl -fsSLO https://raw.githubusercontent.com/Richiestone18/debian13-hyprland-dms/main/debian13-hyprland-dms.sh
chmod +x debian13-hyprland-dms.sh
sudo ./debian13-hyprland-dms.sh
```

Con `wget`:

```bash
wget https://raw.githubusercontent.com/Richiestone18/debian13-hyprland-dms/main/debian13-hyprland-dms.sh
sudo bash debian13-hyprland-dms.sh
```

Por tubería (sin menú, instala todo lo de por defecto):

```bash
curl -fsSL https://raw.githubusercontent.com/Richiestone18/debian13-hyprland-dms/main/debian13-hyprland-dms.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/Richiestone18/debian13-hyprland-dms/main/debian13-hyprland-dms.sh | sudo bash -s -- --sin-kodi --si
```

Al terminar: `sudo reboot` y entras directo al escritorio.

## Banderas

| Bandera | Efecto |
|---|---|
| `--sin-repos-extra` | sin MX Linux ni deb-multimedia |
| `--sin-extras` | sin diseño y multimedia |
| `--sin-kodi` | sin Kodi, RetroArch ni OpenRCT2 |
| `--sin-seguridad` | sin auditoría de redes (wifite, hashcat, Wireshark...) |
| `--sin-wine` | sin WineHQ |
| `--sin-liquorix` | sin kernel Liquorix (se omite solo si hay Secure Boot) |
| `--sin-brave` | sin Brave (el navegador será Firefox ESR) |
| `--idioma CODIGO` | idioma del sistema (por defecto `es_MX.UTF-8`) |
| `--teclado DISTRIB` | teclado (por defecto el que elegiste al instalar Debian, p. ej. `latam`) |
| `--usuario NOMBRE` | usuario a configurar (por defecto quien ejecuta `sudo`) |
| `--sddm` | pantalla de acceso gráfica SDDM en vez de greetd |
| `--quickshell-debian` | quickshell de Debian (por defecto gana el más nuevo) |
| `--seco` | solo revisa los requisitos y muestra el plan, sin cambiar nada |
| `--si` | desatendido total (sin menú) |
| `--ayuda` | ayuda |

## Atajos principales

Son los de DankMaterialShell más tres al estilo Omarchy (Super+B, Super+E y Super+C):

| Atajo | Acción |
|---|---|
| Super+Espacio | menú de aplicaciones |
| Super+Enter | terminal (Ghostty) |
| Super+B / Super+E | navegador / archivos |
| Super+V | portapapeles |
| Super+C o Super+, | ajustes de DMS |
| Super+Y | fondos de pantalla |
| Super+X | apagar / reiniciar |
| Super+Alt+L | bloquear |
| Super+Q | cerrar ventana |
| Super+1..9 | escritorios |
| Impr | captura de pantalla |
| Super+Shift+/ | lista de todos los atajos |

Tus atajos propios van en `~/.config/hypr/dms/binds-user.lua`.

## Cambios en la 2.1

Fallos de la 2.0 que impedían terminar en un Debian limpio:

- Buscaba fondos en `/usr/share/backgrounds` (no existe) y abortaba → usa los de `hyprland-backgrounds`.
- Escribía la config de Ghostty y Kitty antes de crear sus carpetas → abortaba.
- `~/.config` quedaba como propiedad de root → todo se crea como tu usuario (y se reparan restos).
- El *pin* `a=trixie-backports` no coincide en Debian 13 → Hyprland no se podía instalar. Ahora `n=trixie-backports`.
- hyprpaper 0.8 rechazaba la sintaxis vieja → el fondo lo pone DMS.
- `--greeter` usaba el usuario `greeter` (en Debian es `_greetd`) → se retiró; greetd entra solo al escritorio.
- `apti_try` abortaba si un paquete fallaba → ahora reintenta uno por uno y sigue.
- Las llaves de MX y deb-multimedia necesitan `gpgv`, que Debian 13 ya no trae → se instala antes.

Otros arreglos y mejoras:

- Configuración **Lua oficial de DMS** (Hyprland 0.55 marcó `hyprland.conf` como obsoleto); atajos sin programas faltantes.
- DMS hace fondo, colores (matugen), polkit, bloqueo y lanzador: ya no se instalan piezas que chocaban (hyprpaper, hyprlock, waybar, fuzzel...).
- greetd por defecto (SDDM arrastraba Xorg y KWin); SDDM sigue disponible con `--sddm`.
- DVDStyler y ClipGrab se instalan desde MX; se quitaron 10 paquetes que no existen.
- Fuentes de Debian completas (`contrib`, `non-free`), fuente `cdrom` desactivada y red pasada a NetworkManager.
- Comprobaciones previas: internet por HTTPS, espacio libre, batería y Secure Boot.
- Registro con fecha, respaldo de cada archivo cambiado y aviso de la sección y línea si algo falla.
- Si ya existía otra definición de un repo que maneja el script (p. ej. la guía oficial de DMS
  o de Brave, con otra llave), se desactiva: con dos llaves distintas apt no lee ninguna fuente.
- Los instaladores web (mise, lazydocker, tte) trabajan en disco y en una carpeta del usuario:
  en Debian 13 `/tmp` vive en la RAM y el de mise lo llenaba (~200 MB).
- Si `apt update` falla por algo general (espacio, red, hora) lo dice claro, sin culpar a un repo.
- Soporte para ARM (arm64), `--teclado`, `--usuario` y detección del usuario al usar `su -`.
- Se retiró `--compositor niri`: estaba a medias (no configuraba DMS en niri).

## Cómo se probó

- **Simulación apt amd64** con todos los repos: 207 paquetes, ninguno inexistente; la
  instalación completa resuelve junta (~2,300 paquetes, ~3.5 GB). `--sddm` también resuelve.
- **Instalación real** en un Debian 13 arm64 recién instalado (contenedor `systemd-nspawn`
  con `sources.list` clásico, fuente `cdrom` activa y red en `/etc/network/interfaces` con WiFi):
  - Terminó completa: 2,018 paquetes, ninguno a medias; Hyprland validó su configuración
    (`config ok`); greetd entra directo; el WiFi pasó a NetworkManager.
  - Se recuperó de corridas que fallaron a medias, retiró los restos de la v2.0 (con
    respaldo) y al volver a ejecutarlo no cambia nada.
  - El menú se probó con teclas simuladas en una terminal real (marcar, volver atrás, cancelar).
- `bash -n` y `shellcheck` sin advertencias.
- **No se pudo probar aquí**: arrancar la sesión gráfica (el contenedor no tiene pantalla ni
  GPU) y lo que solo existe para PC amd64 (Wine y Liquorix), que se validó con la simulación.

## Notas

- **Idioma del shell**: DMS trae sus propios idiomas (incluye español): *Ajustes de DMS → Idioma*.
  El script fija el idioma del sistema, que es el que siguen Brave, GTK, Qt y tus carpetas.
- **Colores en apps GTK**: actívalo en *Ajustes de DMS → Tema* (aplicar temas GTK).
- **Llavero**: como la sesión entra sola, se crea un llavero sin contraseña (igual que Omarchy)
  para que Brave no la pida en cada inicio.
- **Repos de terceros a prioridad 500**: si traen algo más nuevo que Debian, se instala lo suyo.
- No toca BIOS ni gestor de arranque (salvo instalar el kernel Liquorix, si se elige).

## Créditos

Hecho para el taller de **Richiestone** (Jerez, Zacatecas). Basado en su script
[Debian-13-Postinstall](https://github.com/Richiestone18/Debian-13-Postinstall).
Escritorio inspirado en [Omarchy](https://omarchy.org) de DHH; shell
[DankMaterialShell](https://danklinux.com), [Quickshell](https://quickshell.org) e
[Hyprland](https://hypr.land).
