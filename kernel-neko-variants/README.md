# Kernel-Neko

Colección completa y centralizada de kernels optimizados para **Neko Void Linux**.

## Variantes Disponibles

| Carpeta de Variante | Planificador / Núcleo | Enfoque / Uso Principal |
| :--- | :--- | :--- |
| **`Kernel-Neko-zen`** | **Zen** | Interactividad y respuesta de escritorio (Zen patches) |
| **`Kernel-Neko-liquorix`**| **Liquorix (PDS/Zen)** | Baja latencia para multimedia, escritorio y juegos |
| **`Kernel-Neko-rt`** | **PREEMPT_RT** | Tiempo real estricto para baja latencia crítica |
| **`Kernel-Neko-lite`** | **LTS 6.12** | Ultra-ligero para PCs antiguas y de 1GB RAM (Loc-OS style) |
| **`Kernel-Neko-bore`** | **BORE** | Prioridad dinámica a tareas interactivas de escritorio |
| **`Kernel-Neko-bmq`** | **BMQ (Project C)** | Baja latencia con cola O(1) para procesadores de 2 a 8 núcleos |
| **`Kernel-Neko-lts`** | **LTS 6.18** | Soporte prolongado con parches de rendimiento |
| **`Kernel-Neko-rt-bore`**| **Realtime + BORE** | Combinación de tiempo real estricto y BORE |
| **`Kernel-Neko`** | **EEVDF estándar** | Kernel base afinado para rendimiento general |
| **`Kernel-Neko-hardened`**| **Hardened** | Mitigación avanzada de vulnerabilidades y seguridad |
| **`Kernel-Neko-deckify`**| **Deckify** | Optimizado para consolas y dispositivos portátiles |
| **`Kernel-Neko-server`** | **Server** | Rendimiento y cálculo continuo para servidores |
| **`Kernel-Neko-rc`** | **Release Candidate**| Pruebas de las últimas ramas upstream del kernel |

## Estructura de Cada Variante

Cada carpeta de variante incluye:
- `config`: Archivo de configuración oficial del kernel.
- `template`: Plantilla nativa para empaquetado `.xbps` con `xbps-src` en Void Linux.
- `PKGBUILD` y `.SRCINFO`: Especificaciones estandarizadas del paquete.
