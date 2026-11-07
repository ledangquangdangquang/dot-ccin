// Task list + pomodoro timer TUI, and the i3status-rust block helpers.
// `pomodoro-task` opens the TUI, `show` prints the bar text (and advances the timer),
// `done` finishes the doing task, `timer` starts/pauses/resumes the timer.
// Storage: ~/.cache/pomodoro-tasks, one "state<TAB>name<TAB>pomodoros" per line (state: todo|doing|done);
// ~/.cache/pomodoro-timer, "work|break<TAB>run|pause<TAB>end epoch (run) or seconds left (pause)".

use std::{
    env, fs, io,
    path::PathBuf,
    process::Command,
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use ratatui::{
    crossterm::event::{self, Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers},
    layout::{Constraint, Layout, Margin, Position},
    style::{Color, Modifier, Style},
    symbols,
    text::{Line, Span},
    widgets::{Block, BorderType, LineGauge, List, ListItem, ListState, Paragraph, Wrap},
    DefaultTerminal, Frame,
};

// Catppuccin Mocha
const BLUE: Color = Color::Rgb(0x89, 0xb4, 0xfa);
const GREEN: Color = Color::Rgb(0xa6, 0xe3, 0xa1);
const PEACH: Color = Color::Rgb(0xfa, 0xb3, 0x87);
const TEXT: Color = Color::Rgb(0xcd, 0xd6, 0xf4);
const SUBTEXT0: Color = Color::Rgb(0xa6, 0xad, 0xc8);
const OVERLAY0: Color = Color::Rgb(0x6c, 0x70, 0x86);
const SURFACE0: Color = Color::Rgb(0x31, 0x32, 0x44);
const SURFACE1: Color = Color::Rgb(0x45, 0x47, 0x5a);
const BASE: Color = Color::Rgb(0x1e, 0x1e, 0x2e);

const WORK_SECS: u64 = 25 * 60;
const BREAK_SECS: u64 = 5 * 60;
// Nerd Font glyphs: timer, coffee, pause
const ICON_WORK: &str = "\u{f051b}";
const ICON_BREAK: &str = "\u{f0f4}";
const ICON_PAUSE: &str = "\u{f04c}";

#[derive(Clone, Copy, PartialEq)]
enum State {
    Todo,
    Doing,
    Done,
}

impl State {
    fn parse(s: &str) -> Option<Self> {
        match s {
            "todo" => Some(Self::Todo),
            "doing" => Some(Self::Doing),
            "done" => Some(Self::Done),
            _ => None,
        }
    }
    fn as_str(self) -> &'static str {
        match self {
            Self::Todo => "todo",
            Self::Doing => "doing",
            Self::Done => "done",
        }
    }
    // List order: doing first, done last
    fn rank(self) -> u8 {
        match self {
            Self::Doing => 0,
            Self::Todo => 1,
            Self::Done => 2,
        }
    }
    fn next(self) -> Self {
        match self {
            Self::Todo => Self::Doing,
            Self::Doing => Self::Done,
            Self::Done => Self::Todo,
        }
    }
}

struct Task {
    state: State,
    name: String,
    pomos: u32,
}

fn cache(name: &str) -> PathBuf {
    PathBuf::from(env::var_os("HOME").unwrap_or_default()).join(".cache").join(name)
}

fn load() -> Vec<Task> {
    let mut tasks: Vec<Task> = fs::read_to_string(cache("pomodoro-tasks"))
        .unwrap_or_default()
        .lines()
        .filter_map(|l| {
            let mut f = l.split('\t');
            let state = State::parse(f.next()?)?;
            let name = f.next()?.to_string();
            let pomos = f.next().and_then(|p| p.parse().ok()).unwrap_or(0);
            Some(Task { state, name, pomos })
        })
        .collect();
    tasks.sort_by_key(|t| t.state.rank());
    tasks
}

fn save(tasks: &[Task]) -> io::Result<()> {
    let p = cache("pomodoro-tasks");
    if let Some(dir) = p.parent() {
        fs::create_dir_all(dir)?;
    }
    let body: String =
        tasks.iter().map(|t| format!("{}\t{}\t{}\n", t.state.as_str(), t.name, t.pomos)).collect();
    // fs::write truncates in place (same inode), so the bar's inotify watch keeps working
    fs::write(p, body)
}

fn counts(tasks: &[Task]) -> (usize, usize) {
    (tasks.iter().filter(|t| t.state == State::Done).count(), tasks.len())
}

fn doing(tasks: &[Task]) -> Option<&str> {
    tasks.iter().find(|t| t.state == State::Doing).map(|t| t.name.as_str())
}

fn now() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0)
}

