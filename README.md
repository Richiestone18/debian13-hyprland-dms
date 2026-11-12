# debian13-hyprland-dms

Instalador para dejar **Debian 13 (Trixie) puro** con un escritorio estilo **Omarchy 4.5**:
**Hyprland + Quickshell + DankMaterialShell (dms)**, con menú interactivo, instalación
desatendida y reporte final.

## ¿Qué hace?

- **Menú interactivo** (`whiptail`) al arrancar: marcas los componentes, eliges idioma y
  compositor, ves el resumen y puedes **volver atrás** para cambiar algo antes de confirmar.
- **Instalación desatendida** desde que confirmas hasta el final (sin más preguntas).
- **Reporte final** en pantalla y en `~/reporte-instalacion-<fecha>.txt`; el registro
  completo queda en `/var/log/debian13-hyprland-dms.log`.
- **Autologin** configurado: al reiniciar entras **directo al escritorio**.
- **Repositorios**: MX Linux y deb-multimedia **al principio y siempre**, backports de
  Debian, OBS de AvengeMedia/DankLinux (dms, matugen, ghostty, niri), Brave, WineHQ y
  Liquorix — todos con **llave firmada** y *pinning* con la política de que **gana siempre
  la versión más nueva**.
- **Escritorio**: Hyprland + Quickshell + DankMaterialShell (más matugen, ghostty, niri,
  xwayland-satellite). `dist-upgrade` tras los repos y `full-upgrade` al final.
- **Apariencia de distro buena**: fondo (hyprland-backgrounds) con hyprpaper y hyprlock,
  **paleta Material You generada desde el fondo con matugen** y aplicada a GTK3, GTK4,
  Ghostty, Kitty y Hyprland; iconos Papirus-Dark, cursor Bibata, fuentes Inter y
  JetBrains Mono. Extra: el helper `tema-desde-fondo /ruta/imagen.jpg` cambia el fondo y
  **regenera todo el tema** de una sola vez.
- **Programas**: diseño y multimedia, Kodi + RetroArch + OpenRCT2, auditoría de redes,
  Wine (WineHQ) y kernel Liquorix. Todo **por defecto**; las banderas sirven para omitir.
- **Idioma**: locale del sistema configurable, paquetes de traducción/diccionarios y
  métodos de entrada CJK (mozc, hangul, libpinyin, chewing).

## Requisitos

- Debian 13 (Trixie) recién instalado (**sin escritorio**)
- Conexión a internet
- Ejecutar como root (`sudo`)

## Uso

Con `curl` + `chmod` + `sudo`:

```bash
curl -fsSLO https://raw.githubusercontent.com/Richiestone18/debian13-hyprland-dms/main/debian13-hyprland-dms.sh
chmod +x debian13-hyprland-dms.sh
sudo ./debian13-hyprland-dms.sh
```

Con `wget`:

```bash
wget https://raw.githubusercontent.com/Richiestone18/debian13-hyprland-dms/main/debian13-hyprland-dms.sh
chmod +x debian13-hyprland-dms.sh
sudo bash debian13-hyprland-dms.sh
```

Sin descargar (por tubería, modo desatendido):

```bash
curl -fsSL https://raw.githubusercontent.com/Richiestone18/debian13-hyprland-dms/main/debian13-hyprland-dms.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/Richiestone18/debian13-hyprland-dms/main/debian13-hyprland-dms.sh | sudo bash -s -- --idioma es_MX.UTF-8 --si
```

Al terminar: `sudo reboot` (el autologin te deja en el escritorio).

## Banderas

Por defecto instala **todo**. Las banderas sirven para **omitir** o ajustar:

| Bandera | Efecto |
|---|---|
| `--idioma CODE` | locale del sistema (por defecto `es_MX.UTF-8`) |
| `--compositor hyprland\|niri` | compositor Wayland (por defecto `hyprland`) |
| `--greeter` | pantalla de acceso `dms-greeter` en vez de SDDM |
| `--sin-extras` | sin diseño/multimedia (Inkscape, Krita, GIMP, Blender...) |
| `--sin-kodi` | sin Kodi + RetroArch + OpenRCT2 |
| `--sin-seguridad` | sin wifite, hashcat, hcxdumptool, Wireshark, macchanger... |
| `--sin-wine` | sin WineHQ |
| `--sin-liquorix` | sin kernel Liquorix |
| `--sin-repos-extra` | sin MX Linux ni deb-multimedia |
| `--sin-brave` | sin Brave (y sin ponerlo por defecto) |
| `--quickshell-debian` | forzar el quickshell de Debian |
| `--seco` | simulación: comprueba y muestra lo que haría, **sin tocar nada** |
| `--si` | desatendido total (sin menú y sin preguntas) |
| `--ayuda` | ayuda |

## Notas importantes

- **`dvdstyler` y `clipgrab` no existen en Debian 13**: se usan `devede` y `yt-dlp`.
- **`quickshell`**: por defecto gana la versión más nueva (puede ser la del OBS); con
  `--quickshell-debian` se clava al de Debian.
- **Idioma del shell**: DMS trae sus propios idiomas (se cambian en *Ajustes → Locale*).
  El script deja el **locale del sistema**, que es lo que siguen las demás aplicaciones
  (Brave, LibreOffice, GTK, xdg-user-dirs).
- **Repos de terceros con prioridad 500**: si traen algo más nuevo que Debian, se instala
  lo suyo.
- El script **no toca BIOS ni bootloader**; sólo el sistema instalado.

## Créditos

Hecho para el taller de **Richiestone** (Jerez, Zacatecas). Basado en su script
[Debian-13-Postinstall](https://github.com/Richiestone18/Debian-13-Postinstall).
Escritorio inspirado en [Omarchy](https://omarchy.org) de DHH; shell
[DankMaterialShell](https://danklinux.com) y [Quickshell](https://quickshell.org).
