# LotCraft 1.0.0 Safety-Critical Ambiguity Record

The resolutions below were selected without adding controls or strategy behavior.

| Topic | Conflict or gap | Resolution |
|---|---|---|
| Instant Entry | Editable Entry conflicts with mandatory live executable-price synchronization | Instant Entry is market-bound. Raw text is preserved during focus; commit resynchronizes to current Ask/Bid. Persistent manual Entry is available in Pending mode. |
| Commission | “Per lot one side or round trip” does not prescribe how one-side risk is totaled | One-side value is charged twice for an open-to-stop round trip; round-trip value is charged once. |
| Volume cap | Clamp or reject policy is left open | Cap downward at broker maximum and remaining directional aggregate limit. Never round upward. Reject below minimum. |
| Move SLs eligibility | Existing “trades” can mean positions only or positions plus orders | Include every open position and active pending order on the current chart symbol whose SL can validly be placed at the exact red-line price, regardless of selected direction or whether the change tightens or widens risk. |
| Pending expiry | No expiry control is permitted | Prefer GTC, otherwise DAY; reject specified-date-only symbols. |
| Quote changes after confirmation | Exact confirmation values can become stale before send | Rebuild once after confirmation and reconfirm material changes; abort if material values change again. |
