import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Test;

//! Run No Evil unit tests (Core Topics -> Unit Testing). Compiled only with `monkeyc --unit-test` and run with
//! `monkeydo <prg> fenix9pro47mm -t` in the simulator; test code is not included in normal builds.
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

(:test)
function testFontCandidates(logger as Logger) as Boolean {
    var small = NoirLayout.fontCandidates(NoirSettings.SIZE_SMALL);
    var medium = NoirLayout.fontCandidates(NoirSettings.SIZE_MEDIUM);
    var large = NoirLayout.fontCandidates(NoirSettings.SIZE_LARGE);
    var xlarge = NoirLayout.fontCandidates(NoirSettings.SIZE_XLARGE);
    var xxlarge = NoirLayout.fontCandidates(NoirSettings.SIZE_XXLARGE);
    Test.assertEqual(small[0], Graphics.FONT_NUMBER_MILD);
    Test.assertEqual(medium[0], Graphics.FONT_NUMBER_MEDIUM);
    Test.assertEqual(large[0], Graphics.FONT_NUMBER_HOT);
    Test.assertEqual(xlarge[0], Graphics.FONT_NUMBER_THAI_HOT);
    // XX-Large uses a scalable font; its system-font fallback is the X-Large list.
    Test.assertEqual(xxlarge[0], Graphics.FONT_NUMBER_THAI_HOT);
    Test.assertEqual(xxlarge.size(), xlarge.size());
    // Every list ends with a font no bigger than the next smaller size's first choice.
    Test.assertEqual(medium[medium.size() - 1], Graphics.FONT_NUMBER_MILD);
    Test.assertEqual(large[large.size() - 1], Graphics.FONT_NUMBER_MILD);
    Test.assertEqual(xlarge[xlarge.size() - 1], Graphics.FONT_NUMBER_MILD);
    Test.assertEqual(small[small.size() - 1], Graphics.FONT_LARGE);
    return true;
}

//! XX-Large scalable font search range and faces (D-24).
(:test)
function testXxlSearch(logger as Logger) as Boolean {
    Test.assert(NoirLayout.XXL_SIZE_STEP > 0);
    Test.assert(NoirLayout.XXL_SIZE_MIN < NoirLayout.XXL_SIZE_MAX);
    // The search starts above the largest system number font (FONT_NUMBER_THAI_HOT, 210 px on this device).
    Test.assert(NoirLayout.XXL_SIZE_MAX > 210);
    var faces = NoirLayout.xxlFaces();
    Test.assertEqual(faces.size(), 2);
    Test.assertEqual(faces[0], "RobotoCondensedRegular");
    Test.assertEqual(faces[1], "BionicMedium");
    Test.assert(NoirLayout.DIGIT_HALF_PERCENT_CONDENSED >= NoirLayout.DIGIT_HALF_PERCENT_NUMBER);
    Test.assertEqual(NoirLayout.digitHalfHeight(210, 28), 59);   // 58.8 rounded up
    Test.assertEqual(NoirLayout.digitHalfHeight(200, 33), 66);
    Test.assertEqual(NoirLayout.digitHalfHeight(100, 28), 28);
    return true;
}

