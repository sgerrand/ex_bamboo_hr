# Changelog

All notable changes to this project will be documented in this file. See [Keep a
CHANGELOG](http://keepachangelog.com/) for how to update this file. This project
adheres to [Semantic Versioning](http://semver.org/).

## [0.5.0](https://github.com/sgerrand/ex_bamboo_hr/compare/v0.4.0...v0.5.0) (2026-05-28)


### Added

* **metadata:** add /meta/* endpoints for field discovery ([807de09](https://github.com/sgerrand/ex_bamboo_hr/commit/807de09296dfb38c9e403c3dcbcd7ce3fb2bd777))


### Fixed

* **client:** correct doctest, widen response type, harden request opts ([9db49bc](https://github.com/sgerrand/ex_bamboo_hr/commit/9db49bc82e384761cff694518c429d5a71639e91))
* **deps:** bump jason from 1.4.4 to 1.4.5 ([#77](https://github.com/sgerrand/ex_bamboo_hr/issues/77)) ([590e939](https://github.com/sgerrand/ex_bamboo_hr/commit/590e9395ca6bc31f273984f6f3daad4138d29d56))


### Changed

* document git_hoox-based pre-commit setup ([58eb902](https://github.com/sgerrand/ex_bamboo_hr/commit/58eb9022d09d9b8365a79ad1a2152ca337fe465d))
* remove unused BambooHR.Application supervisor ([b0351c0](https://github.com/sgerrand/ex_bamboo_hr/commit/b0351c04e797cb8b5b2df48e3d260b6981208fa0))

## [0.4.0](https://github.com/sgerrand/ex_bamboo_hr/compare/bamboo_hr-v0.3.1...bamboo_hr-v0.4.0) (2026-04-13)


### Added

* Add configurable request timeout to Client ([#59](https://github.com/sgerrand/ex_bamboo_hr/issues/59)) ([07fd1bb](https://github.com/sgerrand/ex_bamboo_hr/commit/07fd1bbbe16f4de749aacbde496e4371bce3c521))


### Fixed

* Handle empty and non-JSON response bodies ([#57](https://github.com/sgerrand/ex_bamboo_hr/issues/57)) ([9befc41](https://github.com/sgerrand/ex_bamboo_hr/commit/9befc41f48e574df5970e1364c2bc99083562ae9))
* Remove $schema from release-please manifest ([#50](https://github.com/sgerrand/ex_bamboo_hr/issues/50)) ([3b3a6d1](https://github.com/sgerrand/ex_bamboo_hr/commit/3b3a6d135acd8679d1039c4b3e3358c223487f96))


### Changed

* Document configurable request timeout option ([#60](https://github.com/sgerrand/ex_bamboo_hr/issues/60)) ([f83dd1a](https://github.com/sgerrand/ex_bamboo_hr/commit/f83dd1a3dc456b6fbfb3191d690d7a715ab2865d))
* Separate HTTPClient behaviour from Req implementation ([#58](https://github.com/sgerrand/ex_bamboo_hr/issues/58)) ([9ffaf73](https://github.com/sgerrand/ex_bamboo_hr/commit/9ffaf733af0424cab25687779b32273f3e3d1379))

## 0.3.1 - 2025-04-25

### Changes

- Updated dependencies.

## 0.3.0 - 2025-03-10

### Changed

- Configurable HTTP client.

## 0.2.0 - 2025-03-04

### Changed

- Introduced new modules for Company, Employee and TimeTracking resources
- Improved the package documentation

## 0.1.0 - 2025-01-29

Initial release. :rocket:
