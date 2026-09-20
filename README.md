# kernel-neko-void
- Workflows of Neko Void for builds kernels
<img width="1280" height="768" alt="image" src="https://github.com/user-attachments/assets/74c14b59-c9c8-4422-b834-cc789f64d738" />




#  MANUAL BUILD ON VOID:

# KERNEL ZEN 
```
xbps-install -Syu --repository=https://repo-de.voidlinux.org/current/ base-devel git bc kmod elfutils-devel bash cpio xz lz4 zstd flex bison openssl-devel curl pahole tar python3 patch wget rsync -y
git clone --depth 1 --branch v7.1.2-zen3 https://github.com/zen-kernel/zen-kernel.git linux-src
cd linux-src
wget -O .config https://raw.githubusercontent.com/void-linux/void-packages/master/srcpkgs/linux7.1/files/x86_64-dotconfig

# Evitar sufijo -dirty (por si acaso)
scripts/config --disable CONFIG_LOCALVERSION_AUTO
scripts/config --set-str CONFIG_LOCALVERSION "-neko"
# Optimizaciones
scripts/config --enable CONFIG_CC_OPTIMIZE_FOR_SIZE
scripts/config --enable CONFIG_MODULE_COMPRESS_ZSTD
          
# Desactivar debug masivo
scripts/config --disable CONFIG_DEBUG_INFO \
                         --disable CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT \
                         --disable CONFIG_DEBUG_INFO_REDUCED \
                         --disable CONFIG_DEBUG_INFO_BTF \
                         --disable CONFIG_DEBUG_VM \
                         --disable CONFIG_DEBUG_KERNEL \
                         --disable CONFIG_PROVE_LOCKING \
                         --disable CONFIG_LOCK_STAT \
                         --disable CONFIG_LATENCYTOP

# Desactivar firma de módulos
scripts/config --disable CONFIG_MODULE_SIG
scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
          
# Actualizar configuración (incorpora nuevas opciones)
make olddefconfig
make -j$(nproc) prepare
make -j$(nproc) bzImage modules V=1 2>&1 | tee ../build.log
```

# KERNEL LIQUORIX
Liquorix se construye sobre el kernel estable de Linux con su parche Zen/PDS y su configuración oficial. Esta variante no activa `PREEMPT_RT`; es un kernel de baja latencia para escritorio y juegos.
```bash
# DEPENDENCIES
xbps-install -Syu --repository=https://repo-de.voidlinux.org/current/ base-devel git bc kmod elfutils-devel bash cpio xz lz4 zstd flex bison openssl-devel curl pahole tar python3 patch wget rsync perl gettext -y

# KERNEL BASE Y PAQUETE DE PARCHES LIQUORIX
git clone --depth 1 --branch v7.2.6 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux-src
wget -O liquorix-package.tar.gz https://github.com/damentz/liquorix-package/archive/refs/heads/7.2/master.tar.gz
tar -xzf liquorix-package.tar.gz
LIQUORIX_TREE=$(find . -type d -path '*/linux-liquorix/debian/patches' -print -quit | sed 's#/linux-liquorix/debian/patches##')

cd linux-src
LIQUORIX_PATCHES="../${LIQUORIX_TREE}/linux-liquorix/debian/patches"
grep -E '^(zen|lqx)/' "${LIQUORIX_PATCHES}/series" | while IFS= read -r patch_name; do
    patch -Np1 --batch < "${LIQUORIX_PATCHES}/${patch_name}"
done

# CONFIGURACIÓN OFICIAL DE LIQUORIX
wget -O .config https://raw.githubusercontent.com/damentz/liquorix-package/7.2/master/linux-liquorix/debian/config/kernelarch-x86/config-arch-64
wget -O fixdep-largefile.patch https://github.com/void-linux/void-packages/raw/refs/heads/master/srcpkgs/linux7.2/patches/fixdep-largefile.patch
patch -p1 -N --batch < fixdep-largefile.patch || true

# IDENTIFICACIÓN DE NEKO VOID Y AJUSTES DE MÓDULOS
scripts/config --disable CONFIG_LOCALVERSION_AUTO
scripts/config --set-str CONFIG_LOCALVERSION ""
scripts/config --enable CONFIG_SCHED_ALT --enable CONFIG_SCHED_PDS
scripts/config --disable CONFIG_PREEMPT_RT --enable CONFIG_PREEMPT
printf '%s\n' "-1" > localversion.10-pkgrel
printf '%s\n' "-lqx-neko" > localversion.20-pkgname
scripts/config --enable CONFIG_MODULES --enable CONFIG_MODVERSIONS --enable CONFIG_MODULE_UNLOAD
scripts/config --enable CONFIG_MODULE_COMPRESS --disable CONFIG_MODULE_COMPRESS_GZIP --enable CONFIG_MODULE_COMPRESS_ZSTD
scripts/config --disable CONFIG_MODULE_SIG
scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
scripts/config --disable CONFIG_DEBUG_INFO --disable CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT --disable CONFIG_DEBUG_INFO_REDUCED --disable CONFIG_DEBUG_INFO_BTF
scripts/config --disable CONFIG_HZ_300 --enable CONFIG_HZ_1000 --set-val CONFIG_HZ 1000

make olddefconfig
make -j$(nproc) prepare
make -j$(nproc) bzImage modules V=1 2>&1 | tee ../build.log
```

