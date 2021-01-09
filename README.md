
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

A minimal example of use with Travis follows:

```sh
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
[tidyCpp](https://github.com/eddelbuettel/tidycpp/blob/master/.github/workflows/R-CMD-check.yaml)). Similarly,
Azure Pipelines can be used (as was done by a test repo on Azure).

There are also other options of use with PPAs and more---for fullest details see the source of the
shell script `run.sh`.

### Author

Dirk Eddelbuettel (for this maintained fork)

Craig Citro, Kirill Mueller, Dirk Eddelbuettel, ... (for the original r-travis)


