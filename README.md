# Stitch Stash

A native iOS and iPadOS app for needlepoint crafters. It keeps a pattern library, a thread stash and a shopping list, and works out which patterns you can start with the threads you already own.

The app is written in Swift with SwiftUI. It replaces an earlier single-file web app (`index.html`, kept in the repo as a reference for behavior and copy). Where this README and `index.html` disagree, this README wins.

## Status

- [ ] Data model in SwiftData
- [ ] Patterns tab with designer folders
- [ ] Pattern editor (fields, thread list, file and cover photo)
- [ ] Thread stash tab, including paste-a-list import
- [ ] Shopping list tab
- [ ] WIP tab
- [ ] Ready to stitch tab
- [ ] Folder image editor and folder rename
- [ ] iCloud sync (after the first release)
- [ ] "Read threads from pattern" (planned, see below)
- [ ] Import of data exported from the web app
- [ ] App icon, launch screen, TestFlight build

## Platform and tech

| Concern                   | Choice                                                                                                                  |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| UI                        | SwiftUI                                                                                                                 |
| Minimum OS                | iOS / iPadOS 18, the first release with the `Tab` API and the sidebar-adaptable tab style                               |
| Devices                   | iPad first                                                                                                              |
| Persistence               | SwiftData                                                                                                               |
| Sync                      | None in the first release, which stores data on the device only. A later release adds SwiftData's CloudKit integration with the private database. No sign-in screen; the user's iCloud account is the identity. |
| Pattern files and images  | Stored as `Data` with `@Attribute(.externalStorage)` so CloudKit syncs them as assets                                   |
| PDF viewing and rendering | PDFKit (`PDFView` for viewing, `PDFPage.thumbnail(of:for:)` for covers and page images, `PDFPage.string` for text)      |
| Picking files and photos  | `.fileImporter` for PDFs and images, `PhotosPicker` for the photo library, camera via `UIImagePickerController` wrapper |
| Fonts                     | DM Serif Display for headings, Nunito Sans for body, bundled in the app (both are under the SIL Open Font License)      |

The web app's backend plan (custom auth, database, blob storage, server functions, GitHub Pages) does not carry over. SwiftData covers storage and files. CloudKit adds sync in a later release.

## Navigation

A `TabView` with five tabs. On iPad, use the sidebar-adaptable tab style so the tabs become a sidebar in landscape.

| Tab label | Screen title    |
| --------- | --------------- |
| Patterns  | Patterns        |
| WIP       | WIP             |
| Ready     | Ready to stitch |
| Stash     | Thread stash    |
| Shopping  | Shopping list   |

The tab bar uses the short labels because the five full names don't fit in the iPad's top tab bar in portrait. When they overflow, iPadOS hides the last tabs behind a "Next Page" arrow. Each screen's navigation title uses the full name.

Each tab shows a count badge: the number of patterns, works in progress, ready patterns, distinct stash threads, and shopping-list lines. Hide the badge when the count is zero.

A summary header at the top of the Patterns tab (or in the sidebar on iPad) shows three totals: patterns, threads on hand (sum of quantities), and threads to buy (sum of "buy" amounts on the shopping list).

Editors open as sheets. Destructive actions confirm with `.confirmationDialog`. Short success messages ("Pattern saved", "Thread removed") appear as a transient overlay that disappears after about two seconds.

## Data model

Three SwiftData models. CloudKit requires every stored property to be optional or have a default, and does not support unique constraints, so the app enforces uniqueness itself. The first release doesn't sync, but the models follow these rules from the start so that turning on sync later doesn't require changing them.

### `Pattern`

| Property    | Type                                    | Notes                                                 |
| ----------- | --------------------------------------- | ----------------------------------------------------- |
| `id`        | `UUID`                                  |                                                       |
| `name`      | `String`                                | Required, non-empty after trimming                    |
| `designer`  | `String`                                | May be empty. Drives folder grouping.                 |
| `status`    | `PatternStatus`                         | Default `.notStarted`                                 |
| `mesh`      | `Mesh?`                                 | `10`, `13`, `18`, `other`, or unset                   |
| `notes`     | `String`                                | Free text                                             |
| `threads`   | `[PatternThread]`                       | Codable value array, ordered as the user entered them |
| `fileData`  | `Data?`                                 | External storage. The pattern PDF or photo.           |
| `fileName`  | `String`                                |                                                       |
| `fileType`  | `UTType?` (stored as identifier string) |                                                       |
| `coverData` | `Data?`                                 | External storage. JPEG.                               |
| `created`   | `Date`                                  |                                                       |

`PatternThread` is a struct: `brand: String`, `code: String`, `name: String`, `qty: Int` (at least 1).

