# NBS IPS QR Generator

An offline, browser-based generator for **NBS IPS QR** codes — the
instant-payment QR standard of the National Bank of Serbia (Narodna banka Srbije).

Drop in a PDF (or paste its text) and the app extracts the fields, normalizes them
to a spec-valid IPS string, and renders a scannable QR code that any Serbian
banking app can read (**IPS skeniraj**).

Everything runs **client-side** — no backend, no data ever leaves the browser.

---

## Document types

The app parses two different official documents, chosen with the tabs at the top:

| Tab | Document | Typical source |
|-----|----------|----------------|
| **Prekršajni nalog** | Speeding-fine notice (*prekršajni nalog*) | Ministry of the Interior |
| **Ekološka naknada** | Debt notice (*Obaveštenje o stanju duga*) for the environmental fee — *Naknada za zaštitu i unapređivanje životne sredine* | City tax administration (*Sekretarijat za javne prihode*) |

Each tab has its own parser, because the two documents have completely different
layouts. Switching tabs re-parses whatever text is already in the paste box.

---

## Interface languages

Serbian, Russian and English. The language is picked automatically on the first
visit from the browser's `navigator.languages`
(`sr`/`hr`/`bs` → Serbian, `ru`/`uk`/`be` → Russian, `en` → English, otherwise Serbian).
Choosing a language from the selector stores it in `localStorage`, and that
choice wins over auto-detection on every later visit.

Only the *interface* is translated. Parsing always works on the original Serbian
document text, and the QR payload is always ASCII Latin.

---

## Features

