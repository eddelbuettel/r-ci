
## r-ci: Continuous Integration for R at Travis, GitHub, Azure, ...

This is the successor / continuation of the [r-travis](https://github.com/eddelbuettel/r-travis)
repository, which is itself a maintained fork of the (now deprecated) original
[r-travis](https://github.com/craigcitro/r-travis) repository by Craig Citro et al.  I was an early
[contributor to this project](https://github.com/craigcitro/r-travis/graphs/contributors), and quite
like its design and features -- so I have been keeping it around, maintained and extended it. It is
my 'go-to' CI setup for a few dozen repositories affecting a fairly decent number of users.

### Documentation

See the [r-ci webpage](https://eddelbuettel.github.io/r-ci) for a brief overview of usage with
GitHub Actions, Travis, Azure DevOps and Docker. See [this r^4 blog
post](http://dirk.eddelbuettel.com/blog/2021/01/07#032_portable_ci_with_r-ci) for a short
[video](https://youtu.be/W5yYkfFKBG4) and [background
slides](https://dirk.eddelbuettel.com/papers/r4_portable_ci.pdf).


### Basic Usage 

#### See other repos

The file `.github/workflows/ci.yaml` in many of my repos provides a working example. It is
frequently a copy or variant of [the r-ci.yaml file here](docs/r-ci.yaml). It relies on a
corresponding GitHub Action which _run boths setup and bootstrap steps_ and should be all you need. 
A minimal versions follows:

```yaml
# Run CI for R using https://eddelbuettel.github.io/r-ci/

name: ci

on:
  push:
  pull_request:

env:
  _R_CHECK_FORCE_SUGGESTS_: "false"

jobs:
  ci:
    strategy:
      matrix:
        include:
          #- {os: macOS-latest}
          - {os: ubuntu-latest}

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - name: Setup
        uses: eddelbuettel/github-actions/r-ci@master

      - name: Dependencies
        run: ./run.sh install_deps

      - name: Test
        run: ./run.sh run_tests

      #- name: Coverage
      #  if: ${{ matrix.os == 'ubuntu-latest' }}
      #  run: ./run.sh coverage
```

Other variants can be found at different GitHub repos. They sometimes experiment with different
containers, or with swapping `install_all` (which includes Suggests:) for `install_deps`.
 
#### Old

An older and minimal example of use with Travis follows:

```yaml
language: c
sudo: required
dist: focal

before_install:
  - curl -OLs https://eddelbuettel.github.io/r-ci/run.sh && chmod 0755 run.sh
  - ./run.sh bootstrap

install:
  - ./run.sh install_deps

script:
  - ./run.sh run_tests
```

This downloads the `run.sh` script, uses it to _bootstrap_ the test environment, then installs
dependencies via `install_deps` and finally runs tests. For a realistic but real example see _e.g._
[this .travis.yml file of package
digest](https://github.com/eddelbuettel/digest/blob/master/.travis.yml).  For another example, see
package [tidyCpp](https://github.com/eddelbuettel/tidycpp/) which shows how to use the `run.sh`
script [with Travis CI](https://github.com/eddelbuettel/tidycpp/blob/master/.travis.yml) as well as
[with GitHub
Actions](https://github.com/eddelbuettel/tidycpp/blob/master/.github/workflows/R-CMD-check.yaml), or
package [dang](https://github.com/eddelbuettel/tidycpp/) (featured in the
[video](https://youtu.be/W5yYkfFKBG4) mentioned above) Numerous variations are possible: running
'test matrices' across macOS and Linux, using BSPM for binaries (both of those [are used by
digest](https://github.com/eddelbuettel/digest/blob/master/.travis.yml), running with several `g++`
versions (as used by
[RcppSimdjson](https://github.com/eddelbuettel/rcppsimdjson/blob/master/.travis.yml), ...).

We also use the same approach of downloading `run.sh` and invoking it for the different steps in
with GitHub Actions (_e.g._ for
[tidyCpp](https://github.com/eddelbuettel/tidycpp/blob/master/.github/workflows/R-CMD-check.yaml)). There
is also an [older Action `r-ci-setup` for
GitHub](https://github.com/eddelbuettel/github-actions/tree/master/r-ci-setup) to download `run.sh`
and set it up. Similarly, Azure Pipelines can be used (as was done by a test repo on Azure).  The
[newer Action `r-ci`](https://github.com/eddelbuettel/github-actions/tree/master/r-ci) is now
preferred as it includes the bootstrap step.

There are also other options of use with PPAs and more---for fullest details see the source of the
shell script `run.sh`.

As of September 2022, we rely on [r2u](https://eddelbuettel.github.io/r2u/) to supply a full set of
binaries for CRAN for use on Ubuntu LTS. You can use it via `install_deps()` or `install_all()`
without having to supply the `r-cran-*` packages explicitly.

### Author

Dirk Eddelbuettel (for this maintained fork)

Craig Citro, Kirill Mueller, Dirk Eddelbuettel, ... (for the original r-travis)