### `PatternStatus`

| Case             | Raw value (matches web data) | Label shown in the UI     |
| ---------------- | ---------------------------- | ------------------------- |
| `wishlist`       | `Wishlist`                   | Wishlist                  |
| `notStarted`     | `Not started`                | Not started               |
| `inProgress`     | `In progress`                | Stitching                 |
| `needsFinishing` | `Needs finishing`            | Stitched, needs finishing |
| `finished`       | `Finished`                   | Finished                  |

Sort order wherever patterns are listed by status: Stitching, Needs finishing, Not started, Wishlist, Finished. Ties sort by name.

### `StashThread`

| Property  | Type     | Notes                                                                        |
| --------- | -------- | ---------------------------------------------------------------------------- |
| `id`      | `UUID`   |                                                                              |
| `brand`   | `String` | Required                                                                     |
| `code`    | `String` | Required. The color number, kept as text (leading zeros and letters matter). |
| `name`    | `String` | Color name                                                                   |
| `color`   | `String` | Swatch as `#rrggbb`, default `#cccccc` when unknown                          |
| `qty`     | `Int`    | Cards or skeins on hand, at least 0                                          |
| `created` | `Date`   |                                                                              |

### `FolderStyle`

Optional styling for a designer folder.

| Property     | Type                 | Notes                                                                |
| ------------ | -------------------- | -------------------------------------------------------------------- |
| `key`        | `String`             | Lowercased, trimmed designer name. Empty string means "No designer". |
| `imageData`  | `Data?`              | External storage                                                     |
| `fit`        | `contain` or `cover` |                                                                      |
| `background` | `String`             | `#rrggbb`                                                            |

### Thread matching

A pattern thread matches a stash thread when brand and code are equal after trimming whitespace and ignoring case. Put this in one function (for example `ThreadKey(brand:code:)`) and use it everywhere. Adding a stash thread whose key already exists updates the existing entry instead of creating a duplicate.

## Features

### Patterns tab

- Search field (`.searchable`) that matches name, designer, notes, and each listed thread's brand, code and name.
- Status filter menu: All statuses, or one status.
- A segmented control switches between Folders and All patterns. Persist the choice with `@AppStorage`.
- "Add pattern" toolbar button.

Folders mode:

- Shows one tile per designer, sorted by name, with "No designer" last.
- Each tile shows the pattern count and how many are in progress (Stitching or Needs finishing). With a status filter active, it shows "N of M patterns" and hides folders with no matches.
- The tile image is the folder's custom image if set. Otherwise it is a mosaic of up to four pattern covers. With no covers, it shows a folder glyph with the designer's initial.
- Tapping a folder pushes a screen with that designer's patterns. That screen has "Rename folder" (not for "No designer"), "Edit folder image", and "Add to this folder" (opens the pattern editor with the designer pre-filled).
- Typing a search in Folders mode at the top level shows matching patterns across all designers, with a note saying so.

Pattern cards (used on every tab):

- Cover image, or a placeholder that reads "PDF pattern" or "No file yet" with the file name.
- Name, designer ("Designer not set" if empty), mesh ("13 mesh").
- Status pill, colored for Stitching, Needs finishing and Finished.
- A progress bar and "X of Y threads in stash", where a thread counts when the stash quantity is at least the pattern quantity. "No threads listed" when the pattern has none.
- Tapping a card opens the pattern editor.

Empty state: "Your pattern library is empty" with an "Add pattern" button.

### Pattern editor

A sheet with a `Form`:

- Preview of the attached file. Images show inline. PDFs show in a `PDFView`, with a button to open the PDF full screen.
- Name (required) and designer. The designer field suggests existing designer names.
- Status and mesh pickers.
- Pattern file: attach a PDF or image up to 20 MB. Replacing the file deletes the old one.
- Cover photo: choose a photo, use page 1 of the PDF (shown only when the file is a PDF), or remove. When no cover is set and the file is an image, the card uses the file itself.
- Thread list. Each row has brand (with suggestions from the brand list below), number, color name or where it's used, and quantity (minimum 1), plus a delete button. Under each row, show "In stash (N)" in green, or "Need N more" (with "you have M" when M > 0) in orange. "Add thread" appends a row pre-filled with the previous row's brand and focuses the number field.
- Notes.
- Save, Cancel, and Delete (existing patterns only, with confirmation; deleting also removes the file and cover).

On save, drop thread rows where brand, code and name are all empty, trim fields, and clamp quantities to at least 1.

