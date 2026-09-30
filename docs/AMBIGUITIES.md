# LotCraft 1.2.1 Safety-Critical Ambiguity Record

The resolutions below were selected without adding controls or strategy behavior.

| Topic | Conflict or gap | Resolution |
|---|---|---|
| Instant Entry | Editable Entry conflicts with mandatory live executable-price synchronization | Instant Entry is market-bound. Raw text is preserved during focus; commit resynchronizes to current Ask/Bid. Persistent manual Entry is available in Pending mode. |
| Commission | “Per lot one side or round trip” does not prescribe how one-side risk is totaled | One-side value is charged twice for an open-to-stop round trip; round-trip value is charged once. |
| Volume cap | Later owner request permits minimum-volume sizing above target risk | Cap at broker maximum and remaining directional aggregate limit. Use minimum volume for a positive below-minimum request only when capacity permits; display actual SL loss separately. |
| Move SLs eligibility | Existing “trades” can mean positions only or positions plus orders | Include every open position and active pending order on the current chart symbol whose SL can validly be placed at the exact red-line price, regardless of selected direction or whether the change tightens or widens risk. |
| Pending expiry | No expiry control is permitted | Prefer GTC, otherwise DAY; reject specified-date-only symbols. |
| Quote changes after confirmation | Later owner request removes repeated new-order confirmation | Rebuild and validate once after the single risk-only confirmation. Abort if invalid; do not open another new-order confirmation. SL-batch target-set confirmation is a separate safety path. |
| Exposure percent basis | New-trade basis can be Equity, Balance or Manual | Chart/account exposure always uses current equity. Target risk uses the selected sizing basis. |
| Closed market | Planning can be useful without permission to trade | Retain planning from usable cached data, but disable submission until all execution gates pass. |
| Update timing | Daily throttle alone does not schedule checks | Owner-approved 1.2.1 launches after ten seconds and then hourly while attached. The updater throttles network attempts for 24 hours, including failures. Old 1.2.0 copies still need reattachment/restart; no universal notification deadline is promised. |
