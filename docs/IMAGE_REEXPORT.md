# Portraits to re-export

Generated 2026-10-27 from the files in `ios/GoalDigger/Resources/Assets.xcassets/Portraits`.

Bundled portraits are drawn at up to 280 pt (the "ones to know" carousel). Most
are ~195 px tall, and at that size they look fine (Anton, 2026-10-26). So the app
now caps every portrait at **1.45 pt per pixel** — the median upscale
(`PlayerPortrait.maxPointsPerPixel`, `Views/Team/TeamPageCard.swift`). A smaller
file is drawn proportionally smaller rather than blurrier.

These 110 portraits are below 193 px tall, so the cap shrinks them on the
carousel. Re-export them first, at **900 px tall** (280 pt × 3, with headroom);
the cap then stops applying on its own and they draw full size. A re-export of
all ~430 at 900 px would make every portrait sharp at @3x.

| Asset | Now (w×h px) | Drawn on carousel at |
|---|---|---|
| `bw-sunderland-bris` | 255×167 | 242 pt (of 280) |
| `bw-newcastle-jaissle` | 245×169 | 245 pt (of 280) |
| `bw-nottm_forest-glasner` | 244×169 | 245 pt (of 280) |
| `bw-spurs-zerbi` | 252×170 | 246 pt (of 280) |
| `bw-man_utd-carrick` | 243×171 | 248 pt (of 280) |
| `bw-ipswich-neil` | 238×172 | 249 pt (of 280) |
| `bw-spurs-bergvall` | 248×172 | 249 pt (of 280) |
| `bw-spurs-gray` | 244×172 | 249 pt (of 280) |
| `bw-spurs-kudus` | 257×172 | 249 pt (of 280) |
| `bw-spurs-maddison` | 243×172 | 249 pt (of 280) |
| `bw-spurs-udogie` | 268×172 | 249 pt (of 280) |
| `bw-hull-jakirovic` | 253×173 | 251 pt (of 280) |
| `bw-liverpool-iraola` | 244×173 | 251 pt (of 280) |
| `bw-leeds-farke` | 261×174 | 252 pt (of 280) |
| `bw-man_city-maresca` | 255×174 | 252 pt (of 280) |
| `bw-chelsea-alonso` | 246×177 | 257 pt (of 280) |
| `bw-coventry-lampard` | 247×177 | 257 pt (of 280) |
| `bw-crystal_palace-sage` | 263×177 | 257 pt (of 280) |
| `bw-everton-moyes` | 256×178 | 258 pt (of 280) |
| `bw-sunderland-isidor` | 281×178 | 258 pt (of 280) |
| `bw-fulham-arbeloa` | 250×179 | 260 pt (of 280) |
| `bw-man_city-reilly` | 256×179 | 260 pt (of 280) |
| `bw-sunderland-ahoka` | 269×179 | 260 pt (of 280) |
| `bw-sunderland-fofana` | 258×179 | 260 pt (of 280) |
| `bw-sunderland-rigg` | 251×179 | 260 pt (of 280) |
| `bw-sunderland-talbi` | 257×179 | 260 pt (of 280) |
| `bw-man_city-allan` | 270×180 | 261 pt (of 280) |
| `bw-man_city-bouaddi` | 269×180 | 261 pt (of 280) |
| `bw-man_city-khusanov` | 275×180 | 261 pt (of 280) |
| `bw-man_city-lewis` | 255×180 | 261 pt (of 280) |
| `bw-nottm_forest-netz` | 262×181 | 262 pt (of 280) |
| `bw-nottm_forest-aina` | 270×182 | 264 pt (of 280) |
| `bw-nottm_forest-dominguez` | 266×182 | 264 pt (of 280) |
| `bw-nottm_forest-hudson-odoi` | 270×182 | 264 pt (of 280) |
| `bw-nottm_forest-yates` | 212×182 | 264 pt (of 280) |
| `bw-man_utd-yoro` | 268×184 | 267 pt (of 280) |
| `bw-man_utd-zirkzee` | 271×184 | 267 pt (of 280) |
| `bw-man_utd-cunha` | 277×185 | 268 pt (of 280) |
| `bw-man_utd-mount` | 271×185 | 268 pt (of 280) |
| `bw-man_utd-santos` | 276×185 | 268 pt (of 280) |
| `bw-man_utd-sesko` | 279×185 | 268 pt (of 280) |
| `bw-sunderland-brobbey` | 271×185 | 268 pt (of 280) |
| `bw-spurs-adarabioyo` | 264×186 | 270 pt (of 280) |
| `bw-spurs-dubravka` | 258×186 | 270 pt (of 280) |
| `bw-spurs-gallagher` | 259×186 | 270 pt (of 280) |
| `bw-spurs-senesi` | 255×186 | 270 pt (of 280) |
| `bw-spurs-ven` | 268×186 | 270 pt (of 280) |
| `bw-leeds-elvedi` | 278×187 | 271 pt (of 280) |
| `bw-man_utd-darlow` | 270×187 | 271 pt (of 280) |
| `bw-nottm_forest-delap` | 277×187 | 271 pt (of 280) |
| `bw-nottm_forest-jesus` | 271×187 | 271 pt (of 280) |
| `bw-nottm_forest-john` | 277×187 | 271 pt (of 280) |
| `bw-nottm_forest-sangare` | 269×187 | 271 pt (of 280) |
| `bw-nottm_forest-wood` | 250×187 | 271 pt (of 280) |
| `bw-sunderland-alderete` | 267×187 | 271 pt (of 280) |
| `bw-sunderland-ellborg` | 270×187 | 271 pt (of 280) |
| `bw-sunderland-hume` | 262×187 | 271 pt (of 280) |
| `bw-sunderland-nien` | 272×187 | 271 pt (of 280) |
| `bw-leeds-james` | 282×188 | 273 pt (of 280) |
| `bw-leeds-zetterer` | 279×188 | 273 pt (of 280) |
| `bw-man_utd-dorgu` | 273×188 | 273 pt (of 280) |
| `bw-man_utd-heaven` | 276×188 | 273 pt (of 280) |
| `bw-man_utd-mazraoui` | 266×188 | 273 pt (of 280) |
| `bw-aston_villa-emery` | 241×189 | 274 pt (of 280) |
| `bw-leeds-wilson` | 274×189 | 274 pt (of 280) |
| `bw-bournemouth-rose` | 258×190 | 276 pt (of 280) |
| `bw-brentford-andrews` | 264×190 | 276 pt (of 280) |
| `bw-brighton-hurzeler` | 253×190 | 276 pt (of 280) |
| `bw-fulham-garcia` | 264×190 | 276 pt (of 280) |
| `bw-fulham-lecomte` | 273×190 | 276 pt (of 280) |
| `bw-leeds-longstaff` | 279×190 | 276 pt (of 280) |
| `bw-man_city-ait-nouri` | 273×191 | 277 pt (of 280) |
| `bw-man_city-doku` | 275×191 | 277 pt (of 280) |
| `bw-man_city-haaland` | 270×191 | 277 pt (of 280) |
| `bw-man_city-kovacic` | 279×191 | 277 pt (of 280) |
| `bw-man_city-rulli` | 277×191 | 277 pt (of 280) |
| `bw-newcastle-mills` | 266×191 | 277 pt (of 280) |
| `bw-newcastle-pivas` | 274×191 | 277 pt (of 280) |
| `bw-everton-graham` | 282×192 | 278 pt (of 280) |
| `bw-fulham-andersen` | 277×192 | 278 pt (of 280) |
| `bw-fulham-larsson` | 275×192 | 278 pt (of 280) |
| `bw-hull-cho` | 276×192 | 278 pt (of 280) |
| `bw-hull-gelhardt` | 269×192 | 278 pt (of 280) |
| `bw-hull-giles` | 268×192 | 278 pt (of 280) |
| `bw-hull-gourna-douath` | 268×192 | 278 pt (of 280) |
| `bw-hull-hjerto-dahl` | 283×192 | 278 pt (of 280) |
| `bw-hull-iroegbunam` | 276×192 | 278 pt (of 280) |
| `bw-hull-mcburnie` | 267×192 | 278 pt (of 280) |
| `bw-hull-mcnair` | 273×192 | 278 pt (of 280) |
| `bw-hull-phillips` | 265×192 | 278 pt (of 280) |
| `bw-hull-vaz` | 284×192 | 278 pt (of 280) |
| `bw-newcastle-m-miley` | 279×192 | 278 pt (of 280) |
| `bw-newcastle-salia` | 272×192 | 278 pt (of 280) |
| `bw-newcastle-thompson` | 274×192 | 278 pt (of 280) |
| `bw-brighton-ayari` | 250×193 | 280 pt (of 280) |
| `bw-brighton-baixauli` | 262×193 | 280 pt (of 280) |
| `bw-brighton-gomez` | 252×193 | 280 pt (of 280) |
| `bw-brighton-kadioglu` | 257×193 | 280 pt (of 280) |
| `bw-chelsea-bynoe-gittens` | 265×193 | 280 pt (of 280) |
| `bw-chelsea-lavia` | 260×193 | 280 pt (of 280) |
| `bw-crystal_palace-kamada` | 273×193 | 280 pt (of 280) |
| `bw-crystal_palace-mitchell` | 274×193 | 280 pt (of 280) |
| `bw-crystal_palace-pino` | 254×193 | 280 pt (of 280) |
| `bw-crystal_palace-timber` | 275×193 | 280 pt (of 280) |
| `bw-crystal_palace-wharton` | 269×193 | 280 pt (of 280) |
| `bw-everton-travers` | 263×193 | 280 pt (of 280) |
| `bw-ipswich-akpom` | 279×193 | 280 pt (of 280) |
| `bw-ipswich-fatawu` | 267×193 | 280 pt (of 280) |
| `bw-ipswich-lukic` | 262×193 | 280 pt (of 280) |
| `bw-ipswich-maeda` | 283×193 | 280 pt (of 280) |
