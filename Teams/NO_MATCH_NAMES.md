# Team Match Review

This file records the current non-trivial name matching used by [generate_team_contact_lists.py](./generate_team_contact_lists.py).

## Remaining No Match Names

- `Charlene Jacobs` - no unique candidate. Teams: Ladies, Mixed
- `Jane Dow` - no unique candidate. Teams: Ladies, Mixed, Vets
- `Jane Woods` - no unique candidate. Teams: Ladies

## Explicit Full-Name Overrides

- `Carol Ann Harrison` -> `Carol-Anne Harrison` - explicit full-name override from `name_overrides.csv`. Teams: Mixed
- `CAROLE -ANN HARRISON` -> `Carol-Anne Harrison` - explicit full-name override from `name_overrides.csv`. Teams: Vets
- `Jax S B` -> `Jacqueline Sinclair-Brown` - explicit full-name override from `name_overrides.csv`. Teams: Ladies, Mixed
- `JAX S BROWN` -> `Jacqueline Sinclair-Brown` - explicit full-name override from `name_overrides.csv`. Teams: Vets
- `Tom Van Klavern` -> `Thomas Van Klaveren` - explicit full-name override from `name_overrides.csv`. Teams: Mixed

## Short-Name / Nickname Matches

- `Alec Mach` -> `Aleksander Mach` - short-name override. Teams: Mens
- `Andy Roxburgh` -> `Andrew Roxburgh` - short-name override. Teams: Mens, Mixed
- `Becky Cockerill` -> `Rebecca Cockerill` - nickname override. Teams: Ladies
- `Jacquie Conway` -> `Jacqueline Conway` - nickname override. Teams: Ladies, Vets
- `Mo Clackett` -> `Maureen Clackett` - nickname override. Teams: Ladies, Mixed, Vets
- `Pete Smith` -> `Peter Smith` - short-name override. Teams: Vets
- `Sam Rush` -> `Samantha Rush` - short-name override. Teams: Ladies, Mixed
- `Sue White` -> `Susan White` - short-name override. Teams: Ladies, Mixed, Vets
- `Tom Van Klaveren` -> `Thomas Van Klaveren` - short-name override. Teams: Mens

## Fuzzy Matches

- `Alek Katon` -> `Alex Katon` - fuzzy first-name typo. Teams: Mens
- `Alessandro Barcello` -> `Alessandro Barcella` - fuzzy surname typo. Teams: Mens
- `Alison Jamieson` -> `Alison Jameson` - fuzzy surname typo. Teams: Mixed
- `Andy Mc Elligot` -> `Andy McElligott` - fuzzy spacing and spelling typo. Teams: Mens
- `Andy McElligot` -> `Andy McElligott` - fuzzy spelling typo. Teams: Mixed
- `Antonias Nicolaidis` -> `Antonios Nicolaidis` - fuzzy first-name typo. Teams: Mens
- `Antonis Nicolaidis` -> `Antonios Nicolaidis` - fuzzy first-name typo. Teams: Mixed
- `Graeme Hutcheson` -> `Graeme Hutchison` - fuzzy surname typo. Teams: Mixed
- `Helen Eyres` -> `Helen Eyers` - fuzzy surname typo. Teams: Ladies
- `Jill Penton` -> `Jillian Penton` - fuzzy first-name expansion. Teams: Ladies, Mixed, Vets
- `Lindsey Evans` -> `Lindsay Evans` - fuzzy first-name typo. Teams: Ladies
- `Liz Gruernstern` -> `Liz Gruenstern` - fuzzy surname typo. Teams: Mixed
- `Lynne McKenzie` -> `Lynn Mckenzie` - fuzzy first-name spelling variant. Teams: Mixed
- `Maew Tatum` -> `Maew Tatam` - fuzzy surname typo. Teams: Mixed
- `Paul Tippens` -> `Paul Tippins` - fuzzy surname typo. Teams: Mens, Mixed
- `Santu Asp` -> `Santtu Asp` - fuzzy first-name typo. Teams: Mens, Mixed
- `Trish Harris` -> `Trish Harriss` - fuzzy surname typo. Teams: Ladies, Vets
