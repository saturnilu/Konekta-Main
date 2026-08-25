set -e

git clone https://github.com/flutter/flutter.git -b stable --depth 1 _flutter_sdk
export PATH="$PATH:$(pwd)/_flutter_sdk/bin"

flutter config --enable-web
flutter pub get
flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL"

cp build/web/index.html build/web/app.html
cp web/app_frame.html build/web/index.html

echo "Build complete — build/web/index.html is now the phone-frame wrapper, build/web/app.html is the real Flutter app."