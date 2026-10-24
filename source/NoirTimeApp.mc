import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

//! Application entry point. Watch faces have no input delegate, so only the view is returned.
class NoirTimeApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ new NoirTimeView() ];
    }

    //! On-device settings (time size, hour colour, minute colour), shown by the system from the
    //! Watch Face menu. API 3.2.0, "only applicable to watch faces and data fields".
    function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        var menu = new NoirTimeSettingsMenu();
        return [ menu, new NoirTimeSettingsDelegate(menu) ];
    }

    //! Called when the user changes a setting in Garmin Connect ("triggered by settings change in GCM",
    //! AppBase doc). The settings are cached (battery, DECISIONS.md D-21), so reload them here.
    function onSettingsChanged() as Void {
        NoirSettings.reload();
        WatchUi.requestUpdate();
    }

}