Built-in brand suggestions: DMC Pearl Cotton #3, DMC Pearl Cotton #5, DMC Floss, Silk & Ivory, Splendor, Vineyard Silk, Planet Earth Fiber, Rainbow Gallery Neon Rays, Rainbow Gallery Fyre Werks, Kreinik #12 Braid, Pepper Pot Silk, Appleton Wool, Paternayan, Watercolours, Silk Lamé Braid, Entice, Bravo!. Also suggest every brand already in the stash.

### WIP tab

Patterns with status Stitching or Needs finishing, in two sections, each sorted by name, with its own search:

- On the needle (Stitching). Each card lists "Still need" threads with the shortfall, and has a "Done stitching" button that sets the status to Needs finishing.
- Stitched, needs finishing. Each card shows the first 140 characters of the notes, and has "Mark finished" and "Back to stitching" buttons.

Status changes show a message ("'Name' marked finished, congrats!", "'Name' is stitched, on to finishing", "'Name' is on the needle").

Empty state: "Nothing on the needle", with a button that switches to the Ready to stitch tab.

### Ready to stitch tab

Candidates are patterns that are not Finished or Needs finishing. A toggle, on by default, includes Wishlist patterns. Search matches name and designer.

- Ready to stitch: every listed thread is covered by the stash. Cards have "Start stitching" (sets Stitching), or read "Already on the needle".
- Almost there: missing one or two threads. Cards list what's still needed. Sorted by number missing, then the standard order.
- A footnote counts patterns with no threads listed, which are left out, and suggests adding threads.

The tab badge counts patterns in the Ready section.

### Thread stash tab

- Search by brand, number or color name.
- Threads grouped by brand in `Section`s, sorted by brand, then by code with numeric-aware comparison (`localizedStandardCompare`).
- Each row has a color swatch, the code and name, and a stepper (minus and plus) for quantity, floored at 0. Debounce saves from rapid stepper taps by about 0.7 seconds.
- Tap a row to edit it. Swipe to delete, with confirmation.
- "Add thread" opens an editor with brand (with suggestions), color number, color name, swatch (`ColorPicker`), and quantity on hand.
- "Paste a list" opens a text editor. Each line is `brand, number, name, qty`, separated by commas or tabs. Name and qty are optional. If the third field is a number, treat it as qty. Quantity defaults to 1 when the line has no number. Lines matching an existing thread add to its quantity. Report "Added N threads".

Empty state: "No threads in your stash yet", with Add thread and Paste a list.

### Shopping list tab

Built from patterns that are not Finished or Needs finishing. A toggle, off by default, includes Wishlist patterns.

- Sum the quantity of each thread key across those patterns, subtract what the stash holds, and list keys where the need exceeds what's on hand.
- Group by brand, sorted by brand then code.
- Each row shows the swatch (from the stash if known), code, name, "Buy N, need X, have Y, for <pattern names>", and a "Bought it" button. "Bought it" adds the buy amount to the stash, creating the stash thread if needed.
- A "Copy list" button copies lines of the form `DMC 310 (Black), buy 2` to `UIPasteboard`. Also offer a `ShareLink` with the same text, so the list can go to Messages, Notes or Reminders.

Empty state: "Nothing to buy". Its subtitle says the stash covers every active pattern, or, with no patterns yet, explains that missing threads will show up here.

### Folders

- Rename folder: sets the designer on every pattern in the folder. Renaming to another folder's name merges the two. The folder's custom style moves to the new key unless the target already has one, in which case the old style is deleted.
- Edit folder image: choose or remove an image; choose fit, either "Show whole image (best for logos)" or "Fill the tile"; choose a background color from white, `#f6e4ec`, `#fbf3e2`, `#e3eef6`, `#7a1f4f`, `#221b26`, or a custom `ColorPicker` color. PNG, GIF, WebP and SVG images default to "Show whole image".

### Planned: read threads from pattern

Not in the first release. We'll pick the service that reads the pattern later. `index.html` has the web app's version for reference.

Requirements:

- A "Read threads from pattern" button in the pattern editor. It works on the file just picked in the editor or on the saved file.
- For a PDF, extract text from up to the first 40 pages with PDFKit, capped at 150,000 characters, with each page prefixed by `--- Page N ---`. Score each page by how many thread-related words it contains (`dmc`, `silk`, `thread`, `fib`, `floss`, `kreinik`, `braid`, `wool`, `pearl`, `perle`, `appleton`, `splendor`, `neon`, `ivory`, `planet`, `vineyard`, `color`/`colour`, `stitch guide`, `#` followed by a digit). Render the top-scoring pages as JPEG images: 3 pages if the PDF has more than 300 characters of real text, otherwise 6.
- For an image file, use the image itself.
- The result is a list of threads, each with brand, code, name and qty. Trim and truncate fields (brand 80, code 40, name 120 characters), round qty and clamp it to at least 1, skip entries with no brand and no code, and skip any whose key is already in the list.
- Append new rows to the editor's thread list and highlight them until the sheet closes, so the user can check them before saving. Report "Added N threads", "Every thread found is already listed", or "No threads found in this file".
- Show progress ("Opening the pattern", "Reading the PDF", "Looking at page N") and a Stop button that cancels the Swift `Task`. Closing the editor also cancels it.
- Show plain messages for failures, including a password-protected or broken PDF.
- When this ships, the Ready to stitch footnote should also suggest this button for patterns with no threads listed.

