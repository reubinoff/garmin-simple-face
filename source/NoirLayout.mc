import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

//! Pure layout / formatting / always-on helpers. No Dc and no system calls, so every function here is
//! covered by the Run No Evil unit tests (source/tests/NoirTests.mc) and mirrored by the host-side
//! Python model (tests/host/face_model.py). DECISIONS.md D-17, D-19, D-20.
module NoirLayout {

    // Neutral grey of the date / fields (and of the colon when hour and minute colours differ).
    const COLOR_TEXT = 0xB0B0B0;
    // Date / fields in always-on mode: same font, dimmer grey.
    const COLOR_TEXT_AOD = 0x6E6E6E;
    // Vertical gap between the rows, percent of the screen height.
    const ROW_SPACING_PERCENT = 3;
    // Always-on burn-in shift (pixels): the block walks round an 8-step path whose offsets stay within
    // +-AOD_SHIFT_PIXELS on each axis and which moves exactly AOD_SHIFT_PIXELS on one axis per minute - see
    // aodShiftX() / aodShiftY(). Garmin UX guidelines, Watch Faces, Best Practices: "consider moving elements up to
    // four pixels in any direction every minute while in always-on mode" (D-19, D-43).
    const AOD_SHIFT_PIXELS = 4;
    const AOD_PATH_X = [-1, 0, 1, 1, 1, 0, -1, -1] as Array<Number>;
    const AOD_PATH_Y = [-1, -1, -1, 0, 1, 1, 1, 0] as Array<Number>;
    // Always-on digit / colon colour = the user's colour with every channel scaled to this percent (UX guidelines:
    // "Avoid using much white or blue. Consider using light gray instead."; white becomes 0xB2B2B2). D-43.
    const AOD_DIGIT_PERCENT = 70;
    // Display state used by the view (System.getDisplayMode, API 5.0.0, where available: HIGH_POWER / LOW_POWER / OFF).
    const POWER_HIGH = 0;
    const POWER_LOW = 1;
    const POWER_OFF = 2;
    // Outline stroke for the always-on digits (pixels), see outlineWidth().
    const OUTLINE_MIN = 2;
    const OUTLINE_MAX = 3;
    // Always-on row mask: every AOD_MASK_PERIOD-th screen row is blacked out, a different row set each minute,
    // so no pixel can stay on for AOD_MASK_PERIOD consecutive minutes whatever is drawn (D-19).
    const AOD_MASK_PERIOD = 3;
    // Room kept free at the round edge; must cover AOD_SHIFT_PIXELS + OUTLINE_MAX (unit-tested).
    const EDGE_MARGIN = 12;
    // Representative widest date text used for the fit check (field samples: NoirFields.sampleText).
    const SAMPLE_DATE = "WED 30 SEP";
    // Field icons (DECISIONS.md D-28, D-39): icon height = ICON_HEIGHT_PERCENT of the row font height; gaps are
    // percent of the row font height. Icon widths: iconWidthPercent().
    const ICON_HEIGHT_PERCENT = 60;
    const ICON_GAP_PERCENT = 12;
    const GROUP_GAP_PERCENT = 40;
    // The 8 neighbour directions used to draw an outline (dilation) of a text.
    const OUTLINE_DX = [-1, 0, 1, -1, 1, -1, 0, 1] as Array<Number>;
    const OUTLINE_DY = [-1, -1, -1, 0, 0, 1, 1, 1] as Array<Number>;

