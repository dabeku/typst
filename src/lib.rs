use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{LazyLock, Mutex};

use typst::diag::{FileError, FileResult, SourceDiagnostic};
use typst::foundations::{Bytes, Datetime};
use typst::syntax::{FileId, RootedPath, Source, VirtualPath, VirtualRoot};
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
}

/// Fonts embedded in the binary via `typst-assets` (New Computer Modern,
/// Libertinus Serif, DejaVu Sans Mono). Loaded once and reused across calls.
static FONTS: LazyLock<Vec<Font>> = LazyLock::new(|| {
    typst_assets::fonts()
        .filter_map(|data| Font::new(Bytes::new(data), 0))
        .collect()
});

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
struct TypstWorld {
    library: LazyHash<Library>,
    book: LazyHash<FontBook>,
    fonts: Vec<Font>,
    main_id: FileId,
    texts: HashMap<FileId, String>,
    root: Option<PathBuf>,
    now: time::OffsetDateTime,
    source_cache: Mutex<HashMap<FileId, Source>>,
    resource_cache: Mutex<HashMap<FileId, FileResult<Bytes>>>,
}

impl TypstWorld {
    fn new(main_id: FileId, texts: HashMap<FileId, String>, root: Option<PathBuf>) -> Self {
        let fonts = FONTS.clone();
        let book = FontBook::from_fonts(&fonts);
        Self {
            library: LazyHash::new(Library::default()),
            book: LazyHash::new(book),
            fonts,
            main_id,
            texts,
            root,
            now: time::OffsetDateTime::now_utc(),
            source_cache: Mutex::new(HashMap::new()),
            resource_cache: Mutex::new(HashMap::new()),
        }
    }

    /// Reads the raw bytes of a binary resource (e.g. an image) from disk,
    /// relative to `root`. Caches the result so a resource referenced
    /// multiple times only touches disk once and stays consistent within
    /// this compile.
    fn read_resource(&self, id: FileId) -> FileResult<Bytes> {
        if let Some(cached) = self.resource_cache.lock().unwrap().get(&id) {
            return cached.clone();
        }
        let result = self.read_resource_from_disk(id);
        self.resource_cache.lock().unwrap().insert(id, result.clone());
        result
    }

    fn read_resource_from_disk(&self, id: FileId) -> FileResult<Bytes> {
        let Some(root) = &self.root else {
            return Err(FileError::NotFound(vpath_to_path_buf(id)));
        };
        let rooted = id.get();
        if !matches!(rooted.root(), VirtualRoot::Project) {
            return Err(FileError::Other(Some(
                "package imports are not supported".into(),
            )));
        }
        let path = rooted.vpath().realize(root)?;
        let bytes = std::fs::read(&path).map_err(|e| FileError::from_io(e, &path))?;
        Ok(Bytes::new(bytes))
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
        let text = self
            .texts
            .get(&id)
            .ok_or_else(|| FileError::NotFound(vpath_to_path_buf(id)))?;
        let source = Source::new(id, text.clone());
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

fn compile_with(world: TypstWorld) -> Result<Vec<u8>, TypstError> {
    let document = typst::compile::<PagedDocument>(&world)
        .output
        .map_err(|diags| TypstError::Compile { reason: format_diagnostics(&diags) })?;

    typst_pdf::pdf(&document, &typst_pdf::PdfOptions::default())
        .map_err(|diags| TypstError::Compile { reason: format_diagnostics(&diags) })
}

/// Compiles a single, self-contained Typst source string into a PDF.
/// `#import`/`#image` of external files is not supported; use
/// [`compile_project_to_pdf`] for multi-file projects.
#[uniffi::export]
pub fn compile_to_pdf(source: String) -> Result<Vec<u8>, TypstError> {
    let main_id = intern_path("main.typ").expect("the literal path \"main.typ\" is always valid");
    let world = TypstWorld::new(main_id, HashMap::from([(main_id, source)]), None);
    compile_with(world)
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
/// there on disk. Package imports (`#import "@preview/..."`) are not
/// supported.
#[uniffi::export]
pub fn compile_project_to_pdf(
    root_dir: String,
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

    let world = TypstWorld::new(main_id, texts, Some(PathBuf::from(root_dir)));
    compile_with(world)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compiles_simple_document() {
        let pdf = compile_to_pdf("= Hello\nThis is *Typst* running from Rust.".to_string())
            .expect("compilation should succeed");
        assert!(pdf.starts_with(b"%PDF"));
        assert!(pdf.len() > 100);
    }

    #[test]
    fn reports_syntax_errors() {
        let err = compile_to_pdf("#let x = ".to_string()).unwrap_err();
        let TypstError::Compile { reason } = err;
        assert!(!reason.is_empty());
    }

    #[test]
    fn standalone_compile_rejects_imports() {
        let err = compile_to_pdf("#import \"other.typ\": x".to_string()).unwrap_err();
        let TypstError::Compile { reason } = err;
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
            "main.typ".to_string(),
            sources,
        )
        .unwrap_err();
        let TypstError::Compile { reason } = err;
        assert!(reason.contains("main_path"));
    }
}
