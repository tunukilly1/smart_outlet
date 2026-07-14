#!/bin/bash
set -e

# Install Flutter SDK
git clone https://github.com/flutter/flutter.git --depth 1
export PATH="$PATH:`pwd`/flutter/bin"

# Enable web support
flutter config --enable-web

# Get dependencies
flutter pub get

# Build the web app
flutter build web