#[derive(Clone, Copy, PartialEq)]
enum Phase {
    Work,
    Break,
}

#[derive(Clone, Copy)]
struct Timer {
    phase: Phase,
    running: bool,
    // end epoch while running, seconds left while paused
    value: u64,
}

impl Timer {
    fn load() -> Option<Self> {
        let s = fs::read_to_string(cache("pomodoro-timer")).ok()?;
        let mut f = s.trim().split('\t');
        let phase = match f.next()? {
            "work" => Phase::Work,
            "break" => Phase::Break,
            _ => return None,
        };
        let running = f.next()? == "run";
        let value = f.next()?.parse().ok()?;
        Some(Self { phase, running, value })
    }
    fn save(timer: Option<Self>) -> io::Result<()> {
        let p = cache("pomodoro-timer");
        match timer {
            None => fs::remove_file(p).or_else(|e| if e.kind() == io::ErrorKind::NotFound { Ok(()) } else { Err(e) }),
            Some(t) => {
                let phase = if t.phase == Phase::Work { "work" } else { "break" };
                let mode = if t.running { "run" } else { "pause" };
                fs::write(p, format!("{phase}\t{mode}\t{}\n", t.value))
            }
        }
    }
    fn start(phase: Phase, secs: u64) -> Self {
        Self { phase, running: true, value: now() + secs }
    }
    fn left(self) -> u64 {
        if self.running { self.value.saturating_sub(now()) } else { self.value }
    }
    fn total(self) -> u64 {
        if self.phase == Phase::Work { WORK_SECS } else { BREAK_SECS }
    }
    fn icon(self) -> &'static str {
        match (self.running, self.phase) {
            (false, _) => ICON_PAUSE,
            (true, Phase::Work) => ICON_WORK,
            (true, Phase::Break) => ICON_BREAK,
        }
    }
    fn clock(self) -> String {
        let s = self.left();
        format!("{:02}:{:02}", s / 60, s % 60)
    }
}

// start → pause → resume
fn toggle_timer() -> io::Result<()> {
    let next = match Timer::load() {
        None => Timer::start(Phase::Work, WORK_SECS),
        Some(t) if t.running => Timer { running: false, value: t.left(), ..t },
        Some(t) => Timer::start(t.phase, t.value),
    };
    Timer::save(Some(next))
}

fn notify(body: &str) {
    let _ = Command::new("notify-send").args(["--app-name=Pomodoro", "Pomodoro", body]).status();
}

// Called every second by the bar's `show`, the only place the timer advances:
// a single ticker avoids double notifications. shortcut: with the bar not running, the timer
// never rolls over; move this into a daemon if the bar is ever dropped.
fn tick() -> io::Result<()> {
    let Some(t) = Timer::load() else { return Ok(()) };
    if !t.running || t.left() > 0 {
        return Ok(());
    }
    match t.phase {
        Phase::Work => {
            let mut tasks = load();
            if let Some(task) = tasks.iter_mut().find(|t| t.state == State::Doing) {
                task.pomos += 1;
                save(&tasks)?;
            }
            Timer::save(Some(Timer::start(Phase::Break, BREAK_SECS)))?;
            notify("Work session done. Take a 5 minute break.");
        }
        Phase::Break => {
            Timer::save(None)?;
            notify("Break over. Back to work!");
        }
    }
    Ok(())
}

fn summary(tasks: &[Task], timer: Option<Timer>) -> String {
    let (d, t) = counts(tasks);
    let task = if t == 0 {
        "No task".to_string()
    } else {
        let label = doing(tasks).unwrap_or(if d == t { "All done" } else { "No task in progress" });
        format!("{label} ({d}/{t})")
    };
    match timer {
        Some(tm) if tm.phase == Phase::Break => format!("{} {} Break", tm.icon(), tm.clock()),
        Some(tm) => format!("{} {} {task}", tm.icon(), tm.clock()),
        None => task,
    }
}

fn main() -> io::Result<()> {
    match env::args().nth(1).as_deref() {
        Some("show") => {
            tick()?;
            println!("{}", summary(&load(), Timer::load()));
            Ok(())
        }
        Some("done") => {
            let mut tasks = load();
            tasks.iter_mut().filter(|t| t.state == State::Doing).for_each(|t| t.state = State::Done);
            save(&tasks)
        }
        Some("timer") => toggle_timer(),
        _ => {
            let mut terminal = ratatui::init();
            let result = App::default().run(&mut terminal);
            ratatui::restore();
            result
        }
    }
}

#[derive(Default, PartialEq)]
enum Mode {
    #[default]
    Normal,
    Add,
    Edit,
}

