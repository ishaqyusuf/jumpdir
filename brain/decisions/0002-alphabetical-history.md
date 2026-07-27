# ADR 0002: Alphabetical History Display

## Purpose
Record how command history is ordered for users.

## Decision
Display the selected recent history entries in case-insensitive alphabetical order.

## Context
History remains recency-based for deduplication, retention, filtering, and count limits, but alphabetical display makes the resulting list easier to scan.

## Consequences
- Plain history output and the interactive picker use the same alphabetical order.
- Replay and deletion continue to target the record paired with each displayed entry.
- The count option still selects recent matching entries before they are sorted for display.