    // Time digits (D-38): Bebas Neue bitmap fonts Rez.Fonts.TimeFont0..4 (Small..XX-Large), generated per screen
    // resolution by scripts/make_fonts.py. Each font's line height = digit height + TIME_LINE_EXTRA (the digits fill
    // the line, 1 px free above and below). The colon is drawn as two squares (Bebas Neue's own colon sits at x-height):
    // gap between hour and minute = COLON_GAP_PERCENT of the digit height, square side COLON_DOT_PERCENT (about the
    // stroke width), dot centres COLON_OFFSET_PERCENT above / below the centre line. KEEP COLON_GAP_PERCENT,
    // EDGE_MARGIN and OUTLINE_MAX IN SYNC with scripts/make_fonts.py (checked by tests/host/test_resources.py).
    const TIME_LINE_EXTRA = 2;
    const COLON_GAP_PERCENT = 27;
    const COLON_DOT_PERCENT = 15;
    const COLON_OFFSET_PERCENT = 22;

    // Companion text font (D-40): the scalable RobotoCondensedRegular (Graphics.getVectorFont, API 4.2.1) for the date
    // and the fields, sized in percent of the screen width; system fonts where it is missing (API 3.x, Forerunner 255
    // family) and, for the date, in languages whose script it may not cover.
    const DATE_SIZE_PERCENT = 10;
    const ROW_SIZE_PERCENTS = [10, 9, 8, 7] as Array<Number>;

    //! Time font resources, Small..XX-Large.
    function timeFontIds() as Array<ResourceId> {
        return [Rez.Fonts.TimeFont0, Rez.Fonts.TimeFont1, Rez.Fonts.TimeFont2, Rez.Fonts.TimeFont3,
                Rez.Fonts.TimeFont4] as Array<ResourceId>;
    }

    //! Time font indexes to try for a size setting, largest first: the selected size, then every smaller one.
    //! The first that fits is used in BOTH power modes, so the layout never changes between active and always-on.
    function timeFontOrder(size as Number) as Array<Number> {
        var order = [] as Array<Number>;
        for (var i = size; i >= 0; i--) {
            order.add(i);
        }
        return order;
    }

    function digitHeight(lineHeight as Number) as Number {
        return lineHeight - TIME_LINE_EXTRA;
    }

    function colonGap(digitH as Number) as Number {
        return digitH * COLON_GAP_PERCENT / 100;
    }

    function colonDot(digitH as Number) as Number {
        var side = digitH * COLON_DOT_PERCENT / 100;
        return side < 3 ? 3 : side;
    }

    function colonOffset(digitH as Number) as Number {
        return digitH * COLON_OFFSET_PERCENT / 100;
    }

    //! Width of "HH:MM": two digit pairs plus the colon gap.
    function timeWidth(pairWidth as Number, digitH as Number) as Number {
        return pairWidth * 2 + colonGap(digitH);
    }

    //! Scalable faces for the companion font, preferred first (getVectorFont takes an Array of acceptable faces).
    function textFaces() as Array<String> {
        return ["RobotoCondensedRegular"] as Array<String>;
    }

    function dateVectorSize(screenWidth as Number) as Number {
        return screenWidth * DATE_SIZE_PERCENT / 100;
    }

    //! Row font sizes to try, largest first (the largest that fits is used).
    function rowVectorSizes(screenWidth as Number) as Array<Number> {
        var sizes = [] as Array<Number>;
        for (var i = 0; i < ROW_SIZE_PERCENTS.size(); i++) {
            sizes.add(screenWidth * ROW_SIZE_PERCENTS[i] / 100);
        }
        return sizes;
    }

    //! System font fallback for the field rows, largest first.
    function rowSystemFonts() as Array<Graphics.FontType> {
        return [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY] as Array<Graphics.FontType>;
    }

    //! Languages whose day / month names are plain Latin script, which RobotoCondensed certainly covers. Every other
    //! language (Hebrew, Cyrillic, Greek, CJK, Thai, Arabic, Latin with rarer diacritics ...) keeps the system font for
    //! the date, which is made for the watch's languages (D-40). The fields are digits only and always use it.
    function isBasicLatin(language as Number) as Boolean {
        return language == System.LANGUAGE_ENG || language == System.LANGUAGE_DEU || language == System.LANGUAGE_FRE
            || language == System.LANGUAGE_ITA || language == System.LANGUAGE_SPA || language == System.LANGUAGE_POR
            || language == System.LANGUAGE_DUT || language == System.LANGUAGE_DAN || language == System.LANGUAGE_SWE
            || language == System.LANGUAGE_NOB || language == System.LANGUAGE_FIN;
    }

