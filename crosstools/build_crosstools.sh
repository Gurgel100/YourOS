#!/bin/bash

CORES=`nproc`

OSPATH=

#Versionen
BINUTILS_VERSION=2.26
GCC_VERSION=6.5.0
NEEDS_GMP_MAJOR=4
NEEDS_GMP_MINOR=2
NEEDS_GMP_PATCHLEVEL=0
NEEDS_MPFR_MAJOR=2
NEEDS_MPFR_MINOR=4
NEEDS_MPFR_PATCHLEVEL=0
NEEDS_MPC_MAJOR=0
NEEDS_MPC_MINOR=8
NEEDS_MPC_PATCHLEVEL=0
GMP_VERSION=5.0.5
MPFR_VERSION=3.1.3
MPC_VERSION=1.0.3

CURRENT_DIR=`pwd`
PREFIX=${CURRENT_DIR}/env
TARGET_YOUROS=x86_64-pc-youros
TARGET_GENERIC=x86_64-elf
PATCHES=${CURRENT_DIR}/patches
TMP=${CURRENT_DIR}/tmp
MAKEOPTS=-j${CORES}

# interne Variablen
GCC_CONFIGURE_PARAMS=
GCC_CONFIGURE_PARAMS_GENERIC=
GCC_CONFIGURE_PARAMS_YOUROS=
BUILD_GMP=
BUILD_MPFR=
BUILD_MPC=
CLEANUP=false
FORCE=false
DOWNLOAD=false
ERROR_OPT=false

die() {
	echo -e "$1"
	exit -1
}

function help()
{
	echo "Usage: build_crosstools.sh [options]"
	echo "Options:"
	echo " -h	Display this information"
	echo " -k	Kernel source path"
	echo " -c	Clean up at the end"
	echo " -d	Download all dependencies"
	echo " -t	Use the following path as temporary directory"
	echo " -f	Force building"
}

while getopts ":hk:cdft:i" option; do
	case "${option}" in
		k)
			OSPATH=${OPTARG}
			;;
		h)
			help
			exit 0
			;;
		f)
			FORCE=true
			;;
		c)
			CLEANUP=true
			;;
		d)
			DOWNLOAD=true
			;;
		t)
			TMP=${OPTARG}
			;;
		\?)
			echo "Invalid option -${OPTARG}" >&2
			ERROR_OPT=true
			;;
		:)
			echo -e "Option -${OPTARG} requires an argument" >&2
			ERROR_OPT=true
			;;
	esac
done

if [ ${ERROR_OPT} = true ]; then
	help
	exit 1
fi

LOGS=${TMP}

[ -d ${OSPATH} ] || die "${OSPATH} ist kein Verzeichnis!"
[ -d ${PATCHES} ] || die "${PATCHES} nicht gefunden. Ist das Arbeitsverzeichnis korrekt?"

(which as > /dev/null 2>&1) || die "as nicht installiert. Bitte das Paket 'binutils' installieren."
(which gcc > /dev/null 2>&1) || die "gcc nicht installiert. Bitte das Paket 'gcc' installieren."
(which g++ > /dev/null 2>&1) || die "g++ nicht installiert. Bitte das Paket 'g++' installieren."
(which makeinfo > /dev/null 2>&1) || die "binutils benötigt makeinfo. Bitte das Paket 'texinfo' installieren."

mkdir -p ${PREFIX}
mkdir -p ${PREFIX}/include

#cp -r ${OSPATH}/include ${PREFIX}
#as -64 -o ${PREFIX}/lib/crt0.o ${OSPATH}/lib/start.S
make -C ${OSPATH} SYSROOT_DIR=${PREFIX} install-headers

#
# User nerven
#

# Überprüfen ob GMP in richtiger Version installiert
cat <<EOF > libgmp-test.c
#include <gmp.h>
#if __GNU_MP_VERSION < ${NEEDS_GMP_MAJOR} || (__GNU_MP_VERSION == ${NEEDS_GMP_MAJOR} && (__GNU_MP_VERSION_MINOR < ${NEEDS_GMP_MINOR} || (__GNU_MP_VERSION_MINOR == ${NEEDS_GMP_MINOR} && __GNU_MP_VERSION_PATCHLEVEL < ${NEEDS_GMP_PATCHLEVEL})))
#error unsupported version
#endif
int main(){}
EOF

