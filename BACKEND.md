# Reciclar API contract

The iOS app talks only to the Reciclar API. Developer notes are English. User-facing copy stays `pt-PT`.

Production base URL:

```text
https://ecopontos-api.rgllm.workers.dev
```

OpenAPI 3.1 is `GET /` (alias `GET /openapi.json`) on that host.

Do not treat `MockReciclarClient` or the fixtures as production coverage.

## Configuration

- `AppDependencies.live` uses the production base URL. Previews and `ReciclarCoreChecks` use the mock client.
- A debug build may set `ECOPONTOS_API_BASE` to another base URL. Release uses production.
- Prefer HTTPS. Map reads and community reports do not send an API key.
- Every request sends `X-Reciclar-Version` from `CFBundleShortVersionString` and `CFBundleVersion`, for example `1.1.0 (6)`. The client does not set `User-Agent`.
- GET requests use the URLSession protocol cache so `Cache-Control` and `ETag` / `304` can be reused. The map also skips a request while a tile or event viewport is younger than 15 minutes.
- The sorting guide stays on the device. Do not send catalogue queries to the API.

## Endpoints the app uses

| Method | Path | Purpose |
| --- | --- | --- |
| `GET` | `/v1/health` | Optional reachability probe |
| `GET` | `/v1/stats` | Coverage aggregates for Estatísticas |
| `GET` | `/v1/tiles/11/{x}/{y}` | Slippy-map tile for the visible zone. The only accepted zoom is `MapTilePolicy.zoom` (11). `Cache-Control: public, max-age=300, stale-while-revalidate=3600`, `ETag`, `304` on `If-None-Match`. No community events. `404` falls back to the bbox query. |
| `GET` | `/v1/community-events?bbox=` | Reports and resolutions inside the viewport. `max-age=60`. |
| `GET` | `/v1/locations?bbox=` | Viewport fallback when a tile returns `404`. Follow `cursor` until `has_more` is false. The page includes community events. |
| `GET` | `/v1/locations?ids=` | Up to 50 favourite ids. Body is `{ locations, missing }`. |
| `GET` | `/v1/locations/{id}` | Single location |
| `POST` | `/v1/locations/{id}/reports` | Community issue report |
| `POST` | `/v1/locations/{id}/reports/{category}/resolve` | Resolve one issue category |

The app does not call `GET /v1/sync`, full snapshot pages, or `updated_since` deltas.

### Area cache

1. The map loads the z=11 tiles covering the visible zone and follows each tile's cursor until the page is complete. Community reports come from `GET /v1/community-events?bbox=`.
2. A tile `404` marks tiles unavailable for the freshness window and falls back to `GET /v1/locations?bbox=` for that viewport. A bbox page must include `scope.kind = area` and the same bbox. Reject `is_complete_replacement`. That fallback already includes community events, so it does not also call `community-events`.
3. A covered tile and an event viewport younger than 15 minutes are reused. Manual refresh is Filtros → `Atualizar dados`.
4. If `is_fixture_data` is true, label the UI as non-production. Production responses set it to `false`.

Page size is server-controlled. Follow `next_cursor` / `has_more`.

### Refresh

- On launch: show the disk cache immediately, then refresh if the cache is empty or the last successful sync was at least 15 minutes ago.
- On return to the foreground: the same 15-minute rule.
- While active: refresh every 15 minutes, and expose manual refresh.
- Deduplicate concurrent refreshes. Retry with backoff.
- A failed refresh keeps the last good cache and surfaces a `pt-PT` error. Do not blank the map.
- A fetch does not make an old fill reading fresh. Fill age uses the reading timestamp.

### Coverage

`GET /v1/stats` includes `coverage_note`. Do not claim full Portugal coverage. Geography constants (`area_km2`, `road_km`) are Portugal-wide and exist for the density rows. Show the coverage note with them.

Fill-derived stats (`with_space_available`, usable readings) follow `fill_evaluated_at`. They are omitted when that field is absent. Community issue counts expire after one week.

## JSON → domain mapping

Wire format is snake_case JSON. Map it into `ReciclarCore` models. Omit absent optional fields.

### Location (`Ecoponto`)

| JSON | Swift |
| --- | --- |
| `id` | `id` (string) |
| `concessionaire_id` | `concessionaireID` |
| `latitude` / `longitude` | `coordinate` |
| `district` | `district` |
| `municipality` | `municipality` |
| `parish` | `parish` |
| `locality` | `locality` |
| `address` | `address` |
| `location_description` | `locationDescription` |
| `provenance.label` | `provenance.label` |
| `containers[]` | `containers` |
| `active_issues[]` | Prefer `CommunityIssuePolicy` from `community_events`. `active_issues` is already filtered server-side |
| `updated_at` | Catalog update time, not fill freshness |

Validate coordinates before accepting a row. Do not invent a replacement for an invalid point.

### Container

| JSON | Swift |
| --- | --- |
| `id` | `id` (string) |
| `waste_type_id` | `category.id` |
| `waste_name` | `category.name` |
| `color_token` | `colorToken` (presentation only) |
| `volume_litres` | `volumeLitres` |
| `type_description` | `typeDescription` |
| `code` | `code` |
| `fill.percent_full` | `fillReading.percentFull` |
| `fill.recorded_at` | `fillReading.recordedAt` |
| `fill.space_available` | Recompute on device with `FillReadingPolicy` |
| `last_collection_at` | `lastCollectionAt` (do not infer emptiness) |
| `last_washing_at` | `lastWashingAt` |

