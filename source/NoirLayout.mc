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
    const SAMPLE_BODY_BATTERY = "100";
    // Stats row icons (DECISIONS.md D-28): icon height = ICON_HEIGHT_PERCENT of the row font height; widths are
    // percent of the icon height; gaps are percent of the row font height.
    const ICON_HEIGHT_PERCENT = 60;
    const STEPS_ICON_WIDTH_PERCENT = 84;
    const BODY_BATTERY_ICON_WIDTH_PERCENT = 100;
    const ICON_GAP_PERCENT = 12;
    const GROUP_GAP_PERCENT = 40;
    // The 8 neighbour directions used to draw an outline (dilation) of a text.
    const OUTLINE_DX = [-1, 0, 1, -1, 1, -1, 0, 1] as Array<Number>;
    const OUTLINE_DY = [-1, -1, -1, 0, 0, 1, 1, 1] as Array<Number>;

    //! Vertical half extent of the digits around the TEXT_JUSTIFY_VCENTER line, percent of Dc.getFontHeight().
    //! Measured from the device font files (simulator.json: number fonts = Bionic_Medium.ttf; scalable face
    //! RobotoCondensedRegular = RobotoCondensed-Regular.ttf): digit top 27.5 % / 32.3 % above the centre line,
    //! rounded up. Used only by the fit check (DECISIONS.md D-24).
    const DIGIT_HALF_PERCENT_NUMBER = 28;
    const DIGIT_HALF_PERCENT_CONDENSED = 33;
    // XX-Large: scalable (vector) fonts, Graphics.getVectorFont (API 4.2.1; fenix 9 Pro 47mm lists
    // "RobotoCondensedRegular" and "BionicMedium" as Scalable fonts in the device reference). Requested pixel sizes
    // are tried from XXL_SIZE_MAX down in XXL_SIZE_STEP steps; the first that fits is used (D-24).
    const XXL_SIZE_MAX = 240;
    const XXL_SIZE_MIN = 180;
    const XXL_SIZE_STEP = 4;
    // XXL_SIZE_MAX / XXL_SIZE_MIN are for the 454 px reference screen; other screens scale them (D-36).
    const REFERENCE_SCREEN = 454;

    //! Largest / smallest XX-Large pixel size tried on a screen screenWidth px wide (proportional to REFERENCE_SCREEN).
    function xxlSizeMax(screenWidth as Number) as Number {
        return XXL_SIZE_MAX * screenWidth / REFERENCE_SCREEN;
    }

    function xxlSizeMin(screenWidth as Number) as Number {
        return XXL_SIZE_MIN * screenWidth / REFERENCE_SCREEN;
    }

    //! Scalable faces for XX-Large, preferred first (getVectorFont takes an Array of acceptable faces).
    function xxlFaces() as Array<String> {
        return ["RobotoCondensedRegular", "BionicMedium"] as Array<String>;
    }

    //! System (bitmap) time font candidates per size, largest first; the first one that fits is used in BOTH
    //! power modes, so the layout never changes between active and always-on mode. XX-Large uses a scalable
    //! font (NoirTimeView.updateLayout) and falls back to the X-Large list when none fits / none is available.
    function fontCandidates(size as Number) as Array<Graphics.FontType> {
        if (size == NoirSettings.SIZE_SMALL) {
            return [Graphics.FONT_NUMBER_MILD, Graphics.FONT_LARGE] as Array<Graphics.FontType>;
        }
        if (size == NoirSettings.SIZE_LARGE) {
            return [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD] as Array<Graphics.FontType>;
        }
        if (size == NoirSettings.SIZE_XLARGE || size == NoirSettings.SIZE_XXLARGE) {
            return [Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM,
                    Graphics.FONT_NUMBER_MILD] as Array<Graphics.FontType>;
        }
        return [Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD] as Array<Graphics.FontType>;
    }

    //! Stats row (steps / Body Battery) font candidates, largest first: the largest that fits next to the chosen
    //! time font is used (D-28). FONT_SMALL is the font steps always had, so with Body Battery hidden nothing changes.
    function statsFontCandidates() as Array<Graphics.FontType> {
        return [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY] as Array<Graphics.FontType>;
    }

    function iconHeight(fontHeight as Number) as Number {
        return fontHeight * ICON_HEIGHT_PERCENT / 100;
    }

    function stepsIconWidth(fontHeight as Number) as Number {
        return iconHeight(fontHeight) * STEPS_ICON_WIDTH_PERCENT / 100;
    }

    function bodyBatteryIconWidth(fontHeight as Number) as Number {
        return iconHeight(fontHeight) * BODY_BATTERY_ICON_WIDTH_PERCENT / 100;
    }

    function iconGap(fontHeight as Number) as Number {
        return fontHeight * ICON_GAP_PERCENT / 100;
    }

    function groupGap(fontHeight as Number) as Number {
        return fontHeight * GROUP_GAP_PERCENT / 100;
    }

    //! Width of the stats row "[steps icon] steps   [battery icon] value" for the given text widths; hidden groups
    //! take no space. 0 when both are hidden.
    function statsRowWidth(fontHeight as Number, showSteps as Boolean, stepsWidth as Number, showBodyBattery as Boolean,
            bodyBatteryWidth as Number) as Number {
        var width = 0;
        if (showSteps) {
            width += stepsIconWidth(fontHeight) + iconGap(fontHeight) + stepsWidth;
        }
        if (showBodyBattery) {
            if (showSteps) {
                width += groupGap(fontHeight);
            }
            width += bodyBatteryIconWidth(fontHeight) + iconGap(fontHeight) + bodyBatteryWidth;
        }
        return width;
    }

    //! Body Battery sample (SensorSample.data: Number, Float or null, documented range 0..100) -> Number 0..100 or
    //! null when there is no usable value (D-27).
    function parseBodyBattery(value as Number or Float or Null) as Number or Null {
        if (value == null) {
            return null;
        }
        var level = (value instanceof Float) ? (value + 0.5f).toNumber() : value as Number;
        if (level < 0 || level > 100) {
            return null;
        }
        return level;
    }

    function formatBodyBattery(level as Number or Null) as String {
        return level == null ? "--" : level.toString();
    }

    //! Half height of the digit glyphs for a font of the given height (fit check only).
    function digitHalfHeight(fontHeight as Number, percent as Number) as Number {
        return (fontHeight * percent + 99) / 100;
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

    //! Whole block (date / time / stats) fit check for a round screen of width screenSize.
    //! timeHeight = Dc.getFontHeight of the time font (row stacking), digitHalf = half height of the digit glyphs
    //! (digitHalfHeight), digitsWidth = width of "00" in the time font; pad = extra pixels around the time (outline).
    //! dateHeight / dateWidth: the date row above; statsHeight / statsWidth: the steps + Body Battery row below
    //! (statsWidth 0 = row hidden). Rows are stacked with spacing on the full font height, so they cannot overlap;
    //! the outer corners of the digit box and of both rows must stay inside the circle of radius screenSize/2 - EDGE_MARGIN.
    function blockFits(screenSize as Number, timeHeight as Number, digitHalf as Number, digitsWidth as Number,
            dateHeight as Number, dateWidth as Number, statsHeight as Number, statsWidth as Number, pad as Number) as Boolean {
        var radius = screenSize / 2 - EDGE_MARGIN;
        var spacing = rowSpacing(screenSize);
        var timeHalfWidth = (digitsWidth * 2 + colonGap(timeHeight)) / 2 + pad;
        var timeHalfHeight = digitHalf + pad;
        return insideCircle(radius, timeHalfWidth, timeHalfHeight)
            && insideCircle(radius, dateWidth / 2, timeHeight / 2 + spacing + dateHeight)
            && (statsWidth <= 0 || insideCircle(radius, statsWidth / 2, timeHeight / 2 + spacing + statsHeight));
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