gcc libgmp-test.c -lgmp -o libgmp-test &> /dev/null
gcc_state=$?
rm -f libgmp-test libgmp-test.c
if [ $gcc_state != 0 ]; then
  if ! [ ${DOWNLOAD} ]; then
    echo "Entweder die Entwicklerpakete für GMP sind nicht installiert oder in einer veralteten Version (< ${NEEDS_GMP_MAJOR}.${NEEDS_GMP_MINOR}.${NEEDS_GMP_PATCHLEVEL})."\
         "Wollen Sie die Pakete von Hand nachinstallieren bzw. updaten ('j' eingeben)? Falls Ihre Distribution keine so aktuellen Pakete zur Verfügung stellt,"\
         "geben Sie bitte 'n' ein und der GMP-Quellcode wird automatisch heruntergeladen und installiert (ohne eine vorhandene Installation von GMP zu beeinträchtigen)"

    read should_die
    [ "$should_die" == "n" ] || die "Fehler: GMP-Bibliothek in Version >= ${NEEDS_GMP_MAJOR}.${NEEDS_GMP_MINOR}.${NEEDS_GMP_PATCHLEVEL} (inklusive -dev Paket) benötigt";
  fi

  BUILD_GMP=1
  GCC_CONFIGURE_PARAMS_GENERIC="--with-gmp-include=${TMP}/cross-gcc/build-generic/gmp --with-gmp-lib=${TMP}/cross-gcc/build-generic/gmp/.libs"
  GCC_CONFIGURE_PARAMS_YOUROS="--with-gmp-include=${TMP}/cross-gcc/build-youros/gmp --with-gmp-lib=${TMP}/cross-gcc/build-youros/gmp/.libs"
fi

# Überprüfen ob MPFR in richtiger Version installiert
cat <<EOF > libmpfr-test.c
#include <mpfr.h>
#if MPFR_VERSION_MAJOR < ${NEEDS_MPFR_MAJOR} || (MPFR_VERSION_MAJOR == ${NEEDS_MPFR_MAJOR} && (MPFR_VERSION_MINOR < ${NEEDS_MPFR_MINOR} || (MPFR_VERSION_MINOR == ${NEEDS_MPFR_MINOR} && MPFR_VERSION_PATCHLEVEL < ${NEEDS_MPFR_PATCHLEVEL})))
#error unsupported version
#endif
int main(){}
EOF

gcc libmpfr-test.c -lgmp -o libmpfr-test &> /dev/null
gcc_state=$?
rm -f libmpfr-test libmpfr-test.c
if [ $gcc_state != 0 ]; then
  if ! [ ${DOWNLOAD} ]; then
    echo "Entweder die Entwicklerpakete für MPFR sind nicht installiert oder in einer veralteten Version (< ${NEEDS_MPFR_MAJOR}.${NEEDS_MPFR_MINOR}.${NEEDS_MPFR_PATCHLEVEL})."\
         "Wollen Sie die Pakete von Hand nachinstallieren bzw. updaten ('j' eingeben)? Falls Ihre Distribution keine so aktuellen Pakete zur Verfügung stellt,"\
         "geben Sie bitte 'n' ein und der MPFR-Quellcode wird automatisch heruntergeladen und installiert (ohne eine vorhandene Installation von MPFR zu beeinträchtigen)"

    read should_die
    [ "$should_die" == "n" ] || die "Fehler: MPFR-Bibliothek in Version >= ${NEEDS_MPFR_MAJOR}.${NEEDS_MPFR_MINOR}.${NEEDS_MPFR_PATCHLEVEL} (inklusive -dev Paket) benötigt";
  fi

  BUILD_MPFR=1
fi

# Überprüfen ob MPC in richtiger Version installiert
cat <<EOF > libmpc-test.c
#include <mpc.h>
#if MPC_VERSION_MAJOR < ${NEEDS_MPC_MAJOR} || (MPC_VERSION_MAJOR == ${NEEDS_MPC_MAJOR} && (MPC_VERSION_MINOR < ${NEEDS_MPC_MINOR} || (MPC_VERSION_MINOR == ${NEEDS_MPC_MINOR} && MPC_VERSION_PATCHLEVEL < ${NEEDS_MPC_PATCHLEVEL})))
#error unsupported version
#endif
int main(){}
EOF

