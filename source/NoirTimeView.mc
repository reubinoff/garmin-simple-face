import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Black watch face: the date, the time in Bebas Neue and up to three user-selected data fields.
//!
//!            WED 23 OCT           <- date, grey (RobotoCondensed where available)
//!              12:34              <- hours / minutes in two user-selected colours (Bebas Neue bitmap font, D-38)
//!        [feet] 8,432  [bb] 76    <- left / right field slots, grey, small vector icons (D-39)
//!             [heart] 62          <- bottom slot (the block moves up so it stays centred)
//!
//! Active mode: filled digits. Always-on mode on AMOLED (DECISIONS.md D-19, D-36): exactly the same fonts and layout,
//! but the digits and colon are drawn as outlines only, date/fields in a dimmer grey, the block is shifted every
//! minute and a rotating row mask turns every pixel off at least once every 3 minutes.
//! Battery (D-21): settings, fonts, layout and texts are cached; the fields are read once per minute and only while
//! shown; no timers, no partial updates, no background, no sensors switched on. Only the chosen time font is kept
//! loaded. Icons (D-28, D-34, D-39) are Dc primitives, no bitmaps.
class NoirTimeView extends WatchUi.WatchFace {

    private var _inLowPower as Boolean = false;
    // True on AMOLED screens (DeviceSettings.requiresBurnInProtection, API 3.0.12). Only these get the outline /
    // shift / row-mask always-on style; MIP screens keep the normal look in low power (DECISIONS.md D-36).
    private var _burnIn as Boolean = true;

    // Layout cache: recomputed only when the size or a field setting changes (or on a new layout).
    private var _layoutKey as Number = -1;
    private var _timeFont as Graphics.FontType = Graphics.FONT_NUMBER_MEDIUM;
    private var _timeLine as Number = 0;
    private var _dateFont as Graphics.FontType = Graphics.FONT_SMALL;
    private var _dateHeight as Number = 0;
    private var _upperDate as Boolean = false;
    private var _rowFont as Graphics.FontType = Graphics.FONT_SMALL;
    private var _rowHeight as Number = 0;
    private var _spacing as Number = 0;
    private var _shift as Number = 0;
    private var _colonGap as Number = 0;
    private var _colonDot as Number = 0;
    private var _colonOffset as Number = 0;
    private var _outline as Number = 0;
    // Field rows: row 1 = left + right slot (or the bottom slot alone when both are empty), row 2 = bottom slot.
    private var _row1 as Array<Number> = [] as Array<Number>;
    private var _row2 as Array<Number> = [] as Array<Number>;

    // Text caches.
    private var _minuteOfDay as Number = -1;
    private var _dateText as String = "";
    private var _hourText as String = "";
    private var _minuteText as String = "";
    private var _fieldTexts as Array<String or Null> = new Array<String or Null>[NoirFields.COUNT];
    private var _fieldsMinute as Number = -1;

    function initialize() {
        WatchFace.initialize();
        var settings = System.getDeviceSettings();
        if (settings has :requiresBurnInProtection) {
            _burnIn = settings.requiresBurnInProtection;
        }
    }

    function onLayout(dc as Dc) as Void {
        _layoutKey = -1;
    }

