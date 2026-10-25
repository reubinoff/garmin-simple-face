import Toybox.Lang;
import Toybox.WatchUi;

//! On-device settings for the watch face, returned by NoirTimeApp.getSettingsView().
//! Documented in "Properties and App Settings" -> "On Device Watch Face and Data Field Settings":
//! the system shows it from the Watch Face menu. Each item shows its current value as the sub-label;
//! selecting an item switches to the next value (no extra views are pushed or popped - see DECISIONS.md D-16).
//! Show Steps / Show Body Battery are WatchUi.ToggleMenuItem (API 3.0.0): the system flips the toggle before
//! onSelect is called, the new state is stored (D-29).
class NoirTimeSettingsMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({ :title => Rez.Strings.AppName });
        addItem(new WatchUi.MenuItem(Rez.Strings.TimeSizeTitle, NoirSettings.currentLabel(NoirSettings.KEY_TIME_SIZE), NoirSettings.KEY_TIME_SIZE, null));
        addItem(new WatchUi.MenuItem(Rez.Strings.HourColorTitle, NoirSettings.currentLabel(NoirSettings.KEY_HOUR_COLOR), NoirSettings.KEY_HOUR_COLOR, null));
        addItem(new WatchUi.MenuItem(Rez.Strings.MinuteColorTitle, NoirSettings.currentLabel(NoirSettings.KEY_MINUTE_COLOR), NoirSettings.KEY_MINUTE_COLOR, null));
        var states = { :enabled => Rez.Strings.StateOn, :disabled => Rez.Strings.StateOff };
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.ShowStepsTitle, states, NoirSettings.KEY_SHOW_STEPS, NoirSettings.showSteps(), null));
        addItem(new WatchUi.ToggleMenuItem(Rez.Strings.ShowBodyBatteryTitle, states, NoirSettings.KEY_SHOW_BODY_BATTERY, NoirSettings.showBodyBattery(), null));
    }
}

class NoirTimeSettingsDelegate extends WatchUi.Menu2InputDelegate {

    private var _menu as NoirTimeSettingsMenu;

    function initialize(menu as NoirTimeSettingsMenu) {
        Menu2InputDelegate.initialize();
        _menu = menu;
    }

    //! Back is not overridden: per the Menu2InputDelegate docs the default onBack() pops the menu.
    function onSelect(item as MenuItem) as Void {
        var id = item.getId();
        if (!(id instanceof String)) {
            return;
        }
        var key = id as String;
        if (item instanceof WatchUi.ToggleMenuItem) {
            NoirSettings.setFlag(key, (item as WatchUi.ToggleMenuItem).isEnabled());
            WatchUi.requestUpdate();
            return;
        }
        item.setSubLabel(NoirSettings.cycle(key));
        var index = _menu.findItemById(key);
        if (index >= 0) {
            _menu.updateItem(item, index);
        }
        WatchUi.requestUpdate();
    }
}
