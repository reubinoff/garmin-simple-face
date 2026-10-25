import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;
import Toybox.WatchUi;

//! Run No Evil unit tests (Core Topics -> Unit Testing). Compiled only with `monkeyc --unit-test` and run with
//! `monkeydo <prg> <device> -t` in the simulator; test code is not included in normal builds.
//! See scripts/run-unit-tests.sh and DECISIONS.md D-22.

(:test)
function testParseSize(logger as Logger) as Boolean {
    Test.assertEqual(NoirSettings.parseSize(0), NoirSettings.SIZE_SMALL);
    Test.assertEqual(NoirSettings.parseSize(1), NoirSettings.SIZE_MEDIUM);
    Test.assertEqual(NoirSettings.parseSize(2), NoirSettings.SIZE_LARGE);
    Test.assertEqual(NoirSettings.parseSize(3), NoirSettings.SIZE_XLARGE);
    Test.assertEqual(NoirSettings.parseSize(4), NoirSettings.SIZE_XXLARGE);
    Test.assertEqual(NoirSettings.parseSize(null), NoirSettings.SIZE_MEDIUM);
    Test.assertEqual(NoirSettings.parseSize(-1), NoirSettings.SIZE_MEDIUM);
    Test.assertEqual(NoirSettings.parseSize(5), NoirSettings.SIZE_MEDIUM);
    Test.assertEqual(NoirSettings.parseSize("2"), NoirSettings.SIZE_MEDIUM);
    Test.assertEqual(NoirSettings.parseSize(1.5f), NoirSettings.SIZE_MEDIUM);
    return true;
}

(:test)
function testParseColor(logger as Logger) as Boolean {
    Test.assertEqual(NoirSettings.parseColor(0x00D4FF), 0x00D4FF);
    Test.assertEqual(NoirSettings.parseColor(0x000000), 0x000000);
    Test.assertEqual(NoirSettings.parseColor(0xFFFFFF), 0xFFFFFF);
    Test.assertEqual(NoirSettings.parseColor(null), NoirSettings.DEFAULT_COLOR);
    Test.assertEqual(NoirSettings.parseColor(-1), NoirSettings.DEFAULT_COLOR);
    Test.assertEqual(NoirSettings.parseColor(0x1000000), NoirSettings.DEFAULT_COLOR);
    Test.assertEqual(NoirSettings.parseColor("red"), NoirSettings.DEFAULT_COLOR);
    return true;
}

(:test)
function testPaletteAndLabels(logger as Logger) as Boolean {
    var colors = NoirSettings.colorValues();
    Test.assertEqual(colors.size(), 16);
    Test.assertEqual(NoirSettings.colorLabels().size(), colors.size());
    Test.assertEqual(NoirSettings.sizeValues().size(), 5);
    Test.assertEqual(NoirSettings.sizeLabels().size(), 5);
    Test.assertEqual(colors[0], NoirSettings.DEFAULT_COLOR);
    for (var i = 0; i < colors.size(); i++) {
        // Valid 24-bit colour, not black (would be invisible on the black background).
        Test.assert(colors[i] > 0 && colors[i] <= 0xFFFFFF);
        for (var j = i + 1; j < colors.size(); j++) {
            Test.assertNotEqual(colors[i], colors[j]);
        }
    }
    return true;
}

(:test)
function testIndexAndCycleMath(logger as Logger) as Boolean {
    var colors = NoirSettings.colorValues();
    Test.assertEqual(NoirSettings.indexIn(colors, 0x00D4FF), 10);
    Test.assertEqual(NoirSettings.indexIn(colors, 0x123456), 0);
    Test.assertEqual(NoirSettings.nextIndex(0, 8), 1);
    Test.assertEqual(NoirSettings.nextIndex(7, 8), 0);
    Test.assertEqual(NoirSettings.nextIndex(15, 16), 0);
    Test.assertEqual(NoirSettings.nextIndex(4, 5), 0);
    return true;
}

//! Uses the real Application.Properties of the app under test; restores the value afterwards.
(:test)
function testCycleWritesPropertyAndWraps(logger as Logger) as Boolean {
    var key = NoirSettings.KEY_TIME_SIZE;
    var original = Application.Properties.getValue(key);
    Application.Properties.setValue(key, NoirSettings.SIZE_XXLARGE);
    NoirSettings.reload();
    NoirSettings.cycle(key);
    var wrapped = Application.Properties.getValue(key);
    var cached = NoirSettings.timeSize();
    Application.Properties.setValue(key, NoirSettings.parseSize(original));
    NoirSettings.reload();
    Test.assertEqual(wrapped, NoirSettings.SIZE_SMALL);
    Test.assertEqual(cached, NoirSettings.SIZE_SMALL);
    return true;
}

