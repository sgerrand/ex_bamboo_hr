# Changelog

All notable changes to this project will be documented in this file. See [Keep a
CHANGELOG](http://keepachangelog.com/) for how to update this file. This project
adheres to [Semantic Versioning](http://semver.org/).

## [0.5.0](https://github.com/sgerrand/ex_bamboo_hr/compare/v0.4.0...v0.5.0) (2026-07-18)


### Added

* **client:** add delete/3 for DELETE requests ([6ad253b](https://github.com/sgerrand/ex_bamboo_hr/commit/6ad253b869c91a469661b6b25239153220211f56))
* **client:** add put/3 for PUT requests ([16b510c](https://github.com/sgerrand/ex_bamboo_hr/commit/16b510c211e31d7c603d9176502384b2e43f324b))
* **client:** emit :telemetry span around every request ([db2d86c](https://github.com/sgerrand/ex_bamboo_hr/commit/db2d86c729a3bd4c2297c2a83a03d59908895352))
* **client:** validate company_domain and api_key in new/1 ([bfb4938](https://github.com/sgerrand/ex_bamboo_hr/commit/bfb4938d23ed1ef21a50ab30f5567615c0dc4990))
* **employee:** require non-empty fields list in get/3 ([fc201a4](https://github.com/sgerrand/ex_bamboo_hr/commit/fc201a4f35bdf45a46d660fee6a508fa221c17fb))
* **files:** add BambooHR.Files resource module ([4ac2ed5](https://github.com/sgerrand/ex_bamboo_hr/commit/4ac2ed51f583144f4d021e4f140ad5ce61116e11))
* **hiring:** add BambooHR.Hiring resource module ([5931b73](https://github.com/sgerrand/ex_bamboo_hr/commit/5931b73d3fa9d78e5ca0a3eb7f70cdd5c032f7df))
* **http_client.req:** retry 429 on all methods, transient errors on safe ones ([0b99c91](https://github.com/sgerrand/ex_bamboo_hr/commit/0b99c918ae3b98745ec7341304c4b9777988d780))
* **http_client:** add raw_response opt for binary responses ([455b4c0](https://github.com/sgerrand/ex_bamboo_hr/commit/455b4c056d88b50208089e3114d2c58293e560f7))
* **metadata:** add /meta/* endpoints for field discovery ([807de09](https://github.com/sgerrand/ex_bamboo_hr/commit/807de09296dfb38c9e403c3dcbcd7ce3fb2bd777))
* **metadata:** add time off types and policies endpoints ([ee57370](https://github.com/sgerrand/ex_bamboo_hr/commit/ee57370e6e53125dc458ecbf3e1cadcafa54ef9a))
* **reports:** add BambooHR.Reports resource module ([5b92cb2](https://github.com/sgerrand/ex_bamboo_hr/commit/5b92cb29dbd7341863fcdf5ec2328eb3c7d08c19))
* **tables:** add BambooHR.Tables resource module ([e053c41](https://github.com/sgerrand/ex_bamboo_hr/commit/e053c41e2211972c0ec3fa758d5036749fc73ad9))
* **time_off:** add BambooHR.TimeOff resource module ([1c76df3](https://github.com/sgerrand/ex_bamboo_hr/commit/1c76df3787fff24fd02f10e70a5b285c673ca03f))


### Fixed

* **client:** correct doctest, widen response type, harden request opts ([9db49bc](https://github.com/sgerrand/ex_bamboo_hr/commit/9db49bc82e384761cff694518c429d5a71639e91))
* **client:** normalize base_url and request path when building URLs ([489f604](https://github.com/sgerrand/ex_bamboo_hr/commit/489f604e022ad3a37fa3bc8e6f74d9dfa610b7f0))
* **client:** redact api_key from Inspect output ([91867b3](https://github.com/sgerrand/ex_bamboo_hr/commit/91867b3fd2535ecd5312d5fd78cab02ee2f3f9f6))
* **client:** send Accept: */* instead of application/json for raw_response ([23e4d11](https://github.com/sgerrand/ex_bamboo_hr/commit/23e4d118fac01dd5afb4fc82e7fda7979cdc32e3))
* **deps:** bump jason from 1.4.4 to 1.4.5 ([#77](https://github.com/sgerrand/ex_bamboo_hr/issues/77)) ([590e939](https://github.com/sgerrand/ex_bamboo_hr/commit/590e9395ca6bc31f273984f6f3daad4138d29d56))
* **deps:** bump req from 0.5.17 to 0.5.18 ([#80](https://github.com/sgerrand/ex_bamboo_hr/issues/80)) ([9301ad8](https://github.com/sgerrand/ex_bamboo_hr/commit/9301ad8ae50d26ada44bff67c3ce34651080c8ac))
* **deps:** bump req from 0.5.18 to 0.6.2 ([#87](https://github.com/sgerrand/ex_bamboo_hr/issues/87)) ([d3a00d1](https://github.com/sgerrand/ex_bamboo_hr/commit/d3a00d126201af42453530fd5572f06c956b39a7))
* **employee,files:** don't crash when http_client ignores expose_headers ([0b6ab31](https://github.com/sgerrand/ex_bamboo_hr/commit/0b6ab319e4d3dc2f5bc00f8777bb51de6dba6050))
* **employee:** surface Location header instead of a nonexistent response body ([42296da](https://github.com/sgerrand/ex_bamboo_hr/commit/42296daa2cd975c6afca56532540c35336edc786))
* **test:** stop telemetry test handler cross-contaminating concurrent tests ([c819cee](https://github.com/sgerrand/ex_bamboo_hr/commit/c819cee43478a15cca8b6b45a8f333d6994e1b9d))


### Changed

* document git_hoox-based pre-commit setup ([58eb902](https://github.com/sgerrand/ex_bamboo_hr/commit/58eb9022d09d9b8365a79ad1a2152ca337fe465d))
* note TimeOff module and OpenAPI spec verification tip ([bde37ea](https://github.com/sgerrand/ex_bamboo_hr/commit/bde37eafa7918aceec7eae2ca2bc4b0e2c30b471))
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
