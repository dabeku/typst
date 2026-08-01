use std::collections::{HashMap, HashSet};
use std::path::PathBuf;
use std::sync::{LazyLock, Mutex};

use typst::diag::{FileError, FileResult, PackageError, SourceDiagnostic};
use typst::foundations::{Bytes, Datetime};
use typst::syntax::ast::{self, AstNode};
use typst::syntax::package::PackageSpec;
use typst::syntax::{FileId, RootedPath, Source, SyntaxNode, VirtualPath, VirtualRoot};
use typst::text::{Font, FontBook};
use typst::utils::LazyHash;
use typst::{Library, LibraryExt, World};
use typst_layout::PagedDocument;

uniffi::setup_scaffolding!();

/// Error returned to the app when a Typst source fails to compile or export.
#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum TypstError {
    #[error("{reason}")]
    Compile { reason: String },
    /// Compilation stopped because an `#import`/`#include`d package wasn't
    /// present under `package_cache_dir` (or no `package_cache_dir` was
    /// given). Download `package` and retry the compile.
    #[error("package not found: @{}/{}:{}", package.namespace, package.name, package.version)]
    PackageNotFound { package: PackageRef },
}

/// Fonts embedded in the binary via `typst-assets` (New Computer Modern,
/// Libertinus Serif, DejaVu Sans Mono). Loaded once and reused across calls.
static FONTS: LazyLock<Vec<Font>> = LazyLock::new(|| {
    typst_assets::fonts()
        .filter_map(|data| Font::new(Bytes::new(data), 0))
        .collect()
});

/// Recursively scans `dir` for `.ttf`/`.otf`/`.ttc`/`.otc` files (e.g. a font
/// dropped next to `main.typ`) and loads every face they contain, so
/// `#set text(font: ...)` can reference project-supplied fonts and not just
/// the embedded ones in [`FONTS`]. Unreadable or unparseable files are
/// skipped rather than failing the whole compile — a font file the app
/// doesn't end up needing shouldn't block compilation.
fn load_project_fonts(dir: &std::path::Path) -> Vec<Font> {
    walkdir::WalkDir::new(dir)
        .into_iter()
        .filter_map(|entry| entry.ok())
        .filter(|entry| entry.file_type().is_file())
        .filter(|entry| {
            entry
                .path()
                .extension()
                .and_then(|ext| ext.to_str())
                .is_some_and(|ext| {
                    matches!(ext.to_ascii_lowercase().as_str(), "ttf" | "otf" | "ttc" | "otc")
                })
        })
        .filter_map(|entry| std::fs::read(entry.path()).ok())
        .flat_map(|data| Font::iter(Bytes::new(data)))
        .collect()
}

/// Interns a project-relative path (e.g. `"main.typ"`, `"chapter.typ"`,
/// `"refs.bib"`) as a `FileId` rooted at the (virtual) project root.
fn intern_path(path: &str) -> Result<FileId, TypstError> {
    let vpath = VirtualPath::new(path).map_err(|e| TypstError::Compile {
        reason: format!("invalid path {path:?}: {e}"),
    })?;
    Ok(RootedPath::new(VirtualRoot::Project, vpath).intern())
}

fn vpath_to_path_buf(id: FileId) -> PathBuf {
    PathBuf::from(id.get().vpath().get_without_slash())
}

/// A `typst::World` for a single compile.
///
/// All text sources (the main file, `#import`ed `.typ` files, bibliography
/// files, ...) are supplied directly in `texts` — they are never read from
/// disk, so an editor's unsaved buffers can be compiled as-is. Only binary
/// resources referenced by path but absent from `texts` (images, etc.) are
/// read from `root` on disk, if set.
///
/// Package files (`@namespace/name:version/...`, including a package's own
/// `typst.toml` and `.typ` sources) are never looked up in `texts`; they are
/// always read from `package_cache_dir`, laid out as
/// `{namespace}/{name}/{version}/...` — the same layout the app is
/// responsible for downloading packages into. If the package's version
/// directory isn't present there, this reports `FileError::Package(
/// PackageError::NotFound)` so the caller can distinguish "go download this
/// package" from an ordinary missing-file error.
struct TypstWorld {
    library: LazyHash<Library>,
    book: LazyHash<FontBook>,
    fonts: Vec<Font>,
    main_id: FileId,
    texts: HashMap<FileId, String>,
    root: Option<PathBuf>,
    package_cache_dir: Option<PathBuf>,
    now: time::OffsetDateTime,
    source_cache: Mutex<HashMap<FileId, Source>>,
    resource_cache: Mutex<HashMap<FileId, FileResult<Bytes>>>,
    /// The first package this compile discovered missing from
    /// `package_cache_dir`, if any. Recorded here (rather than only as a
    /// generic diagnostic message) so `compile_with` can report a
    /// structured [`TypstError::PackageNotFound`] instead of just prose.
    missing_package: Mutex<Option<PackageSpec>>,
}