#[derive(Default)]
struct App {
    tasks: Vec<Task>,
    timer: Option<Timer>,
    list: ListState,
    mode: Mode,
    input: String,
    date: String,
    quit: bool,
}

impl App {
    fn run(mut self, terminal: &mut DefaultTerminal) -> io::Result<()> {
        self.date = Command::new("date")
            .arg("+%A, %d/%m")
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
            .unwrap_or_default();
        while !self.quit {
            // Reload every tick: the bar can change both files while this is open
            self.tasks = load();
            self.timer = Timer::load();
            let len = self.tasks.len();
            self.list.select((len > 0).then(|| self.list.selected().unwrap_or(0).min(len - 1)));
            terminal.draw(|f| self.draw(f))?;
            if event::poll(Duration::from_secs(1))? {
                if let Event::Key(key) = event::read()? {
                    if key.kind == KeyEventKind::Press {
                        self.on_key(key)?;
                    }
                }
            }
        }
        Ok(())
    }

    fn on_key(&mut self, key: KeyEvent) -> io::Result<()> {
        let ctrl = key.modifiers.contains(KeyModifiers::CONTROL);
        let code = match key.code {
            // Some terminals (tmux) send Enter as Ctrl+J / Ctrl+M
            KeyCode::Char('j' | 'm') if ctrl => KeyCode::Enter,
            KeyCode::Char('c') if ctrl => {
                self.quit = true;
                return Ok(());
            }
            KeyCode::Char(_) if ctrl => return Ok(()),
            c => c,
        };
        if self.mode != Mode::Normal {
            match code {
                KeyCode::Esc => self.mode = Mode::Normal,
                KeyCode::Enter => return self.commit(),
                KeyCode::Backspace => {
                    self.input.pop();
                }
                KeyCode::Char(c) => self.input.push(c),
                _ => {}
            }
            return Ok(());
        }
        let sel = self.list.selected();
        match code {
            KeyCode::Char('q') | KeyCode::Esc => self.quit = true,
            KeyCode::Char('j') | KeyCode::Down => self.list.select_next(),
            KeyCode::Char('k') | KeyCode::Up => self.list.select_previous(),
            KeyCode::Char('a') | KeyCode::Char('i') => {
                self.input.clear();
                self.mode = Mode::Add;
            }
            KeyCode::Char('e') => {
                if let Some(i) = sel {
                    self.input = self.tasks[i].name.clone();
                    self.mode = Mode::Edit;
                }
            }
            KeyCode::Char('d') | KeyCode::Delete => {
                if let Some(i) = sel {
                    self.tasks.remove(i);
                    save(&self.tasks)?;
                }
            }
            KeyCode::Enter | KeyCode::Char(' ') => {
                if let Some(i) = sel {
                    let next = self.tasks[i].state.next();
                    self.set_state(i, next)?;
                }
            }
            KeyCode::Char('p') => {
                // A fresh timer works on the selected task when nothing is in progress
                if self.timer.is_none() && doing(&self.tasks).is_none() {
                    if let Some(i) = sel.filter(|&i| self.tasks[i].state == State::Todo) {
                        self.set_state(i, State::Doing)?;
                    }
                }
                toggle_timer()?;
            }
            KeyCode::Char('s') => Timer::save(None)?,
            _ => {}
        }
        Ok(())
    }

    fn set_state(&mut self, i: usize, next: State) -> io::Result<()> {
        // Only one task is doing at a time
        if next == State::Doing {
            for t in self.tasks.iter_mut().filter(|t| t.state == State::Doing) {
                t.state = State::Todo;
            }
        }
        self.tasks[i].state = next;
        let name = self.tasks[i].name.clone();
        self.save_and_select(&name)
    }

    fn commit(&mut self) -> io::Result<()> {
        let mode = std::mem::take(&mut self.mode);
        let name = self.input.trim().replace('\t', " ");
        // Names are unique: duplicates are ignored
        if name.is_empty() || self.tasks.iter().any(|t| t.name == name) {
            return Ok(());
        }
        match (mode, self.list.selected()) {
            (Mode::Edit, Some(i)) => self.tasks[i].name = name.clone(),
            _ => self.tasks.push(Task { state: State::Todo, name: name.clone(), pomos: 0 }),
        }
        self.save_and_select(&name)
    }

    // Cursor follows the task after it moves to its new group
    fn save_and_select(&mut self, name: &str) -> io::Result<()> {
        self.tasks.sort_by_key(|t| t.state.rank());
        self.list.select(self.tasks.iter().position(|t| t.name == name));
        save(&self.tasks)
    }