    function iconHeight(fontHeight as Number) as Number {
        return fontHeight * ICON_HEIGHT_PERCENT / 100;
    }

    //! Icon width per field, percent of the icon height.
    function iconWidthPercent(field as Number) as Number {
        if (field == NoirFields.STEPS) {
            return 84;
        }
        if (field == NoirFields.HEART_RATE || field == NoirFields.NOTIFICATIONS || field == NoirFields.STRESS) {
            return 110;
        }
        if (field == NoirFields.BATTERY || field == NoirFields.BATTERY_DAYS) {
            return 150;
        }
        if (field == NoirFields.CALORIES || field == NoirFields.INTENSITY || field == NoirFields.DISTANCE) {
            return 70;
        }
        if (field == NoirFields.TEMPERATURE) {
            return 50;
        }
        return 100;   // Body Battery, floors
    }

    function iconWidth(field as Number, fontHeight as Number) as Number {
        return iconHeight(fontHeight) * iconWidthPercent(field) / 100;
    }

    function iconGap(fontHeight as Number) as Number {
        return fontHeight * ICON_GAP_PERCENT / 100;
    }

    function groupGap(fontHeight as Number) as Number {
        return fontHeight * GROUP_GAP_PERCENT / 100;
    }

    //! Width of one field "[icon] text"; 0 for NONE.
    function fieldWidth(field as Number, fontHeight as Number, textWidth as Number) as Number {
        if (field == NoirFields.NONE) {
            return 0;
        }
        return iconWidth(field, fontHeight) + iconGap(fontHeight) + textWidth;
    }

    //! Width of a row of two fields (either may be 0 = empty): with the group gap between them only when both show.
    function rowWidth(fontHeight as Number, leftWidth as Number, rightWidth as Number) as Number {
        if (leftWidth > 0 && rightWidth > 0) {
            return leftWidth + groupGap(fontHeight) + rightWidth;
        }
        return leftWidth + rightWidth;
    }

    //! Field sample (SensorSample.data: Number, Float or null; Body Battery and stress, documented range 0..100) ->
    //! Number 0..100 or null when there is no usable value (D-27; negative stress = not measurable).
    function parseLevel(value as Number or Float or Null) as Number or Null {
        if (value == null) {
            return null;
        }
        var level = (value instanceof Float) ? (value + 0.5f).toNumber() : value as Number;
        if (level < 0 || level > 100) {
            return null;
        }
        return level;
    }

    function rowSpacing(screenHeight as Number) as Number {
        return screenHeight * ROW_SPACING_PERCENT / 100;
    }

    //! Outline stroke width for a time font: lineHeight / 64, clamped to OUTLINE_MIN..OUTLINE_MAX.
    function outlineWidth(lineHeight as Number) as Number {
        var width = lineHeight / 64;
        if (width < OUTLINE_MIN) {
            return OUTLINE_MIN;
        }
        return width > OUTLINE_MAX ? OUTLINE_MAX : width;
    }

    //! True if the point (halfWidth, dy) relative to the centre is inside the circle of the given radius.
    //! Integer maths (squares), no square root.
    function insideCircle(radius as Number, halfWidth as Number, dy as Number) as Boolean {
        return halfWidth * halfWidth + dy * dy <= radius * radius;
    }

    //! How far the whole block moves up when a second field row is shown, so date / time / rows stay centred.
    function blockShift(secondRow as Boolean, rowHeight as Number, spacing as Number) as Number {
        return secondRow ? (rowHeight + spacing) / 2 : 0;
    }