impl TypstWorld {
    fn new(
        main_id: FileId,
        texts: HashMap<FileId, String>,
        root: Option<PathBuf>,
        package_cache_dir: Option<PathBuf>,
    ) -> Self {
        let mut fonts = FONTS.clone();
        if let Some(dir) = &root {
            fonts.extend(load_project_fonts(dir));
        }
        let book = FontBook::from_fonts(&fonts);
        Self {
            library: LazyHash::new(Library::default()),
            book: LazyHash::new(book),
            fonts,
            main_id,
            texts,
            root,
            package_cache_dir,
            now: time::OffsetDateTime::now_utc(),
            source_cache: Mutex::new(HashMap::new()),
            resource_cache: Mutex::new(HashMap::new()),
            missing_package: Mutex::new(None),
        }
    }

    /// Reads the raw bytes of a resource (an image, a package's `typst.toml`,
    /// a package's `.typ` sources, ...) from disk. Caches the result so a
    /// resource referenced multiple times only touches disk once and stays
    /// consistent within this compile.
    fn read_resource(&self, id: FileId) -> FileResult<Bytes> {
        if let Some(cached) = self.resource_cache.lock().unwrap().get(&id) {
            return cached.clone();
        }
        let result = self.read_resource_from_disk(id);
        self.resource_cache.lock().unwrap().insert(id, result.clone());
        result
    }

    fn read_resource_from_disk(&self, id: FileId) -> FileResult<Bytes> {
        let rooted = id.get();
        let base = match rooted.root() {
            VirtualRoot::Project => self.root.clone(),
            VirtualRoot::Package(spec) => {
                let Some(cache_dir) = &self.package_cache_dir else {
                    return Err(self.record_missing_package(spec));
                };
                let package_dir = cache_dir
                    .join(spec.namespace.as_str())
                    .join(spec.name.as_str())
                    .join(spec.version.to_string());
                if !package_dir.is_dir() {
                    return Err(self.record_missing_package(spec));
                }
                Some(package_dir)
            }
        };
        let Some(base) = base else {
            return Err(FileError::NotFound(vpath_to_path_buf(id)));
        };
        let path = rooted.vpath().realize(&base)?;
        let bytes = std::fs::read(&path).map_err(|e| FileError::from_io(e, &path))?;
        Ok(Bytes::new(bytes))
    }

    /// Records `spec` as missing (if no package has been recorded missing
    /// yet — the first one found is the one reported) and returns the
    /// corresponding `FileError` to hand back to the caller.
    fn record_missing_package(&self, spec: &PackageSpec) -> FileError {
        self.missing_package.lock().unwrap().get_or_insert_with(|| spec.clone());
        FileError::Package(PackageError::NotFound(spec.clone()))
    }
}

impl World for TypstWorld {
    fn library(&self) -> &LazyHash<Library> {
        &self.library
    }

    fn book(&self) -> &LazyHash<FontBook> {
        &self.book
    }

    fn main(&self) -> FileId {
        self.main_id
    }

    fn source(&self, id: FileId) -> FileResult<Source> {
        if let Some(cached) = self.source_cache.lock().unwrap().get(&id) {
            return Ok(cached.clone());
        }
        let text = if let Some(text) = self.texts.get(&id) {
            text.clone()
        } else if matches!(id.get().root(), VirtualRoot::Package(_)) {
            // Package sources (unlike project sources) are never supplied
            // via `texts` — they always come from the on-disk package cache.
            let bytes = self.read_resource(id)?;
            bytes
                .as_str()
                .map_err(|_| FileError::InvalidUtf8)?
                .to_string()
        } else {
            return Err(FileError::NotFound(vpath_to_path_buf(id)));
        };
        let source = Source::new(id, text);
        self.source_cache.lock().unwrap().insert(id, source.clone());
        Ok(source)
    }