//! Time font order (D-38): the selected size first, then every smaller one; one resource per size.
(:test)
function testTimeFontOrder(logger as Logger) as Boolean {
    var order = NoirLayout.timeFontOrder(NoirSettings.SIZE_XXLARGE);
    Test.assertEqual(order.size(), 5);
    for (var i = 0; i < 5; i++) {
        Test.assertEqual(order[i], 4 - i);
    }
    Test.assertEqual(NoirLayout.timeFontOrder(NoirSettings.SIZE_SMALL).size(), 1);
    Test.assertEqual(NoirLayout.timeFontOrder(NoirSettings.SIZE_MEDIUM)[0], 1);
    Test.assertEqual(NoirLayout.timeFontIds().size(), NoirSettings.sizeValues().size());
    return true;
}

//! Real Bebas Neue fonts on the simulated device (D-38): the build picked the folder for this screen (line height =
//! generated digit height + 2), the sizes grow, digits are tabular, and the memory a loaded font costs is logged and
//! leaves room on the 96 KB API 3.x watch faces (fonts live in the app heap before API 4.0.0).
(:test)
function testTimeFontsOnDevice(logger as Logger) as Boolean {
    var ids = NoirLayout.timeFontIds();
    var expected = NoirTestUtil.expectedDigitHeights(System.getDeviceSettings().screenWidth);
    var previous = 0;
    for (var i = 0; i < ids.size(); i++) {
        var before = System.getSystemStats().usedMemory;
        var font = WatchUi.loadResource(ids[i]) as Graphics.FontType;
        var after = System.getSystemStats().usedMemory;
        var height = Graphics.getFontHeight(font);
        logger.debug("TimeFont" + i.toString() + " line " + height.toString() + " px, heap +" + (after - before).toString()
            + " B, free " + (System.getSystemStats().totalMemory - after).toString() + " B");
        Test.assert(height > previous);
        previous = height;
        if (expected != null) {
            Test.assertEqual(height, expected[i] + NoirLayout.TIME_LINE_EXTRA);
        }
        Test.assert(System.getSystemStats().totalMemory - after > 16384);
    }
    return true;
}

//! Companion RobotoCondensed font (D-40) where Graphics.getVectorFont exists.
(:test)
function testVectorFontAvailable(logger as Logger) as Boolean {
    return NoirTestUtil.checkVectorFont(logger);
}

(:test)
function testLanguageAllowList(logger as Logger) as Boolean {
    Test.assert(NoirLayout.isBasicLatin(System.LANGUAGE_ENG));
    Test.assert(NoirLayout.isBasicLatin(System.LANGUAGE_DEU));
    Test.assert(!NoirLayout.isBasicLatin(System.LANGUAGE_HEB));
    Test.assert(!NoirLayout.isBasicLatin(System.LANGUAGE_RUS));
    Test.assert(!NoirLayout.isBasicLatin(System.LANGUAGE_CHS));
    return true;
}

(:test)
function testInsideCircle(logger as Logger) as Boolean {
    Test.assert(NoirLayout.insideCircle(215, 0, 215));
    Test.assert(!NoirLayout.insideCircle(215, 0, 216));
    Test.assert(NoirLayout.insideCircle(215, 152, 152));   // 46208 <= 46225
    Test.assert(!NoirLayout.insideCircle(215, 153, 152));  // 46513 > 46225
    return true;
}

//! Fit math on the 454 px screen with the generated XX-Large font (line 157, "00" 170 px wide, D-38), a 53 px date
//! 200 px wide and 53 px field rows (D-39).
(:test)
function testBlockFits(logger as Logger) as Boolean {
    var timeW = NoirLayout.timeWidth(170, 155);
    Test.assertEqual(timeW, 381);
    Test.assert(NoirLayout.blockFits(454, 157, timeW, 2, 53, 200, 53, 300, 0));     // one row: fits
    Test.assert(!NoirLayout.blockFits(454, 157, timeW, 2, 53, 200, 53, 300, 150));  // second row shifts the time out
    Test.assert(!NoirLayout.blockFits(454, 157, timeW + 20, 2, 53, 200, 53, 0, 0)); // wider time touches the edge
    Test.assert(!NoirLayout.blockFits(454, 157, timeW, 2, 53, 420, 53, 0, 0));      // date too wide
    Test.assert(!NoirLayout.blockFits(454, 157, timeW, 2, 53, 200, 53, 380, 0));    // row too wide
    // Large (line 126, "00" 136 px): two rows fit.
    Test.assert(NoirLayout.blockFits(454, 126, NoirLayout.timeWidth(136, 124), 2, 53, 200, 53, 300, 150));
    Test.assertEqual(NoirLayout.blockShift(false, 53, 13), 0);
    Test.assertEqual(NoirLayout.blockShift(true, 53, 13), 33);
    Test.assertEqual(454 / 2 - NoirLayout.EDGE_MARGIN, 215);
    return true;
}