- **Static app.** No build step, no backend, no network calls.
- **Upload a PDF.** Drop a PDF onto the drop zone (or click to choose a file).
  The text is extracted **in the browser** with [pdf.js](https://mozilla.github.io/pdf.js/)
  and parsed automatically — nothing is uploaded anywhere.
- **Auto-parse from pasted text.** Paste a document; name, address, recipient,
  account, amount, purpose, model and reference are filled automatically
  (on paste or when focus leaves the paste box).
- **Half-amount detection.** If the notice offers a discount for early payment
  (*"PLATI POLOVINU"* — pay half), the amount is automatically halved.
- **Cyrillic → Latin.** The QR payload is always emitted as plain ASCII Latin.
  Serbian Cyrillic and diacritics are transliterated to the nearest Latin letters
  (`Ć→C`, `Ž→Z`, `Š→S`, `Đ→DJ`, `Џ→DZ`, `Љ→LJ`, …). This keeps the QR small and
  maximizes banking-app compatibility.
- **Account normalization.** `840-743324843-18` → `840000074332484318`
  (bank code + 13-digit zero-padded core + 2-digit control = 18 digits).
- **Purpose shortening.** Long fine descriptions are compressed to a compact form
  to reduce QR density (`UPLATA PO PREKRŠAJNOM NALOGU BROJ: 123456789012`
  → `UPLAT PREKRSAJ NALOG 123456789012`).
- **PDF de-spacing.** Fixes letter-spacing artifacts from copied PDFs
  (`BEOGR AD` → `BEOGRAD`, `PETROVIC A` → `PETROVICA`).
- **Optional payer.** The payer field (`P`) is written as three lines
  (name / street / city). It is optional by spec — banking apps fill the payer
  from the scanning account automatically.
- **No premature QR.** Nothing is rendered until there is real data.

---

## Usage

1. Serve the app (see [Self-hosting](#self-hosting)) — `./serve.sh`, then open
   <http://localhost:8777/>.
   Opening `index.html` directly via `file://` does **not** work: the pdf.js worker
   needs a real HTTP origin.
2. Pick the tab matching your document — **Prekršajni nalog** or **Ekološka naknada**.
3. Drop the PDF onto the drop zone, or paste the document text into the paste box —
   fields fill automatically. Or fill the fields manually.
4. The QR code appears below the form. Scan it with your banking app.

> ⚠️ **Always verify every field before paying.** Automatic parsing is a convenience,
> not a guarantee — check the account, amount, and reference against the original notice.

---

## The NBS IPS QR format

The payload is a single string of `TAG:VALUE` pairs separated by `|`.
The tags, in order:

| Tag  | Meaning                        | Notes                                                        |
|------|--------------------------------|--------------------------------------------------------------|
| `K`  | Identifier                     | Always `PR`                                                  |
| `V`  | Version                        | Always `01`                                                  |
| `C`  | Character set                  | `1` = UTF-8                                                  |
| `R`  | Recipient account              | 18 digits (see normalization)                                |
| `N`  | Recipient name                 | e.g. `BUDZET REPUBLIKE SRBIJE`                               |
| `I`  | Amount                         | `RSD` + amount with **comma** decimal, 2 places — `RSD5000,00` |
| `P`  | Payer (optional)               | Name / address / city, one per line (LF)                    |
| `SF` | Payment code (*šifra*)         | e.g. `253` for fines                                         |
| `S`  | Purpose (*svrha plaćanja*)     | Free text                                                    |
| `RO` | Reference                      | Model + *poziv na broj*, e.g. `97` + `12345…`               |

**There are no separate tags for address and city** — they live inside the single
`P` (or `N`) field, ideally on separate lines.

### Example payload

```
K:PR|V:01|C:1|R:840000074332484318|N:BUDZET REPUBLIKE SRBIJE|I:RSD5000,00|P:PETAR PETROVIC
KNEZA MILOSA 12
BEOGRAD|SF:253|S:UPLAT PREKRSAJ NALOG 123456789012|RO:97123456789012345
```

### Account normalization

A Serbian account written as `BBB-CCCCCCCCCC-KK` becomes an 18-digit string:

- first **3** digits — bank code
- last **2** digits — control number
- the middle — left-padded with zeros to **13** digits

`840-743324843-18` → `840` + `0000743324843` + `18` → `840000074332484318`

---

## Self-hosting

The app is fully static — deploying it is just copying these four files into a
web root. There is **no build step**.

Files:

- `index.html` — the app (vanilla HTML/CSS/JS)
- `qrcode.min.js` — the QR encoder ([qrcode-generator](https://github.com/kazuhikoarase/qrcode-generator))
- `pdf.min.js` + `pdf.worker.min.js` — [pdf.js](https://github.com/mozilla/pdf.js) for in-browser PDF text extraction

All four must sit in the same directory so the relative `<script src>` tags and
the PDF worker (`pdf.worker.min.js`) resolve.

### Local development

```bash
./serve.sh          # http://localhost:8777
./serve.sh 9000     # custom port
```

### Deploying

`deploy.sh` copies the four app files to one or more hosts over SSH, staging in
`/tmp` and installing with `sudo` (so the web root need not be writable by the
SSH user), then verifies the deployed `index.html` checksum on each host.

Hosts are **not** stored in this repository. Configure them either as environment
variables or in a local, untracked `deploy.env` next to the script:

```bash
# deploy.env  (gitignored)
NBSQR_HOSTS="user@host-a user@host-b"
NBSQR_REMOTE_DIR="/var/www/qrpay"
```

```bash
./deploy.sh              # every host in NBSQR_HOSTS
./deploy.sh user@host    # a specific host instead
```

When the site is served from several nodes behind one CDN/tunnel, deploy to all
of them in the same run — the checksum check at the end is what confirms every
node ended up with identical content.

---

## How parsing works

Extracted PDF text arrives as one long line per page (pdf.js joins text items
with spaces), so the regexes below anchor on explicit keywords rather than line
ends. All extracted text is de-spaced and transliterated to ASCII Latin on output.

### Prekršajni nalog (speeding fine)

Tolerant regexes handling both **Cyrillic and Latin** Serbian text:

- **Account** — `NNN-…-NN` pattern
- **Reference** — after *"poziv na broj"* / *"позив на број"*
- **Model** — after *"model"* / *"модел"* (2 digits)
- **Recipient** — after *"u korist:"* / *"у корист:"* up to the next comma
- **Purpose** — between *"svrha plaćanja:"* and *"na račun"*, then shortened
- **Payer name** — after *"licu"* / *"лицу"*; surname-first order is swapped to name-first
- **Payer address** — the *"u mestu: … vlasniku"* block, split into street + city;
  house-number leading zeros stripped (`044` → `44`)
- **Amount** — the number before *"dinara"*; **halved** if *"polovinu"* is present

### Ekološka naknada (environmental fee)

- **Account** — the `840-…-NN` public-revenue account from the table
- **Model + reference** — the *"Позив на број одобрења"* column, e.g. `97 85012345678901`
  → model `97`, reference `85012345678901`
- **Amount** — after *"у укупном износу од … динара"*.
  Note this document uses a **dot** as the decimal separator (`921.69`), unlike the
  fine notice which uses a comma
- **Payer name** — after *"Пореском обвезнику:"*, up to *"ЈМБГ"*
- **Payer address** — after *"Улица и број:"*, reordered from
  `city-municipality, municipality, street` to `street, city`
- **Recipient / purpose / payment code** — fixed values for this document type

There is no half-amount rule here: the total already includes accrued interest.

---

## Tech

- Vanilla HTML/CSS/JavaScript — no framework, no build.
- UI translations live in the `I18N` dictionary in `index.html`; markup carries
  `data-i18n` (text) and `data-i18n-ph` (placeholder) attributes. Adding a
  language means adding one dictionary entry and one `<option>`.
- QR encoding: [qrcode-generator](https://github.com/kazuhikoarase/qrcode-generator)
  (MIT), rendered as inline **SVG** (crisp at any size, no canvas quirks).
- PDF text extraction: [pdf.js](https://github.com/mozilla/pdf.js) (Apache-2.0),
  entirely client-side — the PDF never leaves the browser.
- UTF-8 byte encoding enabled in the QR encoder for correct multi-byte handling.

---

## Disclaimer

This is an **unofficial** utility, not affiliated with the National Bank of Serbia
or any bank. It generates a QR code from data **you** provide/verify. Always confirm
the recipient account, amount, and reference number against the original document
before making any payment.

---

## License

MIT — see [LICENSE](LICENSE).

Bundled `qrcode-generator` is © Kazuhiko Arase, MIT licensed.