    fn file(&self, id: FileId) -> FileResult<Bytes> {
        if let Some(text) = self.texts.get(&id) {
            return Ok(Bytes::from_string(text.clone()));
        }
        self.read_resource(id)
    }

    fn font(&self, index: usize) -> Option<Font> {
        self.fonts.get(index).cloned()
    }

    fn today(&self, _offset: Option<typst::foundations::Duration>) -> Option<Datetime> {
        // `typst::foundations::Duration` doesn't expose its inner offset, so
        // an explicit `offset:` argument to `datetime.today()` is ignored and
        // today's UTC date is always returned.
        Datetime::from_ymd(self.now.year(), self.now.month() as u8, self.now.day())
    }
}

fn format_diagnostics(diags: &[SourceDiagnostic]) -> String {
    diags
        .iter()
        .map(|d| d.message.as_str())
        .collect::<Vec<_>>()
        .join("\n")
}

/// How many compiles a `comemo` cache entry may go unused before eviction
/// (see [`compile_with`]).
const EVICT_MAX_AGE: usize = 10;

fn compile_with(world: TypstWorld) -> Result<Vec<u8>, TypstError> {
    let output = typst::compile::<PagedDocument>(&world).output;

    // `comemo`'s memoization caches are process-global and keyed by content
    // hash, not by `TypstWorld` instance — so a caller repeatedly compiling
    // the same project (e.g. an editor's "watch" loop calling this on every
    // edit) keeps benefiting from cached results for files it didn't touch,
    // even though a fresh `TypstWorld` is built each call. Without eviction
    // those caches would grow unboundedly over such a long-running session,
    // so trim entries unused for the last `EVICT_MAX_AGE` compiles after
    // every compile, same as `typst-cli`'s watch mode does.
    comemo::evict(EVICT_MAX_AGE);

    let document = output.map_err(|diags| compile_error(&world, &diags))?;

    typst_pdf::pdf(&document, &typst_pdf::PdfOptions::default())
        .map_err(|diags| TypstError::Compile { reason: format_diagnostics(&diags) })
}

/// Turns a failed compile into a `TypstError`. If the failure was (at least
/// in part) caused by a package missing from `package_cache_dir`, that's
/// reported as a structured [`TypstError::PackageNotFound`] — so the app can
/// go download exactly that package — rather than just the joined prose of
/// `diags`, which only carries a human-readable message.
fn compile_error(world: &TypstWorld, diags: &[SourceDiagnostic]) -> TypstError {
    if let Some(spec) = world.missing_package.lock().unwrap().take() {
        return TypstError::PackageNotFound { package: spec.into() };
    }
    TypstError::Compile { reason: format_diagnostics(diags) }
}

/// Compiles a Typst project into a PDF.
///
/// `sources` maps every project-relative text file path (the main file,
/// any `#import`ed `.typ` files, bibliography `.bib`/`.yml` files, ...) to
/// its live content; it must include an entry for `main_path` (e.g.
/// `"main.typ"`). None of these are read from disk, so unsaved editor
/// buffers work as-is.
///
/// `root_dir` is only consulted for binary resources referenced by path but
/// not present in `sources` — e.g. `#image("logo.png")` — which must exist
/// there on disk. `root_dir` is also recursively scanned for `.ttf`/`.otf`/
/// `.ttc`/`.otc` font files, which are loaded alongside the embedded fonts
/// and made available to `#set text(font: ...)`.
///
/// `package_cache_dir`, if set, is where downloaded packages are expected to
/// live, laid out as `{namespace}/{name}/{version}/...` (e.g.
/// `preview/cetz/0.2.2/typst.toml`) — the app owns fetching and unpacking
/// packages there; this function only ever reads from it. If an
/// `#import`/`#include`d package isn't present under `package_cache_dir`
/// (or `package_cache_dir` is `None`), compilation fails with a
/// [`TypstError`] whose message names the missing package; use
/// [`list_package_imports`] beforehand to know which packages to fetch.
#[uniffi::export]
pub fn compile_project_to_pdf(
    root_dir: String,
    package_cache_dir: Option<String>,
    main_path: String,
    sources: HashMap<String, String>,
) -> Result<Vec<u8>, TypstError> {
    let mut texts = HashMap::with_capacity(sources.len());
    let mut main_id = None;
    for (path, content) in sources {
        let id = intern_path(&path)?;
        if path == main_path {
            main_id = Some(id);
        }
        texts.insert(id, content);
    }
    let main_id = main_id.ok_or_else(|| TypstError::Compile {
        reason: format!("main_path {main_path:?} is missing from sources"),
    })?;

    let world = TypstWorld::new(
        main_id,
        texts,
        Some(PathBuf::from(root_dir)),
        package_cache_dir.map(PathBuf::from),
    );
    compile_with(world)
}