gcc libmpc-test.c -lgmp -o libmpc-test &> /dev/null
gcc_state=$?
rm -f libmpc-test.c libmpc-test
if [ $gcc_state != 0 ]; then
  if ! [ ${DOWNLOAD} ]; then
    echo "Entweder die Entwicklerpakete für MPC sind nicht installiert oder in einer veralteten Version (< ${NEEDS_MPC_MAJOR}.${NEEDS_MPC_MINOR}.${NEEDS_MPC_PATCHLEVEL})."\
         "Wollen Sie die Pakete von Hand nachinstallieren bzw. updaten ('j' eingeben)? Falls Ihre Distribution keine so aktuellen Pakete zur Verfügung stellt,"\
         "geben Sie bitte 'n' ein und der MPC-Quellcode wird automatisch heruntergeladen und installiert (ohne eine vorhandene Installation von MPC zu beeinträchtigen)"

    read should_die
    [ "$should_die" == "n" ] || die "Fehler: MPC-Bibliothek in Version >= ${NEEDS_MPC_MAJOR}.${NEEDS_MPC_MINOR}.${NEEDS_MPC_PATCHLEVEL} (inklusive -dev Paket) benötigt";
  fi

  BUILD_MPC=1
fi

#Fragen, ob am Ende aufgeräumt werden soll
if ! [ ${CLEANUP} ]; then
  echo "Soll am Schluss wieder aufgeräumt werden? Dadurch wird der temporäre Ordner wird geleert. ('j' eingeben zum aufräumen)"
  read should_clean
  if [ "$should_clean" == "j" ]; then
    CLEANUP=true
  fi
fi


###########################################################################################
#
# Binutils
#

if [ ${FORCE} = true ]; then
  rm -rf ${TMP}/cross-binutils/build* ${TMP}/cross-binutils/binutils-${BINUTILS_VERSION}
fi

mkdir -p ${TMP}/cross-binutils/build-generic
mkdir -p ${TMP}/cross-binutils/build-youros

cd ${TMP}/cross-binutils
echo "[binutils] Version " ${BINUTILS_VERSION}
if ! [ -e binutils-${BINUTILS_VERSION} ]; then
	echo "[binutils] Herunterladen..."
	[ -f binutils-${BINUTILS_VERSION}.tar.bz2 ] || wget -q https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.bz2 || die "Fehler beim Herunterladen."
	echo "[binutils] Entpacken..."
	tar -xjf binutils-${BINUTILS_VERSION}.tar.bz2 || die "Fehler beim Entpacken."
	echo "[binutils] Patch anwenden..."
	patch -p1 -d binutils-${BINUTILS_VERSION}/ < ${PATCHES}/binutils/${BINUTILS_VERSION}.patch > ${LOGS}/binutils.log || die "Fehler beim Patchen.\nSiehe ${LOGS}/binutils.log für Details."
fi

#Target: Generic
if ! [ -f $PREFIX/bin/${TARGET_GENERIC}-ld ] || [ ${FORCE} = true ]; then
cd build-generic
echo "[binutils-generic] Konfigurieren..."
../binutils-${BINUTILS_VERSION}/configure --prefix="${PREFIX}" --target=${TARGET_GENERIC} --with-sysroot=${PREFIX} --disable-nls >> ${LOGS}/binutils-generic.log || die "Fehler beim Konfigurieren.\nSiehe ${LOGS}/binutils-generic.log für Details."
echo "[binutils-generic] Kompilieren..."
make ${MAKEOPTS} &>> ${LOGS}/binutils-generic.log || die "Fehler beim Kompilieren.\nSiehe ${LOGS}/binutils-generic.log für Details."
echo "[binutils-generic] Installieren..."
make install ${MAKEOPTS} &>> ${LOGS}/binutils-generic.log || die "Fehler beim Installieren.\nSiehe ${LOGS}/binutils-generic.log für Details."
echo -e "[binutils-generic] Abgeschlossen\n"
cd ..
fi

