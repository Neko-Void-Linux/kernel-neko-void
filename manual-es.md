### 1. Instalar dependencias correctas para Void Linux

```bash
sudo xbps-install -S base-devel ncurses-devel bison flex bc kmod openssl-devel libelf-devel perl

```

### 2. Clonar el código fuente

```bash
git clone --depth=1 https://github.com/torvalds/linux.git
cd linux

```

*(Añadí `--depth=1` para bajarte solo la última revisión y ahorrarte gigas de descarga y espacio en disco).*

### 3. Configuración del Kernel

En lugar de partir de cero, lo ideal es copiar la configuración que ya está usando tu kernel actual en Void como base, y luego ajustarla:

```bash
# Copia la config actual de tu sistema como punto de partida
cp /boot/config-$(uname -r) .config

# Actualiza la config para la nueva versión respondiendo a lo nuevo
yes "" | make oldconfig

# Opcional: si quieres afinarla con lo que usa tu hardware actual
make localmodconfig

# Opcional: abrir el menú visual para revisar opciones
make menuconfig

```

### 4. Compilación e instalación

Usa tantos núcleos como tenga tu procesador para acelerar el proceso (cambia el `4` por el número de hilos de tu CPU, por ejemplo `-j8` o `-j$(nproc)`).

```bash
# Compilar kernel y módulos
make -j$(nproc)

# Instalar módulos
sudo make modules_install

```

### 5. Copiar imágenes y registrar el kernel

Asegúrate de cambiar `7.3.0-rc7_1+` por la versión real de tu kernel (puedes verla ejecutando `make kernelrelease` dentro de la carpeta del código fuente).

```bash
# Definir la versión en una variable para evitar errores de tipeo (ejemplo)
KV=$(make kernelrelease)

# Copiar archivos a /boot
sudo cp arch/x86/boot/bzImage /boot/vmlinuz-$KV
sudo cp System.map /boot/System.map-$KV
sudo cp .config /boot/config-$KV

# Generar dependencias de módulos
sudo depmod -a $KV

# Generar el initramfs con dracut
sudo dracut --force /boot/initramfs-$KV.img $KV

# Actualizar GRUB
sudo grub-mkconfig -o /boot/grub/grub.cfg