/// A package referenced by an `#import`/`#include` in a project, as found by
/// [`list_package_imports`].
#[derive(Debug, Clone, PartialEq, Eq, Hash, uniffi::Record)]
pub struct PackageRef {
    pub namespace: String,
    pub name: String,
    pub version: String,
}

impl From<PackageSpec> for PackageRef {
    fn from(spec: PackageSpec) -> Self {
        Self {
            namespace: spec.namespace.to_string(),
            name: spec.name.to_string(),
            version: spec.version.to_string(),
        }
    }
}

/// Scans `sources`, starting at `main_path`, for `#import`/`#include` of
/// `@namespace/name:version` package paths, following local (non-package)
/// imports transitively as long as their targets are present in `sources`.
///
/// This lets the app prefetch every package a project directly needs
/// *before* calling [`compile_project_to_pdf`], instead of discovering them
/// one at a time via compile failures. It's a static, best-effort scan:
/// - Only literal string import paths are seen; a dynamically computed
///   import path can't be resolved without running the compiler.
/// - It doesn't look inside a package for *its own* dependencies — those
///   are only knowable once that package is downloaded. A transitive
///   dependency that's still missing surfaces as a normal
///   [`TypstError`] from `compile_project_to_pdf` naming the missing
///   package, so the app should still be ready to catch that and fetch
///   on demand as a fallback.
#[uniffi::export]
pub fn list_package_imports(
    main_path: String,
    sources: HashMap<String, String>,
) -> Result<Vec<PackageRef>, TypstError> {
    let main_vpath = VirtualPath::new(&main_path).map_err(|e| TypstError::Compile {
        reason: format!("invalid path {main_path:?}: {e}"),
    })?;

    let mut packages = Vec::new();
    let mut seen_packages = HashSet::new();
    let mut visited = HashSet::new();
    let mut stack = vec![main_vpath];

    while let Some(vpath) = stack.pop() {
        let key = vpath.get_without_slash().to_string();
        if !visited.insert(key.clone()) {
            continue;
        }
        let Some(text) = sources.get(&key) else {
            continue;
        };

        let mut targets = Vec::new();
        collect_import_targets(&typst::syntax::parse(text), &mut targets);

        for target in targets {
            if target.starts_with('@') {
                let Ok(spec) = target.parse::<PackageSpec>() else {
                    continue;
                };
                if seen_packages.insert(spec.clone()) {
                    packages.push(spec.into());
                }
            } else {
                let base = vpath
                    .parent()
                    .unwrap_or_else(|| VirtualPath::new("").expect("empty path is valid"));
                if let Ok(joined) = base.join(&target) {
                    stack.push(joined);
                }
            }
        }
    }

    Ok(packages)
}