    //! Called when the view comes back to the foreground (e.g. after the settings menu): refresh the
    //! settings cache in case they were changed while the face was not visible.
    function onShow() as Void {
        NoirSettings.reload();
        _minuteOfDay = -1;   // also picks up a 12/24 h change made in the system settings
        _fieldsMinute = -1;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        // Unsupported fields come back as NONE (D-39).
        updateLayout(dc, NoirSettings.timeSize(), NoirSettings.field(NoirSettings.KEY_FIELD_LEFT),
            NoirSettings.field(NoirSettings.KEY_FIELD_RIGHT), NoirSettings.field(NoirSettings.KEY_FIELD_BOTTOM));
        var clock = System.getClockTime();
        updateTexts(clock);

        // Burn-in style only where the screen needs it (D-36); on MIP low power looks like active mode.
        var lowPower = _burnIn && isLowPower();
        var hourColor = NoirSettings.hourColor();
        var minuteColor = NoirSettings.minuteColor();
        var colonColor = NoirLayout.colonColor(hourColor, minuteColor);
        var textColor = NoirLayout.COLOR_TEXT;
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2 - _shift;
        if (lowPower) {
            var shift = NoirLayout.aodShift(clock.min);
            centerX += shift[0];
            centerY += shift[1];
            textColor = NoirLayout.COLOR_TEXT_AOD;
        }

        // Time: top-justified on the font line (the digits fill it, D-38); the colon squares sit between.
        var top = centerY - _timeLine / 2;
        var hourX = centerX - _colonGap / 2;
        var minuteX = centerX + _colonGap / 2;
        var dotX = centerX - _colonDot / 2;
        var dotY1 = centerY - _colonOffset - _colonDot / 2;
        var dotY2 = centerY + _colonOffset - _colonDot / 2;
        if (lowPower) {
            drawOutlinedText(dc, hourX, top, _hourText, Graphics.TEXT_JUSTIFY_RIGHT, hourColor);
            drawOutlinedText(dc, minuteX, top, _minuteText, Graphics.TEXT_JUSTIFY_LEFT, minuteColor);
            drawOutlinedSquare(dc, dotX, dotY1, colonColor);
            drawOutlinedSquare(dc, dotX, dotY2, colonColor);
        } else {
            dc.setColor(hourColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(hourX, top, _timeFont, _hourText, Graphics.TEXT_JUSTIFY_RIGHT);
            dc.setColor(minuteColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(minuteX, top, _timeFont, _minuteText, Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(colonColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(dotX, dotY1, _colonDot, _colonDot);
            dc.fillRectangle(dotX, dotY2, _colonDot, _colonDot);
        }

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        var justifyCenter = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.drawText(centerX, top - _spacing - _dateHeight / 2, _dateFont, _dateText, justifyCenter);
        var rowY = top + _timeLine + _spacing + _rowHeight / 2;
        if (_row1.size() > 0) {
            drawRow(dc, centerX, rowY, _row1, textColor);
        }
        if (_row2.size() > 0) {
            drawRow(dc, centerX, rowY + _rowHeight + _spacing, _row2, textColor);
        }

        if (lowPower) {
            drawRowMask(dc, clock.min);
        }
    }

    //! "[icon] text  [icon] text" centred on centerX. Colour is already set (grey / dim grey in always-on).
    private function drawRow(dc as Dc, centerX as Number, y as Number, fields as Array<Number>, color as Number) as Void {
        var h = _rowHeight;
        var widths = new Array<Number>[fields.size()];
        for (var i = 0; i < fields.size(); i++) {
            widths[i] = NoirLayout.fieldWidth(fields[i], h, dc.getTextWidthInPixels(textOf(fields[i]), _rowFont));
        }
        var x = centerX - NoirLayout.rowWidth(h, widths[0], fields.size() > 1 ? widths[1] : 0) / 2;
        var iconH = NoirLayout.iconHeight(h);
        var iconTop = y - iconH / 2;
        var gap = NoirLayout.iconGap(h);
        var justifyLeft = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        for (var i = 0; i < fields.size(); i++) {
            var field = fields[i];
            var w = NoirLayout.iconWidth(field, h);
            drawIcon(dc, field, x, iconTop, w, iconH, color);
            dc.drawText(x + w + gap, y, _rowFont, textOf(field), justifyLeft);
            x += widths[i] + NoirLayout.groupGap(h);
        }
    }

    private function textOf(field as Number) as String {
        var text = _fieldTexts[field];
        return text == null ? NoirFormat.NO_VALUE : text as String;
    }

    //! Icon of a field in the box x, top, w x h, drawn in color with Dc primitives (API 1.0.0 / 1.2.0; D-39).
    private function drawIcon(dc as Dc, field as Number, x as Number, top as Number, w as Number, h as Number,
            color as Number) as Void {
        if (field == NoirFields.STEPS) {
            drawStepsIcon(dc, x, top, w, h);
        } else if (field == NoirFields.BODY_BATTERY) {
            drawBodyBatteryIcon(dc, x, top, w, h);
        } else if (field == NoirFields.HEART_RATE) {
            // Two lobes and a point.
            var r = w * 27 / 100;
            dc.fillCircle(x + r, top + r, r);
            dc.fillCircle(x + w - r, top + r, r);
            dc.fillPolygon([[x + w * 2 / 100, top + r * 13 / 10], [x + w * 98 / 100, top + r * 13 / 10], [x + w / 2, top + h]]);
        } else if (field == NoirFields.BATTERY || field == NoirFields.BATTERY_DAYS) {
            drawBatteryIcon(dc, x, top, w, h, color, field == NoirFields.BATTERY_DAYS);
        } else if (field == NoirFields.CALORIES) {
            // Flame: round base and a tip leaning right.
            var r = w / 2;
            var cy = top + h - r;
            dc.fillCircle(x + r, cy, r);
            dc.fillPolygon([[x, cy], [x + w * 18 / 100, top + h * 42 / 100], [x + w * 48 / 100, top],
                [x + w * 82 / 100, top + h * 30 / 100], [x + w, cy]]);
        } else if (field == NoirFields.FLOORS) {
            // Three steps up to the right.
            dc.fillPolygon([[x, top + h], [x, top + h * 2 / 3], [x + w / 3, top + h * 2 / 3], [x + w / 3, top + h / 3],
                [x + w * 2 / 3, top + h / 3], [x + w * 2 / 3, top], [x + w, top], [x + w, top + h]]);
        } else if (field == NoirFields.INTENSITY) {
            // Lightning bolt.
            dc.fillPolygon([[x + w * 62 / 100, top], [x, top + h * 58 / 100], [x + w * 44 / 100, top + h * 58 / 100],
                [x + w * 34 / 100, top + h], [x + w, top + h * 40 / 100], [x + w * 56 / 100, top + h * 40 / 100]]);
        } else if (field == NoirFields.NOTIFICATIONS) {
            // Speech bubble.
            var bubble = h * 76 / 100;
            dc.fillRoundedRectangle(x, top, w, bubble, h / 5);
            dc.fillPolygon([[x + w * 18 / 100, top + bubble - 1], [x + w * 18 / 100, top + h], [x + w * 48 / 100, top + bubble - 1]]);
        } else if (field == NoirFields.STRESS) {
            // Zig-zag line.
            var pen = h / 7 < 2 ? 2 : h / 7;
            var m = pen / 2;
            dc.setPenWidth(pen);
            var xs = [x + m, x + w * 22 / 100, x + w * 44 / 100, x + w * 64 / 100, x + w * 82 / 100, x + w - m];
            var ys = [top + h / 2, top + m, top + h - m, top + h * 20 / 100, top + h * 75 / 100, top + h / 2];
            for (var i = 0; i < 5; i++) {
                dc.drawLine(xs[i], ys[i], xs[i + 1], ys[i + 1]);
            }
        } else if (field == NoirFields.TEMPERATURE) {
            // Thermometer: stem and bulb.
            var r = w / 2;
            dc.fillRoundedRectangle(x + w / 4, top, w - (w / 4) * 2, h - r, w / 4);
            dc.fillCircle(x + r, top + h - r, r);
        } else if (field == NoirFields.DISTANCE) {
            // Map pin with a hole.
            var r = w / 2;
            dc.fillCircle(x + r, top + r, r);
            dc.fillPolygon([[x + w * 4 / 100, top + r * 13 / 10], [x + w * 96 / 100, top + r * 13 / 10], [x + r, top + h]]);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + r, top + r, r * 2 / 5);
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        }
    }

    //! Horizontal battery: outline body and terminal; battery % gets a level bar, battery days a clock-like tick.
    private function drawBatteryIcon(dc as Dc, x as Number, top as Number, w as Number, h as Number, color as Number,
            days as Boolean) as Void {
        var bh = h * 72 / 100;
        var y0 = top + (h - bh) / 2;
        var bw = w * 88 / 100;
        var pen = bh / 7 < 2 ? 2 : bh / 7;
        dc.fillRectangle(x, y0, bw, bh);
        dc.fillRectangle(x + bw, y0 + bh / 4, w - bw, bh - (bh / 4) * 2);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + pen, y0 + pen, bw - 2 * pen, bh - 2 * pen);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var inset = pen * 2;
        if (days) {
            // Three cells: a "remaining time" gauge rather than a percentage bar.
            var cell = (bw - 2 * inset - 2 * pen) / 3;
            for (var i = 0; i < 3; i++) {
                dc.fillRectangle(x + inset + i * (cell + pen), y0 + inset, cell, bh - 2 * inset);
            }
        } else {
            dc.fillRectangle(x + inset, y0 + inset, (bw - 2 * inset) * 65 / 100, bh - 2 * inset);
        }
    }

    //! Steps icon in the style of Garmin's own: two shoe prints, the left one higher. Each print is a forefoot
    //! ellipse and a smaller heel ellipse (Dc.fillEllipse, API 1.0.0). Box: x, top, w x h.
    private function drawStepsIcon(dc as Dc, x as Number, top as Number, w as Number, h as Number) as Void {
        var print = h * 84 / 100;
        var foreRx = w * 22 / 100;
        var heelRx = w * 17 / 100;
        var foreRy = print * 31 / 100;
        var heelRy = print * 20 / 100;
        for (var i = 0; i < 2; i++) {
            var cx = x + (i == 0 ? w * 24 / 100 : w * 76 / 100);
            var py = top + (i == 0 ? 0 : h - print);
            dc.fillEllipse(cx, py + foreRy, foreRx, foreRy);
            dc.fillEllipse(cx, py + print - heelRy, heelRx, heelRy);
        }
    }

    //! Body Battery icon in Garmin's Body Battery visual language (DECISIONS.md D-34): a person with both arms
    //! raised inside an energy-gauge ring that is open at the bottom, where the figure stands. It is deliberately
    //! NOT a device-battery shape. Drawn from primitives (own geometry, not a copy of Garmin's bitmap):
    //! Dc.drawArc (API 1.2.0) with Dc.setPenWidth, Dc.fillCircle and Dc.fillPolygon (API 1.0.0). Box: x, top, w x h.
    private function drawBodyBatteryIcon(dc as Dc, x as Number, top as Number, w as Number, h as Number) as Void {
        var s = w < h ? w : h;
        var left = x + (w - s) / 2;
        var y0 = top + (h - s) / 2;
        var pen = s / 10 < 2 ? 2 : s / 10;
        var cx = left + s / 2;
        var cy = y0 + s / 2;
        dc.setPenWidth(pen);
        // Gauge ring: 300 degrees counter-clockwise from 300 to 240, i.e. a 60 degree gap around 6 o'clock.
        dc.drawArc(cx, cy, s / 2 - (pen + 1) / 2, Graphics.ARC_COUNTER_CLOCKWISE, 300, 240);
        var headR = s * 11 / 100 < 1 ? 1 : s * 11 / 100;
        dc.fillCircle(cx, y0 + s * 30 / 100, headR);
        // Body with raised arms ("Y"): hands up and out, torso down through the ring's gap.
        dc.fillPolygon([
            [left + s * 20 / 100, y0 + s * 36 / 100],
            [left + s * 29 / 100, y0 + s * 29 / 100],
            [left + s * 42 / 100, y0 + s * 47 / 100],
            [left + s * 58 / 100, y0 + s * 47 / 100],
            [left + s * 71 / 100, y0 + s * 29 / 100],
            [left + s * 80 / 100, y0 + s * 36 / 100],
            [left + s * 61 / 100, y0 + s * 58 / 100],
            [left + s * 61 / 100, y0 + s * 96 / 100],
            [left + s * 39 / 100, y0 + s * 96 / 100],
            [left + s * 39 / 100, y0 + s * 58 / 100]
        ]);
    }

    //! Burn-in row mask (D-19): blacks out every AOD_MASK_PERIOD-th row of the whole screen, a different set
    //! each minute, with 1 px high Dc.fillRectangle calls (API 1.0.0). The whole screen is masked so the
    //! guarantee does not depend on where the fonts really put their glyphs. Anti-aliasing (documented for
    //! primitives) is switched off first so the rows are exact.
    private function drawRowMask(dc as Dc, minute as Number) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(false);
        }
        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        for (var row = NoirLayout.maskFirstRow(0, minute); row < height; row += NoirLayout.AOD_MASK_PERIOD) {
            dc.fillRectangle(0, row, width, 1);
        }
    }

