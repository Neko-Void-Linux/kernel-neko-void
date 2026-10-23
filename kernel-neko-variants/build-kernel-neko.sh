#!/usr/bin/env bash
# ==============================================================================
# Kernel-Neko - Compilador de variantes para Neko Void Linux
#
# Uso:
#   ./build-kernel-neko.sh <variante> [--march=v1|v2|v3] [--menuconfig]
#   ./build-kernel-neko.sh list
#
# Niveles de microarquitectura x86-64:
#   --march=v1 (por defecto): Universal. Funciona en TODAS las CPUs de 64 bits (v1, v2 y v3).
#   --march=v2: Optimizado con SSE4.2 / POPCNT (Intel Nehalem / AMD Bulldozer en adelante).
#   --march=v3: Optimizado con AVX / AVX2 / BMI2 (Intel Haswell / AMD Zen en adelante).
#
# Variables opcionales:
#   NEKO_JOBS=8            hilos de compilación (por defecto: nproc)
#   NEKO_MARCH=1|2|3       nivel x86-64 (por defecto 1 = compatible con todo)
#   NEKO_BTF=yes           mantener BTF (necesario para sched_ext/scx; más lento)
#   NEKO_REVISION=1        revision del paquete xbps
#   NEKO_RELEASE_URL=...   URL base donde publicarás los tarballs
# ==============================================================================
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=upstream.conf
. "${HERE}/upstream.conf"

C_G='\033[0;32m'; C_B='\033[0;34m'; C_Y='\033[1;33m'; C_R='\033[0;31m'; C_N='\033[0m'
msg()  { echo -e "${C_B}==>${C_N} $*"; }
ok()   { echo -e "${C_G}  ✔${C_N} $*"; }
warn() { echo -e "${C_Y}  !${C_N} $*"; }
die()  { echo -e "${C_R}ERROR:${C_N} $*" >&2; exit 1; }
trap 'die "falló en la línea $LINENO (ver mensajes arriba)"' ERR

list_variants() {
    echo "Variantes disponibles de Kernel-Neko:"
    for f in "${HERE}"/Kernel-Neko*/neko.conf; do
        local d n; d="$(basename "$(dirname "$f")")"
        n="${d#Kernel-Neko}"; n="${n#-}"; [ -z "$n" ] && n="neko"
        ( . "$f"; printf '  %-10s -> %-20s %s\n' "$n" "$NEKO_PKG" "$NEKO_DESC" )
    done
    echo ""
    echo "Niveles de compatibilidad x86-64 disponibles:"
    echo "  --march=v1 (defecto) : Compatible con v1, v2, v3 y v4 (Core 2 Duo, Celeron, Core i3/i5/i7, Ryzen)"
    echo "  --march=v2           : Compatible con v2, v3 y v4 (Intel Nehalem / AMD FX con SSE4.2)"
    echo "  --march=v3           : Compatible con v3 y v4 (Intel Haswell 4ta gen / AMD Zen con AVX2)"
}

# ------------------------------------------------------------------ argumentos
VARIANT=""
MENUCONFIG="no"
CONFIG_ONLY="no"
MARCH_ARG=""

for arg in "$@"; do
    case "$arg" in
        --menuconfig) MENUCONFIG="yes" ;;
        --config-only|--dry-run) CONFIG_ONLY="yes" ;;
        --march=v1|--march=1) MARCH_ARG="1" ;;
        --march=v2|--march=2) MARCH_ARG="2" ;;
        --march=v3|--march=3) MARCH_ARG="3" ;;
        --march=*) die "Nivel no soportado. Usa --march=v1, --march=v2 o --march=v3" ;;
        -h|--help|list) list_variants; exit 0 ;;
        -*) die "Opción desconocida: $arg" ;;
        *) [ -z "$VARIANT" ] && VARIANT="$arg" ;;
    esac
done

[ -z "$VARIANT" ] && { list_variants; exit 0; }

case "$VARIANT" in
    neko|default|standard) VDIR="Kernel-Neko" ;;
    *) VDIR="Kernel-Neko-${VARIANT}" ;;
esac
[ -f "${HERE}/${VDIR}/neko.conf" ] || { list_variants; die "variante '${VARIANT}' no existe"; }
[ -f "${HERE}/${VDIR}/config" ]    || die "falta ${VDIR}/config"
# shellcheck disable=SC1090
. "${HERE}/${VDIR}/neko.conf"

