"""Host-side consistency checks of resources vs. code (no SDK device files needed).

Run: python3 -m unittest discover -s tests/host -v
The resources.xsd check runs only when CIQ_RESOURCES_XSD points to the SDK's bin/resources.xsd (it is part of the
SDK, under Garmin's licence, so it is not copied into this repository).
"""
import glob
import os
import re
import unittest
import xml.etree.ElementTree as ET

# Products in manifest.xml (DECISIONS.md D-36), sorted.
PRODUCTS = [
    "fenix843mm",
    "fenix847mm",
    "fenix8pro47mm",
    "fenix8solar47mm",
    "fenix8solar51mm",
    "fenix943mm",
    "fenix947mm",
    "fenix9pro43mm",
    "fenix9pro47mm",
    "fenix9pro51mm",
    "fenix9prosolar47mm",
    "fenix9prosolar51mm",
    "fenixe",
    "fr165",
    "fr165m",
    "fr170",
    "fr170m",
    "fr245",
    "fr245m",
    "fr255",
    "fr255m",
    "fr255s",
    "fr255sm",
    "fr265",
    "fr265s",
    "fr55",
    "fr57042mm",
    "fr57047mm",
    "fr645",
    "fr645m",
    "fr70",
    "fr745",
    "fr935",
    "fr945",
    "fr945lte",
    "fr955",
    "fr965",
    "fr970",
]


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def read(*p):
    with open(os.path.join(ROOT, *p), encoding="utf-8") as fh:
        return fh.read()


def strings(path):
    return {e.get("id"): (e.text or "") for e in ET.parse(os.path.join(ROOT, path)).getroot().iter("string")}


