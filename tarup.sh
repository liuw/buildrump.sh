#! /usr/bin/env sh
#
# Copyright (c) 2013 
# Jens Staal <staal1978@gmail.com>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

# This script will generate a tar.bz2 archive of the current git checkout
# The "version number" of the tarball is in unix time format 

: ${GIT:=git}

# files which are not relevant in the tarball
STRIPFILES='README.md tarup.sh checkout.sh .travis.yml'

echo "Detecting buildrump.sh git revision"

_revision=$(${GIT} rev-parse HEAD)
# ideally $_date would be in UTC
_date=$(${GIT} show -s --format="%ci" ${_revision})

#incremental "version number" in unix time format
_date_filename=$(echo ${_date} | sed 's/-//g;s/ .*//')

tarballdir=tarup
tarball=${tarballdir}/buildrump-${_date_filename}.tar
echo "Target name: ${tarball}"

DEST=buildrump-${_date_filename}

die ()
{

  echo '>> ERROR:' $*
  exit 1
}

nuketmp ()
{

  rm -rf "${DEST}" "${tarball}"*
  exit 1
}

if [ "$1" != '-f' ]
then
  [ -e ${tarball} ] && die "${tarball} already exists"
  gitstat="$(${GIT} status --porcelain)"
  if [ ! -z "${gitstat}" ]
  then
    IFS=' '
    die "working directory not clean:
${gitstat}"
  fi
  [ "$(${GIT} status --porcelain -b )" = '## master' ] \
    || die "not on master branch"
fi

rm -f ${tarball}

if [ -z "${_revision}" ]
then
  die "git revision could not be detected"
else
  echo "buildrump.sh git revision is ${_revision}"
fi

trap "nuketmp" INT QUIT
mkdir -p "${DEST}" || die "failed to create directory \"${DEST}\""
mkdir -p "${tarballdir}" || die "failed to create directory \"${tarballdir}\""

echo "Fetching NetBSD sources"

./buildrump.sh -s ${DEST}/src checkoutgit || die "Checkout failed!"

# don't need .git in the tarball
rm -rf ${DEST}/src/.git

echo "Checkout done"

echo "Generating temporary directory to be compressed"

# generate sed expression to filter out unwanted files
unset filt
for file in ${STRIPFILES}
do
  filt="/^${file}\$/d;${filt}"
done

# copy desired files into staging directory
${GIT} ls-files | sed "${filt}" | xargs tar -cf - | (cd ${DEST} ; tar -xf -)

echo ${_revision} > "${DEST}/tarup-gitrevision"
echo ${_date} > "${DEST}/tarup-gitdate"

cat > "${DEST}/README" << EOF
This archive is a self-contained tarball for building rump kernels,
including the build scripts and NetBSD kernel driver sources.  The
archive is meant for example for networkless environments where
fetching the NetBSD kernel drivers at build-time is not possible.

You can recreate this archive by cloning the buildrump.sh repository [1],
checking out revision ${_revision}
and running the "tarup.sh" script.

To build rump kernels for the current platform, run "./buildrump.sh".
For crosscompilation and other instructions, see the git repository.

Unless you have a need to use this self-contained archive, it is
recommended that you use the git repository.

[1] https://github.com/anttikantee/buildrump.sh
EOF

echo "Compressing sources to a snapshot release"

tar -cf "${tarball}" "${DEST}"
gzip - < "${tarball}" > "${tarball}.gz.tmp"
bzip2 - < "${tarball}" > "${tarball}.bz2.tmp"
xz - < "${tarball}" > "${tarball}.xz.tmp"
for x in gz bz2 xz; do
  mv "${tarball}.${x}.tmp" "${tarball}.${x}"
done

echo "Removing temporary files"
rm -rf "${DEST}" "${tarball}"

echo "Congratulations! Your archives are at ${tarball}.{gz,bz2,xz}"
