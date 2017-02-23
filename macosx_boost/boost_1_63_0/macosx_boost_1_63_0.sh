#! /bin/bash
#
#===============================================================================
# Filename:  macosx_boost_1_63_0.sh
# Author:    Pete Goodliffe, Daniel Rosser, Kinder Li
# Copyright: (c) Copyright 2009 Pete Goodliffe, 2013-2015 Daniel Rosser, 2017 Kinder Li
# Licence:   Please feel free to use this, with attribution
#===============================================================================
#
# Builds a Boost framework for the MacOSX.
# Creates a set of universal libraries that can be used on an MacOSX.
# Then creates a pseudo-framework to make using boost in Xcode
# less painful.
#
# To configure the script, define:
#    BOOST_LIBS:        which libraries to build
#    MACOSX_SDKVERSION: MacOSX SDK version (e.g. 8.0)
#
# Then go get the source tar.bz of the boost you want to build, shove it in the
# same directory as this script, and run "./boost.sh". Grab a cuppa. And voila.
#===============================================================================
here="`dirname \"$0\"`"
echo "cd-ing to $here"
cd "$here" || exit 1

CPPSTD=c++11    #c++89, c++99, c++14
STDLIB=libc++   # libstdc++
COMPILER=clang++
PARALLEL_MAKE=16   # how many threads to make boost with

BOOST_V1=1.63.0
BOOST_V2=1_63_0

#BITCODE="-fembed-bitcode"  # Uncomment this line for Bitcode generation

CURRENTPATH=`pwd`
MACOSX_MIN_VERSION=10.9
SDKVERSION=`xcrun -sdk macosx --show-sdk-version`
DEVELOPER=`xcode-select -print-path`
XCODE_ROOT=`xcode-select -print-path`

if [ ! -d "$DEVELOPER" ]; then
  echo "xcode path is not set correctly $DEVELOPER does not exist (most likely because of xcode > 4.3)"
  echo "run"
  echo "sudo xcode-select -switch <xcode path>"
  echo "for default installation:"
  echo "sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

case $DEVELOPER in
     *\ * )
           echo "Your Xcode path contains whitespaces, which is not supported."
           exit 1
          ;;
esac

case $CURRENTPATH in
     *\ * )
           echo "Your path contains whitespaces, which is not supported by 'make install'."
           exit 1
          ;;
esac

: ${BOOST_LIBS:="atomic regex graph random chrono thread signals filesystem system date_time"}
: ${MACOSX_SDKVERSION:=`xcodebuild -showsdks | grep macOS | egrep "[[:digit:]]+\.[[:digit:]]+" -o | tail -1`}
: ${EXTRA_CPPFLAGS:="-fPIC -DBOOST_SP_USE_SPINLOCK -std=$CPPSTD -stdlib=$STDLIB -mmacosx-version-min=$MACOSX_MIN_VERSION $BITCODE -fvisibility=hidden -fvisibility-inlines-hidden"}

: ${TARBALLDIR:=`pwd`}
: ${SRCDIR:=`pwd`/build/src}
: ${MACOSX_BUILD_DIR:=`pwd`/build/lib}
: ${PREFIXDIR:=`pwd`/build/prefix}
: ${COMPILER:="clang++"}

: ${OUTPUT_DIR_LIBS:=`pwd`/../libs}
: ${OUTPUT_DIR_LIB:=`pwd`/../lib}
: ${OUTPUT_DIR_SRC:=`pwd`/../include}
: ${MACOSX_FRAMEWORK_DIR:=`pwd`/../framework}

: ${BOOST_VERSION:=$BOOST_V1}
: ${BOOST_VERSION2:=$BOOST_V2}

BOOST_TARBALL=$TARBALLDIR/boost_$BOOST_VERSION2.tar.bz2
BOOST_SRC=$SRCDIR/boost_${BOOST_VERSION2}
BOOST_INCLUDE=$BOOST_SRC/boost



#===============================================================================
MAC_DEV_CMD="xcrun --sdk macosx"

#===============================================================================


#===============================================================================
# Functions
#===============================================================================

abort()
{
    echo
    echo "Aborted: $@"
    exit 1
}