# KERNEL CACHYOS 
```bash
# DEPENDENCIES
xbps-install -Syu --repository=https://repo-de.voidlinux.org/current/ base-devel git bc kmod elfutils-devel bash cpio xz lz4 zstd flex bison openssl-devel curl pahole tar python3 patch wget rsync -y

# CLONE REPO
git clone --depth 1 --branch v7.1 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux-src
cd linux-src
sed -i 's/^EXTRAVERSION =.*/EXTRAVERSION = -cachy/' Makefile

# Apply config
wget -O .config https://codeberg.org/javiercplus/cachy-void/raw/branch/main/config
wget -O fixdep-largefile.patch https://github.com/void-linux/void-packages/raw/refs/heads/master/srcpkgs/linux7.1/patches/fixdep-largefile.patch
patch -p1 -N --batch < fixdep-largefile.patch
make olddefconfig
          
# Compile
make -j$(nproc) 
make -j$(nproc) bzImage modules 

# Install
make install
```

# REALTIME KERNEL
``` 
xbps-install -Syu --repository=https://repo-de.voidlinux.org/current/ base-devel git bc kmod elfutils-devel bash cpio xz lz4 zstd flex bison openssl-devel curl pahole tar python3 patch wget rsync -y
git clone --depth 1 --branch v7.1 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux-src
cd linux-src
# Cambiar EXTRAVERSION de -rc4 a -rt
sed -i 's/^EXTRAVERSION =.*/EXTRAVERSION = -neko/' Makefile
wget -O .config https://github.com/void-linux/void-packages/raw/refs/heads/master/srcpkgs/linux7.1/files/x86_64-dotconfig
wget -O fixdep-largefile.patch https://github.com/void-linux/void-packages/raw/refs/heads/master/srcpkgs/linux7.1/patches/fixdep-largefile.patch
patch -p1 -N --batch < fixdep-largefile.patch
# Desactivar la generación automática de versión git para evitar -dirty
scripts/config --disable CONFIG_LOCALVERSION_AUTO
# Establecer LOCALVERSION con el identificador deseado (ej: -neko)
scripts/config --set-str CONFIG_LOCALVERSION "-neko"
          
# Frecuencia de reloj 1000 Hz
scripts/config -d CONFIG_HZ_300 -e CONFIG_HZ_1000 --set-val CONFIG_HZ 1000
scripts/config -d CONFIG_HZ_PERIODIC -d CONFIG_NO_HZ_IDLE -e CONFIG_NO_HZ_FULL -e CONFIG_NO_HZ
          
# Compresión ZSTD para módulos
scripts/config -e CONFIG_MODULE_COMPRESS_ZSTD
          
# Hugepages always (mejor rendimiento)
scripts/config -d CONFIG_TRANSPARENT_HUGEPAGE_MADVISE -e CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS
          
# Activar RT (PREEMPT_RT)
scripts/config -d CONFIG_PREEMPT_VOLUNTARY
scripts/config -d CONFIG_PREEMPT_LL
scripts/config -d CONFIG_PREEMPT_NONE
scripts/config -e CONFIG_PREEMPT_RT
          
# Desactivar debug masivo
scripts/config --disable CONFIG_DEBUG_INFO \
               --disable CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT \
                --disable CONFIG_DEBUG_INFO_REDUCED \
                --disable CONFIG_DEBUG_INFO_BTF \
                --disable CONFIG_DEBUG_VM \
                 --disable CONFIG_DEBUG_KERNEL \
                 --disable CONFIG_PROVE_LOCKING \
                 --disable CONFIG_LOCK_STAT \
                  --disable CONFIG_LATENCYTOP
          
# Desactivar firma de módulos (evita problemas con certificados)
scripts/config --disable CONFIG_MODULE_SIG
scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
          
# Actualizar configuración (incorpora nuevas opciones de los parches)
make olddefconfig
make -j$(nproc) prepare V=1
make -j$(nproc) bzImage modules V=1 2>&1 | tee ../build.log
``` 
