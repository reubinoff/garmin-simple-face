import Toybox.Graphics;
import Toybox.Lang;

//! Pure layout / formatting / always-on helpers. No Dc and no system calls, so every function here is
//! covered by the Run No Evil unit tests (source/tests/NoirTests.mc) and mirrored by the host-side
//! Python model (tests/host/face_model.py). DECISIONS.md D-17, D-19, D-20.
module NoirLayout {

    // Neutral grey of date / steps (and of the colon when hour and minute colours differ).
    const COLOR_TEXT = 0xB0B0B0;
    // Date / steps in always-on mode: same font, dimmer grey.
    const COLOR_TEXT_AOD = 0x6E6E6E;
    // Vertical gap between the rows, percent of the screen height.
    const ROW_SPACING_PERCENT = 3;
    // Always-on burn-in shift (pixels, each axis) - see aodShift().
    const AOD_SHIFT_PIXELS = 8;
    // Outline stroke for the always-on digits (pixels), see outlineWidth().
    const OUTLINE_MIN = 2;
    const OUTLINE_MAX = 3;
    // Always-on row mask: every AOD_MASK_PERIOD-th screen row is blacked out, a different row set each minute,
    // so no pixel can stay on for AOD_MASK_PERIOD consecutive minutes whatever is drawn (D-19).
    const AOD_MASK_PERIOD = 3;
    // Room kept free at the round edge; must cover AOD_SHIFT_PIXELS + OUTLINE_MAX (unit-tested).
    const EDGE_MARGIN = 12;
    // Representative widest texts used for the fit check.
    const SAMPLE_DATE = "Wed 30 Sep";
    const SAMPLE_STEPS = "100,000";
    // The 8 neighbour directions used to draw an outline (dilation) of a text.
    const OUTLINE_DX = [-1, 0, 1, -1, 1, -1, 0, 1] as Array<Number>;
    const OUTLINE_DY = [-1, -1, -1, 0, 0, 1, 1, 1] as Array<Number>;

    //! Time font candidates per size, largest first; the first one that fits is used in BOTH power modes,
    //! so the layout never changes between active and always-on mode.
    function fontCandidates(size as Number) as Array<Graphics.FontType> {
        if (size == NoirSettings.SIZE_SMALL) {
            return [Graphics.FONT_NUMBER_MILD, Graphics.FONT_LARGE] as Array<Graphics.FontType>;
        }
        if (size == NoirSettings.SIZE_LARGE) {
            return [Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM,
                    Graphics.FONT_NUMBER_MILD] as Array<Graphics.FontType>;
        }
        return [Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD] as Array<Graphics.FontType>;
    }

    function rowSpacing(screenHeight as Number) as Number {
        return screenHeight * ROW_SPACING_PERCENT / 100;
    }

    function colonRadius(fontHeight as Number) as Number {
        var radius = fontHeight / 26;
        return radius < 3 ? 3 : radius;
    }

    function colonGap(fontHeight as Number) as Number {
        return colonRadius(fontHeight) * 6;
    }

    function colonDotOffset(fontHeight as Number) as Number {
        return fontHeight * 14 / 100;
    }

    //! Outline stroke width for a time font: fontHeight / 64, clamped to OUTLINE_MIN..OUTLINE_MAX.
    function outlineWidth(fontHeight as Number) as Number {
        var width = fontHeight / 64;
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

    //! Whole block (date / time / steps) fit check for a round screen of width screenSize.
    //! digitsWidth = width of "00" in the time font; pad = extra pixels around the time (outline stroke).
    //! Rows are stacked with spacing, so they cannot overlap; the outer corners of each row must stay inside
    //! the circle of radius screenSize/2 - EDGE_MARGIN.
    function blockFits(screenSize as Number, timeHeight as Number, digitsWidth as Number, smallHeight as Number,
            dateWidth as Number, stepsWidth as Number, pad as Number) as Boolean {
        var radius = screenSize / 2 - EDGE_MARGIN;
        var spacing = rowSpacing(screenSize);
        var timeHalfWidth = (digitsWidth * 2 + colonGap(timeHeight)) / 2 + pad;
        var timeHalfHeight = timeHeight / 2 + pad;
        var rowOuterEdge = timeHeight / 2 + spacing + smallHeight;
        return insideCircle(radius, timeHalfWidth, timeHalfHeight)
            && insideCircle(radius, dateWidth / 2, rowOuterEdge)
            && insideCircle(radius, stepsWidth / 2, rowOuterEdge);
    }

    //! Always-on shift for a given minute: a 4-step square cycle (-,-) (+,-) (+,+) (-,+) times AOD_SHIFT_PIXELS.
    //! Consecutive minutes are 2 * AOD_SHIFT_PIXELS apart on one axis.
    function aodShift(minute as Number) as Array<Number> {
        var phase = minute % 4;
        var dx = (phase == 0 || phase == 3) ? -AOD_SHIFT_PIXELS : AOD_SHIFT_PIXELS;
        var dy = (phase < 2) ? -AOD_SHIFT_PIXELS : AOD_SHIFT_PIXELS;
        return [dx, dy];
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

    //! Steps with a thousands separator; "--" when the device reports none (null).
    function formatSteps(steps as Number or Null) as String {
        if (steps == null) {
            return "--";
        }
        var digits = steps.toString();
        var length = digits.length();
        var result = "";
        for (var i = 0; i < length; i++) {
            if (i > 0 && (length - i) % 3 == 0) {
                result += ",";
            }
            result += (digits.substring(i, i + 1) as String);
        }
        return result;
    }
}
