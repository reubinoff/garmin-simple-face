import Toybox.Application;
import Toybox.Lang;

//! Shared definition of the user settings, used by the watch face (reading) and the on-device
//! settings menu (reading + writing). The phone-side definition is in resources/settings/settings.xml
//! and resources/properties/properties.xml - KEEP THE VALUES BELOW IN SYNC WITH THOSE FILES
//! (checked by tests/host/test_resources.py).
//!
//! Battery (DECISIONS.md D-21): the values are read from Application.Properties once and cached.
//! The cache is refreshed by reload(), called from AppBase.onSettingsChanged(), after an on-device change
//! (cycle()) and when the watch face view is shown again (onShow).
module NoirSettings {

    const KEY_TIME_SIZE = "TimeSize";
    const KEY_HOUR_COLOR = "HourColor";
    const KEY_MINUTE_COLOR = "MinuteColor";
    // Data field slots (D-39): Number properties holding a NoirFields id.
    const KEY_FIELD_LEFT = "FieldLeft";
    const KEY_FIELD_RIGHT = "FieldRight";
    const KEY_FIELD_BOTTOM = "FieldBottom";
    // Defaults = the fields of version 1.0 (steps left, Body Battery right), bottom slot empty.
    const DEFAULT_FIELD_LEFT = 1;     // NoirFields.STEPS
    const DEFAULT_FIELD_RIGHT = 2;    // NoirFields.BODY_BATTERY
    const DEFAULT_FIELD_BOTTOM = 0;   // NoirFields.NONE

    const SIZE_SMALL = 0;
    const SIZE_MEDIUM = 1;
    const SIZE_LARGE = 2;
    const SIZE_XLARGE = 3;
    const SIZE_XXLARGE = 4;

    const DEFAULT_COLOR = 0xFFFFFF;

    var _loaded as Boolean = false;
    var _timeSize as Number = SIZE_MEDIUM;
    var _hourColor as Number = DEFAULT_COLOR;
    var _minuteColor as Number = DEFAULT_COLOR;
    var _fieldLeft as Number = DEFAULT_FIELD_LEFT;
    var _fieldRight as Number = DEFAULT_FIELD_RIGHT;
    var _fieldBottom as Number = DEFAULT_FIELD_BOTTOM;
    // Bumped by every reload(), so the view can keep its own resolved copy of the settings and re-read them only
    // when they changed (one Number compare per frame instead of three field() look-ups, D-43).
    var _generation as Number = 0;

    //! The 16 time colours (24-bit 0xRRGGBB as Dc.setColor takes them), same order and values as the lists in settings.xml.
    function colorValues() as Array<Number> {
        return [0xFFFFFF, 0xC8C8C8, 0xFF453A, 0xFF7A5C, 0xFF9500, 0xFFB800, 0xFFD60A, 0xB4F000,
                0x30E060, 0x00C9A7, 0x00D4FF, 0x6FB8FF, 0x2E6BFF, 0xB388FF, 0xFF2BD6, 0xFF4FA0];
    }

    function colorLabels() as Array<ResourceId> {
        return [
            Rez.Strings.ColorWhite, Rez.Strings.ColorSilver, Rez.Strings.ColorRed, Rez.Strings.ColorCoral,
            Rez.Strings.ColorOrange, Rez.Strings.ColorGold, Rez.Strings.ColorYellow, Rez.Strings.ColorLime,
            Rez.Strings.ColorGreen, Rez.Strings.ColorTeal, Rez.Strings.ColorCyan, Rez.Strings.ColorLightBlue,
            Rez.Strings.ColorBlue, Rez.Strings.ColorPurple, Rez.Strings.ColorMagenta, Rez.Strings.ColorPink
        ];
    }

    function sizeValues() as Array<Number> {
        return [SIZE_SMALL, SIZE_MEDIUM, SIZE_LARGE, SIZE_XLARGE, SIZE_XXLARGE];
    }

    function sizeLabels() as Array<ResourceId> {
        return [Rez.Strings.SizeSmall, Rez.Strings.SizeMedium, Rez.Strings.SizeLarge, Rez.Strings.SizeXLarge,
                Rez.Strings.SizeXXLarge];
    }

    //! Parses a stored size: anything that is not a Number in 0..4 becomes Medium.
    function parseSize(value as Object or Null) as Number {
        if (value instanceof Number) {
            var size = value as Number;
            if (size >= SIZE_SMALL && size <= SIZE_XXLARGE) {
                return size;
            }
        }
        return SIZE_MEDIUM;
    }

