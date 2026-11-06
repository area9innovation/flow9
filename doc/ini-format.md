# Flow INI names and values

`formats/ini` reads and writes `IniFile` values. The reader is permissive; it is
not a validator for other INI dialects.

## Legacy documents

Without the marker described below, existing parsing rules are unchanged:

- Section names are taken as written between `[` and the first `]`, including
  quotes, spaces, tabs, and case.
- Keys are trimmed of spaces, tabs, CR, and LF at their edges. Quotes are literal
  characters in keys. `=`, `[`, and `;` participate in parsing rather than being
  part of a key.
- A double quote before the end of a value's line begins a quoted value.
  Quoted values may span lines, and `""` within them means one literal `"`.
  Unquoted values are trimmed according to the existing reader rules.
- Backslashes are literal everywhere. `\n` is two characters, not a line break.

For example, `["Section"]` and `"Key"=value` name a section and key that **include**
the double quotes. Treating those quotes as delimiters by default would change
the meaning of existing documents.

## Quoted-name extension

An exact first line of `; flow9-ini: quoted-names-v1`, followed by LF or CRLF,
enables quoted names. A byte order mark before it is allowed. This first line is
reserved for the extension; a legacy document that used this exact comment must
change or remove it to retain legacy quote interpretation. Similar comments,
comments later in a document, and other version numbers do not enable the
extension.

```ini
; flow9-ini: quoted-names-v1
["section]name"]
"key=with;delimiters["="value"
"""literal quotes"""=plain value
" padded key "=" padded value "
```

In marked documents:

- A name starting with `"` is quoted. For a section, spaces and tabs may come
  between `[` and the opening quote; for a key, leading spaces, tabs, CR, and LF
  may precede it.
- The closing quote must be followed by `]` for sections or `=` for keys, with
  only spaces or tabs between, as in `"key" = value`. Embedded quotes are
  doubled. Empty names, literal line breaks, and delimiters are allowed inside
  quoted names. Backslashes remain literal.
- Names not starting with a quote use the legacy rules. Values are unchanged.
- A quoted name whose closing quote is not followed by its delimiter is skipped
  with the rest of its line, and parsing goes on with the next line. Such a
  section header is dropped together with its keys; such a key is dropped.
- A quoted name whose closing quote never comes, or that reaches the end of the
  input before its delimiter, stops parsing rather than reading its contents
  again as keys or sections. Such a section is retained with its collected name
  and no keys; such a key is not retained.
- `parseIniFile` does not report syntax errors.

## Serializer policy and interoperability

`iniFile2string` keeps the legacy spelling when names need no extension. In
particular, quotes and backslashes alone do not change legacy name output.
It switches to the marked representation if a key contains `=`, `[`, or `;`,
has spaces, tabs, CR, or LF at either edge, or if either kind of name contains
CR or LF, or a section name contains `]`.

Once the extension is needed, **all** section names and keys are quoted. This
also preserves names that themselves include leading or surrounding quotes.
Values are quoted only as needed, using the same doubled-quote convention.
Section and key order, duplicate names, case, and name contents are preserved.
Parsing then serializing may remove the marker when none of the names require
it; this does not change the parsed `IniFile`.

The marker and quoted names are a Flow extension, not a universal INI syntax.
Older Flow readers and third-party readers need support for this extension to
read marked files with the same meaning. Legacy-compatible names continue to
produce the previous unmarked representation.