class ResourcesTest(unittest.TestCase):
    def setUp(self):
        self.settings = ET.parse(os.path.join(ROOT, "resources/settings/settings.xml")).getroot()
        root = ET.parse(os.path.join(ROOT, "resources/properties/properties.xml")).getroot()
        self.prop_types = {p.get("id"): p.get("type") for p in root}
        self.props = {p.get("id"): (p.text.strip() == "true") if p.get("type") == "boolean" else int(p.text.strip(), 0)
                      for p in root}
        self.mc = read("source", "NoirSettings.mc")

    def setting(self, key):
        for s in self.settings.iter("setting"):
            if s.get("propertyKey") == "@Properties." + key:
                return [(int(e.get("value"), 0), e.text) for e in s.iter("listEntry")]
        self.fail("no setting for " + key)

    def test_property_keys_match_code(self):
        keys = dict(re.findall(r'const (KEY_\w+) = "(\w+)";', self.mc))
        self.assertEqual(set(keys.values()), set(self.props))
        self.assertEqual(set(keys.values()), {s.get("propertyKey").split(".")[1] for s in self.settings.iter("setting")})

    def test_palette_matches_code(self):
        code = [int(v, 16) for v in re.search(r"function colorValues\(\).*?\[(.*?)\]", self.mc, re.S).group(1).split(",")]
        labels = re.findall(r"Rez\.Strings\.(Color\w+)", re.search(r"function colorLabels\(\).*?\];", self.mc, re.S).group(0))
        for key in ("HourColor", "MinuteColor"):
            entries = self.setting(key)
            self.assertEqual([v for v, _ in entries], code, key)
            self.assertEqual([t.replace("@Strings.", "") for _, t in entries], labels, key)
        self.assertEqual(len(code), 16)
        self.assertEqual(len(set(code)), 16)
        # 24-bit 0xRRGGBB (Dc.setColor), never black (invisible on the black face), and still 16 distinct colours
        # after reduction to the 16-bit (RGB565, 65,536 colours) display of the fenix 9 Pro 47mm.
        for c in code:
            self.assertTrue(0 < c <= 0xFFFFFF, hex(c))
        rgb565 = {((c >> 19) & 0x1F, (c >> 10) & 0x3F, (c >> 3) & 0x1F) for c in code}
        self.assertEqual(len(rgb565), 16)

    def test_sizes_match_code(self):
        entries = self.setting("TimeSize")
        consts = dict((k, int(v)) for k, v in re.findall(r"const (SIZE_\w+) = (\d+);", self.mc))
        self.assertEqual([v for v, _ in entries], [consts["SIZE_SMALL"], consts["SIZE_MEDIUM"], consts["SIZE_LARGE"],
                                                   consts["SIZE_XLARGE"], consts["SIZE_XXLARGE"]])
        labels = re.findall(r"Rez\.Strings\.(Size\w+)", re.search(r"function sizeLabels\(\).*?\];", self.mc, re.S).group(0))
        self.assertEqual([t.replace("@Strings.", "") for _, t in entries], labels)

    def test_show_hide_toggles(self):
        """ShowSteps / ShowBodyBattery: Boolean properties defaulting to true, boolean settings (D-29)."""
        for key in ("ShowSteps", "ShowBodyBattery"):
            self.assertEqual(self.prop_types[key], "boolean", key)
            self.assertIs(self.props[key], True, key)
            types = [c.get("type") for s in self.settings.iter("setting") if s.get("propertyKey") == "@Properties." + key
                     for c in s.iter("settingConfig")]
            self.assertEqual(types, ["boolean"], key)
        self.assertIn('const KEY_SHOW_STEPS = "ShowSteps";', self.mc)
        self.assertIn('const KEY_SHOW_BODY_BATTERY = "ShowBodyBattery";', self.mc)
        menu = read("source", "NoirTimeSettingsMenu.mc")
        self.assertEqual(menu.count("new WatchUi.ToggleMenuItem("), 2)

    def test_defaults_are_list_values(self):
        for key, default in self.props.items():
            if self.prop_types[key] == "boolean":
                continue
            self.assertIn(default, [v for v, _ in self.setting(key)], key)
        self.assertEqual(self.props["TimeSize"], 1)  # Medium
        self.assertEqual(self.props["HourColor"], 0xFFFFFF)
        self.assertEqual(self.props["MinuteColor"], 0xFFFFFF)

    def test_string_ids_parity_and_usage(self):
        en, he = strings("resources/strings/strings.xml"), strings("resources-heb/strings/strings.xml")
        self.assertEqual(set(en), set(he), "English and Hebrew string ids differ")
        for k in en:
            self.assertTrue(en[k].strip() and he[k].strip(), k)
        used = set()
        for f in glob.glob(os.path.join(ROOT, "source", "**", "*.mc"), recursive=True):
            used |= set(re.findall(r"Rez\.Strings\.(\w+)", read(f)))
        for f in glob.glob(os.path.join(ROOT, "resources*", "**", "*.xml"), recursive=True) + [os.path.join(ROOT, "manifest.xml")]:
            used |= set(re.findall(r"@Strings\.(\w+)", read(f)))
        self.assertEqual(used - set(en), set(), "used but not defined")
        self.assertEqual(set(en) - used, set(), "defined but unused")
        self.assertTrue(re.search(r"[\u0590-\u05FF]", he["HourColorTitle"]))

    def test_manifest(self):
        m = read("manifest.xml")
        self.assertIn('type="watchface"', m)
        self.assertEqual(re.findall(r'<iq:product id="([^"]+)"', m), PRODUCTS)
        # API 3.1.0: lowest connectIQVersion among the products (fr645 / fr935 compiler.json), D-36.
        self.assertIn('minApiLevel="3.1.0"', m)
        self.assertEqual(sorted(re.findall(r"<iq:language>(\w+)</iq:language>", m)), ["eng", "heb"])
        # Exactly one permission: SensorHistory, for SensorHistory.getBodyBatteryHistory (D-27).
        self.assertEqual(re.findall(r'<iq:uses-permission id="([^"]+)"', m), ["SensorHistory"])

    def test_jungle_devices_and_launcher_icons(self):
        """Every device named in monkey.jungle is a manifest product; launcher-icons/<n>/ holds an n x n icon (D-36)."""
        from PIL import Image
        jungle = read("monkey.jungle")
        named = set(re.findall(r"^(\w+)\.(?:excludeAnnotations|resourcePath)", jungle, re.MULTILINE)) - {"base", "project"}
        self.assertEqual(named - set(PRODUCTS), set())
        for size in re.findall(r"launcher-icons/(\d+)", jungle):
            with Image.open(os.path.join(ROOT, "launcher-icons", size, "drawables", "launcher_icon.png")) as im:
                self.assertEqual(im.size, (int(size), int(size)))
        # API 3.x devices must take the fallback variants (no getVectorFont / getDisplayMode symbols).
        for dev in ("fr245", "fr245m", "fr745", "fr945", "fr945lte", "fr55", "fr645", "fr645m", "fr935"):
            self.assertRegex(jungle, rf"(?m)^{dev}\.excludeAnnotations = ciq4;")

    def test_no_keys_or_secrets_tracked(self):
        for f in glob.glob(os.path.join(ROOT, "**", "*"), recursive=True):
            self.assertFalse(f.endswith((".der", ".pem", ".b64")), f)

    @unittest.skipUnless(os.environ.get("CIQ_RESOURCES_XSD"), "set CIQ_RESOURCES_XSD to the SDK's bin/resources.xsd")
    def test_resources_validate_against_sdk_xsd(self):
        from lxml import etree
        schema = etree.XMLSchema(etree.parse(os.environ["CIQ_RESOURCES_XSD"]))
        files = glob.glob(os.path.join(ROOT, "resources*", "**", "*.xml"), recursive=True)
        files += glob.glob(os.path.join(ROOT, "launcher-icons", "**", "*.xml"), recursive=True)
        self.assertTrue(files)
        for f in files:
            self.assertTrue(schema.validate(etree.parse(f)), "%s: %s" % (f, schema.error_log))


if __name__ == "__main__":
    unittest.main()
