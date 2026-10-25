import Toybox.ActivityMonitor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! Black watch face that shows only the date, the time, today's steps and Body Battery.
//!
//!            Fri 23 Oct          <- date, grey
//!              12:34             <- hours / minutes in two user-selected colours
//!        [feet] 8,432  [bat] 76  <- steps / Body Battery with small vector icons, grey; each can be hidden
//!
//! Active mode: filled digits. Always-on mode (DECISIONS.md D-19): exactly the same fonts and layout, but the
//! digits and colon are drawn as outlines only, date/steps in a dimmer grey, the block is shifted every minute and a
//! rotating row mask turns every pixel off at least once every 3 minutes.
//! Battery (D-21): settings, fonts, date text, steps text and the 12/24 h flag are cached; nothing is allocated
//! per frame except what the system calls return; no timers, no partial updates, no background, no sensors.
//! Body Battery (D-27, D-30) is read from SensorHistory at most once per minute, only while it is shown; the icons
//! (D-28, D-34) are Dc primitives (fillEllipse / drawArc / fillCircle / fillPolygon), no bitmaps or fonts to load.
class NoirTimeView extends WatchUi.WatchFace {

    private var _inLowPower as Boolean = false;
    // True on AMOLED screens (DeviceSettings.requiresBurnInProtection, API 3.0.12). Only these get the outline /
    // shift / row-mask always-on style; MIP screens keep the normal look in low power (DECISIONS.md D-36).
    private var _burnIn as Boolean = true;

    // Layout cache: recomputed only when the size setting changes (or on a new layout).
    private var _layoutKey as Number = -1;
    private var _timeFont as Graphics.FontType = Graphics.FONT_NUMBER_MEDIUM;
    private var _smallFont as Graphics.FontType = Graphics.FONT_SMALL;
    private var _timeHeight as Number = 0;
    private var _smallHeight as Number = 0;
    private var _spacing as Number = 0;
    private var _colonGap as Number = 0;
    private var _colonRadius as Number = 0;
    private var _colonOffset as Number = 0;
    private var _outline as Number = 0;
    private var _statsFont as Graphics.FontType = Graphics.FONT_SMALL;
    private var _statsHeight as Number = 0;
    private var _showSteps as Boolean = true;
    private var _showBodyBattery as Boolean = true;

    // Text caches.
    private var _minuteOfDay as Number = -1;
    private var _dateText as String = "";
    private var _is24Hour as Boolean = true;
    private var _hourText as String = "";
    private var _minuteText as String = "";
    private var _steps as Number or Null = null;
    private var _stepsKnown as Boolean = false;
    private var _stepsText as String = "--";
    private var _bodyBatteryAvailable as Boolean = false;
    private var _bodyBatteryMinute as Number = -1;
    private var _bodyBattery as Number or Null = null;
    private var _bodyBatteryText as String = "--";
    private var _statsWidth as Number = -1;   // -1 = recompute (texts or layout changed)

    function initialize() {
        WatchFace.initialize();
        _bodyBatteryAvailable = NoirBodyBattery.isAvailable();
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
        _bodyBatteryMinute = -1;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        // Body Battery is hidden when the API is not on the device (D-27).
        updateLayout(dc, NoirSettings.timeSize(), NoirSettings.showSteps(),
            NoirSettings.showBodyBattery() && _bodyBatteryAvailable);
        var clock = System.getClockTime();
        updateTexts(clock);

        // Burn-in style only where the screen needs it (D-36); on MIP low power looks like active mode.
        var lowPower = _burnIn && isLowPower();
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
        var justifyCenter = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.drawText(centerX, centerY - (_timeHeight / 2 + _spacing + _smallHeight / 2), _smallFont, _dateText, justifyCenter);
        if (_showSteps || _showBodyBattery) {
            drawStatsRow(dc, centerX, centerY + _timeHeight / 2 + _spacing + _statsHeight / 2, justifyLeft);
        }

        if (lowPower) {
            drawRowMask(dc, clock.min);
        }
    }

