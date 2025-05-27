# png2fastfetch

🎨 **Convert PNG logos to ASCII art for FastFetch**

A fast and efficient utility written in D Language that transforms PNG images into beautiful ASCII art compatible with FastFetch display format.

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Language](https://img.shields.io/badge/Language-D-red.svg)](https://dlang.org/)
[![Build System](https://img.shields.io/badge/Build-Meson-green.svg)](https://mesonbuild.com/)

## ✨ Features

- 🖼️ **PNG Support** - Full PNG decoder with support for RGB, RGBA, Grayscale, and Palette formats
- 🎨 **True Color Output** - 24-bit ANSI color support for vibrant ASCII art
- ⚡ **Fast Performance** - Native D language implementation with optimized PNG decoding
- 🔧 **Flexible Sizing** - Customizable output dimensions (1-200 width, 1-100 height)
- 📊 **Verbose Mode** - Detailed statistics and conversion information
- 🎯 **FastFetch Compatible** - Output format specifically designed for FastFetch

## 🚀 Quick Start

### Prerequisites

- **LDC2** (LLVM D Compiler) or **DMD**
- **Meson** build system
- **zlib** development libraries

### Installation

```bash
# Clone the repository
git clone https://github.com/Anmitalidev/png2ff.git
cd png2ff

# Build with Meson
meson setup builddir
meson compile -C builddir

# Install (optional)
sudo meson install -C builddir
```

### Basic Usage

```bash
# Convert PNG to ASCII art
./builddir/png2fastfetch logo.png

# Save to file with distribution name
./builddir/png2fastfetch arch.png -n "Arch Linux" -o arch_logo.txt

# Custom dimensions with verbose output
./builddir/png2fastfetch ubuntu.png -w 40 -h 20 -v

# Disable colors for plain ASCII
./builddir/png2fastfetch fedora.png -c
```

## 📖 Command Line Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--output` | `-o` | Output file (stdout if not specified) | - |
| `--width` | `-w` | ASCII art width | 32 |
| `--height` | `-h` | ASCII art height | 16 |
| `--name` | `-n` | Distribution name for header | - |
| `--no-colors` | `-c` | Disable ANSI colors | false |
| `--verbose` | `-v` | Verbose output with statistics | false |
| `--help` | - | Show help message | - |

## 🎯 Usage Examples

### 1. Basic Conversion
```bash
png2fastfetch archlinux.png
```

### 2. With Distribution Name
```bash
png2fastfetch ubuntu.png -n "Ubuntu" -o ubuntu.txt
```
Creates file with header:
```
# Ubuntu logo for FastFetch
# Generated with png2fastfetch
# https://github.com/Anmitalidev/png2ff

[colored ASCII art]
```

### 3. Custom Dimensions
```bash
png2fastfetch logo.png -w 24 -h 12
```

### 4. Verbose Mode
```bash
png2fastfetch debian.png -v
```
Output:
```
→ Loading PNG image: debian.png
→ Original size: 128x128
→ Color type: 2, Bit depth: 8
→ Target size: 32x16
→ Image resized successfully
→ Generating FastFetch ASCII art...
→ Statistics:
  Total pixels: 512
  Transparent: 45 (8.8%)
  Character distribution:
    ' ': 45 (8.8%)
    '░': 89 (17.4%)
    '▒': 134 (26.2%)
    '▓': 156 (30.5%)
    '█': 88 (17.2%)
✓ Conversion completed successfully!
  Input: debian.png
  Dimensions: 32x16
  Colors: enabled
```

## 🖼️ Recommended Image Specifications

### Ideal Sizes
- **128x128 pixels** - Square logos (Arch, Ubuntu, Fedora)
- **256x128 pixels** - Horizontal logos
- **128x256 pixels** - Vertical logos

### Image Quality Tips
- ✅ **High contrast** - Bright colors on dark background or vice versa
- ✅ **Simple shapes** - Clear contours, minimal small details
- ✅ **Clean background** - Transparent or solid color background
- ❌ **Avoid** - Low contrast, complex gradients, busy backgrounds

## 🏗️ Building from Source

### Manual Compilation
```bash
# Direct compilation with LDC2
ldc2 -release -O source/app.d -of=png2fastfetch

# Or with DMD
dmd -release -O source/app.d -of=png2fastfetch
```

### Development Build
```bash
# Debug build
meson setup builddir --buildtype=debug
meson compile -C builddir

# Release build
meson setup builddir --buildtype=release
meson compile -C builddir
```

## 🧪 System Requirements

### Minimum Requirements
- **Operating System:** Linux, macOS, Windows
- **Compiler:** LDC2 ≥ 1.30.0 or DMD ≥ 2.100.0
- **Memory:** 16 MB RAM
- **Storage:** 5 MB free space

### Dependencies
- **zlib** - For PNG decompression
- **Meson** ≥ 0.55.0 - Build system
- **Standard D libraries** - Included with compiler

## 🐛 Troubleshooting

### Common Issues

**"Failed to load PNG"**
```bash
# Check if file exists and is valid PNG
file your-image.png
```

**"Unsupported color type"**
```bash
# Convert to supported format
convert input.png -type TrueColor output.png
```

**Compilation errors**
```bash
# Ensure all dependencies are installed
sudo apt install ldc meson libz-dev  # Ubuntu/Debian
sudo pacman -S ldc meson zlib        # Arch Linux
```

## 📄 License

This project is licensed under the **Apache License 2.0** - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**AnmiTaliDev**
- GitHub: [@Anmitalidev](https://github.com/Anmitalidev)
- Repository: [png2ff](https://github.com/Anmitalidev/png2ff)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 🌟 Acknowledgments

- [FastFetch](https://github.com/fastfetch-cli/fastfetch) - The amazing system information tool
- [D Language](https://dlang.org/) - For the powerful and efficient programming language
- [Meson](https://mesonbuild.com/) - For the excellent build system

---

⭐ **Star this repository if you find it useful!**