# Target: YourOS
if ! [ -f $PREFIX/bin/${TARGET_YOUROS}-ld ] || [ ${FORCE} = true ]; then
cd build-youros
echo "[binutils-youros] Konfigurieren..."
../binutils-${BINUTILS_VERSION}/configure --prefix="${PREFIX}" --target=${TARGET_YOUROS} --with-sysroot=${PREFIX} --disable-nls >> ${LOGS}/binutils-youros.log || die "Fehler beim Konfigurieren.\nSiehe ${LOGS}/binutils-youros.log für Details."
echo "[binutils-youros] Kompilieren..."
make ${MAKEOPTS} &>> ${LOGS}/binutils-youros.log || die "Fehler beim Kompilieren.\nSiehe ${LOGS}/binutils-youros.log für Details."
echo "[binutils-youros] Installieren..."
make install ${MAKEOPTS} &>> ${LOGS}/binutils-youros.log || die "Fehler beim Installieren.\nSiehe ${LOGS}/binutils-youros.log für Details."
echo -e "[binutils-youros] Abgeschlossen\n"
fi

#
# GCC
#
# GCC herunterladen und entpacken
if [ ${FORCE} = true ]; then
  rm -rf ${TMP}/cross-gcc/build* ${TMP}/cross-gcc/gcc-${GCC_VERSION}/
  rm -f ${PREFIX}/include/limits.h
fi

mkdir -p ${TMP}/cross-gcc/build-generic
mkdir -p ${TMP}/cross-gcc/build-youros

cd ${TMP}/cross-gcc
echo "[gcc] Version " ${GCC_VERSION}
if ! [ -e gcc-${GCC_VERSION} ]; then
	echo "[gcc] Herunterladen..."
	[ -f gcc-${GCC_VERSION}.tar.gz ] || wget -q https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz || die "Fehler beim Herunterladen."
	echo "[gcc] Entpacken..."
	tar -xf gcc-${GCC_VERSION}.tar.gz || die "Fehler beim Entpacken."

	# GCC patchen
	echo "[gcc] Patch anwenden..."
	patch -p1 -d gcc-${GCC_VERSION}/ < ${PATCHES}/gcc/${GCC_VERSION}.patch > ${LOGS}/gcc.log || die "Fehler beim Patchen.\nSiehe ${LOGS}/gcc.log für Details."
fi

# Zusätzlich benötigte Libraries runterladen und compilieren
if ! [ -z ${BUILD_GMP} ] && ! [ -e ${TMP}/cross-gcc/gcc-${GCC_VERSION}/gmp ]; then
  echo "[gmp] Version " ${GMP_VERSION}
  echo "[gmp] Herunterladen..."
  [ -f gmp-${GMP_VERSION}.tar.bz2 ] || wget -q https://ftp.gnu.org/gnu/gmp/gmp-${GMP_VERSION}.tar.bz2 || die "Fehler beim Herunterladen."
  echo "[gmp] Entpacken..."
  (tar -xjf gmp-${GMP_VERSION}.tar.bz2 && mv gmp-${GMP_VERSION} ${TMP}/cross-gcc/gcc-${GCC_VERSION}/gmp ) || die "Fehler beim Entpacken."
fi

if ! [ -z ${BUILD_MPFR} ] && ! [ -e ${TMP}/cross-gcc/gcc-${GCC_VERSION}/mpfr ]; then
  echo "[mpfr] Version " ${MPFR_VERSION}
  echo "[mpfr] Herunterladen..."
  [ -f mpfr-${MPFR_VERSION}.tar.bz2 ] || wget -q https://www.mpfr.org/mpfr-${MPFR_VERSION}/mpfr-${MPFR_VERSION}.tar.bz2 || die "Fehler beim Herunterladen."
  echo "[mpfr] Entpacken..."
  (tar -xjf mpfr-${MPFR_VERSION}.tar.bz2 && mv mpfr-${MPFR_VERSION} ${TMP}/cross-gcc/gcc-${GCC_VERSION}/mpfr ) || die "Fehler beim Entpacken."
fi

if ! [ -z ${BUILD_MPC} ] && ! [ -e ${TMP}/cross-gcc/gcc-${GCC_VERSION}/mpc ]; then
  echo "[mpc] Version " ${MPC_VERSION}
  echo "[mpc] Herunterladen..."
  [ -f mpc-${MPC_VERSION}.tar.gz ] || wget -q https://ftp.gnu.org/gnu/mpc/mpc-${MPC_VERSION}.tar.gz || die "Fehler beim Herunterladen."
  echo "[mpc] Entpacken..."
  (tar -xf mpc-${MPC_VERSION}.tar.gz && mv mpc-${MPC_VERSION} ${TMP}/cross-gcc/gcc-${GCC_VERSION}/mpc ) || die "Fehler beim Entpacken."
