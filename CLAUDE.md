# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HsQML is a Haskell binding to Qt Quick (Qt 5.x and Qt 6.x). It bridges Haskell backend code with QML/JavaScript frontends via a C++ FFI layer. The library uses a custom Cabal build that integrates Qt's `moc` (meta-object compiler) and `c2hs` for FFI code generation.

## Build Commands

```bash
# Build with Qt5 (default)
cabal build

# Build with Qt6
cabal build -f UseQt6

# Build with tests
cabal build --enable-tests
cabal build --enable-tests -f UseQt6

# Run tests (requires offscreen rendering for headless environments)
QT_QPA_PLATFORM=offscreen cabal run hsqml-test1 --enable-tests
QT_QPA_PLATFORM=offscreen cabal run hsqml-test1 --enable-tests -f UseQt6
```

**Prerequisites**: Qt 5.x or Qt 6.x development libraries, c2hs, C++11 compiler (C++17 for Qt6). On macOS, Setup.hs auto-detects Homebrew Qt at `/opt/homebrew/opt/qt@5/bin` or `/opt/homebrew/opt/qt@6/bin`.

## Architecture

### Three-Layer Design

1. **C++ layer** (`cbits/`): Qt QObject proxies and manager classes. Headers with `Q_OBJECT` macros are processed by `moc` during build (listed under `X-moc-headers` in the cabal file). Key files: `Manager.cpp` (object lifecycle), `Object.cpp` (Haskell object proxy), `Class.cpp` (method/property registration), `Engine.cpp` (QML engine), `Canvas.cpp` (OpenGL rendering).

2. **FFI binding layer** (`src/Graphics/QML/Internal/`): Uses `c2hs` preprocessor (`.chs` files) to generate Haskell FFI bindings from the C API defined in `cbits/hsqml.h`. `BindCore.chs`, `BindObj.chs`, `BindPrim.chs`, `BindCanvas.chs` map to different FFI categories.

3. **Public Haskell API** (`src/Graphics/QML/`): Type-safe API exposing `Engine` (QML engine lifecycle), `Objects` (define Haskell types as QML objects with methods/properties/signals), `Marshal` (bidirectional Haskell↔QML type conversion), `Canvas` (OpenGL rendering), `Model` (data models).

### Custom Build System

`Setup.hs` provides custom Cabal hooks that:
- Locate Qt's `moc` and run it on headers listed in `X-moc-headers`
- Substitute `/QT_ROOT` and `/SYS_ROOT` path placeholders with actual Qt installation paths
- Handle platform-specific Qt detection (frameworks on macOS, pkg-config on Linux, direct paths on Windows)
- Build a separate GHCi workaround library when `ForceGHCiLib` is enabled

### Marshalling System

The `Marshal` typeclass with `MarshalMode` associated type family controls how Haskell types convert to/from QML. Capabilities (`CanGetFrom`, `CanPassTo`, `CanReturnTo`) determine which directions a type supports. Supported types include primitives (Bool, Int32, Double, Text), collections (List, Maybe), object references (`ObjRef a`, `AnyObjRef`), and `JSValue`.

### Object System

Haskell types are exposed to QML via `Class a` metadata built from `Member` definitions: `defMethod`/`defMethod'` (methods), `defPropertyConst`/`defPropertyRO`/`defPropertyRW` (properties), `defSignal`/`defSignalNamedParams` (signals). `MetaObj.hs` generates Qt meta-object information at runtime.

## Cabal Flags

- `UseQt6` (default: False) — Build against Qt 6 instead of Qt 5
- `UsePkgConfig` (default: False) — Use pkg-config instead of platform-default Qt detection
- `ForceGHCiLib` (default: True) — Build separate GHCi library for C++ bits
- `UseExitHook` (default: True) — Override OnExitHook for Qt shutdown
- `EnableQmlDebugging` (default: False) — Enable QML debug server
- `ThreadedTestSuite` (default: True) — Build tests with threaded RTS

### Qt6 Known Limitations

- Canvas/OpenGL forces the OpenGL rendering backend (`QQuickWindow::setGraphicsApi(OpenGL)`). Qt6's RHI abstraction (Vulkan, Metal, Direct3D) is not yet supported.
- QML debugging is not yet implemented for Qt6.
- `enableHighDpiScaling` is a no-op on Qt6 (always enabled).
- The QVariant hook mechanism for tracking Haskell object references is disabled on Qt6; relies on `QQmlEngine::setObjectOwnership()` and GCLock instead.

## Testing

Tests use QuickCheck for property-based testing with a custom harness. Test modules in `test/Graphics/QML/Test/` cover methods, properties, signals, data marshalling, and data models. `ScriptDSL.hs` provides a DSL for generating QML test scripts.
