# GCP Big Data

This document summarizes the contents of the GCP Big Data in the repository and provides quick links and concise descriptions of each item found in the folder.

## Overview

THere we have guides and hands-on lab materials for running and migrating Hadoop/Clouder workloads on Google Cloud Platform (GCP). It includes a top-level README, migration guidance, and lab exercises including Dataproc-focused labs and a mapping document describing Clouder-to-GCP mappings.

## Files (with links)

- [Cheatseet](./cheat-sheet.md) - Covers key Google Cloud Platform (GCP) services for big data processing, analytics, and storage.

- [General Lab](https://github.com/pyuriy/hadoop/blob/92e7b6818ba87af9010a4b63d27335283044386a/GCP/lab.md) - General lab exercises for deploying and working with Hadoop on GCP (hands-on tutorials and walkthroughs).

- [Dataproc Lab](https://github.com/pyuriy/hadoop/blob/92e7b6818ba87af9010a4b63d27335283044386a/GCP/dataproc-lab.md) -  Dataproc-specific lab content (examples and exercises showing how to use Google Cloud Dataproc with Hadoop workloads).

- [Migrate to GCP](https://github.com/pyuriy/hadoop/blob/92e7b6818ba87af9010a4b63d27335283044386a/GCP/migrate-to-GCP.md) - Guidance and checklist for migrating on-premises Hadoop/Clouder clusters and workloads to GCP.

- [Clouder GCP Services map](https://github.com/pyuriy/hadoop/blob/92e7b6818ba87af9010a4b63d27335283044386a/GCP/Clouder-GCP-map.md) - Mapping of Clouder/Hadoop components and concepts to equivalent GCP services and configurations.

- Dataproc [Health mangement](./manage-Dataproc.md) - Here is how you perform common "Ambari tasks" in the Dataproc world.

## Suggested quick reads

- Start with README.md for context and prerequisites.
- If you're evaluating lift-and-shift migration, open migrate-to-GCP.md.
- For hands-on practice, follow lab.md and dataproc-lab.md (Dataproc lab focuses on managed cluster usage).

## Observations & Recommendations

- The folder provides both conceptual (migration, mapping) and practical (labs) artifacts, which is useful for adoption and training.
- If not already present in the files, adding a short prerequisites section (GCP project setup, IAM roles, billing, SDK/CLI setup) at the top of README.md would help users get started faster.
- If the labs include scripts or commands, ensure those are copy/paste ready and have explicit region/zone and project placeholders clearly marked.
