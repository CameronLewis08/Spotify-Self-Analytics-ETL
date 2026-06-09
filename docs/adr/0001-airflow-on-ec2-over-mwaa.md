# ADR 0001 — Self-hosted Airflow on EC2 over MWAA

**Status:** Accepted  
**Date:** 2026-06-08

## Context

The pipeline requires a managed Airflow scheduler. AWS offers MWAA (Managed Workflows for Apache Airflow) as a native managed service. The alternative is running Airflow in Docker on a self-managed EC2 instance.

## Decision

Use self-hosted Airflow on a `t3.medium` EC2 instance running Docker Compose.

## Reasons

- MWAA has a minimum cost of ~$300/month. This is a personal portfolio project with no budget.
- A `t3.medium` EC2 instance costs ~$30/month and is sufficient for a single-user daily batch pipeline.
- The AWS skills demonstrated (EC2, IAM, Security Groups, VPC, Systems Manager) are equally relevant to interviewers as MWAA-specific knowledge.
- Self-hosting Airflow is the norm at small and mid-size companies that haven't moved to MWAA or Astronomer.

## Trade-offs

MWAA provides automatic scaling, managed upgrades, and native AWS integrations (e.g. IAM role-based task execution). Those features are not needed at this scale. If this pipeline were production at a company with budget, MWAA would be the correct choice — noted in the README.
