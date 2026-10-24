import Toybox.Application;
import Toybox.Lang;

//! Shared definition of the user settings, used by the watch face (reading) and the on-device
//! settings menu (reading + writing). The phone-side definition is in resources/settings/settings.xml
//! and resources/properties/properties.xml - KEEP THE VALUES BELOW IN SYNC WITH THOSE FILES
//! (checked by tests/host/test_resources.py).
//!
//! Battery (DECISIONS.md D-21): the three values are read from Application.Properties once and cached.
//! The cache is refreshed by reload(), called from AppBase.onSettingsChanged(), after an on-device change
//! (cycle()) and when the watch face view is shown again (onShow).
module NoirSettings {

    const KEY_TIME_SIZE = "TimeSize";
    const KEY_HOUR_COLOR = "HourColor";
    const KEY_MINUTE_COLOR = "MinuteColor";

    const SIZE_SMALL = 0;
    const SIZE_MEDIUM = 1;
    const SIZE_LARGE = 2;

    const DEFAULT_COLOR = 0xFFFFFF;

    var _loaded as Boolean = false;
    var _timeSize as Number = SIZE_MEDIUM;
    var _hourColor as Number = DEFAULT_COLOR;
    var _minuteColor as Number = DEFAULT_COLOR;

    //! The 8 time colours, same order and values as the list in settings.xml.
    function colorValues() as Array<Number> {
        return [0xFFFFFF, 0x00D4FF, 0x30E060, 0xFFD60A, 0xFF9500, 0xFF453A, 0xFF4FA0, 0xB388FF];
    }

    function colorLabels() as Array<ResourceId> {
        return [
            Rez.Strings.ColorWhite, Rez.Strings.ColorCyan, Rez.Strings.ColorGreen, Rez.Strings.ColorYellow,
            Rez.Strings.ColorOrange, Rez.Strings.ColorRed, Rez.Strings.ColorPink, Rez.Strings.ColorPurple
        ];
    }

    function sizeValues() as Array<Number> {
        return [SIZE_SMALL, SIZE_MEDIUM, SIZE_LARGE];
    }

    function sizeLabels() as Array<ResourceId> {
        return [Rez.Strings.SizeSmall, Rez.Strings.SizeMedium, Rez.Strings.SizeLarge];
    }

    //! Parses a stored size: anything that is not a Number in 0..2 becomes Medium.
    function parseSize(value as Object or Null) as Number {
        if (value instanceof Number) {
            var size = value as Number;
            if (size >= SIZE_SMALL && size <= SIZE_LARGE) {
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

    //! Reads all three properties (Properties.getValue, API 2.4.0) into the cache.
    function reload() as Void {
        _timeSize = parseSize(Application.Properties.getValue(KEY_TIME_SIZE));
        _hourColor = parseColor(Application.Properties.getValue(KEY_HOUR_COLOR));
        _minuteColor = parseColor(Application.Properties.getValue(KEY_MINUTE_COLOR));
        _loaded = true;
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

    function valueOf(key as String) as Number {
        if (key.equals(KEY_TIME_SIZE)) {
            return timeSize();
        }
        return key.equals(KEY_HOUR_COLOR) ? hourColor() : minuteColor();
    }

    //! Values and labels for a setting key (used by the on-device menu).
    function valuesFor(key as String) as Array<Number> {
        return key.equals(KEY_TIME_SIZE) ? sizeValues() : colorValues();
    }

    function labelsFor(key as String) as Array<ResourceId> {
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
