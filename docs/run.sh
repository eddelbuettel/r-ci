#!/bin/bash
# -*- sh-basic-offset: 4; sh-indentation: 4 -*-
# Bootstrap a CI environment for R

set -e
# Comment out this line for quieter output:
# Or ratherm set it for a lot noisier output
# set -x

CRAN=${CRAN:-"https://cloud.r-project.org"}
BIOC=${BIOC:-"https://bioconductor.org/biocLite.R"}
BIOC_USE_DEVEL=${BIOC_USE_DEVEL:-"TRUE"}
OS=$(uname -s)

## Default version: Now use 4.0, and 3.5 should still work
R_VERSION=${R_VERSION:-"4.0"}

## Optional drat repos, unset by default
DRAT_REPOS=${DRAT_REPOS:-""}

## Optional BSPM use, defaults to false
USE_BSPM=${USE_BSPM:-"FALSE"}

## Optional additional PPAs, unset by default
ADDED_PPAS=${ADDED_PPAS:-""}

## Optional trimming of extra apt source list entry, defaults to fals
TRIM_APT_SOURCES=${TRIM_APT_SOURCES:-"FALSE"}

## Optional setting of type argument in covr::coverage() call below, defaults to "tests"
COVERAGE_TYPE=${COVERAGE_TYPE:-"tests"}

#PANDOC_VERSION='1.13.1'
#PANDOC_DIR="${HOME}/opt/pandoc"
#PANDOC_URL="https://s3.amazonaws.com/rstudio-buildtools/pandoc-${PANDOC_VERSION}.zip"

# MacTeX installs in a new $PATH entry, and there's no way to force
# the *parent* shell to source it from here. So we just manually add
# all the entries to a location we already know to be on $PATH.
#
# TODO(craigcitro): Remove this once we can add `/usr/texbin` to the
# root path.
PATH="${PATH}:/usr/texbin"

R_BUILD_ARGS=${R_BUILD_ARGS-"--no-build-vignettes --no-manual"}
R_CHECK_ARGS=${R_CHECK_ARGS-"--no-vignettes --no-manual --as-cran"}
R_CHECK_INSTALL_ARGS=${R_CHECK_INSTALL_ARGS-"--install-args=--install-tests"}
_R_CHECK_TESTS_NLINES_=0

R_USE_BIOC_CMDS="source('${BIOC}');"\
" tryCatch(useDevel(${BIOC_USE_DEVEL}),"\
" error=function(e) {if (!grepl('already in use', e$message)) {e}});"\
" options(repos=biocinstallRepos());"

ShowBanner() {
    echo ""
    echo "r-ci: Portable CI for R at Travis, GitHub Actions, Azure, ..."
    echo ""
    echo "On Linux, r-ci defaults to using the most current R version, currently "
    echo "the \"4.0\" API introduced by R 4.0.0."
    echo ""
    echo "But one can select another version explicitly by setting R_VERSION to \"3.5\""
    echo "in the YAML file. Note that the corresponding PPAs will selected based on this"
    echo "variable but the distribution in the YAML file matters as well as not all"
    echo "releases distros have r-3.5 and r-4.0 repos. See the bin/linux/ubuntu/ dir on"
    echo "the CRAN mirrors if in doubt."
    echo ""
    echo "Current value of the (overrideable) R API variable 'R_VERSION': ${R_VERSION}"
    echo "Current Ubuntu distribution per 'lsb_release': '$(lsb_release -ds)' aka '$(lsb_release -cs)'"
    echo ""
    echo "Current coverage type per 'COVERAGE_TYPE': ${COVERAGE_TYPE}"
    echo ""
}

