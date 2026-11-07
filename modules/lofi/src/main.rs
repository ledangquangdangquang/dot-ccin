// Lofi player TUI. Playback lifecycle stays in the `lofi` script (mpv + bar refresh);
// this reads status and sends small commands over mpv's IPC socket.

use std::{
    env, fs,
    io::{self, BufRead, BufReader, Write},
    os::unix::net::UnixStream,
    path::PathBuf,
    process::{Command, Stdio},
    time::Duration,
};

use ratatui::{
    crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers},
    layout::{Constraint, Layout, Margin},
    style::{Color, Modifier, Style},
    symbols,
    text::{Line, Span},
    widgets::{LineGauge, List, ListItem, ListState, Paragraph, Wrap},
    DefaultTerminal, Frame,
};
use serde_json::{json, Value};

// Catppuccin Mocha
const MAUVE: Color = Color::Rgb(0xcb, 0xa6, 0xf7);
const GREEN: Color = Color::Rgb(0xa6, 0xe3, 0xa1);
const TEXT: Color = Color::Rgb(0xcd, 0xd6, 0xf4);
const SUBTEXT0: Color = Color::Rgb(0xa6, 0xad, 0xc8);
const OVERLAY0: Color = Color::Rgb(0x6c, 0x70, 0x86);
const SURFACE0: Color = Color::Rgb(0x31, 0x32, 0x44);
const SURFACE1: Color = Color::Rgb(0x45, 0x47, 0x5a);

fn socket() -> PathBuf {
    PathBuf::from(env::var_os("XDG_RUNTIME_DIR").unwrap_or_else(|| "/tmp".into())).join("lofi-mpv.sock")
}

fn music_dir() -> PathBuf {
    PathBuf::from(env::var_os("HOME").unwrap_or_default()).join("Music/Lofi")
}

fn tracks() -> Vec<PathBuf> {
    let mut files: Vec<PathBuf> = fs::read_dir(music_dir())
        .map(|rd| rd.filter_map(|e| e.ok().map(|e| e.path())).filter(|p| p.is_file()).collect())
        .unwrap_or_default();
    files.sort();
    files
}

// Send commands, return each reply's "data" in order (None on error or missing).
// mpv also pushes event lines to every client, so replies are matched by request_id.
fn ipc(cmds: &[Value]) -> Option<Vec<Value>> {
    let mut stream = UnixStream::connect(socket()).ok()?;
    stream.set_read_timeout(Some(Duration::from_millis(300))).ok()?;
    let mut req = String::new();
    for (i, c) in cmds.iter().enumerate() {
        req += &json!({ "command": c, "request_id": i }).to_string();
        req.push('\n');
    }
    stream.write_all(req.as_bytes()).ok()?;
    let mut out = vec![Value::Null; cmds.len()];
    let mut left = cmds.len();
    for line in BufReader::new(stream).lines() {
        let Ok(line) = line else { break };
        let Ok(v) = serde_json::from_str::<Value>(&line) else { continue };
        if let Some(i) = v.get("request_id").and_then(Value::as_u64) {
            if let Some(slot) = out.get_mut(i as usize) {
                *slot = v.get("data").cloned().unwrap_or(Value::Null);
                left -= 1;
                if left == 0 {
                    break;
                }
            }
        }
    }
    Some(out)
}

fn lofi(args: &[&str]) {
    let _ = Command::new("lofi").args(args).stdout(Stdio::null()).stderr(Stdio::null()).status();
}

#[derive(Default)]
struct Status {
    title: String,
    path: String,
    paused: bool,
    repeat_one: bool,
    pos: f64,
    duration: f64,
    volume: f64,
}

fn status() -> Option<Status> {
    let props = ["media-title", "path", "pause", "loop-file", "time-pos", "duration", "volume"];
    let cmds: Vec<Value> = props.iter().map(|p| json!(["get_property", p])).collect();
    let r = ipc(&cmds)?;
    Some(Status {
        title: r[0].as_str().unwrap_or("").to_string(),
        path: r[1].as_str().unwrap_or("").to_string(),
        paused: r[2].as_bool().unwrap_or(false),
        // loop-file is "inf" when repeating one track
        repeat_one: r[3].as_str() == Some("inf"),
        pos: r[4].as_f64().unwrap_or(0.0),
        duration: r[5].as_f64().unwrap_or(0.0),
        volume: r[6].as_f64().unwrap_or(0.0),
    })
}

fn clock(secs: f64) -> String {
    let s = secs.max(0.0) as u64;
    format!("{:02}:{:02}", s / 60, s % 60)
}

fn main() -> io::Result<()> {
    let mut terminal = ratatui::init();
    let result = run(&mut terminal);
    ratatui::restore();
    result
}

