import Toybox.Application;
import Toybox.Lang;

//! Shared definition of the user settings, used by the watch face (reading) and the on-device
//! settings menu (reading + writing). The phone-side definition is in resources/settings/settings.xml
//! and resources/properties/properties.xml - KEEP THE VALUES BELOW IN SYNC WITH THOSE FILES.
module NoirSettings {

    const KEY_TIME_SIZE = "TimeSize";
    const KEY_HOUR_COLOR = "HourColor";
    const KEY_MINUTE_COLOR = "MinuteColor";

    const SIZE_SMALL = 0;
    const SIZE_MEDIUM = 1;
    const SIZE_LARGE = 2;

    const DEFAULT_COLOR = 0xFFFFFF;

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

    //! Reads a number property; returns fallback if the stored value is not a Number.
    function readNumber(key as String, fallback as Number) as Number {
        var value = Application.Properties.getValue(key);
        if (value instanceof Number) {
            return value as Number;
        }
        return fallback;
    }

    function hourColor() as Number {
        return readNumber(KEY_HOUR_COLOR, DEFAULT_COLOR);
    }

    function minuteColor() as Number {
        return readNumber(KEY_MINUTE_COLOR, DEFAULT_COLOR);
    }

    function timeSize() as Number {
        var size = readNumber(KEY_TIME_SIZE, SIZE_MEDIUM);
        if (size < SIZE_SMALL || size > SIZE_LARGE) {
            return SIZE_MEDIUM;
        }
        return size;
    }

    //! Values and labels for a setting key (used by the on-device menu).
    function valuesFor(key as String) as Array<Number> {
        return key.equals(KEY_TIME_SIZE) ? sizeValues() : colorValues();
    }

    function labelsFor(key as String) as Array<ResourceId> {
        return key.equals(KEY_TIME_SIZE) ? sizeLabels() : colorLabels();
    }

    function fallbackFor(key as String) as Number {
        return key.equals(KEY_TIME_SIZE) ? SIZE_MEDIUM : DEFAULT_COLOR;
    }

    //! Index of the stored value in the value list, or 0 if it is not in the list.
    function currentIndex(key as String) as Number {
        var values = valuesFor(key);
        var current = readNumber(key, fallbackFor(key));
        for (var i = 0; i < values.size(); i++) {
            if (values[i] == current) {
                return i;
            }
        }
        return 0;
    }

    function currentLabel(key as String) as ResourceId {
        return labelsFor(key)[currentIndex(key)];
    }

    //! Moves the setting to the next value (wrapping around), stores it, and returns the new label.
    function cycle(key as String) as ResourceId {
        var values = valuesFor(key);
        var next = (currentIndex(key) + 1) % values.size();
        Application.Properties.setValue(key, values[next]);
        return labelsFor(key)[next];
    }
}
