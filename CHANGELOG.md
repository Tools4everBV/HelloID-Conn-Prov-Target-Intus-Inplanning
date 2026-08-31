# Change Log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com), and this project adheres to [Semantic Versioning](https://semver.org).

## [4.0.0] - 28-08-2026
> [!WARNING]
> **Minimum version requirement** <br>
> Intus InPlanning: **2026.4** or higher

### Changed
GET `/api/users/:UserName` endpoint is now deprecated and replaced with POST `/api/users/retrieve` endpoint. With the body `{"username": "string"}` to retrieve the user.

> A forward slash or backslash (/ or \) in a path parameter is discouraged and will stop being supported in a future release: once the server moves to Tomcat 10 (planned for version 2026.5) an encoded slash (%2F) in a path segment will be rejected.

## [3.0.2] - 12-06-2026

### Changed
- Support '-' in permission names
- Made permission name and role name independent
- Minor fixes

### Fixed
- Issue #8

## [3.0.1] - 01-05-2026

### Added
- Added import scripts for users


## [3.0.0] - 14-04-2026
> Please note that this is a major update, and to switch to the New permissions the Reference is lost in HelloID.
### Added
- All in one script for granting and revoking permissions to Intus InPlanning.
- Used new default SubPermission script from Template.

### Changed
- Moved the permissions "Body" from the Permission.ps1 script to the subPermissions folder for better overview and maintenance. To avoid future permissions references loss after changes in the Permission body.
- Moved Get access token in Create script so it always runs.

### Deprecated

### Removed
- Separate Grant and revoke scripts

## [1.0.0] - 07-01-2026

This is the first changelog of this existing connector.

### Added

### Changed

Permissions scripts placed in subfolder for better overview.

### Deprecated

### Removed
