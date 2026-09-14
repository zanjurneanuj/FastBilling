# Fast Billing — Admin panel

A small static web dashboard for checking on the app's data: users, invoice
counts, total revenue, and who's on the free vs. premium plan — with a
button to manually grant/revoke premium (useful until real Razorpay billing
is fully wired up in the app).

It's plain HTML/CSS/JS with no build step. It talks directly to the same
Firebase project as the mobile app (Firestore + Auth), loading Firebase's
SDK as ES modules straight from Google's CDN.

## 1. Deploy the Firestore security rules first

This is the part that actually matters for security — the admin-email
check in `app.js` is just a UI convenience; anyone can view page source. A
signed-in user is only *actually* prevented from reading everyone else's
data by Firestore's own rules.

1. Open `../firestore.rules` (repo root) and read the comment at the top.
2. Compare it against whatever's currently live in **Firebase Console →
   Firestore Database → Rules** for this project — it *replaces* the whole
   ruleset, not merges with it.
3. Once you're happy it covers everything you rely on, paste it into the
   console (or run `firebase deploy --only firestore:rules` if you have the
   Firebase CLI set up for this project) to make it live.

## 2. Add yourself as an admin

Edit two places, keeping them in sync:

- `admin/app.js` → `ADMIN_EMAILS` array
- `firestore.rules` (repo root) → `isAdmin()`'s email list

Both need your email, or you'll either be able to see the dashboard with no
data (rules block reads) or the rules will allow it but the page will
still show "Access denied" (client-side check blocks it).

## 3. Serve the page

Firebase Auth and Firestore need the page loaded over `http(s)://`, not
opened directly as a `file://` path. Any of these work:

- **Firebase Hosting** (recommended — same project, one command):
  ```
  firebase deploy --only hosting
  ```
  (requires a `firebase.json` pointing its `public` dir at `admin/` —
  not included here since Hosting setup is a one-time `firebase init`
  step you'll want to run yourself against your own project)
- **Any static file server** for local testing, e.g. from this folder:
  ```
  npx serve .
  ```

## 4. Sign in

Use email/password or "Sign in with Google" — whichever your admin
account actually has set up in Firebase Auth. If you only ever signed
into the mobile app via Google, use the Google button here too.

## Notes / known limitations

- **Per-user invoice counts** are computed with one Firestore count query
  per user on every dashboard load. Fine for a small-to-medium user base;
  if the user list grows large, replace this with a denormalized counter
  field written alongside each invoice save instead of counting on read.
- **"Recent invoices"** is capped at the most recent 100 (across all
  users, via a `collectionGroup` query) — it's a sample for spot-checking,
  not a full export. The first time this query runs, Firestore may need a
  composite index for `collectionGroup('invoices')` ordered by
  `createdAt`; if the panel shows a load error here, check the browser
  console — Firestore's error message includes a direct link to create
  the missing index.
- **Total revenue** uses Firestore's server-side `sum()` aggregate query.
  If your Firestore SDK/project doesn't support it, that stat shows "—"
  instead of breaking the rest of the dashboard.
