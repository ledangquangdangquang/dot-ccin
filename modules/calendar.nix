{pkgs, ...}: let
  # Vietnamese lunar date conversion. Ho Ngoc Duc's algorithm (public domain),
  # astronomical new-moon/sun-longitude math accurate for centuries around
  # today. timeZone=7 (Vietnam). ponytail: no external lunar-calendar
  # dependency needed, pure stdlib math.
  lunarDate = pkgs.writers.writePython3Bin "lunar-date" {} ''
    import datetime
    import math
    import sys

    TZ = 7.0


    def jd_from_date(dd, mm, yy):
        a = (14 - mm) // 12
        y = yy + 4800 - a
        m = mm + 12 * a - 3
        jd = (
            dd + (153 * m + 2) // 5 + 365 * y
            + y // 4 - y // 100 + y // 400 - 32045
        )
        if jd < 2299161:
            jd = dd + (153 * m + 2) // 5 + 365 * y + y // 4 - 32083
        return jd


    def new_moon(k):
        T = k / 1236.85
        T2 = T * T
        T3 = T2 * T
        dr = math.pi / 180
        Jd1 = (
            2415020.75933 + 29.53058868 * k
            + 0.0001178 * T2 - 0.000000155 * T3
        )
        Jd1 += 0.00033 * math.sin((166.56 + 132.87 * T - 0.009173 * T2) * dr)
        M = 359.2242 + 29.10535608 * k - 0.0000333 * T2 - 0.00000347 * T3
        Mpr = 306.0253 + 385.81691806 * k + 0.0107306 * T2 + 0.00001236 * T3
        F = 21.2964 + 390.67050646 * k - 0.0016528 * T2 - 0.00000239 * T3
        C1 = (
            (0.1734 - 0.000393 * T) * math.sin(M * dr)
            + 0.0021 * math.sin(2 * dr * M)
        )
        C1 += -0.4068 * math.sin(Mpr * dr) + 0.0161 * math.sin(dr * 2 * Mpr)
        C1 += -0.0004 * math.sin(dr * 3 * Mpr)
        C1 += 0.0104 * math.sin(dr * 2 * F) - 0.0051 * math.sin(dr * (M + Mpr))
        C1 += -0.0074 * math.sin(dr * (M - Mpr))
        C1 += 0.0004 * math.sin(dr * (2 * F + M))
        C1 += -0.0004 * math.sin(dr * (2 * F - M))
        C1 += -0.0006 * math.sin(dr * (2 * F + Mpr))
        C1 += 0.0010 * math.sin(dr * (2 * F - Mpr))
        C1 += 0.0005 * math.sin(dr * (2 * Mpr + M))
        if T < -11:
            deltat = (
                0.001 + 0.000839 * T + 0.0002261 * T2
                - 0.00000845 * T3 - 0.000000081 * T * T3
            )
        else:
            deltat = -0.000278 + 0.000265 * T + 0.000262 * T2
        return Jd1 + C1 - deltat


    def sun_longitude(jdn):
        T = (jdn - 2451545.0) / 36525
        T2 = T * T
        dr = math.pi / 180
        M = 357.52910 + 35999.05030 * T - 0.0001559 * T2 - 0.00000048 * T * T2
        L0 = 280.46645 + 36000.76983 * T + 0.0003032 * T2
        DL = (1.914600 - 0.004817 * T - 0.000014 * T2) * math.sin(dr * M)
        DL += (0.019993 - 0.000101 * T) * math.sin(dr * 2 * M)
        DL += 0.000290 * math.sin(dr * 3 * M)
        L = (L0 + DL) * dr
        return L - math.pi * 2 * math.floor(L / (math.pi * 2))


    def get_sun_longitude(day_number, tz):
        lon = sun_longitude(day_number - 0.5 - tz / 24)
        return math.floor(lon / math.pi * 6)


    def get_new_moon_day(k, tz):
        return math.floor(new_moon(k) + 0.5 + tz / 24)


    def get_lunar_month_11(yy, tz):
        off = jd_from_date(31, 12, yy) - 2415021
        k = math.floor(off / 29.530588853)
        nm = get_new_moon_day(k, tz)
        if get_sun_longitude(nm, tz) >= 9:
            nm = get_new_moon_day(k - 1, tz)
        return nm


    def get_leap_month_offset(a11, tz):
        k = math.floor((a11 - 2415021.076998695) / 29.530588853 + 0.5)
        i = 1
        arc = get_sun_longitude(get_new_moon_day(k + i, tz), tz)
        while True:
            last = arc
            i += 1
            arc = get_sun_longitude(get_new_moon_day(k + i, tz), tz)
            if arc == last or i >= 14:
                break
        return i - 1


    def solar_to_lunar(dd, mm, yy, tz=TZ):
        day_number = jd_from_date(dd, mm, yy)
        k = math.floor((day_number - 2415021.076998695) / 29.530588853)
        month_start = get_new_moon_day(k + 1, tz)
        if month_start > day_number:
            month_start = get_new_moon_day(k, tz)
        a11 = get_lunar_month_11(yy, tz)
        b11 = a11
        if a11 >= month_start:
            lunar_year = yy
            a11 = get_lunar_month_11(yy - 1, tz)
        else:
            lunar_year = yy + 1
            b11 = get_lunar_month_11(yy + 1, tz)
        lunar_day = day_number - month_start + 1
        diff = math.floor((month_start - a11) / 29)
        lunar_leap = 0
        lunar_month = diff + 11
        if b11 - a11 > 365:
            leap_month_off = get_leap_month_offset(a11, tz)
            if diff >= leap_month_off:
                lunar_month = diff + 10
                if diff == leap_month_off:
                    lunar_leap = 1
        if lunar_month > 12:
            lunar_month -= 12
        if lunar_month >= 11 and diff < 4:
            lunar_year -= 1
        return int(lunar_day), int(lunar_month), int(lunar_year), lunar_leap


    CAN = [
        "Giáp", "Ất", "Bính", "Đinh", "Mậu",
        "Kỷ", "Canh", "Tân", "Nhâm", "Quý",
    ]
    CHI = [
        "Tý", "Sửu", "Dần", "Mão", "Thìn", "Tỵ",
        "Ngọ", "Mùi", "Thân", "Dậu", "Tuất", "Hợi",
    ]


    def can_chi_year(y):
        return f"{CAN[(y + 6) % 10]} {CHI[(y + 8) % 12]}"


    def format_lunar(dd, mm, yy):
        d, m, y, leap = solar_to_lunar(dd, mm, yy)
        nhuan = " (nhuận)" if leap else ""
        return (
            f"Dương lịch: {dd:02d}/{mm:02d}/{yy % 100:02d}\n"
            f"Âm lịch: {d:02d}/{m:02d}{nhuan}\n"
            f"Năm: {can_chi_year(y)}"
        )


    def demo():
        # Known Tết (lunar 1/1) reference dates.
        assert solar_to_lunar(22, 1, 2023)[:3] == (1, 1, 2023)  # Quý Mão
        assert solar_to_lunar(10, 2, 2024)[:3] == (1, 1, 2024)  # Giáp Thìn
        assert solar_to_lunar(29, 1, 2025)[:3] == (1, 1, 2025)  # Ất Tỵ
        assert can_chi_year(2024) == "Giáp Thìn"


    if __name__ == "__main__":
        if len(sys.argv) > 1 and sys.argv[1] == "--test":
            demo()
            print("ok")
            sys.exit(0)
        if len(sys.argv) == 4:
            dd, mm, yy = (int(x) for x in sys.argv[1:4])
        else:
            today = datetime.date.today()
            dd, mm, yy = today.day, today.month, today.year
        print(format_lunar(dd, mm, yy))
  '';

  calendarPopup = pkgs.writeShellApplication {
    name = "calendar-popup";
    runtimeInputs = [pkgs.rofi pkgs.python3 lunarDate];
    text = ''
      month_grid="$(python3 -c 'import calendar, datetime; t = datetime.date.today(); print(calendar.TextCalendar().formatmonth(t.year, t.month), end="")')"
      msg="$month_grid
      ────────────────────
      $(lunar-date)
      "
      # Override the shared theme's 800px width and 3-child mainbox (sized
      # for the drun/menu list): -e mode only renders "message", so without
      # this the wide window leaves blank space on the right and clips text
      # at the bottom (mainbox still reserved room for listview).
      rofi -theme-str 'window {width: 240px;} mainbox {children: ["message"];}' -e "$msg"
    '';
  };
in {
  home.packages = [lunarDate calendarPopup];
}
