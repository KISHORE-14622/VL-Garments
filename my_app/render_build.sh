#!/bin/bash
# Render Build Script for Flutter Web
echo "Downloading Flutter SDK..."
git clone https://github.com/flutter/flutter.git -b stable

echo "Adding Flutter to PATH..."
export PATH="$PATH:`pwd`/flutter/bin"

echo "Enabling Web..."
flutter config --enable-web

echo "Getting dependencies..."
flutter pub get

echo "Building web app..."
flutter build web --release
