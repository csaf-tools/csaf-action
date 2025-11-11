# GitHub CSAF Advisory Action
Publish your CSAF Advisories from a GitHub repository to GitHub Pages.

*Validating, signing & publishing [CSAF](https://docs.oasis-open.org/csaf/csaf/v2.0/csaf-v2.0.html) security advisories.*

<!--
 SPDX-License-Identifier: Apache-2.0
 SPDX-FileCopyrightText: 2025 German Federal Office for Information Security (BSI) <https://www.bsi.bund.de>
 Software-Engineering: 2025 Intevation GmbH <https://intevation.de>
-->

## Development status

Please note that this Action is not yet stable, and breaking changes may occur.

## What does it do?

The CSAF Action does

* validate all your CSAF advisories
* create a CSAF provider with it
* sign the documents them optionally with your OpenPGP key
* publish the result with GitHub Pages to `https://<owner>.github.io/<repository>/`.

On every commit containing a change in the document directory, the CSAF Action updates the existing structure and adds the newly added documents.

Internally, it

- creates a branch `gh-pages` if it does not yet exists
- configures and sets up a `csaf_provider` of the CSAF Tools using nginx, go and fcgiwrap.
- sets up a secvisogram validator service with npm and hunspell
- upload the CSAF advisories to the local CSAF provider, generating the file structure and signatures
- make adjustments for publishing it with GitHub Pages
- commit the documents to the branch `gh-pages`

## Activate GitHub Pages

1. In your repository, go to Settings > Pages (`https://github.com/<owner>/<repository>/settings/pages`)
2. Build and Deploy from source: *Deploy from a branch*
3. Branch: *gh-pages* (default)

## Workflow file

```yaml
name: Validate & publish CSAF advisories
on:
  push:
    branches:
      - main
    paths:
      - 'advisories/**.json'
  workflow_dispatch:

permissions:
  contents: write

jobs:
  csaf:
    runs-on: ubuntu-24.04
    name: Create CSAF documents
    strategy:
      fail-fast: false

    steps:
    - name: Publish CSAF advisories
      uses: csaf-tools/csaf-action@v0
      with:
        publisher_name: Example Test Company
        publisher_namespace: https://test.example.com
        publisher_issuing_authority: "We at Example Test Company are responsible for publishing and maintaining Product Test."
        publisher_contact_details: "Example Test Company can be reached at contact_us@example.com or via our website at https://test.example.com/contact."
        source_csaf_documents: advisories/
        openpgp_secret_key: ${{ secrets.CSAF_OPENPGP_SECRET_KEY }}
        openpgp_key: ${{ secrets.CSAF_OPENPGP_KEY }}
```

## Input parameters

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `source_csaf_documents` | No | `csaf_documents/` | Directory to the Source CSAF Advisory JSON files. |
| `csaf_version` | No | `3` | The version of the gocsaf/csaf tool suite. Either only a major version number or the exact version number. |
| `secvisogram_version` | No | `2` | Version of the secvisogram validator service. Either only a major version number or the exact version number. |
| `publisher_category` | No | `vendor` | The category of the CSAF Publisher. |
| `publisher_name` | Yes | - | Name of the CSAF Publisher. |
| `publisher_namespace` | Yes | - | URL of the CSAF Publisher. |
| `publisher_issuing_authority` | Yes | - | Description of the Issuing Authority of the CSAF Publisher. |
| `publisher_contact_details` | Yes | - | Contact details of the CSAF Publisher. |
| `openpgp_use_signatures` | No | `true` | Use the signature files placed along the advisory files with `.asc` file ending |
| `openpgp_key_email_address` | No | `csaf@example.invalid` | If the OpenPGP is to be generated on the fly, this is the associated e-mail address. |
| `openpgp_key_real_name` | No | `Example CSAF Publisher` | If the OpenPGP is to be generated on the fly, this is the associated real name. |
| `openpgp_key_type` | No | `RSA` | If the OpenPGP is to be generated on the fly, this is the key type. |
| `openpgp_key_length` | No | `4096` | If the OpenPGP is to be generated on the fly, this is the key length in bits. |
| `openpgp_secret_key` | No | - | The armored OpenPGP secret key, provided as GitHub secret. |
| `openpgp_public_key` | No | - | The armored OpenPGP public key, provided as string or GitHub secret. |
| `generate_index_files` | No | `false` | Generate index.html files in .well-known/csaf/ for easier navigation in the browser. Otherwise GitHub will give 404s when accessing the directories directly. |
| `target_branch` | No | `gh-pages` | The target branch to push the resulting data to. |
| `tlps` | No | `csaf,white` | Set the TLP levels allowed to be send with the upload request. Possible levels: "csaf", "white", "amber", "green", "red". The "csaf" entry lets the provider take the value from the CSAF document. |

### OpenPGP signatures

#### Signature files (default & recommended)

For each advisory in `source_csaf_documents`, place an OpenPGP signature:
```bash
gpg --armor --detach-sign --local-user KEYID --sign test/inputs/example-company-2025-0001.json
```
And set these two parameters. `openpgp_public_key` must be the one public key that you are using for the signatures.

```yaml
with:
  openpgp_use_signatures: true
  openpgp_public_key: |
    -----BEGIN PGP PUBLIC KEY BLOCK-----
    ...
```

The parameter `openpgp_public_key` can also be set using a secret, see the example below.

#### OpenPGP Secret key uploaded as GitHub secret

Create an OpenPGP key, export it using
```bash
gpg --armor --export KEYID > openpgp_public.asc
gpg --armor --export-secret-keys KEYID > openpgp_private.asc
```
Go to the settings of your repositories, switch to page *Security* > *Secrets and variables* > *Actions* and create two repository secrets:
* `CSAF_OPENPGP_KEY`: Content of file `openpgp_public.asc`
* `CSAF_OPENPGP_SECRET_KEY`: Content of file `openpgp_private.asc`

```yaml
with:
  openpgp_use_signatures: false
  openpgp_secret_key: ${{ secrets.CSAF_OPENPGP_SECRET_KEY }}
  openpgp_public_key: ${{ secrets.CSAF_OPENPGP_PUBLIC_KEY }}
```

##### Security

As the OpenPGP key needs to be provided unencrypted at GitHub, keep in mind that GitHub/Microsoft can read and use it.
Please create a specific OpenPGP key for this purpose, do not reuse any other existing key and prepare for a potential confidentiality breach.
Keep the revocation certificate ready in case you need to revoke the key.

#### Generating key on the fly

When neither an OpenPGP key is given as secret, nor the signatures are in use, then the Action generates an OpenPGP key on the fly and signs the advisories with it.
Please mind that this the absolute fall back and the signatures can't be verified, neither can the private key be recovered or reused for the next run.
The resulting directory structure is CSAF-valid, but without useful signatures.

This mode is useful for starting from scratch, demo and test purposes.

### Changing the URL

When the GitHub Pages URL changes, the file `html/.well-known/csaf/provider-metadata.json` in branch `gh-pages` must be delete to take effect.

## License

**todo**

```
SPDX-License-Identifier: Apache-2.0

SPDX-FileCopyrightText: 2025 German Federal Office for Information Security (BSI) <https://www.bsi.bund.de>
Software-Engineering: 2025 Intevation GmbH <https://intevation.de>
```
