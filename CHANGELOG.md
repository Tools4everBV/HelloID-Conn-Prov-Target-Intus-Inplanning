# Change Log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com), and this project adheres to [Semantic Versioning](https://semver.org).



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
