# The Seventh Card · الورقة السابعة

A real-time, press-your-luck card game for 2–8 friends, each playing on their own phone or computer. Create a private room, share the code, and play. Arabic is the default language; English is also available.

**Play:** https://ahmadalmudhi.github.io/seventh-card-game/ (no install; works on phones and computers). New to it? Try the tutorial game against Robo.

- **App:** Flutter (web on GitHub Pages; iOS and Android later), at the repo root.
- **Server:** TypeScript on Cloudflare Workers and Durable Objects, in [`server/`](server/). It runs every game rule, so players can't cheat.

## Credits

Sound effects use Kenney's [Casino Audio](https://kenney.nl/assets/casino-audio) and [Interface Sounds](https://kenney.nl/assets/interface-sounds) packs (CC0), with chimes made for this game. The font is [Cairo](https://fonts.google.com/specimen/Cairo) (SIL Open Font License).

## Run locally

```sh
# App
flutter pub get
flutter run -d chrome

# Server
cd server
npm install
npm run dev     # http://localhost:8787
npm test
```