doneSection()
{
    echo
    echo "================================================================="
    echo "Done"
    echo
}

#===============================================================================

cleanEverythingReadyToStart()
{
    echo Cleaning everything before we start to build...

    rm -rf $OUTPUT_DIR_SRC
    rm -rf $OUTPUT_DIR_LIBS
    rm -rf $OUTPUT_DIR_LIB
    rm -rf $TARBALLDIR/build
    rm -rf $MACOSX_FRAMEWORK_DIR

    doneSection
}

postcleanEverything()
{
	echo Cleaning everything after the build...
    rm -rf $TARBALLDIR/build
	doneSection
}

prepare()
{

    mkdir -p $OUTPUT_DIR_SRC
    mkdir -p $OUTPUT_DIR_LIBS
    mkdir -p $OUTPUT_DIR_LIB

}

#===============================================================================

downloadBoost()
{
    if [ ! -s $TARBALLDIR/boost_${BOOST_VERSION2}.tar.bz2 ]; then
        echo "Downloading boost ${BOOST_VERSION}"
        curl -L -o $TARBALLDIR/boost_${BOOST_VERSION2}.tar.bz2 http://sourceforge.net/projects/boost/files/boost/${BOOST_VERSION}/boost_${BOOST_VERSION2}.tar.bz2/download
    fi

    doneSection
}

#===============================================================================

unpackBoost()
{
    [ -f "$BOOST_TARBALL" ] || abort "Source tarball missing."

    echo Unpacking boost into $SRCDIR...

    [ -d $SRCDIR ]    || mkdir -p $SRCDIR
    [ -d $BOOST_SRC ] || ( cd $SRCDIR; tar xfj $BOOST_TARBALL )
    [ -d $BOOST_SRC ] && echo "    ...unpacked as $BOOST_SRC"

    doneSection
}

#===============================================================================

restoreBoost()
{
    mv $BOOST_SRC/tools/build/example/user-config.jam.bk $BOOST_SRC/tools/build/example/user-config.jam
}

#===============================================================================

updateBoost()
{

# armv6
#     iPhone
#     iPhone2
#     iPhone3G
#     第一代和第二代iPod Touch
# armv7
#     iPhone4
#     iPhone4S
# armv7s
#     iPhone5
#     iPhone5C
# arm64
#     iPhone5S
#     iPhone6

    echo Updating boost into $BOOST_SRC...
    local CROSS_TOP_MACOSX="${DEVELOPER}/Platforms/MacOSX.platform/Developer"
    local CROSS_SDK_MACOSX="MacOSX${SDKVERSION}.sdk"
    local BUILD_TOOLS="${DEVELOPER}"

    cp $BOOST_SRC/tools/build/example/user-config.jam $BOOST_SRC/tools/build/example/user-config.jam.bk

    cat >> $BOOST_SRC/tools/build/example/user-config.jam <<EOF
using darwin : ${MACOSX_SDKVERSION}~macosx
: $XCODE_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/bin/$COMPILER -arch x86_64 $EXTRA_CPPFLAGS "-isysroot ${CROSS_TOP_MACOSX}/SDKs/${CROSS_SDK_MACOSX}" -I${CROSS_TOP_MACOSX}/SDKs/${CROSS_SDK_MACOSX}/usr/include/
: <striper> <root>$XCODE_ROOT/Platforms/MacOSX.platform/Developer
: <architecture>x86 <target-os>darwin
;
EOF

    doneSection
}

#===============================================================================

inventMissingHeaders()
{
    # These files are missing in the ARM MacOSX SDK, but they are in the simulator.
    # They are supported on the device, so we copy them from x86 SDK to a staging area
    # to use them on ARM, too.
    echo Invent missing headers

    cp $XCODE_ROOT/Platforms/MacOSX.platform/Developer/SDKs/MacOSX${MACOSX_SDKVERSION}.sdk/usr/include/{crt_externs,bzlib}.h $BOOST_SRC
}

#===============================================================================

