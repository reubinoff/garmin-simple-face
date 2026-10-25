import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.System;

//! Configurable data fields (DECISIONS.md D-39). Each of the three slots (left, right, bottom) shows one of these.
//! The ids are stored in the FieldLeft / FieldRight / FieldBottom properties and listed in settings.xml - KEEP THE
//! VALUES IN SYNC (checked by tests/host/test_resources.py). New ids must be appended, never renumbered.
//!
//! API per field (official API docs, Toybox.*; "Since" level and Supported Devices checked for all 38 products):
//!   STEPS          ActivityMonitor.Info.steps                    1.0.0  no permission
//!   BODY_BATTERY   SensorHistory.getBodyBatteryHistory           3.3.0  SensorHistory  (not fr645/645m/935)
//!   HEART_RATE     Activity.Info.currentHeartRate, else the newest ActivityMonitor.getHeartRateHistory sample
//!                                                                1.0.0 / 1.2.1  no permission
//!   BATTERY        System.Stats.battery                          1.0.0  no permission
//!   BATTERY_DAYS   System.Stats.batteryInDays                    3.3.0  no permission  (not on the API 3.x Forerunners)
//!   CALORIES       ActivityMonitor.Info.calories                 1.0.0  no permission
//!   FLOORS         ActivityMonitor.Info.floorsClimbed            2.1.0  no permission  (not fr245/245m/55/70)
//!   INTENSITY      ActivityMonitor.Info.activeMinutesWeek.total  2.1.0  no permission  (moderate + 2 x vigorous)
//!   NOTIFICATIONS  System.DeviceSettings.notificationCount       1.2.0  no permission
//!   STRESS         SensorHistory.getStressHistory                3.3.0  SensorHistory  (not fr645/645m/935)
//!   TEMPERATURE    Weather.getCurrentConditions().temperature    3.2.0  no permission  (not fr645/645m/935)
//!   DISTANCE       ActivityMonitor.Info.distance (cm, today)     1.0.0  no permission
//! The only permission any field needs is SensorHistory, which the app already declares for Body Battery.
module NoirFields {

    const NONE = 0;
    const STEPS = 1;
    const BODY_BATTERY = 2;
    const HEART_RATE = 3;
    const BATTERY = 4;
    const BATTERY_DAYS = 5;
    const CALORIES = 6;
    const FLOORS = 7;
    const INTENSITY = 8;
    const NOTIFICATIONS = 9;
    const STRESS = 10;
    const TEMPERATURE = 11;
    const DISTANCE = 12;
    const COUNT = 13;

    //! Every field id in menu order.
    function allValues() as Array<Number> {
        return [NONE, STEPS, BODY_BATTERY, HEART_RATE, BATTERY, BATTERY_DAYS, CALORIES, FLOORS, INTENSITY,
                NOTIFICATIONS, STRESS, TEMPERATURE, DISTANCE];
    }

    function allLabels() as Array<ResourceId> {
        return [Rez.Strings.FieldNone, Rez.Strings.FieldSteps, Rez.Strings.FieldBodyBattery, Rez.Strings.FieldHeartRate,
                Rez.Strings.FieldBattery, Rez.Strings.FieldBatteryDays, Rez.Strings.FieldCalories, Rez.Strings.FieldFloors,
                Rez.Strings.FieldIntensity, Rez.Strings.FieldNotifications, Rez.Strings.FieldStress,
                Rez.Strings.FieldTemperature, Rez.Strings.FieldDistance];
    }

    //! True when the field can be shown on this device (compile-time variant + documented `has` check).
    function isSupported(field as Number) as Boolean {
        if (field == BODY_BATTERY) {
            return NoirSensors.bodyBatteryAvailable();
        }
        if (field == STRESS) {
            return NoirSensors.stressAvailable();
        }
        if (field == TEMPERATURE) {
            return NoirSensors.weatherAvailable();
        }
        if (field == BATTERY_DAYS) {
            return NoirSensors.batteryDaysAvailable();
        }
        if (field == FLOORS) {
            return NoirSensors.floorsAvailable();
        }
        return field >= NONE && field < COUNT;
    }

    //! Field ids (and their labels) that this device supports, in menu order: the on-watch menu offers only these.
    function supportedValues() as Array<Number> {
        var all = allValues();
        var result = [] as Array<Number>;
        for (var i = 0; i < all.size(); i++) {
            if (isSupported(all[i])) {
                result.add(all[i]);
            }
        }
        return result;
    }

    function supportedLabels() as Array<ResourceId> {
        var all = allValues();
        var labels = allLabels();
        var result = [] as Array<ResourceId>;
        for (var i = 0; i < all.size(); i++) {
            if (isSupported(all[i])) {
                result.add(labels[i]);
            }
        }
        return result;
    }