(:test)
function testColonGeometry(logger as Logger) as Boolean {
    Test.assertEqual(NoirLayout.digitHeight(157), 155);
    Test.assertEqual(NoirLayout.colonGap(155), 41);
    Test.assertEqual(NoirLayout.colonDot(155), 23);
    Test.assertEqual(NoirLayout.colonOffset(155), 34);
    Test.assertEqual(NoirLayout.colonDot(10), 3);
    // The squares stay apart and inside the digit height.
    Test.assert(NoirLayout.colonOffset(155) * 2 > NoirLayout.colonDot(155));
    Test.assert(NoirLayout.colonOffset(155) + NoirLayout.colonDot(155) / 2 < 155 / 2);
    return true;
}

(:test)
function testColonColor(logger as Logger) as Boolean {
    Test.assertEqual(NoirLayout.colonColor(0x00D4FF, 0x00D4FF), 0x00D4FF);
    Test.assertEqual(NoirLayout.colonColor(0xFFFFFF, 0x00D4FF), NoirLayout.COLOR_TEXT);
    return true;
}

(:test)
function testOutlineWidth(logger as Logger) as Boolean {
    Test.assertEqual(NoirLayout.outlineWidth(37), 2);
    Test.assertEqual(NoirLayout.outlineWidth(126), 2);
    Test.assertEqual(NoirLayout.outlineWidth(157), 2);
    Test.assertEqual(NoirLayout.outlineWidth(210), 3);
    Test.assertEqual(NoirLayout.outlineWidth(1000), NoirLayout.OUTLINE_MAX);
    Test.assertEqual(NoirLayout.OUTLINE_DX.size(), 8);
    Test.assertEqual(NoirLayout.OUTLINE_DY.size(), 8);
    return true;
}

//! Burn-in shift: 4-step cycle, every consecutive pair differs by 2 * shift on exactly one axis,
//! and the edge margin covers shift + outline.
(:test)
function testAodShift(logger as Logger) as Boolean {
    var s = NoirLayout.AOD_SHIFT_PIXELS;
    for (var m = 0; m < 60; m++) {
        var a = NoirLayout.aodShift(m);
        var b = NoirLayout.aodShift(m + 1);
        Test.assert((a[0] == s || a[0] == -s) && (a[1] == s || a[1] == -s));
        var moved = ((a[0] - b[0]).abs() == 2 * s ? 1 : 0) + ((a[1] - b[1]).abs() == 2 * s ? 1 : 0);
        Test.assertEqual(moved, 1);
        var c = NoirLayout.aodShift(m + 4);
        Test.assert(a[0] == c[0] && a[1] == c[1]);
    }
    Test.assert(NoirLayout.EDGE_MARGIN >= NoirLayout.AOD_SHIFT_PIXELS + NoirLayout.OUTLINE_MAX);
    return true;
}

(:test)
function testFormatNumbers(logger as Logger) as Boolean {
    Test.assertEqual(NoirFormat.thousands(null), "--");
    Test.assertEqual(NoirFormat.thousands(0), "0");
    Test.assertEqual(NoirFormat.thousands(999), "999");
    Test.assertEqual(NoirFormat.thousands(1000), "1,000");
    Test.assertEqual(NoirFormat.thousands(12345), "12,345");
    Test.assertEqual(NoirFormat.thousands(100000), "100,000");
    Test.assertEqual(NoirFormat.thousands(1234567), "1,234,567");
    Test.assertEqual(NoirFormat.number(null), "--");
    Test.assertEqual(NoirFormat.number(62), "62");
    Test.assertEqual(NoirFormat.percent(84.6f), "85%");
    Test.assertEqual(NoirFormat.percent(100.0f), "100%");
    Test.assertEqual(NoirFormat.percent(null), "--");
    Test.assertEqual(NoirFormat.days(12.9f), "12d");
    Test.assertEqual(NoirFormat.days(0.4f), "0d");
    Test.assertEqual(NoirFormat.days(null), "--");
    return true;
}

