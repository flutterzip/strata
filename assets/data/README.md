# Demo data

Everything the app shows on a fresh install comes from this folder. Edit a
file, hot restart, and the change appears — no code required.

## Files

| File | Drives |
|------|--------|
| `cards.json`         | the wallet: card carousel, home mini-cards, balances, freeze and limits |
| `transactions.json`  | the activity list, and the home "Spent this week" chart |
| `recipients.json`    | who you can send money to |
| `rates.json`         | the demo exchange-rate table |
| `notifications.json` | the notifications sheet |
| `profile.json`       | the profile screen |
| `auth.json`          | the demo credentials and onboarding slides |

There is deliberately no `spending.json`. The chart is **derived** from
`transactions.json` by `SpendRollup`, so editing a transaction moves the
chart instead of leaving two files to disagree about the same week.

### `cards.json` state

`frozen` blocks every flow that moves money — Send refuses the card as a
source, Convert refuses it on either side — and shows on the card face as a
mute plus a badge. Leave every seeded card active: a wallet that opens with
a frozen card looks broken, and freezing is one tap away in More.

`spendLimitMinor` caps what can leave the card each calendar month. What has
been spent is **derived from transactions**, never stored beside the limit —
a second tally is a second thing to drift out of step with the list people
can see. One seeded card carries a limit so the meter is visible on first
run; a test asserts both of those.

### `rates.json`

The only file here with no store behind it. Rates are reference data, not
state: the owner does not edit them, so there is nothing to persist, and
seeding them into storage would only create a stale second copy. Everything
is quoted against `base`, and a cross rate is `rates[to] / rates[from]` —
a stored table of every pair would be thirty entries for six currencies and
could disagree with itself.

`feeBps` is basis points off the amount *before* conversion, which is what
makes the breakdown add up on screen. It is waived when both sides hold the
same currency. `asOf` is shown in the UI beside the word "indicative";
never present a static table as a live rate.

### `recipients.json`

A send resolves what was typed against these records by **handle or email**,
and refuses to invent a payee from unmatched text — there is no undo on
money, and "@akosau" is a perfectly plausible thing to type. So every row
needs a unique handle (stored with one leading `@`) and a unique email, and a
test asserts both.

Leave at least one row with `"verified": false`, and at least one with
`"lastUsedAt": null`. Those two make the unconfirmed-recipient warning and
the recency ordering reachable in the demo rather than theoretical. A
recipient the *user* adds is always unverified: confirming an account is not
the app's call to make.

Do not put the profile's own handle or email in here. "That is your own
account" is a state the lookup reports, and it must not be reachable by
picking a row.

### `transactions.json` dates

Amounts are **signed** in minor units: negative is money out, positive in.
Every row's `currency` must match the currency of the card its `cardId`
names, or the card balance and its own history cannot be reconciled.

The file carries a top-level `asOf` date, and on first run every row is
shifted forward by however many whole days have passed since then. Without
it the home chart — which shows the last seven days — is empty for anyone
who installs the template more than a week after it was built. The shift is
never backwards, so a seed dated ahead of the clock cannot invent history
that has not happened yet. Re-date the rows by hand and you must move `asOf`
with them.

One file per entity, on purpose. A single `data.json` becomes impossible to
scan once a template grows past a couple of screens.

## Seed vs. state

These files are **seed data**: read-only, bundled into the app, used to
populate storage the first time the app runs.

Anything the user then changes is **state**, written to
`shared_preferences` / the app documents directory. Bundled assets cannot be
written to at runtime, which is why the two are separate.

"Reset demo data" in Settings clears state and re-reads these files.

## Adding a file

Drop it in this folder. `pubspec.yaml` declares `assets/data/` as a
directory, so no pubspec edit is needed. Load it through
`DemoData.loadJson('your_file.json')`.

## Images, audio and other media

Media lives as **files**, never as base64 inside JSON. A JSON record stores a
*reference*, and `MediaRef` resolves it:

```json
{ "artwork": "asset:cards/aurora.png" }   // bundled, from assets/images/cards/
{ "artwork": "file:media/ab12cd.png" }    // runtime, from the documents dir
{ "artwork": null }                        // fall back to generated artwork
```

| Folder | Holds |
|--------|-------|
| `assets/images/cards/`   | card artwork shipped with the template |
| `assets/images/avatars/` | demo profile pictures |
| `assets/audio/`          | demo voice notes / sounds |

Anything the *user* captures — a photo, a voice note — is written to the app
documents directory under `media/`, and the JSON record stores
`file:media/<name>`.

### Writing user media — the rules

1. **Destination** is `MediaRef.runtimeMediaDir()`, i.e.
   `<app documents>/media/`. Never the cache directory (the OS deletes it)
   and never `assets/` (read-only at runtime).
2. **Name it yourself.** Use `<entity>_<id>_<millis>.<ext>`, e.g.
   `avatar_me_1762500000000.jpg`. Never keep the name the picker gave you:
   it can collide, contain anything, or be absent entirely.
3. **Store a relative reference only** — `file:media/<name>`. An absolute
   path breaks on reinstall, because the app container is a new UUID every
   time. This is the single most common way photo features break.
4. **Re-encode before saving.** Downscale to the largest size actually
   displayed (512px on the long edge is plenty for an avatar) and save as
   JPEG at ~85%. A 12MP camera photo stored raw bloats the backup and
   stutters the list.
5. **Delete the old file when replacing one**, and when the owning record
   is deleted. Orphaned media is invisible and grows forever.
6. **Treat a missing file as normal.** The record can outlive the file —
   restored backups, cleared storage. `MediaRef.imageProvider()` already
   returns null when the file is gone; always have a drawn fallback, as the
   initials avatar does.
7. **Ask for the narrowest permission** and handle refusal as a normal
   path, not an error state.

### Where those rules live in code

Every rule above is implemented once, in `lib/services/`:

| Rule | Where |
|------|-------|
| 1, 3 | `LocalMediaStore.write` — writes into `MediaRef.runtimeMediaDir()` and returns `file:media/<name>` |
| 2 | `LocalMediaStore.write` — `<entity>_<id>_<millis>.jpg`, never the picker's name |
| 4 | `ImageEncoder.avatar` — long edge to 512, JPEG at 85% |
| 5 | `LocalMediaStore.replace` — writes the new file first, then deletes the old one, so a failure cannot lose both |
| 6 | `LocalMediaStore.imageFor` returns null for a missing file; `AvatarCircle` falls back to initials |
| 7 | `PhotoPicker` throws `PhotoAccessDenied`, which `AvatarSheet` shows as a sentence with the other route still offered |

`LocalMediaStore.delete` also refuses a path containing `../`: a stored path
is data, and data must not be able to reach the rest of the container.

A screen never touches the filesystem. `AvatarCircle` resolves a picture
through `mediaImageProvider`, which is cached per reference — a
`FutureBuilder` handed a newly-created future on every build completes,
rebuilds, creates another, and never settles.

## Swapping in a real backend

Nothing in `lib/screens` knows this folder exists. Every screen talks to
`WalletRepository`. Replace the implementation in
`lib/providers/wallet_providers.dart`:

```dart
walletRepositoryProvider.overrideWithValue(RemoteWalletRepository(dio))
```

See `lib/services/remote_wallet_repository.dart` for the shape.