    //! Outline-only text (D-19): the text is drawn in colour at 8 neighbour offsets of _outline pixels
    //! (a dilation), then once in black at the real position, which leaves a ring _outline pixels wide.
    //! Uses only Dc.setColor / Dc.drawText (API 1.0.0) with a transparent text background.
    private function drawOutlinedText(dc as Dc, x as Number, y as Number, text as String,
            justification as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 8; i++) {
            dc.drawText(x + NoirLayout.OUTLINE_DX[i] * _outline, y + NoirLayout.OUTLINE_DY[i] * _outline,
                _timeFont, text, justification);
        }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, _timeFont, text, justification);
    }

    //! Outline-only colon square: the same dilation as the digits (square grown by _outline, then the square itself
    //! in black).
    private function drawOutlinedSquare(dc as Dc, x as Number, y as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - _outline, y - _outline, _colonDot + 2 * _outline, _colonDot + 2 * _outline);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, _colonDot, _colonDot);
    }

    //! Picks the time font for the size setting (the selected Bebas Neue size or the largest smaller one that fits,
    //! outline included), then the largest field-row font that fits next to it, and caches all derived metrics.
    //! Same result in active and always-on mode. Runs only when the size or a field setting changes; only the chosen
    //! time font stays loaded (the others are released as soon as they have been measured).
    private function updateLayout(dc as Dc, size as Number, left as Number, right as Number, bottom as Number) as Void {
        var key = ((size * NoirFields.COUNT + left) * NoirFields.COUNT + right) * NoirFields.COUNT + bottom;
        if (key == _layoutKey) {
            return;
        }
        _layoutKey = key;
        _fieldsMinute = -1;
        if (left == NoirFields.NONE && right == NoirFields.NONE) {
            _row1 = bottom == NoirFields.NONE ? [] as Array<Number> : [bottom];
            _row2 = [] as Array<Number>;
        } else {
            _row1 = left == NoirFields.NONE ? [right] : (right == NoirFields.NONE ? [left] : [left, right]);
            _row2 = bottom == NoirFields.NONE ? [] as Array<Number> : [bottom];
        }
        var width = dc.getWidth();
        _spacing = NoirLayout.rowSpacing(dc.getHeight());
        chooseDateFont(width);
        _dateHeight = dc.getFontHeight(_dateFont);
        var dateWidth = dc.getTextWidthInPixels(NoirLayout.SAMPLE_DATE, _dateFont);

        // Row font candidates, largest first. The time font is chosen against the smallest one, so picking a field
        // never shrinks the time; then the largest row font that fits next to that time font is used.
        var rowFonts = rowFontCandidates(width);
        var smallest = rowFonts[rowFonts.size() - 1];
        var ids = NoirLayout.timeFontIds();
        var order = NoirLayout.timeFontOrder(size);
        for (var i = 0; i < order.size(); i++) {
            _timeFont = WatchUi.loadResource(ids[order[i]]) as Graphics.FontType;
            if (fits(dc, dateWidth, smallest)) {
                break;
            }
        }
        _rowFont = smallest;
        for (var i = 0; i < rowFonts.size() - 1; i++) {
            if (fits(dc, dateWidth, rowFonts[i])) {
                _rowFont = rowFonts[i];
                break;
            }
        }
        _rowHeight = dc.getFontHeight(_rowFont);
        _timeLine = dc.getFontHeight(_timeFont);
        var digitH = NoirLayout.digitHeight(_timeLine);
        _colonGap = NoirLayout.colonGap(digitH);
        _colonDot = NoirLayout.colonDot(digitH);
        _colonOffset = NoirLayout.colonOffset(digitH);
        _outline = NoirLayout.outlineWidth(_timeLine);
        _shift = NoirLayout.blockShift(_row2.size() > 0, _rowHeight, _spacing);
    }

    //! Date font (D-40): RobotoCondensed in upper case for Latin-script languages where the device has it, else the
    //! system FONT_SMALL with the system's own day / month names as they are.
    (:ciq4)
    private function chooseDateFont(screenWidth as Number) as Void {
        _dateFont = Graphics.FONT_SMALL;
        _upperDate = false;
        if ((Graphics has :getVectorFont) && NoirLayout.isBasicLatin(System.getDeviceSettings().systemLanguage)) {
            var font = Graphics.getVectorFont({ :face => NoirLayout.textFaces(), :size => NoirLayout.dateVectorSize(screenWidth) });
            if (font != null) {
                _dateFont = font;
                _upperDate = true;
            }
        }
    }

    //! Field row fonts: RobotoCondensed in the sizes of NoirLayout.rowVectorSizes, else the system fonts.
    (:ciq4)
    private function rowFontCandidates(screenWidth as Number) as Array<Graphics.FontType> {
        if (Graphics has :getVectorFont) {
            var sizes = NoirLayout.rowVectorSizes(screenWidth);
            var fonts = [] as Array<Graphics.FontType>;
            for (var i = 0; i < sizes.size(); i++) {
                var font = Graphics.getVectorFont({ :face => NoirLayout.textFaces(), :size => sizes[i] });
                if (font == null) {
                    break;
                }
                fonts.add(font);
            }
            if (fonts.size() > 0) {
                return fonts;
            }
        }
        return NoirLayout.rowSystemFonts();
    }

    //! Devices below API 4.2.1 (D-36): Graphics.getVectorFont is unknown to the compiler there; system fonts.
    (:ciq3)
    private function chooseDateFont(screenWidth as Number) as Void {
        _dateFont = Graphics.FONT_SMALL;
        _upperDate = false;
    }

    (:ciq3)
    private function rowFontCandidates(screenWidth as Number) as Array<Graphics.FontType> {
        return NoirLayout.rowSystemFonts();
    }

    //! Fit check of the current _timeFont with the widest sample texts of the shown fields in rowFont.
    private function fits(dc as Dc, dateWidth as Number, rowFont as Graphics.FontType) as Boolean {
        var line = dc.getFontHeight(_timeFont);
        var rowHeight = dc.getFontHeight(rowFont);
        return NoirLayout.blockFits(dc.getWidth(), line,
            NoirLayout.timeWidth(dc.getTextWidthInPixels("00", _timeFont), NoirLayout.digitHeight(line)),
            NoirLayout.outlineWidth(line), _dateHeight, dateWidth, rowHeight,
            sampleRowWidth(dc, _row1, rowFont, rowHeight), sampleRowWidth(dc, _row2, rowFont, rowHeight));
    }

    private function sampleRowWidth(dc as Dc, fields as Array<Number>, font as Graphics.FontType, height as Number) as Number {
        var widths = [0, 0];
        for (var i = 0; i < fields.size(); i++) {
            widths[i] = NoirLayout.fieldWidth(fields[i], height,
                dc.getTextWidthInPixels(NoirFields.sampleText(fields[i]), font));
        }
        return NoirLayout.rowWidth(height, widths[0], widths[1]);
    }

    //! Date, hour and minute texts: rebuilt once per minute. Shown fields: read once per minute (and after a settings
    //! or layout change); fields that are not shown are not read at all.
    private function updateTexts(clock as System.ClockTime) as Void {
        var minuteOfDay = clock.hour * 60 + clock.min;
        if (minuteOfDay != _minuteOfDay) {
            _minuteOfDay = minuteOfDay;
            var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
            _dateText = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.day, info.month]);
            if (_upperDate) {
                _dateText = _dateText.toUpper();
            }
            _hourText = NoirLayout.formatHour(clock.hour, System.getDeviceSettings().is24Hour);
            _minuteText = clock.min.format("%02d");
        }
        if (_fieldsMinute != minuteOfDay) {
            _fieldsMinute = minuteOfDay;
            readFields(_row1);
            readFields(_row2);
        }
    }

    private function readFields(fields as Array<Number>) as Void {
        for (var i = 0; i < fields.size(); i++) {
            _fieldTexts[fields[i]] = NoirFields.text(fields[i]);
        }
    }

    function onEnterSleep() as Void {
        _inLowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _inLowPower = false;
        _fieldsMinute = -1;
        WatchUi.requestUpdate();
    }

    //! True when the watch is in always-on / low power mode.
    (:ciq4)
    private function isLowPower() as Boolean {
        if (System has :getDisplayMode) {
            return System.getDisplayMode() == System.DISPLAY_MODE_LOW_POWER;
        }
        return _inLowPower;
    }

    //! API 3.x devices (D-36): System.getDisplayMode (API 5.0.0) is unknown to the compiler there; use the
    //! onEnterSleep / onExitSleep state.
    (:ciq3)
    private function isLowPower() as Boolean {
        return _inLowPower;
    }

}