JOBS="${NEKO_JOBS:-$(nproc)}"
MARCH="${MARCH_ARG:-${NEKO_MARCH:-1}}"
[ "$LITE" = "yes" ] && MARCH=1
REVISION="${NEKO_REVISION:-1}"
RELEASE_URL="${NEKO_RELEASE_URL:-https://github.com/ANOMALI0x00/kernel-neko/releases/download}"

if [ "$MARCH" -gt 1 ]; then
    TARGET_PKG="${NEKO_PKG}-v${MARCH}"
    TARGET_DESC="${NEKO_DESC} (x86-64-v${MARCH})"
    OUT="${HERE}/output/${VDIR}-v${MARCH}"
    WORK="${HERE}/build/${VDIR}-v${MARCH}"
else
    TARGET_PKG="${NEKO_PKG}"
    TARGET_DESC="${NEKO_DESC}"
    OUT="${HERE}/output/${VDIR}"
    WORK="${HERE}/build/${VDIR}"
fi

CACHE="${HERE}/build/cache"
SRC="${WORK}/src"

echo -e "${C_B}=====================================================================${C_N}"
echo -e "${C_G}  ${TARGET_DESC}${C_N}"
case "$MARCH" in
    1) echo -e "${C_Y}  Nivel: x86-64-v1 [Universal: Compatible con v1, v2 y v3]${C_N}" ;;
    2) echo -e "${C_Y}  Nivel: x86-64-v2 [SSE4.2/POPCNT: Optimizado para CPUs v2 y v3]${C_N}" ;;
    3) echo -e "${C_Y}  Nivel: x86-64-v3 [AVX/AVX2/BMI2: Optimizado para CPUs v3 (Haswell/Zen+)]${C_N}" ;;
esac
echo -e "  Paquete : ${TARGET_PKG} ${KVER} (hilos: ${JOBS})"
echo -e "${C_B}=====================================================================${C_N}"

