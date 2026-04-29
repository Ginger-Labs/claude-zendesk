# Useful Zendesk searches

The Zendesk Search API uses [this query syntax](https://support.zendesk.com/hc/en-us/articles/4408886879258).
Hard limits to remember: **~100 search requests/min**, **1000 results max per query**, **10 pages of 100**.
For anything larger, use the **incremental tickets export** endpoint instead (`/api/v2/incremental/tickets`).

## Triage

```
type:ticket status<solved priority:urgent
type:ticket status:new created>24hours
type:ticket tags:bug status<solved
```

## Web-app specific

Adjust tag names once we know what the support team actually uses. Audit with:
`./zd get tags.json | jq '.tags | sort_by(-.count) | .[0:50]'`

```
type:ticket tags:web status<solved created>14days
type:ticket subject:"tab" OR description:"tab" created>30days
type:ticket tags:sync OR tags:icloud created>14days
type:ticket tags:crash OR tags:freeze created>14days
```

## Trend / volume

```
type:ticket created>7days                 # weekly intake
type:ticket created>7days status:solved   # weekly outflow
type:ticket created>30days tags:regression
```

## Spotting fires

A "fire" is a sudden cluster around the same surface. Search for the surface
keyword over the last 48–72h and compare to the trailing 4-week baseline:

```
type:ticket created>72hours subject:"<keyword>"
type:ticket created>4weeks  subject:"<keyword>" created<72hours   # baseline
```

## Per-user history

```
type:ticket requester:user@example.com
```

## After a release

```
type:ticket created>2026-04-07            # web launch was 2026-04-07
type:ticket tags:web created>2026-04-07 status<solved
```
