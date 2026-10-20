# RiceGrade

Flutter app + Python backend that grades rice from a photo (whole vs broken grains, grain size, grade).

## Stack
- App: Flutter/Dart, Material 3, go_router, Riverpod, free packages only. Target: Android tablet, responsive, light/dark.
- Backend: Python 3, OpenCV 4, numpy, FastAPI. Hosted free on Hugging Face Spaces.
- Algorithm: grayscale, threshold, watershed to split touching grains, contour area/length/breadth, classify whole vs broken, grade.

## Structure
- `app/lib/` : `theme/`, `routes/`, `features/<name>/` (screen, provider, widgets), `services/api_service.dart`
- `backend/` : `main.py` (API), `analyzer.py` (OpenCV pipeline), `requirements.txt`
- Theme, colors, and spacing live in `app/lib/theme/` only. Never hardcode styles in widgets.

## Rules
- Answer first, max 2 sentences of explanation.
- Output only changed code (snippets/diffs) unless a full file is requested.
- Ask one question if the request is ambiguous.
- Don't explain basic Flutter/Python concepts unless asked.
- Every screen needs loading, empty, and error states.
- Don't read the whole repo. Ask for specific file names.
- Run `flutter analyze` and `dart format` before calling a change done.
- Own implementation only. Don't copy code from other rice-analysis repos. Credit references in the README.

## Commands
- App: `flutter pub get`, `flutter run`, `flutter analyze`
- Backend: `pip install -r backend/requirements.txt`, `uvicorn main:app --reload`

## Current status
- (update as you go: what works, what's next)