# --------------------------------------------------------------- dependencias
msg "Comprobando herramientas..."
missing=()
for c in gcc make bc bison flex perl python3 openssl tar xz zstd patch cpio depmod curl; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
done
[ -f /usr/include/libelf.h ] || missing+=("elfutils-devel")
[ -f /usr/include/openssl/ssl.h ] || missing+=("openssl-devel")
if [ ${#missing[@]} -gt 0 ]; then
    die "faltan: ${missing[*]}
  Instala: sudo xbps-install -Syu base-devel bc kmod elfutils-devel openssl-devel \\
           flex bison perl python3 xz zstd tar patch cpio curl ncurses-devel pahole gmp-devel mpfr-devel libmpc-devel"
fi
ok "herramientas presentes"

fetch() { # url destino
    [ -s "$2" ] && { ok "en caché: $(basename "$2")"; return 0; }
    msg "Descargando $(basename "$2")"
    curl -fL --retry 3 --connect-timeout 20 -o "$2.part" "$1" || { rm -f "$2.part"; die "no se pudo descargar: $1"; }
    mv "$2.part" "$2"
}

apply_patch() { # archivo
    patch -Np1 --dry-run -s < "$1" >/dev/null 2>&1 \
        || die "el parche $(basename "$1") NO aplica sobre ${SRC_TYPE} ${SRC_TAG}"
    patch -Np1 -s < "$1"
    ok "parche aplicado: $(basename "$1")"
}

# -------------------------------------------------------------------- fuentes
mkdir -p "$CACHE" "$WORK"
SRC_URL="$(neko_src_url "$SRC_TYPE" "$SRC_TAG")" || die "SRC_TYPE inválido: $SRC_TYPE"
SRC_FILE="${CACHE}/${SRC_TYPE}-${SRC_TAG}.tar.${SRC_URL##*.tar.}"
fetch "$SRC_URL" "$SRC_FILE"

msg "Extrayendo fuentes limpias (cada compilación parte de cero)..."
rm -rf "$SRC"; mkdir -p "$SRC"
tar -xf "$SRC_FILE" -C "$SRC" --strip-components=1
[ -f "$SRC/Makefile" ] || die "el tarball no contiene un árbol de kernel válido"
cd "$SRC"

# --------------------------------------------------------------------- parches
for p in "${PATCHES[@]}"; do
    url="$(neko_patch_url "$p" "$MAJOR")" || die "parche desconocido: $p"
    fetch "$url" "${CACHE}/${MAJOR}-${p}.patch"
    apply_patch "${CACHE}/${MAJOR}-${p}.patch"
done

if [ "$VDIR" = "Kernel-Neko-liquorix" ]; then
    LQX_FILE="${CACHE}/lqx-${MAJOR}.tar.gz"
    fetch "$(neko_lqx_url "$MAJOR")" "$LQX_FILE"
    rm -rf "${WORK}/lqx"; mkdir -p "${WORK}/lqx"
    tar -xzf "$LQX_FILE" -C "${WORK}/lqx" --strip-components=1
    LQX_P="${WORK}/lqx/linux-liquorix/debian/patches"
    [ -f "${LQX_P}/series" ] || die "no se encontró la serie de parches Liquorix"
    while IFS= read -r p; do apply_patch "${LQX_P}/${p}"; done \
        < <(grep -E '^(zen|lqx)/' "${LQX_P}/series")
fi

# ---------------------------------------------------------------- configuración
msg "Aplicando configuración de ${VDIR}..."
cp "${HERE}/${VDIR}/config" .config
cfg() { scripts/config --file .config "$@"; }

# Identidad
cfg -d LOCALVERSION_AUTO --set-str LOCALVERSION "$LOCALVERSION" \
    --set-str DEFAULT_HOSTNAME "nekovoid"
# CPU genérica (paquete distribuible)
cfg -e GENERIC_CPU -d MZEN4 -d X86_NATIVE_CPU --set-val X86_64_VERSION "$MARCH"
# Toolchain GCC sin LTO ni Rust (no requiere clang/rustc en Void)
cfg -e LTO_NONE -d LTO_CLANG_THIN -d LTO_CLANG_FULL -d RUST
# Módulos: ZSTD, sin firma obligatoria (compatible con DKMS)
cfg -e MODULES -e MODULE_UNLOAD -e MODVERSIONS \
    -e MODULE_COMPRESS -d MODULE_COMPRESS_NONE -d MODULE_COMPRESS_GZIP \
    -d MODULE_COMPRESS_XZ -e MODULE_COMPRESS_ZSTD \
    -d MODULE_SIG -d MODULE_SIG_ALL -d MODULE_SIG_FORCE \
    --set-str SYSTEM_TRUSTED_KEYS "" --set-str SYSTEM_REVOCATION_KEYS "" \
    -e IKCONFIG -e IKCONFIG_PROC
# Debug
if [ "${NEKO_BTF:-no}" != "yes" ]; then
    cfg -d DEBUG_INFO -d DEBUG_INFO_BTF -d DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT \
        -d DEBUG_INFO_DWARF4 -d DEBUG_INFO_DWARF5 -e DEBUG_INFO_NONE
fi
# Ajustes de rendimiento del árbol perf
[ "$PERF_TWEAKS" = "yes" ] && cfg -e NEKO -e CACHY
# Planificador
case "$SCHED" in
    bore)  cfg -e SCHED_BORE -d SCHED_ALT ;;
    bmq)   cfg -d SCHED_BORE -e SCHED_ALT -e SCHED_BMQ -d SCHED_PDS ;;
    pds)   cfg -d SCHED_BORE -e SCHED_ALT -d SCHED_BMQ -e SCHED_PDS ;;
    eevdf) cfg -d SCHED_BORE -d SCHED_ALT ;;
    *) die "SCHED inválido: $SCHED" ;;
esac
# Preemption
if [ "$RT" = "yes" ]; then
    cfg -e EXPERT -e PREEMPT_RT
else
    cfg -d PREEMPT_RT
    case "$PREEMPT" in
        full) cfg -d PREEMPT_NONE -d PREEMPT_VOLUNTARY -d PREEMPT_LAZY -e PREEMPT ;;
        lazy) cfg -d PREEMPT_NONE -d PREEMPT_VOLUNTARY -d PREEMPT -e PREEMPT_LAZY ;;
    esac
fi
# Frecuencia del temporizador
cfg -d HZ_100 -d HZ_250 -d HZ_300 -d HZ_500 -d HZ_600 -d HZ_750 -d HZ_1000 \
    -e "HZ_${HZ}" --set-val HZ "$HZ"
# Ticks
case "$TICK" in
    full) cfg -d HZ_PERIODIC -d NO_HZ_IDLE -d CONTEXT_TRACKING_FORCE \
              -e NO_HZ_FULL_NODEF -e NO_HZ_FULL -e NO_HZ -e NO_HZ_COMMON -e CONTEXT_TRACKING ;;
    idle) cfg -d HZ_PERIODIC -d NO_HZ_FULL -e NO_HZ_IDLE -e NO_HZ -e NO_HZ_COMMON ;;
esac
# Transparent Hugepages
case "$THP" in
    always)  cfg -d TRANSPARENT_HUGEPAGE_MADVISE -e TRANSPARENT_HUGEPAGE_ALWAYS ;;
    madvise) cfg -d TRANSPARENT_HUGEPAGE_ALWAYS -e TRANSPARENT_HUGEPAGE_MADVISE ;;