Bootstrap() {
    SetRepos

    if [[ "Darwin" == "${OS}" ]]; then
        BootstrapMac
    elif [[ "Linux" == "${OS}" ]]; then
        BootstrapLinux
    else
        echo "Unknown OS: ${OS}"
        exit 1
    fi

    if [[ "4.0" == "${R_VERSION}" ]]; then
        echo "Using R 4.0.*"
    elif [[ "3.5" == "${R_VERSION}" ]]; then
        echo "Using R 3.5.*"
    elif [[ "3.4" == "${R_VERSION}" ]]; then
        echo "Using R 3.4 is no longer supported."
        exit 1
    else
        echo "Unknown R_VERSION: ${R_VERSION}"
        exit 1
    fi

    if ! (test -e .Rbuildignore && grep -q 'travis-tool' .Rbuildignore); then
        echo '^travis-tool\.sh$' >>.Rbuildignore
    fi
    if ! (test -e .Rbuildignore && grep -q 'run.sh' .Rbuildignore); then
        echo '^run\.sh$' >> .Rbuildignore
    fi
    if ! (test -e .Rbuildignore && grep -q 'travis_wait' .Rbuildignore); then
        echo '^travis_wait_.*\.log$' >> .Rbuildignore
    fi

    # Make sure unit test package (among testthat, tinytest, RUnit) installed
    EnsureUnittestRunner

    # Report version
    Rscript -e 'sessionInfo()'
}

SetRepos() {
    echo "local({" >> ~/.Rprofile
    echo "   r <- getOption(\"repos\");" >> ~/.Rprofile
    echo "   r[\"CRAN\"] <- \"${CRAN}\"" >> ~/.Rprofile
    for d in ${DRAT_REPOS}; do
        echo "   r[\"${d}\"] <- \"https://${d}.github.io/drat\"" >> ~/.Rprofile
    done
    echo "   options(repos=r)" >> ~/.Rprofile
    echo "})" >> ~/.Rprofile
}

InstallPandoc() {
    ## deprecated 2020-Sep
    echo "Deprecated"
    # local os_path="$1"
    # mkdir -p "${PANDOC_DIR}"
    # curl -o /tmp/pandoc-${PANDOC_VERSION}.zip ${PANDOC_URL}
    # unzip -j /tmp/pandoc-${PANDOC_VERSION}.zip "pandoc-${PANDOC_VERSION}/${os_path}/pandoc" -d "${PANDOC_DIR}"
    # chmod +x "${PANDOC_DIR}/pandoc"
    # sudo ln -s "${PANDOC_DIR}/pandoc" /usr/local/bin
    # unzip -j /tmp/pandoc-${PANDOC_VERSION}.zip "pandoc-${PANDOC_VERSION}/${os_path}/pandoc-citeproc" -d "${PANDOC_DIR}"
    # chmod +x "${PANDOC_DIR}/pandoc-citeproc"
    # sudo ln -s "${PANDOC_DIR}/pandoc-citeproc" /usr/local/bin
}

