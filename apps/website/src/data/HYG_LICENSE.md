# HYG4.1 bright-star subset

Data by David Nash / Astronexus, derived from the HYG Stellar Database.
Source snapshot: https://github.com/astronexus/HYG-Database/tree/c7f7f883fe678cc7680169a50ccd7dcc49b060ce

The data file `hyg-v41-bright.json`, including this filtered adaptation, is
licensed under Creative Commons Attribution-ShareAlike4.0 International:
https://creativecommons.org/licenses/by-sa/4.0/

Changes: select stars of apparent magnitude<=6 with positive, non-dubious
distance and finite Cartesian coordinates; remove unused columns; serialize
as JSON. Original coordinates, magnitude, color index, identifiers and names
are retained. Source digest, filter and column order are embedded in the JSON.
Rebuild using `node scripts/import-hyg.mjs /path/to/hygdata_v41.csv`.

Coordinates are in parsecs, equatorial epoch/equinox2000.0 (J2000). Catalog
distances are estimates, not live observations. The screen uses a perspective
projection with a styled brightness/color scale; the game board has no physical
astronomical location or distance scale. No telescope image is claimed.