    fn draw(&mut self, f: &mut Frame) {
        let input_h = if self.mode == Mode::Normal { 0 } else { 3 };
        let [date, gauge, current, timer, input, list, help] = Layout::vertical([
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Length(2),
            Constraint::Length(input_h),
            Constraint::Min(0),
            Constraint::Length(2),
        ])
        .areas(f.area().inner(Margin::new(2, 1)));

        f.render_widget(Paragraph::new(self.date.as_str()).style(Style::new().fg(SUBTEXT0)), date);

        let (d, t) = counts(&self.tasks);
        f.render_widget(
            LineGauge::default()
                .label(format!("Done {d}/{t}  "))
                .ratio(if t == 0 { 0.0 } else { d as f64 / t as f64 })
                .line_set(symbols::line::THICK)
                .style(Style::new().fg(TEXT))
                .filled_style(Style::new().fg(BLUE))
                .unfilled_style(Style::new().fg(SURFACE1)),
            gauge,
        );

        let now = match doing(&self.tasks) {
            Some(name) => Line::from(vec![
                Span::styled("▶ ", Style::new().fg(BLUE)),
                Span::styled(name, Style::new().fg(TEXT).add_modifier(Modifier::BOLD)),
            ]),
            None => Line::styled("No task in progress", Style::new().fg(OVERLAY0)),
        };
        f.render_widget(Paragraph::new(now), current);

        match self.timer {
            Some(tm) => {
                let (label, color) = match (tm.running, tm.phase) {
                    (false, _) => ("Paused", OVERLAY0),
                    (true, Phase::Work) => ("Focus", PEACH),
                    (true, Phase::Break) => ("Break", GREEN),
                };
                f.render_widget(
                    LineGauge::default()
                        .label(format!("{} {}  {label}  ", tm.icon(), tm.clock()))
                        .ratio(1.0 - tm.left() as f64 / tm.total() as f64)
                        .line_set(symbols::line::THICK)
                        .style(Style::new().fg(color))
                        .filled_style(Style::new().fg(color))
                        .unfilled_style(Style::new().fg(SURFACE1)),
                    timer,
                );
            }
            None => f.render_widget(
                Paragraph::new(format!("{ICON_WORK} Press p to start a 25 min focus session"))
                    .style(Style::new().fg(OVERLAY0)),
                timer,
            ),
        }

        if self.mode != Mode::Normal {
            let title = if self.mode == Mode::Add { " New task " } else { " Edit task " };
            let block = Block::bordered()
                .border_type(BorderType::Rounded)
                .border_style(Style::new().fg(BLUE))
                .title(title);
            let inner = block.inner(input);
            f.render_widget(Paragraph::new(self.input.as_str()).style(Style::new().fg(TEXT)).block(block), input);
            // shortcut: no horizontal scroll, very long names run past the box
            f.set_cursor_position(Position::new(inner.x + Line::from(self.input.as_str()).width() as u16, inner.y));
        }

        if self.tasks.is_empty() {
            f.render_widget(
                Paragraph::new("No tasks yet. Press a to add one.").style(Style::new().fg(SUBTEXT0)),
                list,
            );
        } else {
            let items: Vec<ListItem> = self
                .tasks
                .iter()
                .map(|t| {
                    let name = t.name.as_str();
                    let mut spans = match t.state {
                        State::Doing => vec![
                            Span::styled("▌ ", Style::new().fg(BLUE)),
                            Span::styled(name, Style::new().fg(BLUE).add_modifier(Modifier::BOLD)),
                            Span::raw("  "),
                            Span::styled(" Doing ", Style::new().fg(BASE).bg(BLUE)),
                        ],
                        State::Todo => vec![
                            Span::styled("○ ", Style::new().fg(SUBTEXT0)),
                            Span::styled(name, Style::new().fg(TEXT)),
                        ],
                        State::Done => vec![
                            Span::styled("✓ ", Style::new().fg(GREEN)),
                            Span::styled(name, Style::new().fg(OVERLAY0).add_modifier(Modifier::CROSSED_OUT)),
                        ],
                    };
                    if t.pomos > 0 {
                        spans.push(Span::styled(format!("  {ICON_WORK} {}", t.pomos), Style::new().fg(PEACH)));
                    }
                    ListItem::new(Line::from(spans))
                })
                .collect();
            f.render_stateful_widget(
                List::new(items).highlight_style(Style::new().bg(SURFACE0)),
                list,
                &mut self.list,
            );
        }

        let keys = if self.mode == Mode::Normal {
            "enter next state · a add · e edit · d delete · p start/pause timer · s stop timer · q quit"
        } else {
            "enter save · esc cancel"
        };
        f.render_widget(Paragraph::new(keys).style(Style::new().fg(OVERLAY0)).wrap(Wrap { trim: true }), help);
    }
}
