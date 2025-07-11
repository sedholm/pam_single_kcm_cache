#!/bin/bash

# Script to create source package for libpam-single-kcm-cache
# This creates packages for all current Ubuntu LTS releases

set -euo pipefail

PACKAGE_NAME="libpam-single-kcm-cache"
UPSTREAM_REPO="$(git remote get-url origin | sed -E 's#git@([^:]+):#https://\1/#')"
BRANCH=$(git rev-parse --abbrev-ref HEAD)
## if no .gitattributes
#GIT_ARCHIVE_EXCLUDE=(":(exclude)plantuml" ":(exclude)debian-build-script.sh")           ## se "pathspec" in gitglossary(7)

# Ubuntu LTS releases to target
UBUNTU_RELEASES=("jammy" "noble")  # 22.04 LTS and 24.04 LTS
MAINTAINER_NAME="Per Sedholm"
MAINTAINER_EMAIL="sedholm@kth.se"


for RELEASE in "${UBUNTU_RELEASES[@]}"; do (
    VERSION=$(PACKAGE_NAME=$PACKAGE_NAME perl -MEnv -nle 'next unless m{\A${PACKAGE_NAME}\s+\((?:(\d+):)?([0-9A-Za-z.+:~\-]+?)(?:-([0-9A-Za-z.+~]+))?\)\s+}; ($epoch, $upstream, $debrev) = ($1, $2, $3); print $upstream; exit(0);' < debian/changelog.${RELEASE})
    echo "Building ${VERSION} for ${RELEASE}"

    # Create working directory
    WORK_DIR="$(mktemp -d ../build-${RELEASE}-${VERSION}.XXXXXXXXXX)"
    echo "Working in: $WORK_DIR"
    cd "$WORK_DIR"

    # Clone the upstream repository
    echo "Cloning upstream repository..."
    git clone "$UPSTREAM_REPO" "$PACKAGE_NAME-$VERSION"
    cd "$PACKAGE_NAME-$VERSION"
    #? git config --global --add safe.directory $(pwd)
    git switch ${BRANCH}

    # Create upstream source tarball for source package
    DSRC_ORIGIN="${PACKAGE_NAME}_${VERSION}.orig.tar.gz"
    git archive --format=tar.gz --prefix="$PACKAGE_NAME-$VERSION/" --output="../${DSRC_ORIGIN}" ${BRANCH}

    echo "Using debian/changelog.${RELEASE} fo debian/changelog"
    ln -s changelog.${RELEASE} debian/changelog

    _a=($(perl -anle 'next unless m{export-ignore}; next if m{\.gitattributes|\.gitignore|^debian}; print qq($F[0]);' < .gitattributes))
    echo "Moving files excluded from source tree to ../build-excluded/: ${_a[*]}"
    mkdir -p ../build-excluded
    mv --target-directory=../build-excluded ${_a[*]}

    ## NB: Using debuild from devscripts (higher-level warpper for dpkg-buildpackage)
    ## TODO: Set up signing
    ## TODO: repackage as "+dfsg repackaged tarball" to exclude this build script and other non-essential files.
    #debuild -S -sa -k"$MAINTAINER_EMAIL" || echo "Note: Package built but not signed (add GPG key for signing)"



    echo "Building source package for Ubuntu $RELEASE..."
    debuild -S -sa -k"$MAINTAINER_EMAIL" --no-sign
    echo "Moving results to release-specific directory $(pwd)/../release"
    mkdir -p ../release
    mv --target-directory=../release/ ../${PACKAGE_NAME}*${VERSION}*.orig.tar.gz ../${PACKAGE_NAME}*${VERSION}-[0-9]*~*~${RELEASE}*{.dsc,.tar.*,.changes} 2>/dev/null

    echo -e "\n\n    Source packages of ${VERSION} for ${RELEASE}created in: $WORK_DIR/release/\n\n"
); done

## Instructions for PPA upload
#echo "Upload to PPA with: dput ppa:your-ppa-name/ppa-name path/to/changes/file"
#cat << EOF
#
#To upload to your PPA:
#1. Make sure you have a GPG key set up and associated with your Launchpad account
#2. Sign the packages: debsign -k your-key-id *.changes
#3. Upload: dput ppa:your-username/your-ppa-name *.changes
#
#The packages will build for both amd64 and arm64 architectures automatically
#when uploaded to the PPA.
#EOF

## Instructions to build locally. DANGER: NO ISOLATION.
cat << EOF

To build any release locally with debuild:

1.   cd $(pwd)/build-((release))-((version)).*/release
2.   dpkg-source -x *.dsc
3.   cd *-((version))
4.   debuild -b -us -uc
5.   cp *.deb /path/to/.../


DANGER: NO ISOLATION. This may pullute the environment with local dependencies.
DANGER: .deb file(s) are built without signing.
EOF
