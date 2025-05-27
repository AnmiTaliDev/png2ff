/*
 * png2fastfetch - Convert PNG logos to ASCII art for FastFetch
 * 
 * Copyright 2025 AnmiTaliDev
 * Licensed under the Apache License, Version 2.0
 * Repository: https://github.com/Anmitalidev/png2ff
 */

import std.stdio;
import std.getopt;
import std.file;
import std.path;
import std.string;
import std.conv;
import std.algorithm;
import std.range;
import std.format;
import std.math;
import std.bitmanip;
import std.exception;
import std.zlib;

// PNG structures and classes
struct PNGImage {
    uint width;
    uint height;
    ubyte[] pixels; // RGB format: [R, G, B, R, G, B, ...]
    ubyte bitDepth;
    ubyte colorType;
    ubyte channels;
}

class PNGException : Exception {
    this(string msg) {
        super(msg);
    }
}

// PNG color types
enum ColorType : ubyte {
    GRAYSCALE = 0,
    RGB = 2,
    PALETTE = 3,
    GRAYSCALE_ALPHA = 4,
    RGBA = 6
}

// PNG filter types
enum FilterType : ubyte {
    NONE = 0,
    SUB = 1,
    UP = 2,
    AVERAGE = 3,
    PAETH = 4
}

// Helper function to read big-endian uint
uint readBigEndianUint(ubyte[] data) {
    if (data.length < 4) {
        throw new PNGException("Insufficient data for uint");
    }
    return (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
}

PNGImage loadPNG(string filename) {
    ubyte[] data = cast(ubyte[])std.file.read(filename);
    return decodePNG(data);
}

PNGImage decodePNG(ubyte[] data) {
    if (data.length < 8) {
        throw new PNGException("File too small to be PNG");
    }
    
    // Check PNG signature
    ubyte[8] pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (data[0..8] != pngSignature) {
        throw new PNGException("Not a valid PNG file");
    }
    
    PNGImage img;
    size_t pos = 8;
    ubyte[] imageData;
    ubyte[] palette;
    bool foundIHDR = false;
    
    while (pos < data.length) {
        if (pos + 8 > data.length) break;
        
        uint chunkLength = readBigEndianUint(data[pos..pos+4]);
        string chunkType = cast(string)data[pos+4..pos+8];
        
        if (pos + 8 + chunkLength + 4 > data.length) {
            throw new PNGException("Corrupted PNG: chunk extends beyond file");
        }
        
        ubyte[] chunkData = data[pos+8..pos+8+chunkLength];
        
        switch (chunkType) {
            case "IHDR":
                if (chunkLength != 13) {
                    throw new PNGException("Invalid IHDR chunk size");
                }
                
                img.width = readBigEndianUint(chunkData[0..4]);
                img.height = readBigEndianUint(chunkData[4..8]);
                img.bitDepth = chunkData[8];
                img.colorType = chunkData[9];
                ubyte compression = chunkData[10];
                ubyte filter = chunkData[11];
                ubyte interlace = chunkData[12];
                
                if (compression != 0) {
                    throw new PNGException("Unsupported compression method");
                }
                if (filter != 0) {
                    throw new PNGException("Unsupported filter method");
                }
                if (interlace != 0) {
                    throw new PNGException("Interlaced PNG not supported");
                }
                
                // Set channels based on color type
                switch (img.colorType) {
                    case ColorType.GRAYSCALE:
                        img.channels = 1;
                        break;
                    case ColorType.RGB:
                        img.channels = 3;
                        break;
                    case ColorType.PALETTE:
                        img.channels = 1;
                        break;
                    case ColorType.GRAYSCALE_ALPHA:
                        img.channels = 2;
                        break;
                    case ColorType.RGBA:
                        img.channels = 4;
                        break;
                    default:
                        throw new PNGException("Unsupported color type");
                }
                
                foundIHDR = true;
                break;
                
            case "PLTE":
                if (chunkLength % 3 != 0) {
                    throw new PNGException("Invalid palette chunk size");
                }
                palette = chunkData.dup;
                break;
                
            case "IDAT":
                imageData ~= chunkData;
                break;
                
            case "IEND":
                pos = data.length; // End of file
                break;
                
            default:
                // Skip unknown chunks
                break;
        }
        
        pos += 8 + chunkLength + 4; // chunk length + type + data + CRC
    }
    
    if (!foundIHDR) {
        throw new PNGException("Missing IHDR chunk");
    }
    
    if (img.width == 0 || img.height == 0) {
        throw new PNGException("Invalid image dimensions");
    }
    
    if (imageData.length == 0) {
        throw new PNGException("No image data found");
    }
    
    // Decompress and decode image data
    img.pixels = decompressAndDecodeImageData(imageData, img, palette);
    
    return img;
}

ubyte[] decompressAndDecodeImageData(ubyte[] compressedData, PNGImage img, ubyte[] palette) {
    // Decompress using zlib
    ubyte[] decompressed;
    try {
        decompressed = cast(ubyte[])std.zlib.uncompress(compressedData);
    } catch (Exception e) {
        throw new PNGException("Failed to decompress image data: " ~ e.msg);
    }
    
    // Calculate bytes per pixel and scanline
    uint bytesPerPixel = (img.channels * img.bitDepth + 7) / 8;
    uint scanlineLength = (img.width * img.channels * img.bitDepth + 7) / 8;
    uint expectedDataSize = img.height * (scanlineLength + 1); // +1 for filter byte
    
    if (decompressed.length < expectedDataSize) {
        throw new PNGException("Insufficient decompressed data");
    }
    
    // Remove filters and convert to RGB
    ubyte[] result;
    ubyte[] previousScanline = new ubyte[scanlineLength];
    
    for (uint row = 0; row < img.height; row++) {
        uint scanlineStart = row * (scanlineLength + 1);
        ubyte filterType = decompressed[scanlineStart];
        ubyte[] currentScanline = decompressed[scanlineStart + 1 .. scanlineStart + 1 + scanlineLength];
        
        // Apply filter
        applyFilter(currentScanline, previousScanline, filterType, bytesPerPixel);
        
        // Convert scanline to RGB
        ubyte[] rgbScanline = convertScanlineToRGB(currentScanline, img, palette);
        result ~= rgbScanline;
        
        previousScanline = currentScanline.dup;
    }
    
    return result;
}

void applyFilter(ubyte[] current, ubyte[] previous, ubyte filterType, uint bytesPerPixel) {
    switch (filterType) {
        case FilterType.NONE:
            // No filtering
            break;
            
        case FilterType.SUB:
            for (uint i = bytesPerPixel; i < current.length; i++) {
                current[i] = cast(ubyte)((current[i] + current[i - bytesPerPixel]) & 0xFF);
            }
            break;
            
        case FilterType.UP:
            for (uint i = 0; i < current.length; i++) {
                current[i] = cast(ubyte)((current[i] + previous[i]) & 0xFF);
            }
            break;
            
        case FilterType.AVERAGE:
            for (uint i = 0; i < current.length; i++) {
                ubyte a = (i >= bytesPerPixel) ? current[i - bytesPerPixel] : 0;
                ubyte b = previous[i];
                current[i] = cast(ubyte)((current[i] + ((a + b) / 2)) & 0xFF);
            }
            break;
            
        case FilterType.PAETH:
            for (uint i = 0; i < current.length; i++) {
                ubyte a = (i >= bytesPerPixel) ? current[i - bytesPerPixel] : 0;
                ubyte b = previous[i];
                ubyte c = (i >= bytesPerPixel) ? previous[i - bytesPerPixel] : 0;
                current[i] = cast(ubyte)((current[i] + paethPredictor(a, b, c)) & 0xFF);
            }
            break;
            
        default:
            throw new PNGException("Unknown filter type: " ~ filterType.to!string);
    }
}

ubyte paethPredictor(ubyte a, ubyte b, ubyte c) {
    int p = a + b - c;
    int pa = abs(p - a);
    int pb = abs(p - b);
    int pc = abs(p - c);
    
    if (pa <= pb && pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
}

ubyte[] convertScanlineToRGB(ubyte[] scanline, PNGImage img, ubyte[] palette) {
    ubyte[] result;
    
    switch (img.colorType) {
        case ColorType.GRAYSCALE:
            if (img.bitDepth == 8) {
                foreach (gray; scanline) {
                    result ~= [gray, gray, gray];
                }
            } else if (img.bitDepth == 1) {
                for (uint i = 0; i < scanline.length; i++) {
                    ubyte byte_val = scanline[i];
                    for (int bit = 7; bit >= 0; bit--) {
                        if (result.length >= img.width * 3) break;
                        ubyte gray = ((byte_val >> bit) & 1) ? 255 : 0;
                        result ~= [gray, gray, gray];
                    }
                }
            } else {
                throw new PNGException("Unsupported grayscale bit depth: " ~ img.bitDepth.to!string);
            }
            break;
            
        case ColorType.RGB:
            if (img.bitDepth == 8) {
                result = scanline.dup;
            } else {
                throw new PNGException("Unsupported RGB bit depth: " ~ img.bitDepth.to!string);
            }
            break;
            
        case ColorType.PALETTE:
            if (palette.length == 0) {
                throw new PNGException("Missing palette for indexed color");
            }
            
            if (img.bitDepth == 8) {
                foreach (index; scanline) {
                    if (index * 3 + 2 < palette.length) {
                        result ~= palette[index * 3 .. index * 3 + 3];
                    } else {
                        result ~= [0, 0, 0]; // Black for invalid indices
                    }
                }
            } else {
                throw new PNGException("Unsupported palette bit depth: " ~ img.bitDepth.to!string);
            }
            break;
            
        case ColorType.GRAYSCALE_ALPHA:
            if (img.bitDepth == 8) {
                for (uint i = 0; i < scanline.length; i += 2) {
                    ubyte gray = scanline[i];
                    // Ignore alpha for now, just convert to RGB
                    result ~= [gray, gray, gray];
                }
            } else {
                throw new PNGException("Unsupported grayscale+alpha bit depth: " ~ img.bitDepth.to!string);
            }
            break;
            
        case ColorType.RGBA:
            if (img.bitDepth == 8) {
                for (uint i = 0; i < scanline.length; i += 4) {
                    // Convert RGBA to RGB, ignore alpha
                    result ~= scanline[i .. i + 3];
                }
            } else {
                throw new PNGException("Unsupported RGBA bit depth: " ~ img.bitDepth.to!string);
            }
            break;
            
        default:
            throw new PNGException("Unsupported color type: " ~ img.colorType.to!string);
    }
    
    return result;
}

// Helper function for absolute value
int abs(int x) {
    return x < 0 ? -x : x;
}

// Application structures
struct Config {
    string inputFile;
    string outputFile;
    int width = 32;
    int height = 16;
    bool verbose = false;
    bool useColors = true;
    string distroName;
}

struct RGB {
    ubyte r, g, b;
    
    string toAnsiColor() const {
        return format("\033[38;2;%d;%d;%dm", r, g, b);
    }
    
    dchar toBrailleChar() const {
        // Convert RGB to grayscale and map to block characters
        ubyte gray = cast(ubyte)((r * 0.299 + g * 0.587 + b * 0.114));
        if (gray < 32) return ' ';
        if (gray < 64) return '░';
        if (gray < 128) return '▒';
        if (gray < 192) return '▓';
        return '█';
    }
    
    bool isTransparent() const {
        // Consider very dark pixels as transparent for better ASCII art
        return (r + g + b) < 30;
    }
}

void printUsage() {
    writeln("Usage: png2fastfetch [OPTIONS] <input.png>");
    writeln();
    writeln("Options:");
    writeln("  -o, --output FILE    Output file (default: stdout)");
    writeln("  -w, --width WIDTH    ASCII width (default: 32)");
    writeln("  -h, --height HEIGHT  ASCII height (default: 16)");
    writeln("  -n, --name NAME      Distribution name");
    writeln("  -c, --no-colors      Disable ANSI colors");
    writeln("  -v, --verbose        Verbose output");
    writeln("      --help           Show this help");
    writeln();
    writeln("Examples:");
    writeln("  png2fastfetch arch.png -n \"Arch Linux\" -o arch.txt");
    writeln("  png2fastfetch ubuntu.png -w 24 -h 12 > ubuntu_logo.txt");
    writeln("  png2fastfetch fedora.png -c -w 20 -h 10");
}

RGB[][] loadAndResizeImage(string filename, int targetWidth, int targetHeight, bool verbose) {
    if (verbose) {
        writefln("\033[1;33m→\033[0m Loading PNG image: %s", filename);
    }
    
    PNGImage img;
    try {
        img = loadPNG(filename);
    } catch (Exception e) {
        stderr.writefln("\033[1;31mError:\033[0m Failed to load PNG: %s", e.msg);
        throw e;
    }
    
    if (verbose) {
        writefln("\033[1;33m→\033[0m Original size: %dx%d", img.width, img.height);
        writefln("\033[1;33m→\033[0m Color type: %d, Bit depth: %d", img.colorType, img.bitDepth);
        writefln("\033[1;33m→\033[0m Target size: %dx%d", targetWidth, targetHeight);
    }
    
    // Validate image data
    size_t expectedPixels = img.width * img.height * 3; // RGB format
    if (img.pixels.length < expectedPixels) {
        throw new Exception("Insufficient pixel data in image");
    }
    
    // Simple nearest-neighbor resize with improved sampling
    RGB[][] result = new RGB[][](targetHeight, targetWidth);
    
    double scaleX = cast(double)img.width / targetWidth;
    double scaleY = cast(double)img.height / targetHeight;
    
    for (int y = 0; y < targetHeight; y++) {
        for (int x = 0; x < targetWidth; x++) {
            // Use center sampling for better quality
            double srcXf = (x + 0.5) * scaleX - 0.5;
            double srcYf = (y + 0.5) * scaleY - 0.5;
            
            int srcX = cast(int)(srcXf + 0.5); // Round to nearest
            int srcY = cast(int)(srcYf + 0.5);
            
            // Clamp to image bounds
            srcX = max(0, min(srcX, cast(int)img.width - 1));
            srcY = max(0, min(srcY, cast(int)img.height - 1));
            
            size_t pixelIndex = (srcY * img.width + srcX) * 3;
            
            // Safety check
            if (pixelIndex + 2 < img.pixels.length) {
                result[y][x] = RGB(
                    img.pixels[pixelIndex],     // R
                    img.pixels[pixelIndex + 1], // G
                    img.pixels[pixelIndex + 2]  // B
                );
            } else {
                // Fallback to black if index is out of bounds
                result[y][x] = RGB(0, 0, 0);
            }
        }
    }
    
    if (verbose) {
        writefln("\033[1;33m→\033[0m Image resized successfully");
    }
    
    return result;
}

string generateFastFetchArt(RGB[][] pixels, Config config) {
    string result;
    
    // Add header comments if distribution name is provided
    if (config.distroName.length > 0) {
        result ~= format("# %s logo for FastFetch\n", config.distroName);
        result ~= "# Generated with png2fastfetch\n";
        result ~= "# https://github.com/Anmitalidev/png2ff\n";
        result ~= "#\n";
    }
    
    foreach (size_t rowIndex, row; pixels) {
        string line;
        RGB lastColor = RGB(255, 255, 255);
        bool colorChanged = false;
        
        foreach (pixel; row) {
            // Handle transparent pixels
            if (pixel.isTransparent()) {
                if (config.useColors && colorChanged) {
                    line ~= "\033[0m"; // Reset color for transparent areas
                    colorChanged = false;
                }
                line ~= ' ';
                lastColor = RGB(255, 255, 255); // Reset to default
                continue;
            }
            
            // Apply color if enabled and color changed
            if (config.useColors && (pixel.r != lastColor.r || pixel.g != lastColor.g || pixel.b != lastColor.b)) {
                line ~= pixel.toAnsiColor();
                lastColor = pixel;
                colorChanged = true;
            }
            
            line ~= pixel.toBrailleChar();
        }
        
        // Reset color at end of line if colors were used
        if (config.useColors && colorChanged) {
            line ~= "\033[0m";
        }
        
        result ~= line ~ "\n";
    }
    
    return result;
}

void printStats(RGB[][] pixels, bool verbose) {
    if (!verbose) return;
    
    size_t totalPixels = 0;
    size_t transparentPixels = 0;
    uint[dchar] charCounts;
    
    foreach (row; pixels) {
        foreach (pixel; row) {
            totalPixels++;
            if (pixel.isTransparent()) {
                transparentPixels++;
            }
            dchar c = pixel.toBrailleChar();
            if (c in charCounts) {
                charCounts[c]++;
            } else {
                charCounts[c] = 1;
            }
        }
    }
    
    writefln("\033[1;33m→\033[0m Statistics:");
    writefln("  Total pixels: %d", totalPixels);
    writefln("  Transparent: %d (%.1f%%)", transparentPixels, 
             (cast(double)transparentPixels / totalPixels) * 100);
    
    writeln("  Character distribution:");
    foreach (c; [' ', '░', '▒', '▓', '█']) {
        if (c in charCounts) {
            uint count = charCounts[c];
            writefln("    '%c': %d (%.1f%%)", c, count, 
                     (cast(double)count / totalPixels) * 100);
        }
    }
}

int main(string[] args) {
    Config config;
    bool showHelp = false;
    
    try {
        auto helpInformation = getopt(args,
            "output|o", "Output file", &config.outputFile,
            "width|w", "ASCII width", &config.width,
            "height|h", "ASCII height", &config.height,
            "name|n", "Distribution name", &config.distroName,
            "no-colors|c", "Disable ANSI colors", () { config.useColors = false; },
            "verbose|v", "Verbose output", &config.verbose,
            "help", "Show help", &showHelp
        );
        
        if (showHelp || helpInformation.helpWanted) {
            printUsage();
            return 0;
        }
        
        if (args.length < 2) {
            stderr.writeln("\033[1;31mError:\033[0m No input file specified!");
            printUsage();
            return 1;
        }
        
        config.inputFile = args[1];
        
        // Validate arguments
        if (config.width <= 0 || config.width > 200) {
            stderr.writeln("\033[1;31mError:\033[0m Width must be between 1 and 200");
            return 1;
        }
        
        if (config.height <= 0 || config.height > 100) {
            stderr.writeln("\033[1;31mError:\033[0m Height must be between 1 and 100");
            return 1;
        }
        
    } catch (Exception e) {
        stderr.writefln("\033[1;31mError:\033[0m %s", e.msg);
        return 1;
    }
    
    // Check if input file exists
    if (!exists(config.inputFile)) {
        stderr.writefln("\033[1;31mError:\033[0m File not found: %s", config.inputFile);
        return 1;
    }
    
    // Check if input file has PNG extension
    if (!config.inputFile.toLower().endsWith(".png")) {
        stderr.writefln("\033[1;31mWarning:\033[0m File doesn't have .png extension: %s", config.inputFile);
    }
    
    try {
        // Load and process image
        RGB[][] pixels = loadAndResizeImage(config.inputFile, config.width, config.height, config.verbose);
        
        if (config.verbose) {
            writeln("\033[1;33m→\033[0m Generating FastFetch ASCII art...");
        }
        
        // Generate ASCII art
        string asciiArt = generateFastFetchArt(pixels, config);
        
        // Print statistics if verbose
        printStats(pixels, config.verbose);
        
        // Output result
        if (config.outputFile.length > 0) {
            try {
                std.file.write(config.outputFile, asciiArt);
                if (config.verbose) {
                    writefln("\033[1;32m✓\033[0m ASCII art saved to: %s", config.outputFile);
                    writefln("  File size: %d bytes", asciiArt.length);
                }
            } catch (Exception e) {
                stderr.writefln("\033[1;31mError:\033[0m Failed to write output file: %s", e.msg);
                return 1;
            }
        } else {
            write(asciiArt);
        }
        
        if (config.verbose) {
            writefln("\033[1;32m✓\033[0m Conversion completed successfully!");
            writefln("  Input: %s", config.inputFile);
            writefln("  Dimensions: %dx%d", config.width, config.height);
            writefln("  Colors: %s", config.useColors ? "enabled" : "disabled");
            if (config.distroName.length > 0) {
                writefln("  Distribution: %s", config.distroName);
            }
        }
        
    } catch (Exception e) {
        stderr.writefln("\033[1;31mError:\033[0m %s", e.msg);
        return 1;
    }
    
    return 0;
}