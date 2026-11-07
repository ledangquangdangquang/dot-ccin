// Clipboard history TUI over cliphist: list, filter, text/image preview, copy back, delete.

use std::{
    collections::HashMap,
    io::{self, Write},
    os::unix::process::CommandExt,
    process::{Command, Stdio},
};

use image::DynamicImage;
use ratatui::{
    crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers},
    layout::{Constraint, Layout, Margin, Position, Rect},
    style::{Color, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, List, ListItem, ListState, Paragraph, Wrap},
    DefaultTerminal, Frame,
};

// Catppuccin Mocha
const BLUE: Color = Color::Rgb(0x89, 0xb4, 0xfa);
const RED: Color = Color::Rgb(0xf3, 0x8b, 0xa8);
const PEACH: Color = Color::Rgb(0xfa, 0xb3, 0x87);
const TEXT: Color = Color::Rgb(0xcd, 0xd6, 0xf4);
const SUBTEXT0: Color = Color::Rgb(0xa6, 0xad, 0xc8);
const OVERLAY0: Color = Color::Rgb(0x6c, 0x70, 0x86);
const SURFACE0: Color = Color::Rgb(0x31, 0x32, 0x44);
const SURFACE1: Color = Color::Rgb(0x45, 0x47, 0x5a);

struct Entry {
    // the raw "id<TAB>preview" line cliphist wants back for decode/delete
    line: String,
    preview: String,
    // "png", "jpeg", ... for "[[ binary data 12 KiB png 100x100 ]]" entries
    image: Option<String>,
}

fn list() -> Vec<Entry> {
    let out = Command::new("cliphist").arg("list").output().map(|o| o.stdout).unwrap_or_default();
    String::from_utf8_lossy(&out)
        .lines()
        .filter_map(|l| {
            let (_, preview) = l.split_once('\t')?;
            let image = preview
                .strip_prefix("[[ binary data ")
                .and_then(|rest| rest.split_whitespace().nth(2))
                .map(str::to_string);
            Some(Entry { line: l.to_string(), preview: preview.to_string(), image })
        })
        .collect()
}

fn cliphist(arg: &str, line: &str) -> Vec<u8> {
    let Ok(mut child) = Command::new("cliphist").arg(arg).stdin(Stdio::piped()).stdout(Stdio::piped()).spawn()
    else {
        return Vec::new();
    };
    if let Some(mut stdin) = child.stdin.take() {
        let _ = writeln!(stdin, "{line}");
    }
    child.wait_with_output().map(|o| o.stdout).unwrap_or_default()
}

fn copy(e: &Entry) -> io::Result<()> {
    let data = cliphist("decode", &e.line);
    let mut cmd = Command::new("xclip");
    cmd.args(["-selection", "clipboard"]);
    if let Some(fmt) = &e.image {
        cmd.args(["-t", &format!("image/{fmt}")]);
    }
    // Own process group: xclip stays alive to serve the clipboard after this window closes
    let mut child = cmd.stdin(Stdio::piped()).stdout(Stdio::null()).stderr(Stdio::null()).process_group(0).spawn()?;
    child.stdin.take().map(|mut s| s.write_all(&data)).transpose()?;
    child.wait()?;
    Ok(())
}

enum Preview {
    Text(String),
    Image(DynamicImage),
    Broken,
}

// Half-block pixels: each cell shows two vertically stacked pixels (fg = top, bg = bottom)
fn image_lines(img: &DynamicImage, area: Rect) -> Vec<Line<'static>> {
    let img = img.thumbnail(area.width as u32, area.height as u32 * 2).to_rgb8();
    (0..img.height())
        .step_by(2)
        .map(|y| {
            Line::from(
                (0..img.width())
                    .map(|x| {
                        let t = img.get_pixel(x, y);
                        let b = if y + 1 < img.height() { img.get_pixel(x, y + 1) } else { t };
                        Span::styled(
                            "▀",
                            Style::new().fg(Color::Rgb(t[0], t[1], t[2])).bg(Color::Rgb(b[0], b[1], b[2])),
                        )
                    })
                    .collect::<Vec<_>>(),
            )
        })
        .collect()
}

#[derive(Default)]
struct App {
    entries: Vec<Entry>,
    // indices into entries that match the filter
    shown: Vec<usize>,
    list: ListState,
    filter: String,
    searching: bool,
    confirm_wipe: bool,
    previews: HashMap<String, Preview>,
}

impl App {
    fn refilter(&mut self) {
        let f = self.filter.to_lowercase();
        self.shown =
            (0..self.entries.len()).filter(|&i| self.entries[i].preview.to_lowercase().contains(&f)).collect();
        let len = self.shown.len();
        self.list.select((len > 0).then(|| self.list.selected().unwrap_or(0).min(len - 1)));
    }

    fn selected(&self) -> Option<&Entry> {
        self.list.selected().and_then(|i| self.shown.get(i)).map(|&i| &self.entries[i])
    }

    fn preview(&mut self) -> Option<&Preview> {
        let e = self.selected()?;
        let key = e.line.clone();
        if !self.previews.contains_key(&key) {
            let data = cliphist("decode", &e.line);
            let p = if e.image.is_some() {
                image::load_from_memory(&data).map(Preview::Image).unwrap_or(Preview::Broken)
            } else {
                Preview::Text(String::from_utf8_lossy(&data).replace('\t', "    "))
            };
            self.previews.insert(key.clone(), p);
        }
        self.previews.get(&key)
    }
}