(:test)
function testFormatUnits(logger as Logger) as Boolean {
    Test.assertEqual(NoirFormat.temperature(18.4f, true), "18\u00B0");
    Test.assertEqual(NoirFormat.temperature(18.6f, true), "19\u00B0");
    Test.assertEqual(NoirFormat.temperature(-3.6f, true), "-4\u00B0");
    Test.assertEqual(NoirFormat.temperature(20, false), "68\u00B0");
    Test.assertEqual(NoirFormat.temperature(-40, false), "-40\u00B0");
    Test.assertEqual(NoirFormat.temperature(null, true), "--");
    Test.assertEqual(NoirFormat.distance(523456, true), "5.2");
    Test.assertEqual(NoirFormat.distance(0, true), "0.0");
    Test.assertEqual(NoirFormat.distance(160934, false), "1.0");
    Test.assertEqual(NoirFormat.distance(1234567, true), "12.3");
    Test.assertEqual(NoirFormat.distance(null, false), "--");
    return true;
}

(:test)
function testFormatHour(logger as Logger) as Boolean {
    Test.assertEqual(NoirLayout.formatHour(0, true), "00");
    Test.assertEqual(NoirLayout.formatHour(5, true), "05");
    Test.assertEqual(NoirLayout.formatHour(23, true), "23");
    Test.assertEqual(NoirLayout.formatHour(0, false), "12");
    Test.assertEqual(NoirLayout.formatHour(12, false), "12");
    Test.assertEqual(NoirLayout.formatHour(13, false), "1");
    return true;
}

//! Row mask: for every top row and minute, the first masked row is the right residue and at most
//! AOD_MASK_PERIOD - 1 rows below top; over AOD_MASK_PERIOD consecutive minutes every row is masked once.
(:test)
function testRowMask(logger as Logger) as Boolean {
    var p = NoirLayout.AOD_MASK_PERIOD;
    Test.assert(p >= 2 && p <= 3);
    for (var top = 0; top < 10; top++) {
        for (var m = 0; m < 6; m++) {
            var row = NoirLayout.maskFirstRow(top, m);
            Test.assertEqual(row % p, m % p);
            Test.assert(row >= top && row < top + p);
        }
    }
    for (var y = 0; y < 20; y++) {
        var hits = 0;
        for (var m = 0; m < p; m++) {
            if (y % p == m % p) {
                hits += 1;
            }
        }
        Test.assertEqual(hits, 1);
    }
    return true;
}

//! Field row geometry (D-28, D-39): icon sizes scale with the row font, empty slots take no space.
(:test)
function testFieldRowWidth(logger as Logger) as Boolean {
    Test.assertEqual(NoirLayout.iconHeight(53), 31);
    Test.assertEqual(NoirLayout.iconWidth(NoirFields.STEPS, 53), 26);
    Test.assertEqual(NoirLayout.iconWidth(NoirFields.BODY_BATTERY, 53), 31);
    Test.assertEqual(NoirLayout.iconWidth(NoirFields.BATTERY, 53), 46);
    Test.assertEqual(NoirLayout.iconGap(53), 6);
    Test.assertEqual(NoirLayout.groupGap(53), 21);
    Test.assertEqual(NoirLayout.fieldWidth(NoirFields.NONE, 53, 100), 0);
    Test.assertEqual(NoirLayout.fieldWidth(NoirFields.STEPS, 53, 160), 26 + 6 + 160);
    Test.assertEqual(NoirLayout.rowWidth(53, 0, 0), 0);
    Test.assertEqual(NoirLayout.rowWidth(53, 192, 0), 192);
    Test.assertEqual(NoirLayout.rowWidth(53, 0, 113), 113);
    Test.assertEqual(NoirLayout.rowWidth(53, 192, 113), 192 + 21 + 113);
    for (var f = 0; f < NoirFields.COUNT; f++) {
        Test.assert(NoirLayout.iconWidthPercent(f) > 0);
    }
    Test.assertEqual(NoirLayout.rowSystemFonts().size(), 3);
    Test.assertEqual(NoirLayout.rowVectorSizes(454)[0], 45);
    return true;
}

(:test)
module NoirTestUtil {
    //! Level (Number or null) as text so it can be compared with Test.assertEqual.
    function lv(level as Number or Null) as String {
        return NoirFormat.number(level);
    }

