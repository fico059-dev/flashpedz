# Patched appflowy_editor 6.2.0

Copy of appflowy_editor 6.2.0 (lib, assets, pubspec.yaml, LICENSE) with one
fix in `lib/src/editor/editor_component/service/ime/delta_input_service.dart`:
`DeltaTextInputService` implements `onFocusReceived`, which newer Flutter
versions added to `TextInputClient`. Without it the app doesn't build with
those Flutter versions ("missing implementations for these members:
TextInputClient.onFocusReceived").

Remove this folder and the `dependency_overrides` entry in pubspec.yaml when
a newer appflowy_editor fixes it.
