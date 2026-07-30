# NBS IPS QR Generator

A single-file, offline, browser-based generator for **NBS IPS QR** codes — the
instant-payment QR standard of the National Bank of Serbia (Narodna banka Srbije).

Paste the text of a payment order (e.g. a traffic-fine notice / *prekršajni nalog*),
and the app extracts the fields, normalizes them to a spec-valid IPS string, and
renders a scannable QR code that any Serbian banking app can read (**IPS skeniraj**).

Everything runs **client-side** — no backend, no data ever leaves the browser.

---

## Features

- **Static app.** Open `index.html` in any browser. No build step, no server, no network calls.
- **Upload a PDF.** Drop a PDF payment order onto the drop zone (or click to choose a file).
  The text is extracted **in the browser** with [pdf.js](https://mozilla.github.io/pdf.js/)
  and parsed automatically — nothing is uploaded anywhere.
- **Auto-parse from pasted text.** Paste a fine notice; name, address, recipient,
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

1. Open `index.html` (locally or from any static host).
2. Paste the payment-order text into **"Nalepi tekst naloga"** — fields fill automatically.
   Or fill the fields manually.
3. The QR code appears below the form. Scan it with your banking app.

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

The app is fully static. Serve the two files with any web server, or open the
file directly:

```bash
# any static server works, e.g.:
python3 -m http.server 8080
# then open http://localhost:8080/
```

Files:

- `index.html` — the app (vanilla HTML/CSS/JS)
- `qrcode.min.js` — the QR encoder ([qrcode-generator](https://github.com/kazuhikoarase/qrcode-generator))
- `pdf.min.js` + `pdf.worker.min.js` — [pdf.js](https://github.com/mozilla/pdf.js) for in-browser PDF text extraction

All files must be served from the same directory so the relative `<script src>`
and the PDF worker (`pdf.worker.min.js`) resolve.

---

## How parsing works

The paste box is scanned with a set of tolerant regular expressions that handle
both **Cyrillic and Latin** Serbian text:

- **Account** — `NNN-…-NN` pattern
- **Reference** — after *"poziv na broj"* / *"позив на број"*
- **Model** — after *"model"* / *"модел"* (2 digits)
- **Recipient** — after *"u korist:"* / *"у корист:"* up to the next comma
- **Purpose** — between *"svrha plaćanja:"* and *"na račun"*
- **Payer name** — after *"licu"* / *"лицу"*; surname-first order is swapped to name-first
- **Payer address** — the *"u mestu: … vlasniku"* block, split into street + city
- **Amount** — the number before *"dinara"*; halved if *"polovinu"* is present

All extracted text is de-spaced, transliterated to ASCII Latin on output, and
house-number leading zeros are stripped (`044` → `44`).

---

## Tech

- Vanilla HTML/CSS/JavaScript — no framework, no build.
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