bootstrapBoost()
{
    cd $BOOST_SRC

    BOOST_LIBS_COMMA=$(echo $BOOST_LIBS | sed -e "s/ /,/g")
    echo "Bootstrapping (with libs $BOOST_LIBS_COMMA)"
    ./bootstrap.sh --with-libraries=$BOOST_LIBS_COMMA

    doneSection
}

#===============================================================================

buildBoostForMacOSX()
{
    cd $BOOST_SRC

    # Install this one so we can copy the includes for the frameworks...


    set +e
    echo "------------------"
    echo "Running b2 for macosx-build stage"
    echo "To see status in realtime check:"
    echo "Please stand by..."
    ./b2 -j${PARALLEL_MAKE} --build-dir=macosx-build -sBOOST_BUILD_USER_CONFIG=$BOOST_SRC/tools/build/example/user-config.jam --stagedir=macosx-build/stage --prefix=$PREFIXDIR --toolset=darwin-${MACOSX_SDKVERSION}~macosx cxxflags="-mmacosx-version-min=$MACOSX_MIN_VERSION -stdlib=$STDLIB $BITCODE" variant=release linkflags="-stdlib=$STDLIB" architecture=x86 target-os=darwin macosx-version=${MACOSX_SDKVERSION} define=_LITTLE_ENDIAN link=static stage

    echo "------------------"
    echo "Running b2 for macosx-build install"
    echo "To see status in realtime check:"
    echo "Please stand by..."
    ./b2 -j${PARALLEL_MAKE} --build-dir=macosx-build -sBOOST_BUILD_USER_CONFIG=$BOOST_SRC/tools/build/example/user-config.jam --stagedir=macosx-build/stage --prefix=$PREFIXDIR --toolset=darwin-${MACOSX_SDKVERSION}~macosx cxxflags="-mmacosx-version-min=$MACOSX_MIN_VERSION -stdlib=$STDLIB $BITCODE" variant=release linkflags="-stdlib=$STDLIB" architecture=x86 target-os=darwin macosx-version=${MACOSX_SDKVERSION} define=_LITTLE_ENDIAN link=static install

    doneSection
}

#===============================================================================