If `fill` is omitted, leave `fillReading` nil. Missing evidence is not empty or available.

### Community events

| JSON | Swift |
| --- | --- |
| `id` | `id` |
| `ecoponto_id` | `ecopontoID` |
| `issue` | `issue` |
| `kind` | `kind` (`report` or `resolution`) |
| `server_timestamp` | `serverTimestamp` |

Order and expiry use server timestamps. Local expiry is one week (`CommunityIssuePolicy.expiry`).

### Issue category wire values

| API / path (`issue`) | Swift `CommunityIssueKind` | UI (`pt-PT`) |
| --- | --- | --- |
| `litter_outside_containers` | `.rubbishOutsideContainers` | Lixo fora dos contentores |
| `vandalized` | `.vandalised` | Vandalizado |

Accepted aliases on write: `rubbishOutsideContainers`, `vandalised`. Prefer the canonical snake forms for new requests.

### Page envelope

| JSON | App handling |
| --- | --- |
| `as_of` / `sync_token` | Persist for the next refresh |
| `is_complete_replacement` | Reject on an area page |
| `is_fixture_data` | Non-production banner |
| `has_more` / `next_cursor` | Pagination |
| `locations` | Upserts |
| `removed_ids` | Delete from the cache. Favourites keep the id and show the data as unavailable |
| `community_events` | Merge by event `id`. A resolution wins over an older cached report of that category |
| `scope.kind` | Area pages must be `area` |

## Community reports

The proximity check stays on the device. The request does not include the fix.

- Radius 100 m from the ecoponto coordinate
- Fix age at most 60 s
- Horizontal accuracy greater than 0 and at most 50 m

Wait for HTTP `201` before claiming the report was shared.

`POST /v1/locations/{id}/reports`

`POST /v1/locations/{id}/reports/{category}/resolve`

The path carries the collection-point id. Resolve also carries the category. The JSON body is the collection point, the category, and the type. `kind` is `report` or `resolution`.

```json
{
  "ecoponto_id": "<collection point id>",
  "issue": "litter_outside_containers",
  "kind": "report"
}
```

There is no `installation_id`, no install-id header, and no `evidence` (`latitude`, `longitude`, `horizontal_accuracy_meters`, `recorded_at`). The user's GPS fix is not a query parameter. Map reads name the visible map region: `GET /v1/tiles/11/{x}/{y}`, with `GET /v1/locations?bbox=` only when a tile returns `404`, and `GET /v1/community-events?bbox=` for events in that region.

Launch deletes a legacy Keychain item (`service` `pt.ecopontos.app`, `account` `installation-id`) and the UserDefaults keys `installation-id`, `installationId`, and `installation_id`. The app does not create a replacement.

HTTP `429` on a report or resolution shows `Fizeste muitos reportes. Tenta mais tarde.` The server message is not shown for that status. Preserve the draft for retry. Other `429` responses still show the server `message`.

Persist a report only after `201` with the returned event. Offline, read cached reports. Do not queue report posts.

## Fill levels

Re-evaluate whenever the UI renders:

- Usable reading: `recorded_at` is not in the future and the age is at most 24 hours
- Space available: usable and `percent_full` strictly below 90 (exactly 90 does not qualify)
- No usable reading: no fill indicator and no "available" claim in filters
- Community issues never overwrite fill

## Favourites

- Store favourite ids separately from the location cache (`FavouritesStore`).
- Refreshing the API cache must not erase favourites.
- Resolve favourite details from the location snapshot when present.
- If an id is in `removed_ids` or missing after a refresh, keep the favourite and show the data as unavailable.

## Error mapping

| HTTP | `error` (typical) | App behaviour |
| --- | --- | --- |
| 400 | `invalid_sync_token`, `invalid_issue`, `invalid_json` | Show `message` when it is user-facing |
| 401 | `unauthorized` | Should not happen for these routes |
| 403 | `proximity` | Explain the proximity requirement in `pt-PT` and offer retry |
| 404 | `not_found` | Location unavailable |
| 410 | `gone` | Favourite or detail: removed from the catalog |
| 429 | `rate_limited` | Reports and resolutions show `Fizeste muitos reportes. Tenta mais tarde.` Other routes show the server `message`. Back off from 30 s up to 5 min, and at least `Retry-After`. Keep the draft and the last cache. |
| 503 | `area_unavailable` | Same backoff, honouring `Retry-After`. Retry that viewport. Do not replace it with a global snapshot. |
| 5xx / transport | — | Keep the cache. Retry with the same backoff |

Prefer the server `message` for user-visible failures. It is already `pt-PT`.

## Opaque location ids

The API identifies an ecoponto with an opaque string. The app stores and compares that string. It does not read an operator or a source id out of it.

A retired id is exactly three non-empty colon-separated parts. Public ids are not in that shape. Favourite refresh never sends a retired id to `GET /v1/locations?ids=`, because one retired id makes the API reject the whole batch. An unmatched retired favourite stays saved and keeps its cached detail. A favourite whose id is missing from the latest refresh stays saved and is shown as unavailable data.

When a refresh contains exactly one retired location and exactly one other location at the same coordinate (about a tenth of a metre), the app retargets the cache to the new id, moves community events with it, and keeps the pair until favourites adopt the new id. Ambiguous coordinates are left unchanged. The client cannot derive the new id by itself.