    //! "[feet] 8,432  [battery] 76", centred on centreX. Colour is already set (grey / dim grey in always-on).
    //! The row width is recomputed only when one of its texts or the layout changed.
    private function drawStatsRow(dc as Dc, centerX as Number, y as Number, justifyLeft as Number) as Void {
        var h = _statsHeight;
        if (_statsWidth < 0) {
            _statsWidth = NoirLayout.statsRowWidth(h, _showSteps, dc.getTextWidthInPixels(_stepsText, _statsFont),
                _showBodyBattery, dc.getTextWidthInPixels(_bodyBatteryText, _statsFont));
        }
        var x = centerX - _statsWidth / 2;
        var iconH = NoirLayout.iconHeight(h);
        var iconTop = y - iconH / 2;
        var gap = NoirLayout.iconGap(h);
        if (_showSteps) {
            var w = NoirLayout.stepsIconWidth(h);
            drawStepsIcon(dc, x, iconTop, w, iconH);
            x += w + gap;
            dc.drawText(x, y, _statsFont, _stepsText, justifyLeft);
            x += dc.getTextWidthInPixels(_stepsText, _statsFont) + NoirLayout.groupGap(h);
        }
        if (_showBodyBattery) {
            var w = NoirLayout.bodyBatteryIconWidth(h);
            drawBodyBatteryIcon(dc, x, iconTop, w, iconH);
            dc.drawText(x + w + gap, y, _statsFont, _bodyBatteryText, justifyLeft);
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

    //! Picks the time font for the size setting (first candidate that fits, outline included), then the largest
    //! stats-row font that fits next to it, and caches all derived metrics. Same result in active and always-on
    //! mode. Runs only when the size setting or a show/hide setting changes.
    private function updateLayout(dc as Dc, size as Number, showSteps as Boolean, showBodyBattery as Boolean) as Void {
        var key = size * 4 + (showSteps ? 1 : 0) + (showBodyBattery ? 2 : 0);
        if (key == _layoutKey) {
            return;
        }
        _layoutKey = key;
        _showSteps = showSteps;
        _showBodyBattery = showBodyBattery;
        _statsWidth = -1;
        _smallFont = Graphics.FONT_SMALL;
        _smallHeight = dc.getFontHeight(_smallFont);
        var dateWidth = dc.getTextWidthInPixels(NoirLayout.SAMPLE_DATE, _smallFont);
        // The time font is chosen against the smallest stats font, so showing Body Battery never shrinks the time.
        var statsFonts = NoirLayout.statsFontCandidates();
        var smallest = statsFonts[statsFonts.size() - 1];
        var found = false;
        if (size == NoirSettings.SIZE_XXLARGE) {
            found = chooseVectorFont(dc, dateWidth, smallest);
        }
        if (!found) {
            var candidates = NoirLayout.fontCandidates(size);
            _timeFont = candidates[candidates.size() - 1];
            for (var i = 0; i < candidates.size(); i++) {
                if (fits(dc, candidates[i], NoirLayout.DIGIT_HALF_PERCENT_NUMBER, dateWidth, smallest)) {
                    _timeFont = candidates[i];
                    break;
                }
            }
        }
        var digitPercent = found ? NoirLayout.DIGIT_HALF_PERCENT_CONDENSED : NoirLayout.DIGIT_HALF_PERCENT_NUMBER;
        _statsFont = smallest;
        for (var i = 0; i < statsFonts.size(); i++) {
            if (fits(dc, _timeFont, digitPercent, dateWidth, statsFonts[i])) {
                _statsFont = statsFonts[i];
                break;
            }
        }
        _statsHeight = dc.getFontHeight(_statsFont);
        _timeHeight = dc.getFontHeight(_timeFont);
        _spacing = NoirLayout.rowSpacing(dc.getHeight());
        _colonGap = NoirLayout.colonGap(_timeHeight);
        _colonRadius = NoirLayout.colonRadius(_timeHeight);
        _colonOffset = NoirLayout.colonDotOffset(_timeHeight);
        _outline = NoirLayout.outlineWidth(_timeHeight);
    }

    //! XX-Large (D-24): the largest scalable font (Graphics.getVectorFont, API 4.2.1) that fits, tried from
    //! XXL_SIZE_MAX down. Returns false (caller falls back to the X-Large system fonts) if the API or the faces are
    //! not available or nothing fits. Called once per size change only; the chosen VectorFont is kept in _timeFont.
    (:ciq4)
    private function chooseVectorFont(dc as Dc, dateWidth as Number, statsFont as Graphics.FontType) as Boolean {
        if (!(Graphics has :getVectorFont)) {
            return false;
        }
        var width = dc.getWidth();
        for (var px = NoirLayout.xxlSizeMax(width); px >= NoirLayout.xxlSizeMin(width); px -= NoirLayout.XXL_SIZE_STEP) {
            var font = Graphics.getVectorFont({ :face => NoirLayout.xxlFaces(), :size => px });
            if (font == null) {
                return false;
            }
            if (fits(dc, font, NoirLayout.DIGIT_HALF_PERCENT_CONDENSED, dateWidth, statsFont)) {
                _timeFont = font;
                return true;
            }
        }
        return false;
    }

    //! Devices below API 4.2.1 (Forerunner 245 / 745 / 945 / 55 / 645 / 935, D-36): no Graphics.getVectorFont, which the
    //! compiler rejects for them even behind a `has` check, so this variant is built instead; XX-Large = X-Large there.
    (:ciq3)
    private function chooseVectorFont(dc as Dc, dateWidth as Number, statsFont as Graphics.FontType) as Boolean {
        return false;
    }

    //! Fit check with the widest sample texts in statsFont for the fields currently shown.
    private function fits(dc as Dc, font as Graphics.FontType, digitPercent as Number, dateWidth as Number,
            statsFont as Graphics.FontType) as Boolean {
        var height = dc.getFontHeight(font);
        var statsHeight = dc.getFontHeight(statsFont);
        var statsWidth = NoirLayout.statsRowWidth(statsHeight,
            _showSteps, dc.getTextWidthInPixels(NoirLayout.SAMPLE_STEPS, statsFont),
            _showBodyBattery, dc.getTextWidthInPixels(NoirLayout.SAMPLE_BODY_BATTERY, statsFont));
        return NoirLayout.blockFits(dc.getWidth(), height, NoirLayout.digitHalfHeight(height, digitPercent),
            dc.getTextWidthInPixels("00", font), _smallHeight, dateWidth, statsHeight, statsWidth,
            NoirLayout.outlineWidth(height));
    }

    //! Date, hour and minute texts and the 12/24 h flag: rebuilt once per minute. Steps text: rebuilt only when the
    //! count changes. Body Battery: read once per minute. Hidden fields are not read at all.
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
        if (_showSteps) {
            var steps = ActivityMonitor.getInfo().steps;
            if (!_stepsKnown || steps != _steps) {
                _stepsKnown = true;
                _steps = steps;
                _stepsText = NoirLayout.formatSteps(steps);
                _statsWidth = -1;
            }
        }
        if (_showBodyBattery && _bodyBatteryMinute != minuteOfDay) {
            _bodyBatteryMinute = minuteOfDay;
            var level = NoirBodyBattery.read();
            if (level != _bodyBattery || _bodyBatteryText.equals("--")) {
                _bodyBattery = level;
                _bodyBatteryText = NoirLayout.formatBodyBattery(level);
                _statsWidth = -1;
            }
        }
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