esac
# Optimización del compilador
if [ "$LITE" = "yes" ]; then
    cfg -d CC_OPTIMIZE_FOR_PERFORMANCE -d CC_OPTIMIZE_FOR_PERFORMANCE_O3 -e CC_OPTIMIZE_FOR_SIZE
elif [ "$O3" = "yes" ]; then
    cfg -d CC_OPTIMIZE_FOR_PERFORMANCE -e CC_OPTIMIZE_FOR_PERFORMANCE_O3
fi
# Perfil Lite (PCs antiguas / 1 GB RAM / HDD)
if [ "$LITE" = "yes" ]; then
    cfg -e ZSWAP -e ZSWAP_DEFAULT_ON -e CRYPTO_LZ4 -e ZSWAP_COMPRESSOR_DEFAULT_LZ4 \
        -d ZSWAP_COMPRESSOR_DEFAULT_ZSTD --set-str ZSWAP_COMPRESSOR_DEFAULT lz4 \
        -e ZSMALLOC -m ZRAM -e ZRAM_BACKEND_LZ4 -e ZRAM_BACKEND_ZSTD \
        -e MQ_IOSCHED_BFQ -e BFQ_GROUP_IOSCHED \
        -m ACPI_CMPC -m DRM_I915 -m SND_HDA_INTEL \
        -d AUDIT -d AUDITSYSCALL -d FTRACE -d FUNCTION_TRACER -d SLUB_DEBUG \
        -d DEBUG_KERNEL -d LATENCYTOP -d PROVE_LOCKING -d LOCK_STAT
fi

make olddefconfig >/dev/null
[ "$MENUCONFIG" = "yes" ] && make menuconfig

# Verificación: si un parche no aportó su opción, abortamos en vez de compilar algo distinto
need() { grep -q "^CONFIG_$1=y" .config || die "CONFIG_$1 no quedó activo (¿parche faltante o no compatible?)"; }
case "$SCHED" in bore) need SCHED_BORE ;; bmq) need SCHED_BMQ ;; pds) need SCHED_PDS ;; esac
[ "$RT" = "yes" ] && need PREEMPT_RT
[ "$PERF_TWEAKS" = "yes" ] && { grep -q "^CONFIG_NEKO=y" .config || grep -q "^CONFIG_CACHY=y" .config || die "Ajustes de rendimiento no quedaron activos"; }
grep -q "^CONFIG_HZ=${HZ}$" .config || die "HZ=${HZ} no quedó aplicado"
ok "configuración verificada (sched=${SCHED}, rt=${RT}, HZ=${HZ}, THP=${THP})"

if [ "$CONFIG_ONLY" = "yes" ]; then
    ok "Modo --config-only: Parches y configuración de ${TARGET_PKG} listos y validados correctamente."
    exit 0
fi

# ----------------------------------------------------------------- compilación
msg "Compilando con ${JOBS} hilos (log: ${WORK}/build.log)..."
export KBUILD_BUILD_USER=nekovoid KBUILD_BUILD_HOST=nekovoid
make -j"$JOBS" prepare >> "${WORK}/build.log" 2>&1 || true
make -j"$JOBS" bzImage modules >> "${WORK}/build.log" 2>&1 \
    || { tail -n 60 "${WORK}/build.log"; die "la compilación falló"; }
KR="$(make -s kernelrelease)"
ok "kernel compilado: ${KR}"

# ------------------------------------------------------------------ empaquetado
msg "Empaquetando para Neko Void Linux..."
rm -rf "$OUT"; PKG="${OUT}/pkg"; mkdir -p "$PKG/boot"
install -m644 arch/x86/boot/bzImage "$PKG/boot/vmlinuz-${KR}"
install -m644 System.map            "$PKG/boot/System.map-${KR}"
install -m644 .config               "$PKG/boot/config-${KR}"

make INSTALL_MOD_PATH="$PKG/usr" INSTALL_MOD_STRIP=1 modules_install >> "${WORK}/build.log" 2>&1
MODDIR="$PKG/usr/lib/modules/${KR}"
[ -d "$MODDIR" ] || die "no se instalaron los módulos en $MODDIR"

