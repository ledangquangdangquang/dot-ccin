// Vietnamese lunar calendar, Ho Ngoc Duc's algorithm (public domain).
// Astronomical new-moon / sun-longitude math, accurate for centuries around today.

use std::f64::consts::PI;

const TZ: f64 = 7.0; // Vietnam

pub fn jd_from_date(dd: i64, mm: i64, yy: i64) -> i64 {
    let a = (14 - mm) / 12;
    let y = yy + 4800 - a;
    let m = mm + 12 * a - 3;
    let jd = dd + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045;
    if jd < 2299161 {
        dd + (153 * m + 2) / 5 + 365 * y + y / 4 - 32083
    } else {
        jd
    }
}

pub fn jd_to_date(jd: i64) -> (i64, i64, i64) {
    let (b, c) = if jd > 2299160 {
        let a = jd + 32044;
        let b = (4 * a + 3) / 146097;
        (b, a - b * 146097 / 4)
    } else {
        (0, jd + 32082)
    };
    let d = (4 * c + 3) / 1461;
    let e = c - 1461 * d / 4;
    let m = (5 * e + 2) / 153;
    (e - (153 * m + 2) / 5 + 1, m + 3 - 12 * (m / 10), b * 100 + d - 4800 + m / 10)
}

fn new_moon(k: f64) -> f64 {
    let t = k / 1236.85;
    let t2 = t * t;
    let t3 = t2 * t;
    let dr = PI / 180.0;
    let mut jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
    jd1 += 0.00033 * ((166.56 + 132.87 * t - 0.009173 * t2) * dr).sin();
    let m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
    let mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
    let f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
    let mut c1 = (0.1734 - 0.000393 * t) * (m * dr).sin() + 0.0021 * (2.0 * dr * m).sin();
    c1 += -0.4068 * (mpr * dr).sin() + 0.0161 * (dr * 2.0 * mpr).sin();
    c1 += -0.0004 * (dr * 3.0 * mpr).sin();
    c1 += 0.0104 * (dr * 2.0 * f).sin() - 0.0051 * (dr * (m + mpr)).sin();
    c1 += -0.0074 * (dr * (m - mpr)).sin();
    c1 += 0.0004 * (dr * (2.0 * f + m)).sin();
    c1 += -0.0004 * (dr * (2.0 * f - m)).sin();
    c1 += -0.0006 * (dr * (2.0 * f + mpr)).sin();
    c1 += 0.0010 * (dr * (2.0 * f - mpr)).sin();
    c1 += 0.0005 * (dr * (2.0 * mpr + m)).sin();
    let deltat = if t < -11.0 {
        0.001 + 0.000839 * t + 0.0002261 * t2 - 0.00000845 * t3 - 0.000000081 * t * t3
    } else {
        -0.000278 + 0.000265 * t + 0.000262 * t2
    };
    jd1 + c1 - deltat
}

fn sun_longitude(jdn: f64) -> f64 {
    let t = (jdn - 2451545.0) / 36525.0;
    let t2 = t * t;
    let dr = PI / 180.0;
    let m = 357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
    let l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t2;
    let mut dl = (1.914600 - 0.004817 * t - 0.000014 * t2) * (dr * m).sin();
    dl += (0.019993 - 0.000101 * t) * (dr * 2.0 * m).sin();
    dl += 0.000290 * (dr * 3.0 * m).sin();
    let l = (l0 + dl) * dr;
    l - PI * 2.0 * (l / (PI * 2.0)).floor()
}

fn get_sun_longitude(day_number: i64) -> i64 {
    (sun_longitude(day_number as f64 - 0.5 - TZ / 24.0) / PI * 6.0).floor() as i64
}

fn get_new_moon_day(k: i64) -> i64 {
    (new_moon(k as f64) + 0.5 + TZ / 24.0).floor() as i64
}

fn get_lunar_month_11(yy: i64) -> i64 {
    let off = jd_from_date(31, 12, yy) - 2415021;
    let k = (off as f64 / 29.530588853).floor() as i64;
    let nm = get_new_moon_day(k);
    if get_sun_longitude(nm) >= 9 {
        get_new_moon_day(k - 1)
    } else {
        nm
    }
}

