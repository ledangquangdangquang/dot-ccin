// Month calendar TUI with Vietnamese lunar dates.

mod lunar;

use std::{io, process::Command};

use lunar::{can_chi_day, can_chi_month, can_chi_year, jd_from_date, jd_to_date, solar_to_lunar};
use ratatui::{
    crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers},
    layout::{Constraint, Layout, Margin},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Paragraph, Wrap},
    DefaultTerminal, Frame,
};

// Catppuccin Mocha
const BLUE: Color = Color::Rgb(0x89, 0xb4, 0xfa);
const RED: Color = Color::Rgb(0xf3, 0x8b, 0xa8);
const PEACH: Color = Color::Rgb(0xfa, 0xb3, 0x87);
const TEXT: Color = Color::Rgb(0xcd, 0xd6, 0xf4);
const SUBTEXT0: Color = Color::Rgb(0xa6, 0xad, 0xc8);
const OVERLAY0: Color = Color::Rgb(0x6c, 0x70, 0x86);
const SURFACE1: Color = Color::Rgb(0x45, 0x47, 0x5a);
const BASE: Color = Color::Rgb(0x1e, 0x1e, 0x2e);

const WEEKDAYS: [&str; 7] = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"];
const WEEKDAY_NAMES: [&str; 7] = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
const MONTHS: [&str; 12] = [
    "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November",
    "December",
];

// 0 = Monday
fn weekday(jd: i64) -> i64 {
    jd.rem_euclid(7)
}

fn today() -> i64 {
    let out = Command::new("date").arg("+%d %m %Y").output().ok();
    let s = out.map(|o| String::from_utf8_lossy(&o.stdout).into_owned()).unwrap_or_default();
    let n: Vec<i64> = s.split_whitespace().filter_map(|x| x.parse().ok()).collect();
    match n[..] {
        [d, m, y] => jd_from_date(d, m, y),
        _ => jd_from_date(1, 1, 2000),
    }
}

// Same day in the month `delta` months away, clamped to that month's length
fn add_months(jd: i64, delta: i64) -> i64 {
    let (d, m, y) = jd_to_date(jd);
    let idx = y * 12 + (m - 1) + delta;
    let (ny, nm) = (idx.div_euclid(12), idx.rem_euclid(12) + 1);
    let first = jd_from_date(1, nm, ny);
    let (nny, nnm) = if nm == 12 { (ny + 1, 1) } else { (ny, nm + 1) };
    let len = jd_from_date(1, nnm, nny) - first;
    first + d.min(len) - 1
}

fn main() -> io::Result<()> {
    let mut terminal = ratatui::init();
    let result = run(&mut terminal);
    ratatui::restore();
    result
}

fn run(terminal: &mut DefaultTerminal) -> io::Result<()> {
    let today = today();
    let mut sel = today;
    loop {
        terminal.draw(|f| draw(f, sel, today))?;
        if let Event::Key(key) = event::read()? {
            if key.kind != KeyEventKind::Press {
                continue;
            }
            sel = match key.code {
                KeyCode::Char('q') | KeyCode::Esc => return Ok(()),
                KeyCode::Char('c') if key.modifiers.contains(KeyModifiers::CONTROL) => return Ok(()),
                KeyCode::Char('h') | KeyCode::Left => sel - 1,
                KeyCode::Char('l') | KeyCode::Right => sel + 1,
                KeyCode::Char('k') | KeyCode::Up => sel - 7,
                KeyCode::Char('j') | KeyCode::Down => sel + 7,
                KeyCode::Char('p') | KeyCode::Char('H') | KeyCode::PageUp => add_months(sel, -1),
                KeyCode::Char('n') | KeyCode::Char('L') | KeyCode::PageDown => add_months(sel, 1),
                KeyCode::Char('t') => today,
                _ => sel,
            };
        }
    }
}

fn draw(f: &mut Frame, sel: i64, today: i64) {
    let [title, grid, details, help] = Layout::vertical([
        Constraint::Length(2),
        // weekday header + 6 weeks x 2 rows
        Constraint::Length(13),
        Constraint::Length(4),
        Constraint::Length(2),
    ])
    .areas(f.area().inner(Margin::new(2, 1)));

    let (_, month, year) = jd_to_date(sel);
    f.render_widget(
        Paragraph::new(Line::styled(format!("{} {year}", MONTHS[month as usize - 1]), Style::new().fg(BLUE).add_modifier(Modifier::BOLD))),
        title,
    );

    // 6 weeks from the Monday on/before the 1st; each week is a solar row + a lunar row
    let first = jd_from_date(1, month, year);
    let start = first - weekday(first);
    let mut lines = vec![Line::from(
        WEEKDAYS
            .iter()
            .enumerate()
            .map(|(i, w)| Span::styled(format!("{w:>4}  "), Style::new().fg(if i == 6 { RED } else { SUBTEXT0 })))
            .collect::<Vec<_>>(),
    )];
    for week in 0..6 {
        let mut solar = Vec::new();
        let mut moon = Vec::new();
        for i in 0..7 {
            let jd = start + week * 7 + i;
            let (d, m, _) = jd_to_date(jd);
            let l = solar_to_lunar(jd);
            let lunar_text = if l.day == 1 { format!("{}/{}", l.day, l.month) } else { l.day.to_string() };

            let mut s = Style::new().fg(if i == 6 { RED } else { TEXT });
            let mut ls = Style::new().fg(if l.day == 1 || l.day == 15 { PEACH } else { OVERLAY0 });
            if m != month {
                s = s.fg(SURFACE1);
                ls = ls.fg(SURFACE1);
            }
            if jd == sel {
                s = s.bg(SURFACE1).fg(TEXT).add_modifier(Modifier::BOLD);
                ls = ls.bg(SURFACE1);
            }
            if jd == today {
                s = s.bg(BLUE).fg(BASE).add_modifier(Modifier::BOLD);
                ls = ls.bg(BLUE).fg(BASE);
            }
            solar.push(Span::styled(format!("{d:>4}  "), s));
            moon.push(Span::styled(format!("{lunar_text:>4}  "), ls));
        }
        lines.push(Line::from(solar));
        lines.push(Line::from(moon));
    }
    f.render_widget(Paragraph::new(lines), grid);

    let (d, m, y) = jd_to_date(sel);
    let l = solar_to_lunar(sel);
    let leap = if l.leap { " (leap)" } else { "" };
    let label = Style::new().fg(SUBTEXT0);
    let value = Style::new().fg(TEXT);
    f.render_widget(
        Paragraph::new(vec![
            Line::raw(""),
            Line::styled(
                format!("{}, {d:02}/{m:02}/{y}", WEEKDAY_NAMES[weekday(sel) as usize]),
                Style::new().fg(TEXT).add_modifier(Modifier::BOLD),
            ),
            Line::from(vec![
                Span::styled("Lunar: ", label),
                Span::styled(format!("{:02}/{:02}{leap}, year {}", l.day, l.month, can_chi_year(l.year)), value),
            ]),
            Line::from(vec![
                Span::styled("Day ", label),
                Span::styled(can_chi_day(sel), value),
                Span::styled(" · month ", label),
                Span::styled(can_chi_month(l.month, l.year), value),
            ]),
        ]),
        details,
    );

    f.render_widget(
        Paragraph::new("h/l day · j/k week · n/p month · t today · q quit").style(Style::new().fg(OVERLAY0)).wrap(Wrap { trim: true }),
        help,
    );
}
