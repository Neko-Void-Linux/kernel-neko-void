# Kernel-Neko 🐾

Repositorio unificado de compilación y empaquetado de kernels para **Neko Void Linux**.

---

## Variantes Disponibles

El proyecto soporta 14 variantes optimizadas:

| Variante | Paquete XBPS | Descripción / Planificador |
| :--- | :--- | :--- |
| **`bore`** | `linux-neko-bore` | Planificador **BORE** (Burst-Oriented Response Enhancer) para fluidez interactiva |
| **`bmq`** | `linux-neko-bmq` | Planificador **BMQ** (Project C) con cola O(1) de baja latencia |
| **`lite`** | `linux-neko-lite` | Ultra-ligero para computadoras de bajos recursos (1GB RAM, Loc-OS style) |
| **`lts`** | `linux-neko-lts` | Soporte prolongado (rama 6.18) con parches de rendimiento |
| **`zen`** | `linux-neko-zen` | Kernel Zen interactivo |
| **`liquorix`** | `linux-neko-liquorix` | Kernel Liquorix (PDS) de baja latencia para multimedia y juegos |
| **`rt`** | `linux-neko-rt` | Tiempo real estricto (`PREEMPT_RT`) |
| **`rt-bore`** | `linux-neko-rt-bore` | Combinación de tiempo real (`PREEMPT_RT`) y BORE |
| **`neko`** | `linux-neko` | Kernel-Neko estándar optimizado |
| **`eevdf`** | `linux-neko-eevdf` | Kernel EEVDF estándar afinado |
| **`deckify`** | `linux-neko-deckify` | Optimizado para consolas portátiles y dispositivos handheld |
| **`hardened`** | `linux-neko-hardened` | Endurecimiento y mitigación avanzada de seguridad |
| **`server`** | `linux-neko-server` | Optimizado para cálculo continuo y servidores |
| **`rc`** | `linux-neko-rc` | Versión *Release Candidate* upstream |

---

## Requisitos Previos en Void Linux

Instala las herramientas de compilación necesarias:

```bash
sudo xbps-install -Syu
sudo xbps-install -y base-devel bc kmod elfutils-devel openssl-devel flex bison perl python3 xz zstd tar patch cpio curl ncurses-devel pahole
```

---

## Instrucciones de Compilación

### 1. Listar variantes y niveles de arquitectura
```bash
./build-kernel-neko.sh list
```

### 2. Niveles de Compatibilidad x86-64 (v1, v2 y v3)

Por defecto, la compilación se realiza en **x86-64-v1**, lo que significa que el kernel resultante es **universal y compatible directamente con v1, v2, v3 y v4**:

- **`--march=v1` (Por defecto / Universal)**:
  - Compatible con **todas** las CPUs de 64 bits: Core 2 Duo, Intel Celeron 847, AMD Athlon 64, Core i3/i5/i7, AMD Ryzen.
  - Genera el paquete estándar (ejemplo: `linux-neko-bore`).
  - Aprovecha dinámicamente aceleraciones de hardware (SSE4.2, AVX2, AES-NI) en tiempo de ejecución si la CPU las tiene.

- **`--march=v2` (Optimizado SSE4.2 / POPCNT)**:
  - Optimizado para procesadores Intel Nehalem / Core ix 1ra gen / AMD Bulldozer en adelante.
  - Compatible con CPUs v2, v3 y v4.
  - Genera el paquete `linux-neko-<variante>-v2`.

- **`--march=v3` (Optimizado AVX / AVX2 / FMA / BMI2)**:
  - Optimizado para procesadores modernos: Intel Haswell 4ta gen en adelante y AMD Zen 1/2/3/4/5.
  - Genera el paquete `linux-neko-<variante>-v3`.

### 3. Ejemplos de Compilación

```bash
# Compilar Kernel-Neko BORE universal (compatible con v1, v2 y v3):
./build-kernel-neko.sh bore

# Compilar Kernel-Neko BORE optimizado para CPUs modernas (v3 - AVX2):
./build-kernel-neko.sh bore --march=v3

# Compilar Kernel-Neko Lite para hardware modesto / 1GB RAM:
./build-kernel-neko.sh lite

# Abrir el menú de configuración antes de compilar:
./build-kernel-neko.sh bore --menuconfig
```

---

## Empaquetado e Instalación en Void Linux con `xbps-src`

Una vez finalizada la compilación de la variante (por ejemplo `bore`):

```bash
# 1. Copiar la plantilla generada a tu árbol de void-packages
VPKG_DIR="$([ -d "$HOME/.local/share/pkgs/void-packages" ] && echo "$HOME/.local/share/pkgs/void-packages" || echo "$HOME/void-packages")"
cp -r kernel-neko-variants/output/Kernel-Neko-bore/srcpkgs/linux-neko-bore "${VPKG_DIR}/srcpkgs/"

# 2. Copiar el tarball compilado directamente a hostdir/sources/
mkdir -p "${VPKG_DIR}/hostdir/sources"
cp kernel-neko-variants/output/Kernel-Neko-bore/linux-neko-bore-*.tar.gz "${VPKG_DIR}/hostdir/sources/"

# 3. Construir el paquete nativo .xbps
cd "${VPKG_DIR}"
./xbps-src pkg linux-neko-bore

# 4. Instalar el paquete en el sistema
sudo xbps-install -R hostdir/binpkgs linux-neko-bore
```

Al instalarse, `kernel-hooks` ejecutará automáticamente `dracut` para crear el initramfs y registrará la entrada en el menú de GRUB.
