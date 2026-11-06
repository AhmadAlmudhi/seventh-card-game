# The Seventh Card · الورقة السابعة

A real-time, press-your-luck card game for 2–8 friends, each playing on their own phone or computer. Create a private room, share the code, and play. Arabic is the default language; English is also available.

- **App:** Flutter (web on GitHub Pages; iOS and Android later), at the repo root.
- **Server:** TypeScript on Cloudflare Workers and Durable Objects, in [`server/`](server/). It runs every game rule, so players can't cheat.

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
