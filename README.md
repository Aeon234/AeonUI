# AeonUI

Unit frames for World of Warcraft Retail and WoW: Forever, built on an embedded oUF, with settings on the Aeon suite's settings library. In development; not yet released.

## Development

- Libraries: copy LibStub, CallbackHandler-1.0 and LibSharedMedia-3.0 into `AeonUI/Libs/`, and fetch oUF at the tag pinned in `.pkgmeta` with `python Tools/ouf.py`. AeonSettings is committed in `Libs/AeonSettings`; refresh it from the AeonSettings repository with `python Tools/sync.py ../AeonUI`.
- Checks: `lua Tools/check.lua` (Lua 5.1), `python Tools/ouf.py --check`, `python Tools/sync-locales.py --check`.
