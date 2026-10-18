### 1. Install correct dependencies for Void Linux

```bash
sudo xbps-install -S base-devel ncurses-devel bison flex bc kmod openssl-devel libelf-devel perl


```

### 2. Clone the source code

```bash
git clone --depth=1 [https://github.com/torvalds/linux.git](https://github.com/torvalds/linux.git)
cd linux


```

*(Added `--depth=1` to download only the latest revision and save gigabytes of download and disk space).*

### 3. Kernel Configuration

Instead of starting from scratch, the ideal approach is to copy the configuration your current Void kernel is already using as a base, and then tweak it:

```bash
# Copy your system's current config as a starting point
cp /boot/config-$(uname -r) .config

# Update the config for the new version by accepting defaults for new options
yes "" | make oldconfig

# Optional: if you want to trim it down to what your current hardware uses
make localmodconfig

# Optional: open the visual menu to review options
make menuconfig


```

### 4. Compilation and Installation

Use as many cores as your processor has to speed up the process (replace `4` with the number of CPU threads, for example `-j8` or `-j$(nproc)`).

```bash
# Compile kernel and modules
make -j$(nproc)

# Install modules
sudo make modules_install


```

### 5. Copy images and register the kernel

Make sure to replace `7.3.0-rc7_1+` with your actual kernel version (you can check it by running `make kernelrelease` inside the source code folder).

```bash
# Define the version in a variable to avoid typos (example)
KV=$(make kernelrelease)

# Copy files to /boot
sudo cp arch/x86/boot/bzImage /boot/vmlinuz-$KV
sudo cp System.map /boot/System.map-$KV
sudo cp .config /boot/config-$KV

# Generate module dependencies
sudo depmod -a $KV

# Generate the initramfs with dracut
sudo dracut --force /boot/initramfs-$KV.img $KV

# Update GRUB
sudo grub-mkconfig -o /boot/grub/grub.cfg