BootstrapLinux() {
    ## Check for sudo_release and install if needed
    test -x /usr/bin/sudo || apt-get install -y --no-install-recommends sudo
    ## Hotfix for key issue
    echo 'Acquire::AllowInsecureRepositories "true";' | sudo tee /etc/apt/apt.conf.d/90local-secure >/dev/null

    ## Check for lsb_release and install if needed
    test -x /usr/bin/lsb_release || sudo apt-get install -y --no-install-recommends lsb-release
    ## Check for add-apt-repository and install if needed, using a fudge around the (manual) tz config dialog
    test -x /usr/bin/add-apt-repository || \
        (echo 12 > /tmp/input.txt; echo 5 >> /tmp/input.txt; sudo apt-get install -y tzdata < /tmp/input.txt; sudo apt-get install -y --no-install-recommends software-properties-common)

    ShowBanner

    ## If opted in, trim apt sources
    if [[ "${TRIM_APT_SOURCES}" != "FALSE" ]]; then
        sudo rm -vf /etc/apt/sources.list.d/*.list
    fi

    ## Set up our CRAN mirror.
    ## Check for dirmngr and install if needed
    test -x /usr/bin/dirmngr || sudo apt-get install -y --no-install-recommends dirmngr
    ## Check for gpg and install gnupg if needed (on bare-bones Ubuntu)
    test -x /usr/bin/gpg || sudo apt install -y --no-install-recommends gnupg
    ## Check for gpg-agent and install if needed
    test -x /usr/bin/gpg-agent || sudo apt install -y --no-install-recommends gpg-agent
    ## Get the key
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
    ## Add the repo
    if [[ "${R_VERSION}" == "4.0" ]]; then
        ## need pinning to ensure repo sorts higher
        echo "Package: *" | sudo tee /etc/apt/preferences.d/c2d4u-pin >/dev/null
        echo "Pin: release o=LP-PPA-c2d4u.team-c2d4u4.0+" | sudo tee -a /etc/apt/preferences.d/c2d4u-pin >/dev/null
        echo "Pin-Priority: 750" | sudo tee -a /etc/apt/preferences.d/c2d4u-pin >/dev/null
        ## now add repo (and update index)
        sudo add-apt-repository "deb ${CRAN}/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
    elif [[ "${R_VERSION}" == "3.5" ]]; then
        sudo add-apt-repository "deb ${CRAN}/bin/linux/ubuntu $(lsb_release -cs)-cran35/"
    elif [[ "${R_VERSION}" == "3.4" ]]; then
        echo "Using R 3.4 is no longer supported."
        exit 1
    fi

    # Add marutter's c2d4u repository.
    if [[ "${R_VERSION}" == "4.0" ]]; then
        ## R 4.0 and c2d4u/4.0 variant
        sudo add-apt-repository -y "ppa:marutter/rrutter4.0"
        sudo add-apt-repository -y "ppa:c2d4u.team/c2d4u4.0+"
        ## Added PPAs, if given
        if [[ "${ADDED_PPAS}" != "" ]]; then
            for ppa in "${ADDED_PPAS}"; do
                sudo add-apt-repository -y "${ppa}"
            done
        fi
    elif [[ "${R_VERSION}" == "3.5" ]]; then
        sudo add-apt-repository -y "ppa:marutter/rrutter3.5"
        sudo add-apt-repository -y "ppa:marutter/c2d4u3.5"
    elif [[ "${R_VERSION}" == "3.4" ]]; then
        exit "R 3.4 is too old."
        exit 1
    fi

    # Update after adding all repositories.  Retry several times to work around
    # flaky connection to Launchpad PPAs.
    Retry sudo apt-get update -qq

    # Install an R development environment. qpdf is also needed for
    # --as-cran checks:
    #   https://stat.ethz.ch/pipermail/r-help//2012-September/335676.html
    # May 2020: we also need devscripts for checkbashism
    # Sep 2020: add bspm, remotes
    Retry sudo apt-get install -y --no-install-recommends r-base-dev r-recommended qpdf devscripts r-cran-remotes
    
    if [[ "${USE_BSPM}" != "FALSE" ]]; then
        Retry sudo apt-get install -y --no-install-recommends r-cran-bspm
    fi

    #sudo cp -ax /usr/lib/R/site-library/littler/examples/{build.r,check.r,install*.r,update.r} /usr/local/bin
    ## for now also from littler from GH
    #sudo install.r remotes
    #sudo installGithub.r eddelbuettel/littler
    #sudo cp -ax /usr/local/lib/R/site-library/littler/examples/{check.r,install*.r} /usr/local/bin

    # Default to no recommends
    echo 'APT::Install-Recommends "false";' | sudo tee /etc/apt/apt.conf.d/90local-no-recommends >/dev/null

    # Change permissions for /usr/local/lib/R/site-library
    # This should really be via 'staff adduser travis staff'
    # but that may affect only the next shell
    sudo chmod 2777 /usr/local/lib/R /usr/local/lib/R/site-library

    # Process options
    BootstrapLinuxOptions
}

BootstrapLinuxOptions() {
    if [[ -n "$BOOTSTRAP_LATEX" ]]; then
        # We add a backports PPA for more recent TeX packages.
        # sudo add-apt-repository -y "ppa:texlive-backports/ppa"

        Retry sudo apt-get install -y --no-install-recommends \
            texlive-base texlive-latex-base \
            texlive-fonts-recommended texlive-fonts-extra \
            texlive-extra-utils texlive-latex-recommended texlive-latex-extra \
            texinfo lmodern
        # no longer exists: texlive-generic-recommended
    fi
    if [[ -n "$BOOTSTRAP_PANDOC" ]]; then
        InstallPandoc 'linux/debian/x86_64'
    fi
    if [[ "${USE_BSPM}" != "FALSE" ]]; then
        echo "bspm::enable()" | sudo tee --append /etc/R/Rprofile.site >/dev/null
    fi
}

BootstrapMac() {
    # Install from latest CRAN binary build for OS X
    wget ${CRAN}/bin/macosx/R-latest.pkg  -O /tmp/R-latest.pkg

    echo "Installing OS X binary package for R"
    sudo installer -pkg "/tmp/R-latest.pkg" -target /
    rm "/tmp/R-latest.pkg"

    # Process options
    BootstrapMacOptions

    # Default packages
    sudo Rscript -e 'install.packages(c("remotes"))'
}

BootstrapMacOptions() {
    if [[ -n "$BOOTSTRAP_LATEX" ]]; then
        # TODO: Install MacTeX.pkg once there's enough disk space
        MACTEX=BasicTeX.pkg
        wget http://ctan.math.utah.edu/ctan/tex-archive/systems/mac/mactex/$MACTEX -O "/tmp/$MACTEX"

        echo "Installing OS X binary package for MacTeX"
        sudo installer -pkg "/tmp/$MACTEX" -target /
        rm "/tmp/$MACTEX"
        # We need a few more packages than the basic package provides; this
        # post saved me so much pain:
        #   https://stat.ethz.ch/pipermail/r-sig-mac/2010-May/007399.html
        sudo tlmgr update --self
        sudo tlmgr install inconsolata upquote courier courier-scaled helvetic
    fi
    if [[ -n "$BOOTSTRAP_PANDOC" ]]; then
        InstallPandoc 'mac'
    fi
}

EnsureDevtools() {
    ## deprecated 2020-Sep
    echo "Deprecated"
    #if ! Rscript -e 'if (!("devtools" %in% rownames(installed.packages()))) q(status=1)' ; then
    #    # Install devtools and testthat.
    #    RBinaryInstall devtools testthat
    #fi
}

EnsureUnittestRunner() {
    sudo Rscript -e 'dcf <- read.dcf(file="DESCRIPTION")[1,]; if ("Suggests" %in% names(dcf)) { sug <- dcf[["Suggests"]]; pkg <- do.call(c, sapply(c("testthat", "tinytest", "RUnit"), function(p, sug) if (grepl(p, sug)) p else NULL, sug, USE.NAMES=FALSE)); if (!is.null(pkg)) install.packages(pkg) }'
}

InstallIfNotYetInstalled() {
    res=$(Rscript -e 'if (requireNamespace(commandArgs(TRUE), quietly=TRUE)) cat("YES") else cat("NO")' "$1")
    if [[ "${res}" != "YES" ]]; then
        sudo Rscript -e 'install.packages(commandArgs(TRUE))' "$1"
    fi
}

AptGetInstall() {
    if [[ "Linux" != "${OS}" ]]; then
        echo "Wrong OS: ${OS}"
        exit 1
    fi

    if [[ "" == "$*" ]]; then
        echo "No arguments to aptget_install"
        exit 1
    fi

    echo "Installing apt package(s) $@"
    Retry sudo apt-get -y --no-install-recommends --allow-unauthenticated install "$@"
}

DpkgCurlInstall() {
    if [[ "Linux" != "${OS}" ]]; then
        echo "Wrong OS: ${OS}"
        exit 1
    fi

    if [[ "" == "$*" ]]; then
        echo "No arguments to dpkgcurl_install"
        exit 1
    fi

    echo "Installing remote package(s) $@"
    for rf in "$@"; do
        curl -OL ${rf}
        f=$(basename ${rf})
        sudo dpkg -i ${f}
        rm -v ${f}
    done
}

RInstall() {
    if [[ "" == "$*" ]]; then
        echo "No arguments to r_install"
        exit 1
    fi

    echo "Installing R package(s): $@"
    sudo Rscript -e 'install.packages(commandArgs(TRUE))' "$@"
}

BiocInstall() {
    if [[ "" == "$*" ]]; then
        echo "No arguments to bioc_install"
        exit 1
    fi

    echo "Installing R Bioconductor package(s): $@"
    Rscript -e "${R_USE_BIOC_CMDS}"' biocLite(commandArgs(TRUE))' "$@"
}

RBinaryInstall() {
    if [[ -z "$#" ]]; then
        echo "No arguments to r_binary_install"
        exit 1
    fi

    if [[ "Linux" != "${OS}" ]] || [[ -n "${FORCE_SOURCE_INSTALL}" ]]; then
        echo "Fallback: Installing from source"
        RInstall "$@"
        return
    fi

    echo "Installing *binary* R packages: $*"
    r_packages=$(echo $* | tr '[:upper:]' '[:lower:]')
    r_debs=$(for r_package in ${r_packages}; do echo -n "r-cran-${r_package} "; done)

    AptGetInstall ${r_debs}
}

InstallGithub() {
    #EnsureDevtools

    #echo "Installing GitHub packages: $@"
    # Install the package.
    #Rscript -e 'library(devtools); library(methods); install_github(commandArgs(TRUE), build_vignettes = FALSE)' "$@"
    sudo Rscript -e 'remotes::install_github(commandArgs(TRUE))' "$@"
}

InstallDeps() {
    #EnsureDevtools
    #Rscript -e 'library(devtools); library(methods); install_deps(dependencies = TRUE)'
    sudo Rscript -e 'remotes::install_deps(".")'
}

InstallDepsAndSuggests() {
    sudo Rscript -e 'remotes::install_deps(".", dependencies=TRUE)'
}

InstallBiocDeps() {
    ## deprecated 2020-Sep
    echo "Deprecated"
    #EnsureDevtools
    #Rscript -e "${R_USE_BIOC_CMDS}"' library(devtools); install_deps(dependencies = TRUE)'
}

DumpSysinfo() {
    echo "Dumping system information."
    R -e '.libPaths(); sessionInfo(); installed.packages()'
}

DumpLogsByExtension() {
    if [[ -z "$1" ]]; then
        echo "dump_logs_by_extension requires exactly one argument, got: $@"
        exit 1
    fi
    extension=$1
    shift
    package=$(find . -maxdepth 1 -name "*.Rcheck" -type d)
    if [[ ${#package[@]} -ne 1 ]]; then
        echo "Could not find package Rcheck directory, skipping log dump."
        exit 0
    fi
    for name in $(find "${package}" -type f -name "*${extension}"); do
        echo ">>> Filename: ${name} <<<"
        cat ${name}
    done
}

DumpLogs() {
    echo "Dumping test execution logs."
    DumpLogsByExtension "out"
    DumpLogsByExtension "log"
    DumpLogsByExtension "fail"
}

Coverage() {
    echo "Running Code Coverage analysis via the covr package"

    ## assumes that the Rutter PPAs are in fact known, which is a given here
    AptGetInstall r-cran-covr

    Rscript -e "covr::codecov(type = '${COVERAGE_TYPE}', quiet = FALSE)"
}

RunTests() {
    echo "Building with: R CMD build ${R_BUILD_ARGS}"
    R CMD build ${R_BUILD_ARGS} .
    # We want to grab the version we just built.
    FILE=$(ls -1t *.tar.gz | head -n 1)

    # Create binary package (currently Windows only)
    if [[ "${OS:0:5}" == "MINGW" ]]; then
        R_CHECK_INSTALL_ARGS=${R_CHECK_INSTALL_ARGS-"--install-args=\"--build --install-tests\""}
    fi

    echo "Testing with: R CMD check \"${FILE}\" ${R_CHECK_ARGS} ${R_CHECK_INSTALL_ARGS}"
    _R_CHECK_CRAN_INCOMING_=${_R_CHECK_CRAN_INCOMING_:-FALSE}
    if [[ "$_R_CHECK_CRAN_INCOMING_" == "FALSE" ]]; then
        echo "(CRAN incoming checks are off)"
    fi
    _R_CHECK_CRAN_INCOMING_=${_R_CHECK_CRAN_INCOMING_} R CMD check "${FILE}" ${R_CHECK_ARGS} ${R_CHECK_INSTALL_ARGS}

    # Check reverse dependencies
    #if [[ -n "$R_CHECK_REVDEP" ]]; then
    #    echo "Checking reverse dependencies"
    #    Rscript -e 'library(devtools); checkOutput <- unlist(revdep_check(as.package(".")$package));if (!is.null(checkOutput)) {print(data.frame(pkg = names(checkOutput), error = checkOutput));for(i in seq_along(checkOutput)){;cat("\n", names(checkOutput)[i], " Check Output:\n  ", paste(readLines(regmatches(checkOutput[i], regexec("/.*\\.out", checkOutput[i]))[[1]]), collapse = "\n  ", sep = ""), "\n", sep = "")};q(status = 1, save = "no")}'
    #fi

    if [[ -n "${WARNINGS_ARE_ERRORS}" ]]; then
        if DumpLogsByExtension "00check.log" | grep -q WARNING; then
            echo "Found warnings, treated as errors."
            echo "Clear or unset the WARNINGS_ARE_ERRORS environment variable to ignore warnings."
            exit 1
        fi
    fi
}

Retry() {
    if "$@"; then
        return 0
    fi
    for wait_time in 5 20 30 60; do
        echo "Command failed, retrying in ${wait_time} ..."
        sleep ${wait_time}
        if "$@"; then
            return 0
        fi
    done
    echo "Failed all retries!"
    exit 1
}

ShowHelpAndExit() {
    echo "Usage: run.sh COMMAND"
    echo "Derived from the venerable r-travis project, and still maintained lovingly by @eddelbuettel."
    echo "See https://eddelbuettel.github.io/r-ci for more."
    exit 0
}

COMMAND=$1
#echo "\033[0;31m
#r-travis is DEPRECATED!
#Please see https://docs.travis-ci.com/user/languages/r/ for info, or
#https://github.com/craigcitro/r-travis/wiki/Porting-to-native-R-support-in-Travis
#for information on porting to native R support in Travis.\033[0m"
#echo "Running command: ${COMMAND}"
shift
case $COMMAND in
    ##
    ## Bootstrap a new core system
    "bootstrap")
        Bootstrap
        ;;
    ## Code coverage via covr.io
    "coverage")
        Coverage
        ;;
    ##
    ## Ensure devtools is loaded (implicitly called)
    "install_devtools"|"devtools_install")
        EnsureDevtools
        ;;
    ##
    ## Install a binary deb package via apt-get
    "install_aptget"|"aptget_install")
        AptGetInstall "$@"
        ;;
    ##
    ## Install a binary deb package via a curl call and local dpkg -i
    "install_dpkgcurl"|"dpkgcurl_install")
        DpkgCurlInstall "$@"
        ;;
    ##
    ## Install an R dependency from CRAN
    "install_r"|"r_install")
        RInstall "$@"
        ;;
    ##
    ## Install an R dependency from Bioconductor
    "install_bioc"|"bioc_install")
        BiocInstall "$@"
        ;;
    ##
    ## Install an R dependency as a binary (via c2d4u PPA)
    "install_r_binary"|"r_binary_install")
        RBinaryInstall "$@"
        ;;
    ##
    ## Install a package from github sources
    "install_github"|"github_package")
        InstallGithub "$@"
        ;;
    ##
    ## Install package dependencies from CRAN
    "install_deps")
        InstallDeps
        ;;
    ##
    ## Install package dependencies and suggests from CRAN
    "install_all")
        InstallDepsAndSuggests
        ;;
    ##
    ## Install package dependencies from Bioconductor and CRAN (needs devtools)
    "install_bioc_deps")
        InstallBiocDeps
        ;;
    ##
    ## Run the actual tests, ie R CMD check
    "run_tests")
        RunTests
        ;;
    ##
    ## Dump information about installed packages
    "dump_sysinfo")
        DumpSysinfo
        ;;
    ##
    ## Dump build or check logs
    "dump_logs")
        DumpLogs
        ;;
    ##
    ## Dump selected build or check logs
    "dump_logs_by_extension")
        DumpLogsByExtension "$@"
        ;;
    ##
    ## Help
    "help")
        ShowHelpAndExit
        ;;
esac