    //! Whole block fit check for a round screen of width screenSize (D-24, D-39):
    //!            date            dateHeight x dateWidth, `spacing` above the time line
    //!           HH:MM            timeLine high (digits fill it), timeWidth wide, `pad` around it (outline)
    //!       [i] 8,432  [i] 76    row 1: rowHeight x row1Width (0 = no row), `spacing` below the time line
    //!          [i] 62            row 2: rowHeight x row2Width (0 = no row), `spacing` below row 1
    //! The block is moved up by blockShift(). The outer corners of every element must stay inside the circle of radius
    //! screenSize/2 - EDGE_MARGIN. Rows are stacked on full font heights, so nothing can overlap.
    function blockFits(screenSize as Number, timeLine as Number, timeWidth as Number, pad as Number,
            dateHeight as Number, dateWidth as Number, rowHeight as Number, row1Width as Number,
            row2Width as Number) as Boolean {
        var radius = screenSize / 2 - EDGE_MARGIN;
        var spacing = rowSpacing(screenSize);
        var shift = blockShift(row2Width > 0, rowHeight, spacing);
        var half = timeLine / 2;
        var row1Bottom = half + spacing + rowHeight - shift;
        return insideCircle(radius, timeWidth / 2 + pad, half + pad + shift)
            && insideCircle(radius, dateWidth / 2, shift + half + spacing + dateHeight)
            && (row1Width <= 0 || insideCircle(radius, row1Width / 2, row1Bottom))
            && (row2Width <= 0 || insideCircle(radius, row2Width / 2, row1Bottom + spacing + rowHeight));
    }

    //! Always-on shift for a minute of the DAY (hour * 60 + min, 0..1439), x and y separately so nothing is allocated
    //! per frame: an 8-step walk (-,-) (0,-) (+,-) (+,0) (+,+) (0,+) (-,+) (-,0) times AOD_SHIFT_PIXELS. Consecutive
    //! minutes, including 23:59 -> 00:00 (1440 % 8 == 0), are exactly AOD_SHIFT_PIXELS apart on exactly one axis.
    //! Do not pass clock.min: 60 % 8 != 0, so the walk would jump at every full hour.
    function aodShiftX(minuteOfDay as Number) as Number {
        return AOD_PATH_X[minuteOfDay % AOD_PATH_X.size()] * AOD_SHIFT_PIXELS;
    }

    function aodShiftY(minuteOfDay as Number) as Number {
        return AOD_PATH_Y[minuteOfDay % AOD_PATH_Y.size()] * AOD_SHIFT_PIXELS;
    }

    //! Always-on colour: each 0xRRGGBB channel scaled to AOD_DIGIT_PERCENT (rounded down).
    function dimColor(color as Number) as Number {
        var r = ((color >> 16) & 0xFF) * AOD_DIGIT_PERCENT / 100;
        var g = ((color >> 8) & 0xFF) * AOD_DIGIT_PERCENT / 100;
        var b = (color & 0xFF) * AOD_DIGIT_PERCENT / 100;
        return (r << 16) | (g << 8) | b;
    }

    //! First screen row >= top that the always-on mask blacks out in the given minute
    //! (rows with y % AOD_MASK_PERIOD == minute % AOD_MASK_PERIOD). top must be >= 0.
    function maskFirstRow(top as Number, minute as Number) as Number {
        var target = minute % AOD_MASK_PERIOD;
        var row = top;
        while (row % AOD_MASK_PERIOD != target) {
            row += 1;
        }
        return row;
    }

    //! Colon colour: the digit colour when hours and minutes match, otherwise the neutral grey (D-15).
    function colonColor(hourColor as Number, minuteColor as Number) as Number {
        return (hourColor == minuteColor) ? hourColor : COLOR_TEXT;
    }

    //! Hour text: 24 h -> "00".."23", 12 h -> "1".."12".
    function formatHour(hour as Number, is24Hour as Boolean) as String {
        if (is24Hour) {
            return hour.format("%02d");
        }
        var h = hour % 12;
        return (h == 0 ? 12 : h).toString();
    }
}
