# EPIC005 Spec: Snapshots, Checkpoints, And Backups

## Purpose

Provide consistent reads and operational data-protection APIs on the maintained backend.

## Scope

Snapshot resources and all snapshot read/iterator APIs; checkpoints; backup creation, listing, purging, and restoration.

## Acceptance Criteria

- Snapshots preserve the captured view after later writes.
- Snapshot default and CF operations match legacy shapes.
- Checkpoint databases can be opened and read.
- Backup metadata, purge, latest/specific restore all work.

## Test Strategy

Use disposable source, checkpoint, backup, and restore paths and port existing protection tests.

## Quality Gate

Run protection tests and the full suite before commit.