fn main() -> io::Result<()> {
    let mut app = App { entries: list(), ..Default::default() };
    app.refilter();
    let mut terminal = ratatui::init();
    let result = run(&mut terminal, &mut app);
    ratatui::restore();
    result
}

fn run(terminal: &mut DefaultTerminal, app: &mut App) -> io::Result<()> {
    loop {
        terminal.draw(|f| draw(f, app))?;
        let Event::Key(key) = event::read()? else { continue };
        if key.kind != KeyEventKind::Press {
            continue;
        }
        let ctrl = key.modifiers.contains(KeyModifiers::CONTROL);
        let code = match key.code {
            // Some terminals (tmux) send Enter as Ctrl+J / Ctrl+M
            KeyCode::Char('j' | 'm') if ctrl => KeyCode::Enter,
            KeyCode::Char('c') if ctrl => return Ok(()),
            KeyCode::Char(_) if ctrl => continue,
            c => c,
        };
        if app.confirm_wipe {
            app.confirm_wipe = false;
            if code == KeyCode::Char('y') {
                let _ = Command::new("cliphist").arg("wipe").status();
                app.entries = list();
                app.previews.clear();
                app.refilter();
            }
            continue;
        }
        if app.searching {
            match code {
                KeyCode::Esc => {
                    app.searching = false;
                    app.filter.clear();
                }
                KeyCode::Enter => app.searching = false,
                KeyCode::Backspace => {
                    app.filter.pop();
                }
                KeyCode::Char(c) => app.filter.push(c),
                KeyCode::Down => app.list.select_next(),
                KeyCode::Up => app.list.select_previous(),
                _ => {}
            }
            app.refilter();
            continue;
        }
        match code {
            KeyCode::Char('q') | KeyCode::Esc => return Ok(()),
            KeyCode::Char('j') | KeyCode::Down => app.list.select_next(),
            KeyCode::Char('k') | KeyCode::Up => app.list.select_previous(),
            KeyCode::Char('g') | KeyCode::Home => app.list.select_first(),
            KeyCode::Char('G') | KeyCode::End => app.list.select_last(),
            KeyCode::Char('/') => app.searching = true,
            KeyCode::Char('D') => app.confirm_wipe = !app.entries.is_empty(),
            KeyCode::Enter => {
                if let Some(e) = app.selected() {
                    copy(e)?;
                    return Ok(());
                }
            }
            KeyCode::Char('d') | KeyCode::Delete => {
                if let Some(e) = app.selected() {
                    cliphist("delete", &e.line);
                    app.entries = list();
                    app.refilter();
                }
            }
            _ => {}
        }
        app.refilter();
    }
}

fn draw(f: &mut Frame, app: &mut App) {
    let [search, body, help] =
        Layout::vertical([Constraint::Length(3), Constraint::Min(0), Constraint::Length(2)])
            .areas(f.area().inner(Margin::new(2, 1)));
    let [list_area, preview_area] =
        Layout::vertical([Constraint::Percentage(45), Constraint::Percentage(55)]).areas(body);

    let border = if app.searching { BLUE } else { SURFACE1 };
    let block = Block::bordered()
        .border_type(BorderType::Rounded)
        .border_style(Style::new().fg(border))
        .title(format!(" Clipboard ({}) ", app.shown.len()));
    let inner = block.inner(search);
    let (text, style) = if app.filter.is_empty() && !app.searching {
        ("/ to search", Style::new().fg(OVERLAY0))
    } else {
        (app.filter.as_str(), Style::new().fg(TEXT))
    };
    f.render_widget(Paragraph::new(text).style(style).block(block), search);
    if app.searching {
        f.set_cursor_position(Position::new(inner.x + Line::from(app.filter.as_str()).width() as u16, inner.y));
    }

    let items: Vec<ListItem> = app
        .shown
        .iter()
        .map(|&i| {
            let e = &app.entries[i];
            match &e.image {
                Some(_) => ListItem::new(Line::styled(format!("\u{f03e}  {}", e.preview), Style::new().fg(PEACH))),
                None => ListItem::new(Line::styled(e.preview.clone(), Style::new().fg(TEXT))),
            }
        })
        .collect();
    f.render_stateful_widget(List::new(items).highlight_style(Style::new().bg(SURFACE0)), list_area, &mut app.list);

    let block = Block::bordered()
        .border_type(BorderType::Rounded)
        .border_style(Style::new().fg(SURFACE1))
        .title(" Preview ");
    let inner = block.inner(preview_area);
    f.render_widget(block, preview_area);
    match app.preview() {
        Some(Preview::Text(t)) => {
            f.render_widget(Paragraph::new(t.as_str()).style(Style::new().fg(TEXT)).wrap(Wrap { trim: false }), inner)
        }
        Some(Preview::Image(img)) => f.render_widget(Paragraph::new(image_lines(img, inner)), inner),
        Some(Preview::Broken) => {
            f.render_widget(Paragraph::new("Cannot decode this image").style(Style::new().fg(OVERLAY0)), inner)
        }
        None => f.render_widget(Paragraph::new("Clipboard history is empty").style(Style::new().fg(OVERLAY0)), inner),
    }

    let (keys, style) = if app.confirm_wipe {
        ("Clear ALL clipboard history? y to confirm, any other key cancels", Style::new().fg(RED))
    } else {
        ("enter copy · / search · d delete · D clear all · g/G top/bottom · q quit", Style::new().fg(SUBTEXT0))
    };
    f.render_widget(Paragraph::new(keys).style(style).wrap(Wrap { trim: true }), help);
}