/// Collects the literal string source of every `#import`/`#include` in a
/// syntax tree, in document order.
fn collect_import_targets(node: &SyntaxNode, out: &mut Vec<String>) {
    if let Some(import) = ast::ModuleImport::from_untyped(node) {
        if let ast::Expr::Str(s) = import.source() {
            out.push(s.get().to_string());
        }
    } else if let Some(include) = ast::ModuleInclude::from_untyped(node) {
        if let ast::Expr::Str(s) = include.source() {
            out.push(s.get().to_string());
        }
    }
    for child in node.children() {
        collect_import_targets(child, out);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compiles_simple_document() {
        let dir = tempfile::tempdir().expect("tempdir");
        let sources = HashMap::from([(
            "main.typ".to_string(),
            "= Hello\nThis is *Typst* running from Rust.".to_string(),
        )]);
        let pdf = compile_project_to_pdf(
            dir.path().to_string_lossy().into_owned(),
            None,
            "main.typ".to_string(),
            sources,
        )
        .expect("compilation should succeed");
        assert!(pdf.starts_with(b"%PDF"));
        assert!(pdf.len() > 100);
    }

    #[test]
    fn reports_syntax_errors() {
        let dir = tempfile::tempdir().expect("tempdir");
        let sources = HashMap::from([("main.typ".to_string(), "#let x = ".to_string())]);
        let err = compile_project_to_pdf(
            dir.path().to_string_lossy().into_owned(),
            None,
            "main.typ".to_string(),
            sources,
        )
        .unwrap_err();
        let TypstError::Compile { reason } = err else {
            panic!("expected TypstError::Compile, got {err:?}");
        };
        assert!(!reason.is_empty());
    }

    #[test]
    fn load_project_fonts_scans_root_dir_recursively() {
        let dir = tempfile::tempdir().expect("tempdir");
        let subdir = dir.path().join("fonts");
        std::fs::create_dir(&subdir).unwrap();
        // Real font bytes are needed for `Font::iter` to parse successfully;
        // reuse one of the embedded assets rather than embedding a fixture.
        let font_data = typst_assets::fonts().next().expect("embedded font asset");
        std::fs::write(subdir.join("custom.otf"), font_data).unwrap();
        // Non-font files must be ignored rather than failing the scan.
        std::fs::write(dir.path().join("notes.txt"), b"not a font").unwrap();

        let fonts = load_project_fonts(dir.path());
        assert_eq!(fonts.len(), 1);
        assert_eq!(fonts[0].data().as_slice(), font_data);
    }

    #[test]
    fn project_compile_reports_missing_import_file() {
        let dir = tempfile::tempdir().expect("tempdir");
        let sources = HashMap::from([(
            "main.typ".to_string(),
            "#import \"other.typ\": x".to_string(),
        )]);
        let err = compile_project_to_pdf(
            dir.path().to_string_lossy().into_owned(),
            None,
            "main.typ".to_string(),
            sources,
        )
        .unwrap_err();
        let TypstError::Compile { reason } = err else {
            panic!("expected TypstError::Compile, got {err:?}");
        };
        assert!(!reason.is_empty());
    }

    #[test]
    fn project_compile_resolves_import_and_image_from_root_dir() {
        let dir = tempfile::tempdir().expect("tempdir");
        // Only the binary resource lives on disk.
        let png: &[u8] = &[
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
            0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00,
            0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78,
            0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
            0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
        ];
        std::fs::write(dir.path().join("logo.png"), png).unwrap();

        let sources = HashMap::from([
            (
                "main.typ".to_string(),
                "#import \"chapter.typ\": greeting\n#greeting\n#image(\"logo.png\")".to_string(),
            ),
            (
                "chapter.typ".to_string(),
                "#let greeting = \"Hi from chapter\"".to_string(),
            ),
        ]);

        let pdf = compile_project_to_pdf(
            dir.path().to_string_lossy().into_owned(),
            None,
            "main.typ".to_string(),
            sources,
        )
        .expect("project compilation should succeed");
        assert!(pdf.starts_with(b"%PDF"));
    }

    #[test]
    fn project_compile_serves_text_files_from_sources_not_disk() {
        let dir = tempfile::tempdir().expect("tempdir");
        // Deliberately not written to disk: if text files fell back to disk
        // reads, this would fail with a "file not found" error.
        let sources = HashMap::from([
            ("main.typ".to_string(), "#read(\"refs.bib\")".to_string()),
            (
                "refs.bib".to_string(),
                "@article{foo, title = {Bar}, author = {Baz}, year = {2024}}".to_string(),
            ),
        ]);

        let pdf = compile_project_to_pdf(
            dir.path().to_string_lossy().into_owned(),
            None,
            "main.typ".to_string(),
            sources,
        )
        .expect("project compilation should succeed");
        assert!(pdf.starts_with(b"%PDF"));
    }

    #[test]
    fn project_compile_requires_main_path_in_sources() {
        let dir = tempfile::tempdir().expect("tempdir");
        let sources = HashMap::from([("other.typ".to_string(), "hi".to_string())]);
        let err = compile_project_to_pdf(
            dir.path().to_string_lossy().into_owned(),
            None,
            "main.typ".to_string(),
            sources,
        )
        .unwrap_err();
        let TypstError::Compile { reason } = err else {
            panic!("expected TypstError::Compile, got {err:?}");
        };
        assert!(reason.contains("main_path"));
    }

    #[test]
    fn project_compile_reports_missing_package() {
        let dir = tempfile::tempdir().expect("tempdir");
        let cache_dir = tempfile::tempdir().expect("tempdir");
        let sources = HashMap::from([(
            "main.typ".to_string(),
            "#import \"@preview/cetz:0.2.2\": canvas".to_string(),
        )]);

        let err = compile_project_to_pdf(
            dir.path().to_string_lossy().into_owned(),
            Some(cache_dir.path().to_string_lossy().into_owned()),
            "main.typ".to_string(),
            sources,
        )
        .unwrap_err();
        let TypstError::PackageNotFound { package } = err else {
            panic!("expected TypstError::PackageNotFound, got {err:?}");
        };
        assert_eq!(
            package,
            PackageRef {
                namespace: "preview".to_string(),
                name: "cetz".to_string(),
                version: "0.2.2".to_string(),
            }
        );
    }

    #[test]
    fn project_compile_reports_missing_package_when_no_cache_dir_given() {
        let dir = tempfile::tempdir().expect("tempdir");
        let sources = HashMap::from([(
            "main.typ".to_string(),
            "#import \"@preview/cetz:0.2.2\": canvas".to_string(),
        )]);

        let err = compile_project_to_pdf(
            dir.path().to_string_lossy().into_owned(),
            None,
            "main.typ".to_string(),
            sources,
        )
        .unwrap_err();
        let TypstError::PackageNotFound { package } = err else {
            panic!("expected TypstError::PackageNotFound, got {err:?}");
        };
        assert_eq!(package.name, "cetz");
    }

    #[test]
    fn project_compile_resolves_package_from_cache_dir() {
        let dir = tempfile::tempdir().expect("tempdir");
        let cache_dir = tempfile::tempdir().expect("tempdir");
        let pkg_dir = cache_dir.path().join("preview").join("greet").join("0.1.0");
        std::fs::create_dir_all(&pkg_dir).unwrap();
        std::fs::write(
            pkg_dir.join("typst.toml"),
            "[package]\nname = \"greet\"\nversion = \"0.1.0\"\nentrypoint = \"lib.typ\"\n",
        )
        .unwrap();
        std::fs::write(
            pkg_dir.join("lib.typ"),
            "#let hello = \"Hi from package\"",
        )
        .unwrap();

        let sources = HashMap::from([(
            "main.typ".to_string(),
            "#import \"@preview/greet:0.1.0\": hello\n#hello".to_string(),
        )]);

        let pdf = compile_project_to_pdf(
            dir.path().to_string_lossy().into_owned(),
            Some(cache_dir.path().to_string_lossy().into_owned()),
            "main.typ".to_string(),
            sources,
        )
        .expect("project compilation should succeed");
        assert!(pdf.starts_with(b"%PDF"));
    }

    #[test]
    fn list_package_imports_finds_direct_and_transitive_imports() {
        let sources = HashMap::from([
            (
                "main.typ".to_string(),
                "#import \"@preview/cetz:0.2.2\": canvas\n#import \"chapters/intro.typ\": greeting"
                    .to_string(),
            ),
            (
                "chapters/intro.typ".to_string(),
                "#import \"@preview/tablex:0.0.9\"\n#let greeting = \"hi\"".to_string(),
            ),
        ]);

        let mut packages = list_package_imports("main.typ".to_string(), sources).unwrap();
        packages.sort_by(|a, b| a.name.cmp(&b.name));

        assert_eq!(
            packages,
            vec![
                PackageRef {
                    namespace: "preview".to_string(),
                    name: "cetz".to_string(),
                    version: "0.2.2".to_string(),
                },
                PackageRef {
                    namespace: "preview".to_string(),
                    name: "tablex".to_string(),
                    version: "0.0.9".to_string(),
                },
            ]
        );
    }

    #[test]
    fn list_package_imports_ignores_missing_local_imports() {
        let sources = HashMap::from([(
            "main.typ".to_string(),
            "#import \"does-not-exist.typ\": x".to_string(),
        )]);
        let packages = list_package_imports("main.typ".to_string(), sources).unwrap();
        assert!(packages.is_empty());
    }
}
