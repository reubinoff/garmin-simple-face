import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Black watch face that shows only the date, the time and today's steps.
//!
//!            Fri 23 Oct          <- date, grey
//!              12:34             <- hours / minutes in two user-selected colours
//!              8,432             <- steps, grey
//!
//! Settings (phone or watch): time size Small / Medium / Large, hour colour, minute colour.
//! The colon is the hour/minute colour when both are equal, otherwise neutral grey (DECISIONS.md D-15).
//! Every size is checked against the round screen so time, date and steps never overlap and stay
//! inside the circle (D-17). Always-on mode is smaller, dimmer and shifted every minute (D-09).
class NoirTimeView extends WatchUi.WatchFace {

    // Colours (0xRRGGBB). The background is always pure black.
    private const COLOR_TEXT = 0xB0B0B0;
    private const COLOR_TEXT_AOD = 0x6E6E6E;

    // Always-on mode: brightness of the time colours (percent) and the size of the pixel shift.
    private const AOD_TIME_BRIGHTNESS_PERCENT = 60;
    private const AOD_SHIFT_PIXELS = 8;
    // Room kept free at the edge of the round screen, in pixels (also covers the AOD shift).
    private const EDGE_MARGIN = 12;
    // Representative widest texts used for the fit check (the real text is drawn, these only size the layout).
    private const SAMPLE_DATE = "Wed 30 Sep";
    private const SAMPLE_STEPS = "100,000";

    // Font cache: recomputed only when the size setting or the power mode changes.
    private var _cachedKey as Number = -1;
    private var _timeFont as Graphics.FontType = Graphics.FONT_NUMBER_MEDIUM;
    private var _smallFont as Graphics.FontType = Graphics.FONT_SMALL;
    private var _inLowPower as Boolean = false;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _cachedKey = -1;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        var lowPower = isLowPower();
        var size = NoirSettings.timeSize();
        chooseFonts(dc, size, lowPower);

        var hourColor = NoirSettings.hourColor();
        var minuteColor = NoirSettings.minuteColor();
        var colonColor = (hourColor == minuteColor) ? hourColor : COLOR_TEXT;
        var textColor = COLOR_TEXT;
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;

        if (lowPower) {
            // Burn-in protection: dimmer, and shifted on a 4-step cycle (one step per minute).
            var phase = System.getClockTime().min % 4;
            centerX += (phase == 0 || phase == 3) ? -AOD_SHIFT_PIXELS : AOD_SHIFT_PIXELS;
            centerY += (phase < 2) ? -AOD_SHIFT_PIXELS : AOD_SHIFT_PIXELS;
            hourColor = scaleColor(hourColor, AOD_TIME_BRIGHTNESS_PERCENT);
            minuteColor = scaleColor(minuteColor, AOD_TIME_BRIGHTNESS_PERCENT);
            colonColor = (colonColor == COLOR_TEXT) ? COLOR_TEXT_AOD : scaleColor(colonColor, AOD_TIME_BRIGHTNESS_PERCENT);
            textColor = COLOR_TEXT_AOD;
        }

        var timeHeight = dc.getFontHeight(_timeFont);
        var smallHeight = dc.getFontHeight(_smallFont);
        var spacing = rowSpacing(dc);

        drawTime(dc, centerX, centerY, timeHeight, hourColor, minuteColor, colonColor);

