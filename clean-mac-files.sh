#!/bin/bash

# Find and delete all .DS_Store files
find . -name ".DS_Store" -delete

# Find and delete all resource fork files
find . -name "._*" -delete

# Find and delete any Windows specific files that might cause issues
find . -name "*.ico" -delete

# Clean up build artifacts
rm -rf obj-*
rm -rf nginx-headers
rm -f *.o *.so

echo "Cleaned up all macOS and Windows specific files"
