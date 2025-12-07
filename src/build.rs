//! Build command - compiles resumes using the Typst API.

use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::sync::OnceLock;

use anyhow::{bail, Context, Result};
use chrono::{Datelike, Local};
use colored::Colorize;
use typst::diag::{FileError, FileResult, Severity};
use typst::foundations::{Bytes, Datetime};
use typst::syntax::{FileId, Source, VirtualPath};
use typst::text::{Font, FontBook};
use typst::utils::LazyHash;
use typst::{Library, LibraryExt, World};
use typst_pdf::PdfOptions;

use crate::common::{
    content_filename, output_filename, resolve_languages, resolve_types, temp_filename,
    ProjectPaths, ResumeLanguage, ResumeType,
};

/// Static font book cache.
static FONT_BOOK: OnceLock<(LazyHash<FontBook>, Vec<Font>)> = OnceLock::new();

/// Load system fonts once.
fn load_fonts() -> &'static (LazyHash<FontBook>, Vec<Font>) {
    FONT_BOOK.get_or_init(|| {
        let mut fontdb = fontdb::Database::new();
        fontdb.load_system_fonts();

        let mut book = FontBook::new();
        let mut fonts = Vec::new();

        for face in fontdb.faces() {
            if let fontdb::Source::File(path) = &face.source {
                if let Ok(data) = fs::read(path) {
                    let bytes = Bytes::new(data);
                    for font in Font::iter(bytes) {
                        book.push(font.info().clone());
                        fonts.push(font);
                    }
                }
            }
        }

        (LazyHash::new(book), fonts)
    })
}

/// A Typst world implementation for resume compilation.
struct ResumeWorld {
    /// Project root directory.
    root: PathBuf,
    /// The main source file.
    main: Source,
    /// Library with standard definitions.
    library: LazyHash<Library>,
    /// Font book reference.
    book: &'static LazyHash<FontBook>,
    /// Loaded fonts.
    fonts: &'static [Font],
    /// Cached source files.
    sources: HashMap<FileId, Source>,
    /// Cached binary files.
    files: HashMap<FileId, Bytes>,
}

impl ResumeWorld {
    /// Create a new world for compiling a resume.
    fn new(root: PathBuf, main_path: PathBuf) -> Result<Self> {
        let main_content = fs::read_to_string(&main_path)
            .with_context(|| format!("Failed to read main file: {}", main_path.display()))?;

        let main_id = FileId::new(None, VirtualPath::new(main_path.file_name().unwrap()));
        let main = Source::new(main_id, main_content);

        let (book, fonts) = load_fonts();

        Ok(Self {
            root,
            main,
            library: LazyHash::new(Library::default()),
            book,
            fonts,
            sources: HashMap::new(),
            files: HashMap::new(),
        })
    }

    /// Resolve a file path relative to the project root.
    fn resolve_path(&self, id: FileId) -> PathBuf {
        let vpath = id.vpath();
        self.root.join(
            vpath
                .as_rooted_path()
                .strip_prefix("/")
                .unwrap_or(vpath.as_rooted_path()),
        )
    }
}

impl World for ResumeWorld {
    fn library(&self) -> &LazyHash<Library> {
        &self.library
    }

    fn book(&self) -> &LazyHash<FontBook> {
        self.book
    }

    fn main(&self) -> FileId {
        self.main.id()
    }

    fn source(&self, id: FileId) -> FileResult<Source> {
        if id == self.main.id() {
            return Ok(self.main.clone());
        }

        if let Some(source) = self.sources.get(&id) {
            return Ok(source.clone());
        }

        let path = self.resolve_path(id);
        let content = fs::read_to_string(&path).map_err(|e| FileError::from_io(e, &path))?;

        Ok(Source::new(id, content))
    }

    fn file(&self, id: FileId) -> FileResult<Bytes> {
        if let Some(bytes) = self.files.get(&id) {
            return Ok(bytes.clone());
        }

        let path = self.resolve_path(id);
        let data = fs::read(&path).map_err(|e| FileError::from_io(e, &path))?;

        Ok(Bytes::new(data))
    }

    fn font(&self, index: usize) -> Option<Font> {
        self.fonts.get(index).cloned()
    }

    fn today(&self, offset: Option<i64>) -> Option<Datetime> {
        let now = Local::now();
        let offset = offset.unwrap_or(0);
        let shifted = now.checked_add_signed(chrono::Duration::hours(offset))?;
        Datetime::from_ymd(
            shifted.year(),
            shifted.month().try_into().ok()?,
            shifted.day().try_into().ok()?,
        )
    }
}