fn get_leap_month_offset(a11: i64) -> i64 {
    let k = ((a11 as f64 - 2415021.076998695) / 29.530588853 + 0.5).floor() as i64;
    let mut i = 1;
    let mut arc = get_sun_longitude(get_new_moon_day(k + i));
    loop {
        let last = arc;
        i += 1;
        arc = get_sun_longitude(get_new_moon_day(k + i));
        if arc == last || i >= 14 {
            break;
        }
    }
    i - 1
}

pub struct Lunar {
    pub day: i64,
    pub month: i64,
    pub year: i64,
    pub leap: bool,
}

pub fn solar_to_lunar(jd: i64) -> Lunar {
    let (_, _, yy) = jd_to_date(jd);
    let k = ((jd as f64 - 2415021.076998695) / 29.530588853).floor() as i64;
    let mut month_start = get_new_moon_day(k + 1);
    if month_start > jd {
        month_start = get_new_moon_day(k);
    }
    let mut a11 = get_lunar_month_11(yy);
    let mut b11 = a11;
    let mut year = if a11 >= month_start {
        a11 = get_lunar_month_11(yy - 1);
        yy
    } else {
        b11 = get_lunar_month_11(yy + 1);
        yy + 1
    };
    let day = jd - month_start + 1;
    let diff = (month_start - a11) / 29;
    let mut leap = false;
    let mut month = diff + 11;
    if b11 - a11 > 365 {
        let leap_off = get_leap_month_offset(a11);
        if diff >= leap_off {
            month = diff + 10;
            leap = diff == leap_off;
        }
    }
    if month > 12 {
        month -= 12;
    }
    if month >= 11 && diff < 4 {
        year -= 1;
    }
    Lunar { day, month, year, leap }
}

pub const CAN: [&str; 10] = ["Giáp", "Ất", "Bính", "Đinh", "Mậu", "Kỷ", "Canh", "Tân", "Nhâm", "Quý"];
pub const CHI: [&str; 12] = ["Tý", "Sửu", "Dần", "Mão", "Thìn", "Tỵ", "Ngọ", "Mùi", "Thân", "Dậu", "Tuất", "Hợi"];

pub fn can_chi_year(y: i64) -> String {
    format!("{} {}", CAN[((y + 6) % 10) as usize], CHI[((y + 8) % 12) as usize])
}

pub fn can_chi_month(month: i64, year: i64) -> String {
    format!("{} {}", CAN[((year * 12 + month + 3) % 10) as usize], CHI[((month + 1) % 12) as usize])
}

pub fn can_chi_day(jd: i64) -> String {
    format!("{} {}", CAN[((jd + 9) % 10) as usize], CHI[((jd + 1) % 12) as usize])
}

#[cfg(test)]
mod tests {
    use super::*;

    fn lunar(dd: i64, mm: i64, yy: i64) -> (i64, i64, i64) {
        let l = solar_to_lunar(jd_from_date(dd, mm, yy));
        (l.day, l.month, l.year)
    }

    #[test]
    fn tet_dates() {
        assert_eq!(lunar(22, 1, 2023), (1, 1, 2023));
        assert_eq!(lunar(10, 2, 2024), (1, 1, 2024));
        assert_eq!(lunar(29, 1, 2025), (1, 1, 2025));
        assert_eq!(lunar(17, 2, 2026), (1, 1, 2026));
    }

    #[test]
    fn matches_python_version() {
        assert_eq!(lunar(7, 11, 2026), (29, 9, 2026));
        assert_eq!(lunar(1, 1, 2026), (13, 11, 2025));
    }

    #[test]
    fn leap_month() {
        // 2025 has a leap 6th month starting 25/07/2025
        let l = solar_to_lunar(jd_from_date(25, 7, 2025));
        assert_eq!((l.day, l.month, l.leap), (1, 6, true));
    }

    #[test]
    fn can_chi() {
        assert_eq!(can_chi_year(2024), "Giáp Thìn");
        assert_eq!(can_chi_year(2026), "Bính Ngọ");
    }

    #[test]
    fn jd_roundtrip() {
        for jd in 2451545..2451545 + 2000 {
            let (d, m, y) = jd_to_date(jd);
            assert_eq!(jd_from_date(d, m, y), jd);
        }
    }
}
