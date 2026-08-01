# Setup (mac)

```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
sh -s -- -y --default-toolchain stable --profile minimal

source "$HOME/.cargo/env"

rustup component add rustfmt clippy

rustup target add \
 aarch64-linux-android \
 armv7-linux-androideabi \
 x86_64-linux-android \
 i686-linux-android

cargo install cargo-edit cargo-audit cargo-ndk

rustc --version
cargo --version
cargo fmt --version
cargo clippy --version
cargo ndk --version
cargo audit --version
cargo set-version --version
```

# typst_uniffi

Compiles [Typst](https://typst.app) markup to a PDF from Rust, exposed to
Android (Java/Kotlin) via [UniFFI](https://mozilla.github.io/uniffi-rs/).

The whole Typst compiler plus a set of embedded fonts (New Computer Modern,
Libertinus Serif, DejaVu Sans Mono — same fonts `typst-cli` ships with) are
statically linked into the `.so`, so the functions below work fully offline.

## API

```rust
/// Multi-file project. `sources` maps every project-relative *text* file
/// path (main file, `#import`ed `.typ` files, bibliography `.bib`/`.yml`
/// files, ...) to its live content — none of these are read from disk, so
/// unsaved editor buffers work as-is. `main_path` (e.g. "main.typ") must be
/// a key in `sources`. `root_dir` on disk is only consulted for binary
/// resources referenced by path but absent from `sources`, e.g.
/// `#image("logo.png")` — and is recursively scanned for `.ttf`/`.otf`/
/// `.ttc`/`.otc` font files, loaded alongside the embedded fonts and made
/// available to `#set text(font: ...)`. `package_cache_dir`, if set, is
/// where downloaded packages live (see "Package imports" below).
pub fn compile_project_to_pdf(
    root_dir: String,
    package_cache_dir: Option<String>,
    main_path: String,
    sources: std::collections::HashMap<String, String>,
) -> Result<Vec<u8>, TypstError>;

/// Scans `sources`, starting at `main_path`, for `#import`/`#include` of
/// `@namespace/name:version` packages, following local imports
/// transitively. Lets the app prefetch packages before compiling. See
/// "Package imports" below.
pub fn list_package_imports(
    main_path: String,
    sources: std::collections::HashMap<String, String>,
) -> Result<Vec<PackageRef>, TypstError>;

pub struct PackageRef {
    pub namespace: String,
    pub name: String,
    pub version: String,
}

pub enum TypstError {
    /// Typst syntax/compile errors, PDF export errors, a missing/unreadable
    /// image, or a `main_path` absent from `sources`. `reason` joins all
    /// diagnostics with `\n`.
    Compile { reason: String },
    /// Compilation needed a package that isn't present under
    /// `package_cache_dir` (or no `package_cache_dir` was given). `package`
    /// names exactly which one — download it and retry.
    PackageNotFound { package: PackageRef },
}
```

`compile_project_to_pdf` never touches disk for text files — every `.typ`
and bibliography file the project needs must be an entry in `sources`. Only
binary resources (images, etc.) not found in `sources` fall back to
`root_dir` — e.g. an app-specific directory the Android app has saved
resource files into (`context.getFilesDir()` or similar).

### Package imports

typst_uniffi never downloads packages itself — the app owns fetching and
storing them; Rust only ever reads them back from disk. Workflow:

1. Before compiling, call `list_package_imports(main_path, sources)` to get
   every `@namespace/name:version` package the project directly imports or
   includes (following local `.typ` imports transitively). This is a
   static scan of literal import paths — it won't see dynamically computed
   import paths, and it can't see a package's *own* dependencies (those are
   only knowable once that package is downloaded).
2. For each `PackageRef` not already cached, download and unpack it into
   `package_cache_dir`, laid out as `{namespace}/{name}/{version}/...`
   (e.g. `preview/cetz/0.2.2/typst.toml`, `preview/cetz/0.2.2/src/lib.typ`)
   — the same layout typst-cli's own package cache uses, and typically
   fetched by downloading and untarring
   `https://packages.typst.org/{namespace}/{name}-{version}.tar.gz`.
3. Call `compile_project_to_pdf(root_dir, Some(package_cache_dir), main_path,
   sources)`. If a package the project needs still isn't present under
   `package_cache_dir` — including a transitive dependency step 1 couldn't
   see — compilation fails with `TypstError::PackageNotFound { package }`,
   naming exactly the missing package; download `package` and retry.

## Rebuilding

```sh
# host build + tests
cargo test

# Android .so for all 4 ABIs -> ./jniLibs/<abi>/libtypst_uniffi.so
export ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/<version>
cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 -t x86 -o jniLibs build --release --lib

# regenerate Kotlin bindings (uses a host build, any ABI's .so has the same
# metadata) -> ./bindings/kotlin/uniffi/typst_uniffi/typst_uniffi.kt
cargo build --lib
cargo run --bin uniffi-bindgen -- generate \
  --library target/debug/libtypst_uniffi.dylib \
  --language kotlin --out-dir bindings/kotlin
```

Requires `cargo-ndk` (`cargo install cargo-ndk`) and the four Android Rust
targets (`rustup target add aarch64-linux-android armv7-linux-androideabi
x86_64-linux-android i686-linux-android`).

## Integrating into the Android app

UniFFI only generates **Kotlin** bindings — there's no first-party Java
generator. That's fine even for a Java app: the generated `.kt` file compiles
to plain JVM bytecode and is callable from Java like any other class, once
the Kotlin Gradle plugin is applied to the app module.

1. **Enable Kotlin** in the app module's `build.gradle` (only needed to
   compile the one generated file; the rest of the app can stay Java):

   ```gradle
   plugins {
       id 'com.android.application'
       id 'org.jetbrains.kotlin.android' version '<matches your AGP setup>'
   }
   android {
       kotlinOptions { jvmTarget = '17' } // match your Java compat
   }
   dependencies {
       implementation 'net.java.dev.jna:jna:5.14.0@aar'
   }
   ```

2. **Copy the native libraries** into the app module:

   ```
   app/src/main/jniLibs/arm64-v8a/libtypst_uniffi.so
   app/src/main/jniLibs/armeabi-v7a/libtypst_uniffi.so
   app/src/main/jniLibs/x86_64/libtypst_uniffi.so
   app/src/main/jniLibs/x86/libtypst_uniffi.so
   ```

   (from this repo's `jniLibs/`; drop `x86`/`x86_64` if you don't ship for
   emulators/Chromebooks to save APK size — ~50MB per ABI, mostly the
   bundled compiler + fonts).

3. **Copy the binding file**:

   ```
   app/src/main/kotlin/uniffi/typst_uniffi/typst_uniffi.kt
   ```

   (from this repo's `bindings/kotlin/uniffi/typst_uniffi/typst_uniffi.kt`).

4. **Call it from Java.** Top-level Kotlin functions in `typst_uniffi.kt`
   compile to static methods on a `Typst_uniffiKt` class:

   ```java
   import uniffi.typst_uniffi.Typst_uniffiKt;
   import uniffi.typst_uniffi.TypstException;

   // Single file, no imports/images:
   try {
       byte[] pdf = Typst_uniffiKt.compileToPdf("= Hello\nWritten from *Typst*.");
       // e.g. write `pdf` to a file, or feed it to a PDF renderer
   } catch (TypstException e) {
       // e.getMessage() contains the Typst diagnostics
   }

   // Multi-file project — logo.png must already be in projectDir; main.typ
   // and chapter.typ are passed directly and never touch disk.
   try {
       Map<String, String> sources = new HashMap<>();
       sources.put("main.typ", "#import \"chapter.typ\": greeting\n#greeting\n#image(\"logo.png\")");
       sources.put("chapter.typ", "#let greeting = \"Hi from chapter\"");

       byte[] pdf = Typst_uniffiKt.compileProjectToPdf(
           projectDir.getAbsolutePath(),
           null, // no packages used, so no package cache needed
           "main.typ",
           sources
       );
   } catch (TypstException e) {
       // e.getMessage() contains the Typst diagnostics
   }

   // Project that imports a package — prefetch it into packageCacheDir
   // first (download+unpack is entirely the app's job), then compile.
   try {
       Map<String, String> sources = new HashMap<>();
       sources.put("main.typ", "#import \"@preview/cetz:0.2.2\": canvas\ncanvas(...)");

       for (PackageRef pkg : Typst_uniffiKt.listPackageImports("main.typ", sources)) {
           ensurePackageDownloaded(packageCacheDir, pkg.getNamespace(), pkg.getName(), pkg.getVersion());
       }

       byte[] pdf = Typst_uniffiKt.compileProjectToPdf(
           projectDir.getAbsolutePath(),
           packageCacheDir.getAbsolutePath(),
           "main.typ",
           sources
       );
   } catch (TypstException.PackageNotFound e) {
       // A transitive dependency listPackageImports couldn't see. e.getPackage()
       // is the exact PackageRef to download — fetch it and retry the compile.
       PackageRef pkg = e.getPackage();
   } catch (TypstException e) {
       // e.getMessage() contains the Typst diagnostics
   }
   ```

If you use `abiFilters`/App Bundles with per-ABI splits, Gradle picks the
matching `.so` automatically at install time — no extra config needed beyond
having all four directories present.