/// Generate a temporary Typst file that imports the template and content.
fn generate_temp_typst_file(
    paths: &ProjectPaths,
    resume_type: ResumeType,
    language: ResumeLanguage,
) -> Result<PathBuf> {
    let template_name = format!("{}.typ", resume_type.as_str());
    let template_path = paths.templates.join(&template_name);

    if !template_path.exists() {
        bail!("Missing template: {}", template_path.display());
    }

    let content_name = content_filename(language);
    let content_path = paths.root.join(&content_name);

    if !content_path.exists() {
        bail!("Missing content file: {}", content_path.display());
    }

    let temp_name = temp_filename(resume_type, language);
    let temp_path = paths.root.join(&temp_name);

    let temp_content = format!(
        r#"#import "resume_templates/{template_name}": {type_name}_template

// Load content file
#let content_file = (content_file: "{content_name}").content_file
#let content = yaml(content_file)

// Generate resume
#{type_name}_template(content)
"#,
        template_name = template_name,
        type_name = resume_type.as_str(),
        content_name = content_name,
    );

    fs::write(&temp_path, &temp_content)
        .with_context(|| format!("Failed to write temp file: {}", temp_path.display()))?;

    Ok(temp_path)
}

/// Build a single resume variant.
pub fn build_single(
    paths: &ProjectPaths,
    resume_type: ResumeType,
    language: ResumeLanguage,
    keep_temp: bool,
) -> Result<PathBuf> {
    let temp_file = generate_temp_typst_file(paths, resume_type, language)?;

    // Ensure output directory exists
    fs::create_dir_all(&paths.output).with_context(|| {
        format!(
            "Failed to create output directory: {}",
            paths.output.display()
        )
    })?;

    let output_file = paths.output.join(output_filename(resume_type, language));

    println!(
        "{}",
        format!(
            "Building {}",
            output_file
                .strip_prefix(&paths.root)
                .unwrap_or(&output_file)
                .display()
        )
        .cyan()
    );

    // Create the Typst world
    let world = ResumeWorld::new(paths.root.clone(), temp_file.clone())?;

    // Compile the document
    let result = typst::compile(&world);

    // Clean up temp file if not keeping
    let cleanup = || {
        if !keep_temp && temp_file.exists() {
            let _ = fs::remove_file(&temp_file);
        }
    };

    match result.output {
        Ok(doc) => {
            // Export to PDF
            let pdf_options = PdfOptions::default();
            let pdf_result = typst_pdf::pdf(&doc, &pdf_options);

            match pdf_result {
                Ok(pdf_data) => {
                    fs::write(&output_file, pdf_data).with_context(|| {
                        format!("Failed to write PDF: {}", output_file.display())
                    })?;

                    cleanup();
                    Ok(output_file)
                }
                Err(errors) => {
                    cleanup();
                    let error_messages: Vec<String> = errors
                        .iter()
                        .map(|diag| {
                            let severity = match diag.severity {
                                Severity::Error => "error".red(),
                                Severity::Warning => "warning".yellow(),
                            };
                            format!("{}: {}", severity, diag.message)
                        })
                        .collect();
                    bail!("PDF export failed:\n{}", error_messages.join("\n"))
                }
            }
        }
        Err(errors) => {
            cleanup();

            // Format and display errors
            let mut error_messages = Vec::new();
            for diag in errors.iter() {
                let severity = match diag.severity {
                    Severity::Error => "error".red(),
                    Severity::Warning => "warning".yellow(),
                };
                error_messages.push(format!("{}: {}", severity, diag.message));
            }

            bail!("Typst compilation failed:\n{}", error_messages.join("\n"))
        }
    }
}

/// Build multiple resume variants.
pub fn build_resumes(
    paths: &ProjectPaths,
    types: Option<Vec<ResumeType>>,
    languages: Option<Vec<ResumeLanguage>>,
    keep_temp: bool,
) -> Result<Vec<PathBuf>> {
    let resolved_types = resolve_types(types);
    let resolved_languages = resolve_languages(languages);

    let mut built = Vec::new();

    for resume_type in resolved_types {
        for language in &resolved_languages {
            let output = build_single(paths, resume_type, *language, keep_temp)?;
            built.push(output);
        }
    }

    Ok(built)
}
