import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;

//! Device-dependent readers for the data fields (DECISIONS.md D-27, D-39). Each API that is missing from some of the
//! 38 products has two compile-time variants selected by monkey.jungle excludeAnnotations ("Build Configuration"):
//!   (:hist33) / (:nohist33)  SensorHistory.getBodyBatteryHistory / getStressHistory (3.3.0) and
//!                            Weather.getCurrentConditions (3.2.0): all products except Forerunner 645 / 645 Music / 935
//!   (:ciq4) / (:ciq3)        System.Stats.batteryInDays (3.3.0; its Supported Devices list has none of the API 3.x
//!                            Forerunners)
//!   (:floors) / (:nofloors)  ActivityMonitor.Info.floorsClimbed (2.1.0; not in the list for Forerunner 245 / 245 Music
//!                            / 55 / 70 - no barometer)
//! The compiler rejects an API symbol above a product's API level even behind `has`, hence the variants; at run time the
//! documented `has` checks are still made. SensorHistory reads the history the watch already records: no sensor is
//! switched on, no listener or timer is registered. Every reader is called at most once per minute, and only for a
//! field that is shown (NoirTimeView.updateTexts).
module NoirSensors {

    //! Anything with a `data` member like SensorHistory.SensorSample (lets the unit tests use a stub).
    typedef Sample as interface {
        var data as Number or Float or Null;
    };

    // ---- Body Battery / stress / weather (API 3.3 history, Weather 3.2) --------------------------------------------

    (:hist33)
    function bodyBatteryAvailable() as Boolean {
        return (Toybox has :SensorHistory) && (Toybox.SensorHistory has :getBodyBatteryHistory);
    }

    //! Newest Body Battery value 0..100, or null. {:period => 1} = last entry only, newest first.
    (:hist33)
    function bodyBattery() as Number or Null {
        if (!bodyBatteryAvailable()) {
            return null;
        }
        var history = SensorHistory.getBodyBatteryHistory({ :period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST });
        return fromSample(history.next());
    }

    (:hist33)
    function stressAvailable() as Boolean {
        return (Toybox has :SensorHistory) && (Toybox.SensorHistory has :getStressHistory);
    }

    //! Newest stress level 0..100 (the value Garmin's stress widget shows), or null (negative = not measurable).
    (:hist33)
    function stress() as Number or Null {
        if (!stressAvailable()) {
            return null;
        }
        var history = SensorHistory.getStressHistory({ :period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST });
        return fromSample(history.next());
    }

    (:hist33)
    function weatherAvailable() as Boolean {
        return (Toybox has :Weather) && (Toybox.Weather has :getCurrentConditions);
    }

    //! Last cached outdoor temperature in Celsius (Weather.getCurrentConditions, synced from the phone), or null.
    (:hist33)
    function temperature() as Numeric or Null {
        if (!weatherAvailable()) {
            return null;
        }
        var conditions = Toybox.Weather.getCurrentConditions();
        return conditions == null ? null : conditions.temperature;
    }

    //! Forerunner 645 / 645 Music / 935: none of these APIs (D-36, D-39); the fields are hidden.
    (:nohist33)
    function bodyBatteryAvailable() as Boolean {
        return false;
    }

    (:nohist33)
    function bodyBattery() as Number or Null {
        return null;
    }

    (:nohist33)
    function stressAvailable() as Boolean {
        return false;
    }

    (:nohist33)
    function stress() as Number or Null {
        return null;
    }

    (:nohist33)
    function weatherAvailable() as Boolean {
        return false;
    }

    (:nohist33)
    function temperature() as Numeric or Null {
        return null;
    }

    // ---- Battery days -------------------------------------------------------------------------------------------

    (:ciq4)
    function batteryDaysAvailable() as Boolean {
        return System.Stats has :batteryInDays;
    }

    (:ciq4)
    function batteryDays() as Float or Null {
        var stats = System.getSystemStats();
        return (stats has :batteryInDays) ? stats.batteryInDays : null;
    }

    (:ciq3)
    function batteryDaysAvailable() as Boolean {
        return false;
    }

    (:ciq3)
    function batteryDays() as Float or Null {
        return null;
    }

    // ---- Floors -------------------------------------------------------------------------------------------------

    (:floors)
    function floorsAvailable() as Boolean {
        return ActivityMonitor.Info has :floorsClimbed;
    }

    (:floors)
    function floors(info as ActivityMonitor.Info) as Number or Null {
        return (info has :floorsClimbed) ? info.floorsClimbed : null;
    }

    (:nofloors)
    function floorsAvailable() as Boolean {
        return false;
    }

    (:nofloors)
    function floors(info as ActivityMonitor.Info) as Number or Null {
        return null;
    }

    //! Newest sample (SensorHistoryIterator.next(), null when there is none) -> Number 0..100 or null.
    function fromSample(sample as Sample or Null) as Number or Null {
        if (sample == null) {
            return null;
        }
        return NoirLayout.parseLevel(sample.data);
    }
}