//! Real scalable font on the simulated device: getVectorFont returns a font for the XX-Large faces and the
//! chosen layout search finds a size that fits (the device reference lists both faces as Scalable).
(:test)
function testVectorFontAvailable(logger as Logger) as Boolean {
    Test.assert(Graphics has :getVectorFont);
    var font = Graphics.getVectorFont({ :face => NoirLayout.xxlFaces(), :size => NoirLayout.XXL_SIZE_MIN });
    Test.assert(font != null);
    Test.assert(Graphics.getFontHeight(font as Graphics.VectorFont) > 0);
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

//! Fit math with fēnix 9 Pro 47mm font heights (device reference) and widths measured from the device fonts.
(:test)
function testBlockFits(logger as Logger) as Boolean {
    // 454 px screen, FONT_SMALL height 53, date 237 px, stats row 160 px wide (Roboto-Regular, D-23).
    Test.assert(NoirLayout.blockFits(454, 113, 32, 89, 53, 237, 53, 160, 2));     // NUMBER_MILD
    Test.assert(NoirLayout.blockFits(454, 153, 43, 120, 53, 237, 53, 160, 2));    // NUMBER_MEDIUM
    Test.assert(NoirLayout.blockFits(454, 210, 59, 165, 53, 237, 53, 160, 3));    // NUMBER_THAI_HOT (X-Large) fits on its digit box
    Test.assert(NoirLayout.blockFits(454, 208, 69, 174, 53, 237, 53, 160, 3));    // RobotoCondensedRegular 208 px (XX-Large)
    Test.assert(!NoirLayout.blockFits(454, 212, 70, 178, 53, 237, 53, 160, 3));   // next XX-Large step: too wide
    Test.assert(!NoirLayout.blockFits(454, 210, 105, 165, 53, 237, 53, 160, 3));  // same font with the full line height as box
    Test.assert(!NoirLayout.blockFits(454, 260, 70, 100, 53, 237, 53, 160, 3));   // date/steps rows pushed off the circle
    Test.assert(!NoirLayout.blockFits(454, 113, 32, 89, 53, 420, 53, 160, 2));    // date too wide
    // Stats row hidden (width 0) never blocks; a wide stats row in a small font fits where FONT_SMALL does not (D-28).
    Test.assert(NoirLayout.blockFits(454, 260, 70, 100, 53, 0, 0, 0, 3) == NoirLayout.insideCircle(215, 0, 130 + 13 + 53));
    Test.assert(NoirLayout.blockFits(454, 208, 69, 174, 53, 237, 37, 232, 3));    // XX-Large + both fields in FONT_XTINY
    Test.assert(!NoirLayout.blockFits(454, 208, 69, 174, 53, 237, 53, 326, 3));   // ... but not in FONT_SMALL
    var radius = 454 / 2 - NoirLayout.EDGE_MARGIN;
    Test.assert(radius == 215);
    return true;
}

(:test)
function testColonGeometry(logger as Logger) as Boolean {
    Test.assertEqual(NoirLayout.colonRadius(52), 3);
    Test.assertEqual(NoirLayout.colonRadius(153), 5);
    Test.assertEqual(NoirLayout.colonGap(153), 30);
    Test.assertEqual(NoirLayout.colonDotOffset(153), 21);
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
    Test.assertEqual(NoirLayout.outlineWidth(71), 2);
    Test.assertEqual(NoirLayout.outlineWidth(113), 2);
    Test.assertEqual(NoirLayout.outlineWidth(153), 2);
    Test.assertEqual(NoirLayout.outlineWidth(173), 2);
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
function testFormatSteps(logger as Logger) as Boolean {
    Test.assertEqual(NoirLayout.formatSteps(null), "--");
    Test.assertEqual(NoirLayout.formatSteps(0), "0");
    Test.assertEqual(NoirLayout.formatSteps(999), "999");
    Test.assertEqual(NoirLayout.formatSteps(1000), "1,000");
    Test.assertEqual(NoirLayout.formatSteps(12345), "12,345");
    Test.assertEqual(NoirLayout.formatSteps(100000), "100,000");
    Test.assertEqual(NoirLayout.formatSteps(1234567), "1,234,567");
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

//! Stats row geometry (D-28): icon sizes scale with the row font, hidden groups take no space.
(:test)
function testStatsRowWidth(logger as Logger) as Boolean {
    Test.assertEqual(NoirLayout.iconHeight(53), 31);
    Test.assertEqual(NoirLayout.iconHeight(37), 22);
    Test.assertEqual(NoirLayout.stepsIconWidth(53), 26);
    Test.assertEqual(NoirLayout.bodyBatteryIconWidth(53), 17);
    Test.assertEqual(NoirLayout.iconGap(53), 6);
    Test.assertEqual(NoirLayout.groupGap(53), 21);
    Test.assertEqual(NoirLayout.statsRowWidth(53, false, 160, false, 76), 0);
    Test.assertEqual(NoirLayout.statsRowWidth(53, true, 160, false, 76), 26 + 6 + 160);
    Test.assertEqual(NoirLayout.statsRowWidth(53, false, 160, true, 76), 17 + 6 + 76);
    Test.assertEqual(NoirLayout.statsRowWidth(53, true, 160, true, 76), 26 + 6 + 160 + 21 + 17 + 6 + 76);
    var fonts = NoirLayout.statsFontCandidates();
    Test.assertEqual(fonts.size(), 3);
    Test.assertEqual(fonts[0], Graphics.FONT_SMALL);
    Test.assertEqual(fonts[2], Graphics.FONT_XTINY);
    return true;
}

//! Nullable Body Battery value as text ("--" = null), so it can be compared with Test.assertEqual.
(:test)
module NoirTestUtil {
    function bb(level as Number or Null) as String {
        return NoirLayout.formatBodyBattery(level);
    }
}

(:test)
function testParseBodyBattery(logger as Logger) as Boolean {
    Test.assertEqual(NoirTestUtil.bb(NoirLayout.parseBodyBattery(null)), "--");
    Test.assertEqual(NoirTestUtil.bb(NoirLayout.parseBodyBattery(0)), "0");
    Test.assertEqual(NoirTestUtil.bb(NoirLayout.parseBodyBattery(76)), "76");
    Test.assertEqual(NoirTestUtil.bb(NoirLayout.parseBodyBattery(100)), "100");
    Test.assertEqual(NoirTestUtil.bb(NoirLayout.parseBodyBattery(101)), "--");
    Test.assertEqual(NoirTestUtil.bb(NoirLayout.parseBodyBattery(-1)), "--");
    Test.assertEqual(NoirTestUtil.bb(NoirLayout.parseBodyBattery(42.6f)), "43");
    Test.assertEqual(NoirTestUtil.bb(NoirLayout.parseBodyBattery(42.4f)), "42");
    Test.assertEqual(NoirLayout.formatBodyBattery(null), "--");
    Test.assertEqual(NoirLayout.formatBodyBattery(7), "7");
    Test.assertEqual(NoirLayout.formatBodyBattery(100), "100");
    return true;
}

//! Stub with the same shape as SensorHistory.SensorSample (a `data` member).
(:test)
class StubBodyBatterySample {
    var data as Number or Float or Null;
    function initialize(value as Number or Float or Null) {
        data = value;
    }
}

//! NoirBodyBattery.fromSample with stubbed samples: no sample, null data, Float, Number, out of range.
(:test)
function testBodyBatteryFromStubSample(logger as Logger) as Boolean {
    Test.assertEqual(NoirTestUtil.bb(NoirBodyBattery.fromSample(null)), "--");
    Test.assertEqual(NoirTestUtil.bb(NoirBodyBattery.fromSample(new StubBodyBatterySample(null))), "--");
    Test.assertEqual(NoirTestUtil.bb(NoirBodyBattery.fromSample(new StubBodyBatterySample(64))), "64");
    Test.assertEqual(NoirTestUtil.bb(NoirBodyBattery.fromSample(new StubBodyBatterySample(63.7f))), "64");
    Test.assertEqual(NoirTestUtil.bb(NoirBodyBattery.fromSample(new StubBodyBatterySample(250))), "--");
    return true;
}

//! Real API on the simulated fenix 9 Pro 47mm: present (has-check) and read() returns null or 0..100 without throwing.
(:test)
function testBodyBatteryApiOnDevice(logger as Logger) as Boolean {
    Test.assert(NoirBodyBattery.isAvailable());
    var level = NoirBodyBattery.read();
    logger.debug("Body Battery read: " + NoirLayout.formatBodyBattery(level));
    Test.assert(level == null || (level >= 0 && level <= 100));
    return true;
}

(:test)
function testParseFlag(logger as Logger) as Boolean {
    Test.assertEqual(NoirSettings.parseFlag(true), true);
    Test.assertEqual(NoirSettings.parseFlag(false), false);
    Test.assertEqual(NoirSettings.parseFlag(null), true);
    Test.assertEqual(NoirSettings.parseFlag(0), true);
    Test.assertEqual(NoirSettings.parseFlag("false"), true);
    Test.assert(NoirSettings.isFlagKey(NoirSettings.KEY_SHOW_STEPS));
    Test.assert(NoirSettings.isFlagKey(NoirSettings.KEY_SHOW_BODY_BATTERY));
    Test.assert(!NoirSettings.isFlagKey(NoirSettings.KEY_TIME_SIZE));
    return true;
}

//! Toggles write the Boolean property, refresh the cache and are independent; originals restored afterwards.
(:test)
function testToggleFlagsRoundTrip(logger as Logger) as Boolean {
    var stepsKey = NoirSettings.KEY_SHOW_STEPS;
    var bbKey = NoirSettings.KEY_SHOW_BODY_BATTERY;
    var origSteps = NoirSettings.parseFlag(Application.Properties.getValue(stepsKey));
    var origBb = NoirSettings.parseFlag(Application.Properties.getValue(bbKey));
    NoirSettings.setFlag(stepsKey, true);
    NoirSettings.setFlag(bbKey, false);
    var a = [NoirSettings.showSteps(), NoirSettings.showBodyBattery(),
        NoirSettings.parseFlag(Application.Properties.getValue(bbKey))] as Array<Boolean>;
    NoirSettings.setFlag(stepsKey, false);
    NoirSettings.setFlag(bbKey, true);
    var b = [NoirSettings.showSteps(), NoirSettings.showBodyBattery(), NoirSettings.flagOf(stepsKey)] as Array<Boolean>;
    NoirSettings.setFlag(stepsKey, origSteps);
    NoirSettings.setFlag(bbKey, origBb);
    Test.assert(a[0] == true && a[1] == false && a[2] == false);
    Test.assert(b[0] == false && b[1] == true && b[2] == false);
    return true;
}
