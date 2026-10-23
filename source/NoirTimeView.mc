import Toybox.Application;
import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Black watch face that shows only the date, the time and today's steps.
//!
//! Layout (all positions are derived from the real screen size, nothing is hard-coded to 454 px):
//!
//!            Fri 23 Oct          <- date, grey
//!              12:34             <- time, user-selected colour
//!              8,432             <- steps, grey
//!
//! In always-on (low power) mode the whole block is drawn smaller and dimmer and is moved by a
//! few pixels every minute, to respect the AMOLED burn-in rules (see DECISIONS.md D-09).
class NoirTimeView extends WatchUi.WatchFace {

    // Colours (0xRRGGBB). The background is always pure black.
    private const COLOR_TEXT = 0xB0B0B0;
    private const COLOR_TEXT_AOD = 0x6E6E6E;

    // Fraction (percent) of the screen width the time may use in high power mode.
    private const TIME_MAX_WIDTH_PERCENT = 86;
    // Always-on mode: brightness of the time colour (percent) and the size of the pixel shift.
    private const AOD_TIME_BRIGHTNESS_PERCENT = 60;
    private const AOD_SHIFT_PIXELS = 8;

    // Time fonts from largest to smallest. The first one that fits the width budget is used.
    private const TIME_FONTS = [
        Graphics.FONT_NUMBER_THAI_HOT,
        Graphics.FONT_NUMBER_HOT,
        Graphics.FONT_NUMBER_MEDIUM,
        Graphics.FONT_NUMBER_MILD
    ] as Array<Graphics.FontType>;

    private var _timeFont as Graphics.FontType = Graphics.FONT_NUMBER_MEDIUM;
    private var _inLowPower as Boolean = false;

    function initialize() {
        WatchFace.initialize();
    }

    //! Pick the biggest time font that fits. Done once, because the screen size never changes.
    function onLayout(dc as Dc) as Void {
        var maxWidth = dc.getWidth() * TIME_MAX_WIDTH_PERCENT / 100;
        _timeFont = TIME_FONTS[TIME_FONTS.size() - 1];
        for (var i = 0; i < TIME_FONTS.size(); i++) {
            var font = TIME_FONTS[i];
            // "00" is used as a representative pair of digits so the size does not depend on the minute.
            var pairWidth = dc.getTextWidthInPixels("00", font);
            var gap = colonGap(dc.getFontHeight(font));
            if (pairWidth * 2 + gap <= maxWidth) {
                _timeFont = font;
                break;
            }
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        var lowPower = isLowPower();
        var timeColor = readTimeColor();
        var textColor = COLOR_TEXT;
        var timeFont = _timeFont;
        var smallFont = Graphics.FONT_SMALL;
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;

        if (lowPower) {
            // Burn-in protection: smaller, dimmer, and shifted on a 4-step cycle (one step per minute).
            var phase = System.getClockTime().min % 4;
            centerX += (phase == 0 || phase == 3) ? -AOD_SHIFT_PIXELS : AOD_SHIFT_PIXELS;
            centerY += (phase < 2) ? -AOD_SHIFT_PIXELS : AOD_SHIFT_PIXELS;
            timeColor = scaleColor(timeColor, AOD_TIME_BRIGHTNESS_PERCENT);
            textColor = COLOR_TEXT_AOD;
            timeFont = Graphics.FONT_NUMBER_MILD;
            smallFont = Graphics.FONT_XTINY;
        }

        var timeHeight = dc.getFontHeight(timeFont);
        var smallHeight = dc.getFontHeight(smallFont);
        var spacing = dc.getHeight() * 3 / 100;

        drawTime(dc, centerX, centerY, timeFont, timeHeight, timeColor);

        dc.setColor(textColor, Graphics.COLOR_BLACK);
        dc.drawText(
            centerX,
            centerY - timeHeight / 2 - spacing - smallHeight / 2,
            smallFont,
            dateText(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        dc.drawText(
            centerX,
            centerY + timeHeight / 2 + spacing + smallHeight / 2,
            smallFont,
            stepsText(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    function onEnterSleep() as Void {
        _inLowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _inLowPower = false;
        WatchUi.requestUpdate();
    }

    //! Draws "HH:MM" with the colon fixed at (centerX, centerY). The colon is two filled circles,
    //! because colon support in the number-only fonts is not documented.
    private function drawTime(dc as Dc, centerX as Number, centerY as Number, font as Graphics.FontType, fontHeight as Number, color as Number) as Void {
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

        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.drawText(centerX - gap / 2, centerY, font, hourText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(centerX + gap / 2, centerY, font, minuteText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
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

    //! Reads the user's colour. Falls back to white if the stored value is not a number.
    private function readTimeColor() as Number {
        var value = Application.Properties.getValue("TimeColor");
        if (value instanceof Number) {
            return value as Number;
        }
        return Graphics.COLOR_WHITE;
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
