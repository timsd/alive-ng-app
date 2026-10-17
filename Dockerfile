# syntax=docker/dockerfile:1
# Coolify deployment: pulls the pre-built Flutter web image produced by GitHub Actions.
# Compiling Flutter web is handled off the VPS in GitHub Actions to avoid 100% CPU lockups.
FROM ghcr.io/timsd/alive-ng-app:latest
