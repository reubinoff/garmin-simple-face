# Noir Time

**A clean, black, AMOLED-friendly watch face for the Garmin fēnix® 9 Pro 47mm.**

Noir Time puts the time front and centre in big, crisp digits on a pure black background, with the date above and your
steps and Body Battery below. Pick the size and colours you like right on the watch or in the Garmin Connect app.

<p align="center">
  <img src="docs/screenshots/active_xlarge_white-cyan.png" alt="Noir Time on a fēnix 9 Pro 47mm (real simulator screenshot)" width="360">
</p>

## Features

- **Date** and **time**, with **separate colours for hours and minutes**
- **Steps** and **Body Battery** with small Garmin-style icons; each can be hidden
- **5 time sizes**: Small, Medium, Large, X-Large, XX-Large
- **16-colour palette**
- **Pure black background**, easy on the eyes and the battery
- **Always-on mode**: outline digits at the same size, with burn-in protection
- **Settings on the watch** (watch face menu) or in the Garmin Connect app, in English and Hebrew

## Build

You need the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) (9.3.0 or newer) and a developer key.

```sh
scripts/keygen.sh     # once: creates your developer key
scripts/build.sh      # -> build/NoirTime.prg and build/NoirTime.iq
```

## Install

Connect the watch over USB, copy `build/NoirTime.prg` to the watch's `GARMIN/APPS` folder, eject, then pick
**Noir Time** from the watch faces list.


## More

- [Developer guide](docs/DEVELOPMENT.md): simulator, tests, battery profiling, CI, publishing
- [DECISIONS.md](DECISIONS.md): every technical decision, with the Garmin docs it is based on
- [Screenshots](docs/screenshots/) and the [burn-in report](docs/burn-in-report.md)

> **בעברית:** פני שעון שחורים ונקיים ל-fēnix 9 Pro 47mm: שעה גדולה בצבעים נפרדים לשעות ולדקות, תאריך, צעדים ו-Body Battery
> (אפשר להסתיר), 5 גדלים, 16 צבעים ומצב Always-On. ההגדרות זמינות בשעון ובאפליקציית Garmin Connect, גם בעברית.

## License

Noir Time © 2026 reubinoff is licensed under
[Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)](https://creativecommons.org/licenses/by-nc/4.0/).
You may use, share and modify it for personal and other non-commercial purposes, with attribution.
**Commercial use is not permitted.** See [LICENSE](LICENSE) for the full text.

Garmin, fēnix and Body Battery are trademarks of Garmin Ltd. This project is not affiliated with Garmin.
