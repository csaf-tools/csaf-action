<!--
SPDX-FileCopyrightText: 2025 German Federal Office for Information Security (BSI) <https://www.bsi.bund.de>

SPDX-License-Identifier: Apache-2.0
-->

# Release documentation

This document contains some notes for the maintainers of the CSAF action when creating a new release of the action.

Create a new tag obeying [Semantic versioning](https://semver.org/) with prefix `v`. Also, (re-)create a new tag for the major version alone.

For example, when releasing version 0.5.4:
- create a new tag `v0.5.4`
- delete the existing tag `v0`
- create a new tag `v0`

After creating a new major release, don't forget to inform the users about it so that they can update their workflow files accordingly.