## Look and feel

The web app's design notes: warm and tidy, like a crafter's workroom, calm enough to use mid-project. A plum header band printed with a canvas-mesh pattern, blush for secondary surfaces, teal for primary actions.

Define these as named colors in `Assets.xcassets` with light and dark variants:

| Name          | Light     | Dark      |
| ------------- | --------- | --------- |
| Background    | `#fbfaf8` | `#17121a` |
| Ink           | `#221b26` | `#f1eaf0` |
| Mute          | `#6d6372` | `#b5a9b8` |
| Plum          | `#7a1f4f` | `#5a1739` |
| Blush         | `#f6e4ec` | `#2c1d27` |
| Card          | `#ffffff` | `#221a25` |
| Line          | `#e7dde3` | `#3a2e3b` |
| Teal (accent) | `#0c7480` | `#4cc3cf` |
| Warn          | `#b23a12` | `#ff9a73` |
| OK            | `#1f7a4c` | `#6fd3a0` |

Use Dynamic Type through `Font.custom(_:size:relativeTo:)`, keep tap targets at least 44 points, label icon-only buttons for VoiceOver, and respect Reduce Motion for the toast animation.

## Migrating data from the web app

The web app stored one JSON document per item with an `id` and a `kind` of `pattern`, `thread` or `folder`, plus uploaded files referenced by `assetId` and `coverId`. The importer should accept a JSON export of those documents (and the files, if the export includes them) through `.fileImporter`, map fields one to one using the status raw values above, and merge threads by key. Folder documents map to `FolderStyle` using their `key`, `coverId`, `fit` and `bg`.

How to get the export out of claude.ai is still open.

## Running tests

The project has two test targets:

- `NeedlepointTests` holds unit tests written with Swift Testing. They use an in-memory SwiftData store, so they never touch saved data.
- `NeedlepointUITests` holds UI tests written with XCTest. They launch the app with `-ui-testing`, which gives it an empty in-memory store. Each test relaunches the app, so this target is much slower than the unit tests.

In Xcode, ⌘U runs both targets. To run one test or one suite, click the diamond next to it in the editor or the Test navigator.

From the command line, run tests from the repository root. These commands leave out `-derivedDataPath`, so `xcodebuild` uses the same build cache as Xcode and doesn't rebuild everything from scratch.

Set the destination and turn off parallel testing once per shell:

```sh
DEST='platform=iOS Simulator,name=iPad Pro 11-inch (M5)'
NOCLONE='-parallel-testing-enabled NO'
```

With parallel testing on, `xcodebuild` creates and boots copies of the simulator ("Clone 1 of ..."), even for the unit tests alone. Each clone boots from cold before any test runs. Running tests is faster when the simulator is already booted, for example because you left it open after running the app from Xcode.

While working on a change, run only the unit tests:

```sh
xcodebuild test -scheme Needlepoint -destination "$DEST" $NOCLONE -only-testing:NeedlepointTests
```

To run one suite or one test, name it after the target:

```sh
xcodebuild test -scheme Needlepoint -destination "$DEST" $NOCLONE \
  -only-testing:NeedlepointTests/StashThreadTests
xcodebuild test -scheme Needlepoint -destination "$DEST" $NOCLONE \
  -only-testing:NeedlepointUITests/ShellUITests/testSeeWhatsReadySwitchesToTheReadyTab
```

To rerun tests several times without changing code, build once and then skip the build step:

```sh
xcodebuild build-for-testing -scheme Needlepoint -destination "$DEST"
xcodebuild test-without-building -scheme Needlepoint -destination "$DEST" $NOCLONE -only-testing:NeedlepointTests
```

Before committing, run both targets:

```sh
xcodebuild test -scheme Needlepoint -destination "$DEST" $NOCLONE
```

`xcodebuild` prints a lot of log noise. To see which tests failed and why, open the newest result bundle under `~/Library/Developer/Xcode/DerivedData/Needlepoint-*/Logs/Test/` in Xcode, or read it with `xcrun xcresulttool get test-results tests --path <bundle>`.

Add `-quiet` to print only warnings, errors and the result.

## Open decisions

1. Whether to keep visionOS in the supported destinations.