    //! Stored value -> field id; anything that is not a known id becomes fallback.
    function parse(value as Object or Null, fallback as Number) as Number {
        if (value instanceof Number) {
            var field = value as Number;
            if (field >= NONE && field < COUNT) {
                return field;
            }
        }
        return fallback;
    }

    //! Current text of a field ("--" when the device has no value). Called once per minute per shown field.
    function text(field as Number) as String {
        if (field == STEPS || field == CALORIES || field == FLOORS || field == INTENSITY || field == DISTANCE) {
            var info = ActivityMonitor.getInfo();
            if (field == STEPS) {
                return NoirFormat.thousands(info.steps);
            }
            if (field == CALORIES) {
                return NoirFormat.thousands(info.calories);
            }
            if (field == FLOORS) {
                return NoirFormat.number(NoirSensors.floors(info));
            }
            if (field == INTENSITY) {
                var week = info.activeMinutesWeek;
                return NoirFormat.thousands(week == null ? null : week.total);
            }
            var metric = System.getDeviceSettings().distanceUnits == System.UNIT_METRIC;
            return NoirFormat.distance(info.distance, metric);
        }
        if (field == HEART_RATE) {
            return NoirFormat.number(heartRate());
        }
        if (field == BATTERY) {
            return NoirFormat.percent(System.getSystemStats().battery);
        }
        if (field == BATTERY_DAYS) {
            return NoirFormat.days(NoirSensors.batteryDays());
        }
        if (field == NOTIFICATIONS) {
            return System.getDeviceSettings().notificationCount.toString();
        }
        if (field == BODY_BATTERY) {
            return NoirFormat.number(NoirSensors.bodyBattery());
        }
        if (field == STRESS) {
            return NoirFormat.number(NoirSensors.stress());
        }
        if (field == TEMPERATURE) {
            var metric = System.getDeviceSettings().temperatureUnits == System.UNIT_METRIC;
            return NoirFormat.temperature(NoirSensors.temperature(), metric);
        }
        return "";
    }

    //! Current heart rate: Activity.Info.currentHeartRate (1.0.0); when that is null, the newest valid sample of
    //! ActivityMonitor.getHeartRateHistory (1.2.1, {period 1, newest first}; INVALID_HR_SAMPLE = no reading).
    function heartRate() as Number or Null {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) {
            return info.currentHeartRate;
        }
        var sample = ActivityMonitor.getHeartRateHistory(1, true).next();
        if (sample == null || sample.heartRate == null || sample.heartRate == ActivityMonitor.INVALID_HR_SAMPLE) {
            return null;
        }
        return sample.heartRate;
    }

    //! Representative widest text per field (fit check, D-39).
    function sampleText(field as Number) as String {
        if (field == STEPS || field == CALORIES) {
            return "88,888";
        }
        if (field == DISTANCE) {
            return "88.8";
        }
        if (field == BATTERY) {
            return "100%";
        }
        if (field == BATTERY_DAYS) {
            return "88d";
        }
        if (field == TEMPERATURE) {
            return "-88\u00B0";
        }
        if (field == INTENSITY) {
            return "8,888";
        }
        return field == NONE ? "" : "888";
    }
}

//! Pure text formatting for the fields (no system calls; unit-tested).
module NoirFormat {

    const NO_VALUE = "--";

    function number(value as Number or Null) as String {
        return value == null ? NO_VALUE : value.toString();
    }

    //! Thousands separator for a non-negative count, e.g. 12345 -> "12,345"; "--" for null.
    function thousands(value as Number or Null) as String {
        if (value == null) {
            return NO_VALUE;
        }
        var digits = value.toString();
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

    //! Battery percentage (Stats.battery is a Float 0..100), rounded: "85%".
    function percent(value as Float or Null) as String {
        return value == null ? NO_VALUE : (value + 0.5f).toNumber().toString() + "%";
    }

    //! Remaining battery days (Stats.batteryInDays, Float), whole days: "12d".
    function days(value as Float or Null) as String {
        return value == null ? NO_VALUE : value.toNumber().toString() + "d";
    }

    //! Celsius (Weather) -> rounded degrees in the user's unit with a degree sign: "18°" / "64°".
    function temperature(celsius as Numeric or Null, metric as Boolean) as String {
        if (celsius == null) {
            return NO_VALUE;
        }
        var value = celsius.toFloat();
        if (!metric) {
            value = value * 9.0f / 5.0f + 32.0f;
        }
        var rounded = value >= 0.0f ? (value + 0.5f).toNumber() : -((-value + 0.5f).toNumber());
        return rounded.toString() + "\u00B0";
    }

    //! Distance in cm -> km or miles with one decimal, truncated: "5.2".
    function distance(cm as Number or Null, metric as Boolean) as String {
        if (cm == null) {
            return NO_VALUE;
        }
        var tenths = metric ? cm / 10000 : cm / 16093;   // 1 mile = 160934 cm
        return (tenths / 10).toString() + "." + (tenths % 10).toString();
    }
}