fi

# Target Generic
if [ ! -f $PREFIX/bin/${TARGET_GENERIC}-gcc ] || [ ${FORCE} = true ]; then
cd build-generic
echo "[gcc-generic] Konfigurieren..."
export MAKEINFO=missing
../gcc-${GCC_VERSION}/configure --prefix="${PREFIX}" --target=${TARGET_GENERIC} --disable-nls --enable-languages=c --without-headers ${GCC_CONFIGURE_PARAMS} ${GCC_CONFIGURE_PARAMS_GENERIC} &>> ${LOGS}/gcc-generic.log || die "Fehler beim Konfigurieren.\nSiehe ${LOGS}/gcc-generic.log für Details."
echo "[gcc-generic] Kompilieren..."
make all-gcc ${MAKEOPTS} &>> ${LOGS}/gcc-generic.log || die "Fehler beim Kompilieren.\nSiehe ${LOGS}/gcc-generic.log für Details."
echo "[gcc-generic] Kompilieren (libgcc)..."
make all-target-libgcc ${MAKEOPTS} &>> ${LOGS}/gcc-generic.log || die "Fehler beim Kompilieren der libgcc.\nSiehe ${LOGS}/gcc-generic.log für Details."
echo "[gcc-generic] Installieren..."
make install-gcc ${MAKEOPTS} &>> ${LOGS}/gcc-generic.log || die "Fehler beim Installieren.\nSiehe ${LOGS}/gcc-generic.log für Details."
echo "[gcc-generic] Installieren (libgcc)..."
make install-target-libgcc ${MAKEOPTS} &>> ${LOGS}/gcc-generic.log || die "Fehler beim Installieren der libgcc.\nSiehe ${LOGS}/gcc-generic.log für Details."
echo -e "[gcc-generic] Abgeschlossen\n"
cd ..
fi

# Target YourOS
if ! [ -f $PREFIX/bin/${TARGET_YOUROS}-gcc ] || [ ${FORCE} = true ]; then
cd build-youros
echo "[gcc-youros] Konfigurieren..."
export MAKEINFO=missing
../gcc-${GCC_VERSION}/configure --prefix="${PREFIX}" --target=${TARGET_YOUROS} --with-sysroot=${PREFIX} --disable-nls --enable-languages=c --disable-shared --disable-libssp ${GCC_CONFIGURE_PARAMS} ${GCC_CONFIGURE_PARAMS_YOUROS} &>> ${LOGS}/gcc-youros.log || die "Fehler beim Konfigurieren.\nSiehe ${LOGS}/gcc-youros.log für Details."
echo "[gcc-youros] Kompilieren..."
make all-gcc ${MAKEOPTS} &>> ${LOGS}/gcc-youros.log || die "Fehler beim Kompilieren.\nSiehe ${LOGS}/gcc-youros.log für Details."
echo "[gcc-youros] Kompilieren (libgcc)..."
make all-target-libgcc ${MAKEOPTS} &>> ${LOGS}/gcc-youros.log || die "Fehler beim Kompilieren der libgcc.\nSiehe ${LOGS}/gcc-youros.log für Details."
echo "[gcc-youros] Installieren..."
make install-gcc ${MAKEOPTS} &>> ${LOGS}/gcc-youros.log || die "Fehler beim Installieren.\nSiehe ${LOGS}/gcc-youros.log für Details."
echo "[gcc-youros] Installieren (libgcc)..."
make install-target-libgcc ${MAKEOPTS} &>> ${LOGS}/gcc-youros.log || die "Fehler beim Installieren der libgcc.\nSiehe ${LOGS}/gcc-youros.log für Details."
echo -e "[gcc-youros] Abgeschlossen\n"
fi

#Aufräumen
if [ ${CLEANUP} = true ]; then
	echo "Räume auf..."
	rm -r -f ${TMP}/*
fi

touch ${CURRENT_DIR}/crosstools_installed

