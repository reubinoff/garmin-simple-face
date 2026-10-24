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
//! Active mode: filled digits. Always-on mode (DECISIONS.md D-19): exactly the same fonts and layout, but the
//! digits and colon are drawn as outlines only, date/steps in a dimmer grey, the block is shifted every minute and a
//! rotating row mask turns every pixel off at least once every 3 minutes.
//! Battery (D-21): settings, fonts, date text, steps text and the 12/24 h flag are cached; nothing is allocated
//! per frame except what the system calls return; no timers, no partial updates, no background, no sensors.
class NoirTimeView extends WatchUi.WatchFace {

    private var _inLowPower as Boolean = false;

    // Layout cache: recomputed only when the size setting changes (or on a new layout).
    private var _layoutSize as Number = -1;
    private var _timeFont as Graphics.FontType = Graphics.FONT_NUMBER_MEDIUM;
    private var _smallFont as Graphics.FontType = Graphics.FONT_SMALL;
    private var _timeHeight as Number = 0;
    private var _smallHeight as Number = 0;
    private var _spacing as Number = 0;
    private var _colonGap as Number = 0;
    private var _colonRadius as Number = 0;
    private var _colonOffset as Number = 0;
    private var _outline as Number = 0;

    // Text caches.
    private var _minuteOfDay as Number = -1;
    private var _dateText as String = "";
    private var _is24Hour as Boolean = true;
    private var _hourText as String = "";
    private var _minuteText as String = "";
    private var _steps as Number or Null = null;
    private var _stepsKnown as Boolean = false;
    private var _stepsText as String = "--";

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
        _layoutSize = -1;
    }

    //! Called when the view comes back to the foreground (e.g. after the settings menu): refresh the
    //! settings cache in case they were changed while the face was not visible.
    function onShow() as Void {
        NoirSettings.reload();
        _minuteOfDay = -1;   // also picks up a 12/24 h change made in the system settings
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        updateLayout(dc, NoirSettings.timeSize());
        var clock = System.getClockTime();
        updateTexts(clock);

        var lowPower = isLowPower();
        var hourColor = NoirSettings.hourColor();
        var minuteColor = NoirSettings.minuteColor();
        var colonColor = NoirLayout.colonColor(hourColor, minuteColor);
        var textColor = NoirLayout.COLOR_TEXT;
        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;
        if (lowPower) {
            var shift = NoirLayout.aodShift(clock.min);
            centerX += shift[0];
            centerY += shift[1];
            textColor = NoirLayout.COLOR_TEXT_AOD;
        }

        var justifyRight = Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER;
        var justifyLeft = Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER;
        var hourX = centerX - _colonGap / 2;
        var minuteX = centerX + _colonGap / 2;

        if (lowPower) {
            drawOutlinedText(dc, hourX, centerY, _hourText, justifyRight, hourColor);
            drawOutlinedText(dc, minuteX, centerY, _minuteText, justifyLeft, minuteColor);
            dc.setColor(colonColor, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(_outline);
            dc.drawCircle(centerX, centerY - _colonOffset, _colonRadius);
            dc.drawCircle(centerX, centerY + _colonOffset, _colonRadius);
        } else {
            dc.setColor(hourColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(hourX, centerY, _timeFont, _hourText, justifyRight);
            dc.setColor(minuteColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(minuteX, centerY, _timeFont, _minuteText, justifyLeft);
            dc.setColor(colonColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(centerX, centerY - _colonOffset, _colonRadius);
            dc.fillCircle(centerX, centerY + _colonOffset, _colonRadius);
        }

        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        var rowOffset = _timeHeight / 2 + _spacing + _smallHeight / 2;
        var justifyCenter = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.drawText(centerX, centerY - rowOffset, _smallFont, _dateText, justifyCenter);
        dc.drawText(centerX, centerY + rowOffset, _smallFont, _stepsText, justifyCenter);

        if (lowPower) {
            drawRowMask(dc, clock.min);
        }
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

    function onEnterSleep() as Void {
        _inLowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _inLowPower = false;
        WatchUi.requestUpdate();
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

    //! Picks the time font for the size setting (first candidate that fits, outline included) and caches
    //! all derived metrics. Same result in active and always-on mode.
    private function updateLayout(dc as Dc, size as Number) as Void {
        if (size == _layoutSize) {
            return;
        }
        _layoutSize = size;
        _smallFont = Graphics.FONT_SMALL;
        _smallHeight = dc.getFontHeight(_smallFont);
        var dateWidth = dc.getTextWidthInPixels(NoirLayout.SAMPLE_DATE, _smallFont);
        var stepsWidth = dc.getTextWidthInPixels(NoirLayout.SAMPLE_STEPS, _smallFont);
        var candidates = NoirLayout.fontCandidates(size);
        _timeFont = candidates[candidates.size() - 1];
        for (var i = 0; i < candidates.size(); i++) {
            var height = dc.getFontHeight(candidates[i]);
            var digits = dc.getTextWidthInPixels("00", candidates[i]);
            if (NoirLayout.blockFits(dc.getWidth(), height, digits, _smallHeight, dateWidth, stepsWidth,
                    NoirLayout.outlineWidth(height))) {
                _timeFont = candidates[i];
                break;
            }
        }
        _timeHeight = dc.getFontHeight(_timeFont);
        _spacing = NoirLayout.rowSpacing(dc.getHeight());
        _colonGap = NoirLayout.colonGap(_timeHeight);
        _colonRadius = NoirLayout.colonRadius(_timeHeight);
        _colonOffset = NoirLayout.colonDotOffset(_timeHeight);
        _outline = NoirLayout.outlineWidth(_timeHeight);
    }

    //! Date, hour and minute texts and the 12/24 h flag: rebuilt once per minute. Steps text: rebuilt only when the count changes.
    private function updateTexts(clock as System.ClockTime) as Void {
        var minuteOfDay = clock.hour * 60 + clock.min;
        if (minuteOfDay != _minuteOfDay) {
            _minuteOfDay = minuteOfDay;
            var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
            _dateText = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.day, info.month]);
            _is24Hour = System.getDeviceSettings().is24Hour;
            _hourText = NoirLayout.formatHour(clock.hour, _is24Hour);
            _minuteText = clock.min.format("%02d");
        }
        var steps = ActivityMonitor.getInfo().steps;
        if (!_stepsKnown || steps != _steps) {
            _stepsKnown = true;
            _steps = steps;
            _stepsText = NoirLayout.formatSteps(steps);
        }
    }

    //! True when the watch is in always-on / low power mode.
    private function isLowPower() as Boolean {
        if (System has :getDisplayMode) {
            return System.getDisplayMode() == System.DISPLAY_MODE_LOW_POWER;
        }
        return _inLowPower;
    }

}
