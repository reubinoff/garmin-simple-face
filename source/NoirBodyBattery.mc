import Toybox.Lang;
import Toybox.SensorHistory;

//! Body Battery reader (DECISIONS.md D-27).
//! API: Toybox.SensorHistory.getBodyBatteryHistory (Since API Level 3.3.0; fēnix® 9 Pro 47mm is in its Supported
//! Devices list), module permission "SensorHistory" (declared in manifest.xml). It reads the history the watch
//! already records: no sensor is switched on, no listener or timer is registered. Called at most once per minute
//! and only while the field is shown (NoirTimeView.updateTexts).
module NoirBodyBattery {

    //! Anything with a `data` member like SensorHistory.SensorSample (lets the unit tests use a stub).
    typedef Sample as interface {
        var data as Number or Float or Null;
    };

    //! True when the API exists on this device / firmware (the documented `has` check).
    (:bodybattery)
    function isAvailable() as Boolean {
        return (Toybox has :SensorHistory) && (Toybox.SensorHistory has :getBodyBatteryHistory);
    }

    //! Newest Body Battery value 0..100, or null (API missing, no samples, null sample or out of range).
    //! {:period => 1} asks for the last entry only; ORDER_NEWEST_FIRST is the documented default, set explicitly.
    (:bodybattery)
    function read() as Number or Null {
        if (!isAvailable()) {
            return null;
        }
        var history = SensorHistory.getBodyBatteryHistory({ :period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST });
        return fromSample(history.next());
    }

    //! Forerunner 645 / 645 Music / 935 (API 3.1 / 3.2, below getBodyBatteryHistory's 3.3.0): the compiler rejects the
    //! symbol for them, so these variants are built instead and the field is hidden (D-36).
    (:nobodybattery)
    function isAvailable() as Boolean {
        return false;
    }

    (:nobodybattery)
    function read() as Number or Null {
        return null;
    }

    //! Newest sample (SensorHistoryIterator.next(), null when there is none) -> Number 0..100 or null.
    function fromSample(sample as Sample or Null) as Number or Null {
        if (sample == null) {
            return null;
        }
        return NoirLayout.parseBodyBattery(sample.data);
    }
}