scrunchAllLibsTogetherInOneLibPerPlatform()
{
    cd $BOOST_SRC

	mkdir -p $MACOSX_BUILD_DIR/x86_64/obj

    ALL_LIBS=$(find macosx-build/stage/lib -name "libboost_*.a" | sed -n 's/.*\(libboost_.*.a\)/\1/p' | paste -sd " " -)

    echo Splitting all existing fat binaries...

    for NAME in $ALL_LIBS; do

		$MAC_DEV_CMD lipo "macosx-build/stage/lib/$NAME" -thin x86_64 -o $MACOSX_BUILD_DIR/x86_64/$NAME

    done
    cp -r $PREFIXDIR/lib/*  $OUTPUT_DIR_LIBS/

    echo "Decomposing each architecture's .a files"

    for NAME in $ALL_LIBS; do
        echo Decomposing $NAME...
		(cd $MACOSX_BUILD_DIR/x86_64/obj; ar -x ../$NAME );
    done

    echo "Linking each architecture into an uberlib ($ALL_LIBS => libboost.a )"

    rm $MACOSX_BUILD_DIR/*/libboost.a

    echo ...x86_64
    (cd $MACOSX_BUILD_DIR/x86_64;  $MAC_DEV_CMD ar crus libboost.a obj/*.o; )

    echo "Making fat lib for MACOSX Boost $BOOST_VERSION"
    $MAC_DEV_CMD lipo -create $MACOSX_BUILD_DIR/x86_64/libboost.a \
                      -output $OUTPUT_DIR_LIB/libboost.a

    echo "Completed Fat Lib"
    echo "------------------"

}

#===============================================================================
buildIncludes()
{

    echo "------------------"
    echo "Copying Includes to Final Dir $OUTPUT_DIR_SRC"
    set +e

    cp -r $PREFIXDIR/include/boost  $OUTPUT_DIR_SRC/

    echo "Copy of Includes successful"
    echo "------------------"

    doneSection
}
#===============================================================================
buildFramework()
{
    : ${1:?}
    FRAMEWORKDIR=$1

    VERSION_TYPE=Release
    FRAMEWORK_NAME=boost_${BOOST_VERSION2}
    FRAMEWORK_VERSION=A

    FRAMEWORK_CURRENT_VERSION=$BOOST_VERSION
    FRAMEWORK_COMPATIBILITY_VERSION=$BOOST_VERSION

    FRAMEWORK_BUNDLE=$FRAMEWORKDIR/$FRAMEWORK_NAME.framework
    echo "Framework: Building $FRAMEWORK_BUNDLE from $BUILDDIR..."

    rm -rf $FRAMEWORK_BUNDLE

    echo "Framework: Setting up directories..."
    mkdir -p $FRAMEWORK_BUNDLE
    mkdir -p $FRAMEWORK_BUNDLE/Versions
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Resources
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Headers
    mkdir -p $FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/Documentation

    echo "Framework: Creating symlinks..."
    ln -s $FRAMEWORK_VERSION               $FRAMEWORK_BUNDLE/Versions/Current
    ln -s Versions/Current/Headers         $FRAMEWORK_BUNDLE/Headers
    ln -s Versions/Current/Resources       $FRAMEWORK_BUNDLE/Resources
    ln -s Versions/Current/Documentation   $FRAMEWORK_BUNDLE/Documentation
    ln -s Versions/Current/$FRAMEWORK_NAME $FRAMEWORK_BUNDLE/$FRAMEWORK_NAME

    FRAMEWORK_INSTALL_NAME=$FRAMEWORK_BUNDLE/Versions/$FRAMEWORK_VERSION/$FRAMEWORK_NAME

    echo "Lipoing library into $FRAMEWORK_INSTALL_NAME..."
    $MAC_DEV_CMD lipo -create $MACOSX_BUILD_DIR/*/libboost.a -output "$FRAMEWORK_INSTALL_NAME" || abort "Lipo $1 failed"

    echo "Framework: Copying includes..."
    mkdir -p $FRAMEWORK_BUNDLE/Headers/boost/
    cp -r $PREFIXDIR/include/boost/*  $FRAMEWORK_BUNDLE/Headers/boost

    echo "Framework: Creating plist..."
    cat > $FRAMEWORK_BUNDLE/Resources/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>CFBundleDevelopmentRegion</key>
<string>English</string>
<key>CFBundleExecutable</key>
<string>${FRAMEWORK_NAME}</string>
<key>CFBundleIdentifier</key>
<string>org.boost</string>
<key>CFBundleInfoDictionaryVersion</key>
<string>6.0</string>
<key>CFBundlePackageType</key>
<string>FMWK</string>
<key>CFBundleSignature</key>
<string>????</string>
<key>CFBundleVersion</key>
<string>${FRAMEWORK_CURRENT_VERSION}</string>
</dict>
</plist>
EOF

    doneSection
}


#===============================================================================
# Execution starts here
#===============================================================================

mkdir -p $MACOSX_BUILD_DIR

cleanEverythingReadyToStart #may want to comment if repeatedly running during dev
restoreBoost

echo "BOOST_VERSION:     $BOOST_VERSION"
echo "BOOST_LIBS:        $BOOST_LIBS"
echo "BOOST_SRC:         $BOOST_SRC"
echo "MACOSX_BUILD_DIR:       $MACOSX_BUILD_DIR"
echo "PREFIXDIR:         $PREFIXDIR"
echo "MACOSX_FRAMEWORK_DIR:   $MACOSX_FRAMEWORK_DIR"
echo "MACOSX_SDKVERSION: $MACOSX_SDKVERSION"
echo "XCODE_ROOT:        $XCODE_ROOT"
echo "COMPILER:          $COMPILER"
if [ -z ${BITCODE} ]; then
    echo "BITCODE EMBEDDED: NO $BITCODE"
else
    echo "BITCODE EMBEDDED: YES with: $BITCODE"
fi

downloadBoost
unpackBoost
inventMissingHeaders
prepare
bootstrapBoost
updateBoost
buildBoostForMacOSX
scrunchAllLibsTogetherInOneLibPerPlatform
buildIncludes
buildFramework $MACOSX_FRAMEWORK_DIR

restoreBoost

postcleanEverything

echo "Completed successfully"

#===============================================================================
