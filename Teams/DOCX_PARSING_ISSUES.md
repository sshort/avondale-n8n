# Team `.docx` Parsing Issues

This note records the formatting inconsistencies encountered while generating the contact lists from the team `.docx` files in this directory.

## Summary

The source `.docx` files are structurally similar enough to parse, but not consistent enough to trust cell text at face value. The parser had to normalize names and split/join cell content in a few special cases.

## Problems Encountered

### 1. Captains are marked inconsistently

Observed captain markers include:

- `(C)`
- `( C)`
- trailing `C`
- `©`
- `Capt`

Examples:

- `David Pharo (C)`
- `Tim Read ( C)`
- `Kate Liggett C`
- `Jane Dow ©`
- `Sue White Capt`

### 2. Some names are split across multiple Word runs

When extracted naively, some names contain internal spaces that are not real.

Examples:

- `Kat e Liggett`
- `Alison Jam eson`
- `Beck y Cockerill`
- `Kat herine Rogers`

This was fixed by concatenating the text runs within each paragraph before normalizing whitespace.

### 3. Some names are split across multiple paragraphs in the same cell

In a few cells, one player name is broken over multiple paragraphs.

Example:

- `Antonias`
- `Nicolaidis`

This had to be re-joined into:

- `Antonias Nicolaidis`

### 4. Some cells contain more than one player

A few cells contain two players in the same cell rather than one player per cell. In those cases the names are separated by a full stop and a space.

Examples seen during parsing:

- `Chris Ezra. Richard Vallis`
- `Edward Woods. Paul Hampshire`
- `Jon Clackett. James Cholerton`
- `Matt Napper. Graham Friel`

These had to be split into separate player rows.

### 5. Inconsistent punctuation and hyphenation

Names appear with different punctuation or spacing between files.

Examples:

- `Carol- Anne Harrison`
- `Carol Ann Harrison`
- `CAROLE -ANN HARRISON`
- `Mc Crossan` vs `McCrossan`
- `Mc Elligot` vs `McElligot`

The exact-name matcher therefore normalizes punctuation and spacing before comparison, while still treating genuinely different spellings as different names.

### 6. Inconsistent capitalisation

Some files use normal mixed case, others use uppercase.

Examples:

- `Jane Dow`
- `JANE DOW`

This was handled by case-insensitive matching.

### 7. Placeholder or non-player text appears in roster cells

At least one roster cell contained non-player text:

- `HALF`

These values need to be ignored rather than treated as member names.

### 8. Header formatting is inconsistent

Squad/team headers are not uniform across files.

Examples:

- `A SQUAD`
- `A TEAM`
- `Reserves`
- `RESERVES`
- first header cell blank in most files
- first header cell `]` in the vets file

The parser ignores the first column and treats the remaining header cells as the actual squads/teams.

## Practical Impact

Because of the issues above:

- exact-name matching must normalize spacing, punctuation, hyphens, and case
- paragraph boundaries cannot always be treated as row boundaries
- full stops inside a cell can mean multiple players
- captain detection must handle several marker styles

## Remaining Non-Parsing Issues

Some `No Match` rows in the generated outputs are real data mismatches rather than parsing problems. Typical examples include:

- people not found in current club records
- spelling differences that are more than punctuation/spacing
- ambiguous duplicate-name cases

Those are intentionally left as `No Match` in the contact sheets.
