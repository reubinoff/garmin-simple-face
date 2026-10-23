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

    //! Called when the user changes a setting in Garmin Connect; redraw with the new colour.
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }

}