# Cabeceras para DKMS (nvidia, broadcom-wl, virtualbox, etc.)
HDR="$PKG/usr/src/kernel-headers-${KR}"
install -Dt "$HDR" -m644 .config Makefile Module.symvers System.map
install -Dt "$HDR/kernel" -m644 kernel/Makefile
install -Dt "$HDR/arch/x86" -m644 arch/x86/Makefile
[ -f arch/x86/kernel/asm-offsets.s ] && install -Dt "$HDR/arch/x86/kernel" -m644 arch/x86/kernel/asm-offsets.s
cp -a scripts include "$HDR/"
cp -a arch/x86/include "$HDR/arch/x86/"
[ -x tools/objtool/objtool ] && install -Dt "$HDR/tools/objtool" tools/objtool/objtool
[ -x tools/bpf/resolve_btfids/resolve_btfids ] && install -Dt "$HDR/tools/bpf/resolve_btfids" tools/bpf/resolve_btfids/resolve_btfids
find . \( -path ./scripts -o -path ./include -o -path ./Documentation -o -path ./tools -o -path ./.git \) -prune -o \
     -type f \( -name 'Kbuild*' -o -name 'Kconfig*' -o -name 'Makefile*' \) -print0 \
     | xargs -0 cp --parents -t "$HDR"
find "$HDR/scripts" -type f -name '*.o' -delete
rm -f "$MODDIR/build" "$MODDIR/source"
ln -s "/usr/src/kernel-headers-${KR}" "$MODDIR/build"
ln -s "/usr/src/kernel-headers-${KR}" "$MODDIR/source"

TARNAME="${TARGET_PKG}-${KVER}.tar.gz"
tar --owner=0 --group=0 --numeric-owner -C "$PKG" -czf "${OUT}/${TARNAME}" .
SHA="$(sha256sum "${OUT}/${TARNAME}" | cut -d' ' -f1)"

# Estructura lista para void-packages: hostdir/sources/ y srcpkgs/<pkg>/
mkdir -p "${OUT}/sources" "${OUT}/srcpkgs/${TARGET_PKG}"
cp "${OUT}/${TARNAME}" "${OUT}/sources/"
cat > "${OUT}/srcpkgs/${TARGET_PKG}/template" <<EOF
# Template file for '${TARGET_PKG}' (generado por build-kernel-neko.sh)
pkgname=${TARGET_PKG}
version=${KVER}
revision=${REVISION}
archs="x86_64*"
short_desc="${TARGET_DESC} for Neko Void Linux"
maintainer="Neko Void Linux <nekovoid@local>"
license="GPL-2.0-only"
homepage="https://github.com/ANOMALI0x00/kernel-neko"
distfiles="${RELEASE_URL}/${TARGET_PKG}-${KVER}/${TARNAME}"
checksum=${SHA}
create_wrksrc=yes
depends="linux-base"
nodebug=yes
nostrip=yes
noverifyrdeps=yes
noshlibprovides=yes
preserve=yes
triggers="kernel-hooks"
kernel_hooks_version="${KR}"

do_install() {
	vmkdir boot
	vmkdir usr
	cp -a boot/. \${DESTDIR}/boot/
	cp -a usr/. \${DESTDIR}/usr/
}
EOF
[ "$MARCH" -eq 1 ] && cp "${OUT}/srcpkgs/${TARGET_PKG}/template" "${HERE}/${VDIR}/template"
rm -rf "$PKG"

echo -e "\n${C_G}=====================================================================${C_N}"
echo -e "${C_G}  ${TARGET_PKG} ${KVER} listo  (uname -r: ${KR}, x86-64-v${MARCH})${C_N}"
echo -e "  Tarball : ${OUT}/${TARNAME}"
echo -e "  SHA256  : ${SHA}"
echo -e "  Template: ${OUT}/srcpkgs/${TARGET_PKG}/template"
echo -e "${C_G}=====================================================================${C_N}"
echo "Instalar con xbps-src o vouru:"
echo "  # Detectar ruta de void-packages (~/void-packages o ~/.local/share/pkgs/void-packages)"
echo "  VPKG_DIR=\"\$([ -d \"\$HOME/.local/share/pkgs/void-packages\" ] && echo \"\$HOME/.local/share/pkgs/void-packages\" || echo \"\$HOME/void-packages\")\""
echo "  cp -r ${OUT}/srcpkgs/${TARGET_PKG}   \"\${VPKG_DIR}/srcpkgs/\""
echo "  mkdir -p \"\${VPKG_DIR}/hostdir/sources\""
echo "  cp ${OUT}/${TARNAME} \"\${VPKG_DIR}/hostdir/sources/\""
echo "  cd \"\${VPKG_DIR}\" && ./xbps-src pkg ${TARGET_PKG}"
echo "  sudo xbps-install -R hostdir/binpkgs ${TARGET_PKG}"
