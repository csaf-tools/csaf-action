# GitHub CSAF Advisory Action
Publish your CSAF Advisories from a GitHub repository to GitHub Pages.

*Validating, signing & publishing [CSAF](https://docs.oasis-open.org/csaf/csaf/v2.0/csaf-v2.0.html) security advisories.*

## What does it do?

The CSAF Action does

* validate all your CSAF advisories
* create a CSAF provider with it
* sign the documents them optionally with your OpenPGP key
* publish the result with GitHub Pages to `https://<woner>.github.io/<repository>/`.

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
      uses: wagner-intevation/csaf-action@main
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
| `csaf_version` | No | `3.3.0` | The version of the gocsaf/csaf tool suite. |
| `secvisogram_version` | No | `2.0.7` | Version of the secvisogram validator service. |
| `publisher_category` | No | `vendor` | The category of the CSAF Publisher. |
| `publisher_name` | Yes | - | Name of the CSAF Publisher. |
| `publisher_namespace` | Yes | - | URL of the CSAF Publisher. |
| `publisher_issuing_authority` | Yes | - | Description of the Issuing Authority of the CSAF Publisher. |
| `publisher_contact_details` | Yes | - | Contact details of the CSAF Publisher. |
| `openpgp_key_email_address` | No | `csaf@example.invalid` | If the OpenPGP is to be generated on the fly, this is the associated e-mail address. |
| `openpgp_key_real_name` | No | `Example CSAF Publisher` | If the OpenPGP is to be generated on the fly, this is the associated real name. |
| `openpgp_key_type` | No | `RSA` | If the OpenPGP is to be generated on the fly, this is the key type. |
| `openpgp_key_length` | No | `4096` | If the OpenPGP is to be generated on the fly, this is the key length in bits. |
| `openpgp_secret_key` | No | - | The armored OpenPGP secret key, provided as GitHub secret. |
| `openpgp_key` | No | - | The armored OpenPGP public key, provided as GitHub secret. |
| `generate_index_files` | No | `false` | Generate index.html files in .well-known/csaf/ for easier navigation in the browser. Otherwise GitHub will give 404s when accessing the directories directly. |
| `target_branch` | No | `gh-pages` | The target branch to push the resulting data to. |

### OpenPGP key security

As the OpenPGP key needs to be provided unencrypted at GitHub, keep in mind that GitHub/Microsoft can read and use it.
Please create a specific OpenPGP key for this purpose, do not reuse any other existing key and prepare for a potential confidentiality breach.
Keep the revocation certificate ready in case you need to revoke the key.

### Changing the URL

When the GitHub Pages URL changes, the file `html/.well-known/csaf/provider-metadata.json` in branch `gh-pages` must be delete to take effect.

## License

FIXME