    //! Digit heights scripts/make_fonts.py generated per screen width (Small..XX-Large); null = unknown width.
    function expectedDigitHeights(width as Number) as Array<Number> or Null {
        var table = {
            208 => [35, 43, 51, 57, 64], 218 => [38, 46, 54, 61, 68], 240 => [42, 51, 60, 68, 76],
            260 => [47, 57, 67, 75, 84], 280 => [50, 61, 72, 81, 91], 360 => [67, 81, 96, 108, 120],
            390 => [73, 89, 104, 117, 131], 416 => [78, 95, 112, 126, 141], 454 => [86, 105, 124, 139, 155],
            466 => [89, 108, 127, 142, 159]
        } as Dictionary<Number, Array<Number>>;
        return table[width];
    }

    //! API 4.2.1+ build: getVectorFont, when the device has it, returns the companion face in every row size.
    (:ciq4)
    function checkVectorFont(logger as Logger) as Boolean {
        if (!(Graphics has :getVectorFont)) {
            logger.debug("getVectorFont not on this device: system fonts");
            return true;
        }
        var sizes = NoirLayout.rowVectorSizes(System.getDeviceSettings().screenWidth);
        for (var i = 0; i < sizes.size(); i++) {
            var font = Graphics.getVectorFont({ :face => NoirLayout.textFaces(), :size => sizes[i] });
            logger.debug("RobotoCondensedRegular " + sizes[i].toString() + ": "
                + (font == null ? "missing" : Graphics.getFontHeight(font).toString() + " px"));
            if (font != null) {
                Test.assert(Graphics.getFontHeight(font) > 0);
            }
        }
        return true;
    }

    //! API 3.x build (D-36): no getVectorFont symbol; system fonts.
    (:ciq3)
    function checkVectorFont(logger as Logger) as Boolean {
        logger.debug("API 3.x build: no vector fonts");
        return true;
    }
}

(:test)
function testParseLevel(logger as Logger) as Boolean {
    Test.assertEqual(NoirTestUtil.lv(NoirLayout.parseLevel(null)), "--");
    Test.assertEqual(NoirTestUtil.lv(NoirLayout.parseLevel(0)), "0");
    Test.assertEqual(NoirTestUtil.lv(NoirLayout.parseLevel(76)), "76");
    Test.assertEqual(NoirTestUtil.lv(NoirLayout.parseLevel(100)), "100");
    Test.assertEqual(NoirTestUtil.lv(NoirLayout.parseLevel(101)), "--");
    Test.assertEqual(NoirTestUtil.lv(NoirLayout.parseLevel(-1)), "--");
    Test.assertEqual(NoirTestUtil.lv(NoirLayout.parseLevel(-2)), "--");
    Test.assertEqual(NoirTestUtil.lv(NoirLayout.parseLevel(42.6f)), "43");
    Test.assertEqual(NoirTestUtil.lv(NoirLayout.parseLevel(42.4f)), "42");
    return true;
}

//! Stub with the same shape as SensorHistory.SensorSample (a `data` member).
(:test)
class StubSample {
    var data as Number or Float or Null;
    function initialize(value as Number or Float or Null) {
        data = value;
    }
}

//! NoirSensors.fromSample with stubbed samples: no sample, null data, Float, Number, out of range.
(:test)
function testFromStubSample(logger as Logger) as Boolean {
    Test.assertEqual(NoirTestUtil.lv(NoirSensors.fromSample(null)), "--");
    Test.assertEqual(NoirTestUtil.lv(NoirSensors.fromSample(new StubSample(null))), "--");
    Test.assertEqual(NoirTestUtil.lv(NoirSensors.fromSample(new StubSample(64))), "64");
    Test.assertEqual(NoirTestUtil.lv(NoirSensors.fromSample(new StubSample(63.7f))), "64");
    Test.assertEqual(NoirTestUtil.lv(NoirSensors.fromSample(new StubSample(250))), "--");
    return true;
}