fn run(terminal: &mut DefaultTerminal) -> io::Result<()> {
    let files = tracks();
    let mut list = ListState::default();
    let mut st = status();
    // Start on the playing track, else the first
    let playing = st.as_ref().and_then(|s| files.iter().position(|f| f.to_string_lossy() == s.path));
    list.select(if files.is_empty() { None } else { Some(playing.unwrap_or(0)) });
    loop {
        terminal.draw(|f| draw(f, &files, &mut list, st.as_ref()))?;
        if event::poll(Duration::from_millis(500))? {
            if let Event::Key(key) = event::read()? {
                if key.kind != KeyEventKind::Press {
                    continue;
                }
                let sel = list.selected().filter(|&i| i < files.len());
                match key.code {
                    KeyCode::Char('q') | KeyCode::Esc => return Ok(()),
                    KeyCode::Char('c') if key.modifiers.contains(KeyModifiers::CONTROL) => return Ok(()),
                    KeyCode::Char('j') | KeyCode::Down => list.select_next(),
                    KeyCode::Char('k') | KeyCode::Up => list.select_previous(),
                    KeyCode::Enter => {
                        if let Some(i) = sel {
                            lofi(&["play", &files[i].to_string_lossy()]);
                        }
                    }
                    KeyCode::Char('s') => lofi(&["play"]),
                    KeyCode::Char(' ') | KeyCode::Char('p') => lofi(&["toggle"]),
                    KeyCode::Char('r') => lofi(&["loop"]),
                    KeyCode::Char('x') => lofi(&["stop"]),
                    KeyCode::Char('n') => drop(ipc(&[json!(["playlist-next", "force"])])),
                    KeyCode::Char('b') => drop(ipc(&[json!(["playlist-prev", "force"])])),
                    KeyCode::Right | KeyCode::Char('l') => drop(ipc(&[json!(["seek", 10])])),
                    KeyCode::Left | KeyCode::Char('h') => drop(ipc(&[json!(["seek", -10])])),
                    KeyCode::Char('+') | KeyCode::Char('=') => drop(ipc(&[json!(["add", "volume", 5])])),
                    KeyCode::Char('-') => drop(ipc(&[json!(["add", "volume", -5])])),
                    _ => {}
                }
            }
        }
        if let Some(i) = list.selected() {
            list.select((!files.is_empty()).then(|| i.min(files.len() - 1)));
        }
        st = status();
    }
}

fn draw(f: &mut Frame, files: &[PathBuf], list: &mut ListState, st: Option<&Status>) {
    let [title, progress, info, _, tracks_area, help] = Layout::vertical([
        Constraint::Length(1),
        Constraint::Length(1),
        Constraint::Length(1),
        Constraint::Length(1),
        Constraint::Min(0),
        Constraint::Length(3),
    ])
    .areas(f.area().inner(Margin::new(2, 1)));

    match st {
        Some(s) => {
            let icon = if s.paused { "\u{f04c}" } else { "\u{f04b}" };
            f.render_widget(
                Paragraph::new(Line::from(vec![
                    Span::styled(format!("{icon}  "), Style::new().fg(MAUVE)),
                    Span::styled(s.title.as_str(), Style::new().fg(TEXT).add_modifier(Modifier::BOLD)),
                ])),
                title,
            );
            f.render_widget(
                LineGauge::default()
                    .label(format!("{} / {}  ", clock(s.pos), clock(s.duration)))
                    .ratio(if s.duration > 0.0 { (s.pos / s.duration).clamp(0.0, 1.0) } else { 0.0 })
                    .line_set(symbols::line::THICK)
                    .style(Style::new().fg(SUBTEXT0))
                    .filled_style(Style::new().fg(MAUVE))
                    .unfilled_style(Style::new().fg(SURFACE1)),
                progress,
            );
            let repeat = if s.repeat_one { "Repeat one" } else { "Repeat all" };
            f.render_widget(
                Paragraph::new(format!("Volume {:.0}%  ·  {repeat}", s.volume)).style(Style::new().fg(SUBTEXT0)),
                info,
            );
        }
        None => f.render_widget(
            Paragraph::new("Not playing. Enter plays the selected track, s shuffles all.")
                .style(Style::new().fg(OVERLAY0))
                .wrap(Wrap { trim: true }),
            title.union(progress),
        ),
    }

    if files.is_empty() {
        f.render_widget(
            Paragraph::new(format!("No tracks in {}", music_dir().display())).style(Style::new().fg(SUBTEXT0)),
            tracks_area,
        );
    } else {
        let playing = st.map(|s| s.path.as_str()).unwrap_or("");
        let items: Vec<ListItem> = files
            .iter()
            .map(|p| {
                let name = p.file_stem().map(|s| s.to_string_lossy().into_owned()).unwrap_or_default();
                if p.to_string_lossy() == playing {
                    ListItem::new(Line::from(vec![
                        Span::styled("\u{f075a} ", Style::new().fg(GREEN)),
                        Span::styled(name, Style::new().fg(GREEN).add_modifier(Modifier::BOLD)),
                    ]))
                } else {
                    ListItem::new(Line::styled(format!("  {name}"), Style::new().fg(TEXT)))
                }
            })
            .collect();
        f.render_stateful_widget(List::new(items).highlight_style(Style::new().bg(SURFACE0)), tracks_area, list);
    }

    f.render_widget(
        Paragraph::new("enter play · space pause · s shuffle · n/b next/prev · ←/→ seek · +/- volume · r repeat · x stop · q quit")
            .style(Style::new().fg(OVERLAY0))
            .wrap(Wrap { trim: true }),
        help,
    );
}