    //! Parses a stored colour: anything that is not a Number in 0x000000..0xFFFFFF becomes white.
    function parseColor(value as Object or Null) as Number {
        if (value instanceof Number) {
            var color = value as Number;
            if (color >= 0 && color <= 0xFFFFFF) {
                return color;
            }
        }
        return DEFAULT_COLOR;
    }

    //! Reads all properties (Properties.getValue, API 2.4.0) into the cache.
    function reload() as Void {
        _fieldLeft = NoirFields.parse(Application.Properties.getValue(KEY_FIELD_LEFT), DEFAULT_FIELD_LEFT);
        _fieldRight = NoirFields.parse(Application.Properties.getValue(KEY_FIELD_RIGHT), DEFAULT_FIELD_RIGHT);
        _fieldBottom = NoirFields.parse(Application.Properties.getValue(KEY_FIELD_BOTTOM), DEFAULT_FIELD_BOTTOM);
        _timeSize = parseSize(Application.Properties.getValue(KEY_TIME_SIZE));
        _hourColor = parseColor(Application.Properties.getValue(KEY_HOUR_COLOR));
        _minuteColor = parseColor(Application.Properties.getValue(KEY_MINUTE_COLOR));
        _loaded = true;
        _generation += 1;
    }

    //! Changes after every reload(); never 0 once loaded.
    function generation() as Number {
        ensureLoaded();
        return _generation;
    }

    function ensureLoaded() as Void {
        if (!_loaded) {
            reload();
        }
    }

    function hourColor() as Number {
        ensureLoaded();
        return _hourColor;
    }

    function minuteColor() as Number {
        ensureLoaded();
        return _minuteColor;
    }

    function timeSize() as Number {
        ensureLoaded();
        return _timeSize;
    }

    //! Field id stored for a slot (may be one this device does not support; see field()).
    function storedField(key as String) as Number {
        ensureLoaded();
        if (key.equals(KEY_FIELD_LEFT)) {
            return _fieldLeft;
        }
        return key.equals(KEY_FIELD_RIGHT) ? _fieldRight : _fieldBottom;
    }

    //! Field shown in a slot: the stored one, or NONE when this device does not support it (D-39).
    function field(key as String) as Number {
        var id = storedField(key);
        return NoirFields.isSupported(id) ? id : NoirFields.NONE;
    }

    function isFieldKey(key as String) as Boolean {
        return key.equals(KEY_FIELD_LEFT) || key.equals(KEY_FIELD_RIGHT) || key.equals(KEY_FIELD_BOTTOM);
    }

    function valueOf(key as String) as Number {
        if (key.equals(KEY_TIME_SIZE)) {
            return timeSize();
        }
        if (isFieldKey(key)) {
            return field(key);
        }
        return key.equals(KEY_HOUR_COLOR) ? hourColor() : minuteColor();
    }

    //! Values and labels for a setting key (used by the on-device menu). Field slots offer only the fields this
    //! device supports.
    function valuesFor(key as String) as Array<Number> {
        if (isFieldKey(key)) {
            return NoirFields.supportedValues();
        }
        return key.equals(KEY_TIME_SIZE) ? sizeValues() : colorValues();
    }

    function labelsFor(key as String) as Array<ResourceId> {
        if (isFieldKey(key)) {
            return NoirFields.supportedLabels();
        }
        return key.equals(KEY_TIME_SIZE) ? sizeLabels() : colorLabels();
    }

    //! Index of value in values, or 0 if it is not in the list.
    function indexIn(values as Array<Number>, value as Number) as Number {
        for (var i = 0; i < values.size(); i++) {
            if (values[i] == value) {
                return i;
            }
        }
        return 0;
    }

    //! Index after index, wrapping around at count.
    function nextIndex(index as Number, count as Number) as Number {
        return (index + 1) % count;
    }

    function currentLabel(key as String) as ResourceId {
        return labelsFor(key)[indexIn(valuesFor(key), valueOf(key))];
    }

    //! Moves the setting to the next value (wrapping around), stores it (Properties.setValue, API 2.4.0),
    //! refreshes the cache and returns the new label.
    function cycle(key as String) as ResourceId {
        var values = valuesFor(key);
        var next = nextIndex(indexIn(values, valueOf(key)), values.size());
        Application.Properties.setValue(key, values[next]);
        reload();
        return labelsFor(key)[next];
    }
}
