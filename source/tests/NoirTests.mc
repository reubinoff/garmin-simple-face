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
    Test.assertEqual(NoirSettings.parseSize(null), NoirSettings.SIZE_MEDIUM);
    Test.assertEqual(NoirSettings.parseSize(-1), NoirSettings.SIZE_MEDIUM);
    Test.assertEqual(NoirSettings.parseSize(3), NoirSettings.SIZE_MEDIUM);
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
    Test.assertEqual(colors.size(), 8);
    Test.assertEqual(NoirSettings.colorLabels().size(), colors.size());
    Test.assertEqual(NoirSettings.sizeValues().size(), 3);
    Test.assertEqual(NoirSettings.sizeLabels().size(), 3);
    Test.assertEqual(colors[0], NoirSettings.DEFAULT_COLOR);
    for (var i = 0; i < colors.size(); i++) {
        for (var j = i + 1; j < colors.size(); j++) {
            Test.assertNotEqual(colors[i], colors[j]);
        }
    }
    return true;
}

(:test)
function testIndexAndCycleMath(logger as Logger) as Boolean {
    var colors = NoirSettings.colorValues();
    Test.assertEqual(NoirSettings.indexIn(colors, 0x00D4FF), 1);
    Test.assertEqual(NoirSettings.indexIn(colors, 0x123456), 0);
    Test.assertEqual(NoirSettings.nextIndex(0, 8), 1);
    Test.assertEqual(NoirSettings.nextIndex(7, 8), 0);
    Test.assertEqual(NoirSettings.nextIndex(2, 3), 0);
    return true;
}

//! Uses the real Application.Properties of the app under test; restores the value afterwards.
(:test)
function testCycleWritesPropertyAndWraps(logger as Logger) as Boolean {
    var key = NoirSettings.KEY_TIME_SIZE;
    var original = Application.Properties.getValue(key);
    Application.Properties.setValue(key, NoirSettings.SIZE_LARGE);
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
    Test.assertEqual(small[0], Graphics.FONT_NUMBER_MILD);
    Test.assertEqual(medium[0], Graphics.FONT_NUMBER_MEDIUM);
    Test.assertEqual(large[0], Graphics.FONT_NUMBER_THAI_HOT);
    // Every list ends with a font no bigger than the next smaller size's first choice.
    Test.assertEqual(medium[medium.size() - 1], Graphics.FONT_NUMBER_MILD);
    Test.assertEqual(large[large.size() - 1], Graphics.FONT_NUMBER_MILD);
    Test.assertEqual(small[small.size() - 1], Graphics.FONT_LARGE);
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

//! Fit math with fēnix 9 Pro 47mm font heights (device reference) and assumed widths.
(:test)
function testBlockFits(logger as Logger) as Boolean {
    // 454 px screen, FONT_SMALL height 53, date 250 px, steps 180 px wide.
    Test.assert(NoirLayout.blockFits(454, 113, 120, 53, 250, 180, 2));    // NUMBER_MILD, modest width
    Test.assert(NoirLayout.blockFits(454, 153, 150, 53, 250, 180, 2));    // NUMBER_MEDIUM
    Test.assert(!NoirLayout.blockFits(454, 210, 230, 53, 250, 180, 3));   // too wide for the circle
    Test.assert(!NoirLayout.blockFits(454, 260, 100, 53, 250, 180, 3));   // date/steps rows pushed off the circle
    Test.assert(!NoirLayout.blockFits(454, 113, 120, 53, 420, 180, 2));   // date too wide
    // The outline pad can be the deciding factor.
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