        dc.setColor(textColor, Graphics.COLOR_BLACK);
        dc.drawText(centerX, centerY - timeHeight / 2 - spacing - smallHeight / 2, _smallFont, dateText(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(centerX, centerY + timeHeight / 2 + spacing + smallHeight / 2, _smallFont, stepsText(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function onEnterSleep() as Void {
        _inLowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _inLowPower = false;
        WatchUi.requestUpdate();
    }

    //! Font candidates per size, largest first. The first candidate that fits the screen is used.
    //! Always-on mode is capped at FONT_NUMBER_MILD to keep the lit area small (D-09, D-17).
    private function timeFontCandidates(size as Number, lowPower as Boolean) as Array<Graphics.FontType> {
        if (lowPower) {
            if (size == NoirSettings.SIZE_SMALL) {
                return [Graphics.FONT_LARGE] as Array<Graphics.FontType>;
            }
            return [Graphics.FONT_NUMBER_MILD, Graphics.FONT_LARGE] as Array<Graphics.FontType>;
        }
        if (size == NoirSettings.SIZE_SMALL) {
            return [Graphics.FONT_NUMBER_MILD, Graphics.FONT_LARGE] as Array<Graphics.FontType>;
        }
        if (size == NoirSettings.SIZE_LARGE) {
            return [Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM,
                    Graphics.FONT_NUMBER_MILD] as Array<Graphics.FontType>;
        }
        return [Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD] as Array<Graphics.FontType>;
    }

    private function chooseFonts(dc as Dc, size as Number, lowPower as Boolean) as Void {
        var key = size * 2 + (lowPower ? 1 : 0);
        if (key == _cachedKey) {
            return;
        }
        _cachedKey = key;
        _smallFont = lowPower ? Graphics.FONT_XTINY : Graphics.FONT_SMALL;
        var candidates = timeFontCandidates(size, lowPower);
        _timeFont = candidates[candidates.size() - 1];
        for (var i = 0; i < candidates.size(); i++) {
            if (fits(dc, candidates[i], _smallFont)) {
                _timeFont = candidates[i];
                return;
            }
        }
    }

    //! True if a point at horizontal half-width halfW and vertical offset dy from the centre is inside
    //! the round screen minus EDGE_MARGIN. Integer maths only (squares), no square roots.
    private function insideCircle(dc as Dc, halfW as Number, dy as Number) as Boolean {
        var radius = dc.getWidth() / 2 - EDGE_MARGIN;
        return halfW * halfW + dy * dy <= radius * radius;
    }

    //! Checks the whole block (date / time / steps) for a time font against the round screen:
    //! the outer corners of each row's box must be inside the circle. Rows are stacked without overlap
    //! by construction (each row is placed below the previous one's box plus spacing).
    private function fits(dc as Dc, timeFont as Graphics.FontType, smallFont as Graphics.FontType) as Boolean {
        var timeHeight = dc.getFontHeight(timeFont);
        var smallHeight = dc.getFontHeight(smallFont);
        var spacing = rowSpacing(dc);
        var timeHalfWidth = (dc.getTextWidthInPixels("00", timeFont) * 2 + colonGap(timeHeight)) / 2;
        var dateHalfWidth = dc.getTextWidthInPixels(SAMPLE_DATE, smallFont) / 2;
        var stepsHalfWidth = dc.getTextWidthInPixels(SAMPLE_STEPS, smallFont) / 2;
        var rowOuterEdge = timeHeight / 2 + spacing + smallHeight;
        return insideCircle(dc, timeHalfWidth, timeHeight / 2)
            && insideCircle(dc, dateHalfWidth, rowOuterEdge)
            && insideCircle(dc, stepsHalfWidth, rowOuterEdge);
    }

    private function rowSpacing(dc as Dc) as Number {
        return dc.getHeight() * 3 / 100;
    }

    //! Draws "HH:MM" with the colon fixed at (centerX, centerY). The colon is two filled circles,
    //! because colon support in the number-only fonts is not documented.
    private function drawTime(dc as Dc, centerX as Number, centerY as Number, fontHeight as Number,
            hourColor as Number, minuteColor as Number, colonColor as Number) as Void {
        var clock = System.getClockTime();
        var hour = clock.hour;
        var is24Hour = System.getDeviceSettings().is24Hour;
        if (!is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        var hourText = is24Hour ? hour.format("%02d") : hour.toString();
        var minuteText = clock.min.format("%02d");

        var gap = colonGap(fontHeight);
        var dotRadius = colonRadius(fontHeight);
        var dotOffset = fontHeight * 14 / 100;

        dc.setColor(hourColor, Graphics.COLOR_BLACK);
        dc.drawText(centerX - gap / 2, centerY, _timeFont, hourText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(minuteColor, Graphics.COLOR_BLACK);
        dc.drawText(centerX + gap / 2, centerY, _timeFont, minuteText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(colonColor, Graphics.COLOR_BLACK);
        dc.fillCircle(centerX, centerY - dotOffset, dotRadius);
        dc.fillCircle(centerX, centerY + dotOffset, dotRadius);
    }

    private function colonRadius(fontHeight as Number) as Number {
        var radius = fontHeight / 26;
        return radius < 3 ? 3 : radius;
    }

    private function colonGap(fontHeight as Number) as Number {
        return colonRadius(fontHeight) * 6;
    }

    //! "Fri 23 Oct" in the language of the watch (FORMAT_MEDIUM returns localised strings).
    private function dateText() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        return Lang.format("$1$ $2$ $3$", [info.day_of_week, info.day, info.month]);
    }

    //! Today's steps with a thousands separator, or "--" when the device reports none.
    private function stepsText() as String {
        var steps = ActivityMonitor.getInfo().steps;
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

    private function scaleColor(color as Number, percent as Number) as Number {
        var red = ((color >> 16) & 0xFF) * percent / 100;
        var green = ((color >> 8) & 0xFF) * percent / 100;
        var blue = (color & 0xFF) * percent / 100;
        return (red << 16) | (green << 8) | blue;
    }

    //! True when the watch is in always-on / low power mode.
    private function isLowPower() as Boolean {
        if (System has :getDisplayMode) {
            return System.getDisplayMode() == System.DISPLAY_MODE_LOW_POWER;
        }
        return _inLowPower;
    }

}