//! Field ids, lists and parsing (D-39).
(:test)
function testFieldLists(logger as Logger) as Boolean {
    var all = NoirFields.allValues();
    Test.assertEqual(all.size(), NoirFields.COUNT);
    Test.assertEqual(NoirFields.allLabels().size(), NoirFields.COUNT);
    for (var i = 0; i < all.size(); i++) {
        Test.assertEqual(all[i], i);
    }
    var supported = NoirFields.supportedValues();
    Test.assertEqual(NoirFields.supportedLabels().size(), supported.size());
    Test.assertEqual(supported[0], NoirFields.NONE);
    // Fields every product has.
    var always = [NoirFields.NONE, NoirFields.STEPS, NoirFields.HEART_RATE, NoirFields.BATTERY, NoirFields.CALORIES,
        NoirFields.INTENSITY, NoirFields.NOTIFICATIONS, NoirFields.DISTANCE];
    for (var i = 0; i < always.size(); i++) {
        Test.assert(NoirFields.isSupported(always[i]));
        Test.assert(supported.indexOf(always[i]) >= 0);
    }
    Test.assert(!NoirFields.isSupported(-1));
    Test.assert(!NoirFields.isSupported(NoirFields.COUNT));
    Test.assertEqual(NoirFields.parse(5, 1), 5);
    Test.assertEqual(NoirFields.parse(NoirFields.COUNT, 1), 1);
    Test.assertEqual(NoirFields.parse(-1, 2), 2);
    Test.assertEqual(NoirFields.parse(null, 2), 2);
    Test.assertEqual(NoirFields.parse("3", 0), 0);
    return true;
}

//! Every field this device supports is read through its real API without throwing (the device-dependent variants
//! and `has` checks are exercised here on each simulated product); unsupported ones are logged.
(:test)
function testFieldsOnDevice(logger as Logger) as Boolean {
    var line = "";
    for (var f = 1; f < NoirFields.COUNT; f++) {
        if (NoirFields.isSupported(f)) {
            var text = NoirFields.text(f);
            Test.assert(text.length() > 0);
            line += f.toString() + "=" + text + " ";
        } else {
            line += f.toString() + "=n/a ";
        }
    }
    logger.debug("fields: " + line);
    var bb = NoirSensors.bodyBattery();
    Test.assert(NoirSensors.bodyBatteryAvailable() || bb == null);
    Test.assert(bb == null || (bb >= 0 && bb <= 100));
    var stress = NoirSensors.stress();
    Test.assert(stress == null || (stress >= 0 && stress <= 100));
    return true;
}

//! Slot settings: defaults, cycling through the supported fields with wrap-around, unsupported ids hidden.
//! Uses the real Application.Properties; originals restored afterwards.
(:test)
function testFieldSettings(logger as Logger) as Boolean {
    var key = NoirSettings.KEY_FIELD_BOTTOM;
    var original = Application.Properties.getValue(key);
    var supported = NoirFields.supportedValues();
    Application.Properties.setValue(key, supported[supported.size() - 1]);
    NoirSettings.reload();
    NoirSettings.cycle(key);
    var wrapped = NoirSettings.field(key);
    Application.Properties.setValue(key, 99);
    NoirSettings.reload();
    var invalid = NoirSettings.storedField(key);
    Application.Properties.setValue(key, NoirFields.parse(original, NoirSettings.DEFAULT_FIELD_BOTTOM));
    NoirSettings.reload();
    Test.assertEqual(wrapped, NoirFields.NONE);
    Test.assertEqual(invalid, NoirSettings.DEFAULT_FIELD_BOTTOM);
    Test.assert(NoirSettings.isFieldKey(NoirSettings.KEY_FIELD_LEFT));
    Test.assert(!NoirSettings.isFieldKey(NoirSettings.KEY_HOUR_COLOR));
    Test.assertEqual(NoirSettings.valuesFor(NoirSettings.KEY_FIELD_RIGHT).size(), supported.size());
    // A stored field the device lacks shows as None.
    for (var f = 0; f < NoirFields.COUNT; f++) {
        if (!NoirFields.isSupported(f)) {
            Application.Properties.setValue(key, f);
            NoirSettings.reload();
            var shown = NoirSettings.field(key);
            Application.Properties.setValue(key, NoirFields.parse(original, NoirSettings.DEFAULT_FIELD_BOTTOM));
            NoirSettings.reload();
            Test.assertEqual(shown, NoirFields.NONE);
            break;
        }
    }
    return true;
}

//! Screen facts the layout depends on (D-36): logged per device; burn-in protection is a Boolean when present.
(:test)
function testDeviceScreen(logger as Logger) as Boolean {
    var settings = System.getDeviceSettings();
    logger.debug("screen " + settings.screenWidth.toString() + "x" + settings.screenHeight.toString());
    Test.assertEqual(settings.screenShape, System.SCREEN_SHAPE_ROUND);
    if (settings has :requiresBurnInProtection) {
        logger.debug("requiresBurnInProtection " + settings.requiresBurnInProtection.toString());
    }
    return true;
}
