#!/usr/bin/env bash

set -x

if [[ "$(uname)" == 'Linux' ]]; then
    _os_name=linux

    install -D /bin/sed $BUILD_PREFIX/bin/sed

    # Install gtk-sharp2
    install -D /usr/lib/cli/gtk-sharp-2.0/gtk-sharp.dll* $BUILD_PREFIX/lib/mono/4.5-api/
    install -D /usr/lib/cli/glib-sharp-2.0/glib-sharp.dll* $BUILD_PREFIX/lib/mono/4.5-api/
    install -D /usr/lib/cli/atk-sharp-2.0/atk-sharp.dll* $BUILD_PREFIX/lib/mono/4.5-api/
    install -D /usr/lib/cli/gdk-sharp-2.0/gdk-sharp.dll* $BUILD_PREFIX/lib/mono/4.5-api/
    install -D /usr/lib/cli/pango-sharp-2.0/pango-sharp.dll* $BUILD_PREFIX/lib/mono/4.5-api/


    mkdir -p $PREFIX/opt/renode/bin
    cp /usr/lib/cli/gtk-sharp-2.0/gtk-sharp.dll* $PREFIX/opt/renode/bin/
    cp /usr/lib/cli/glib-sharp-2.0/glib-sharp.dll* $PREFIX/opt/renode/bin/
    cp /usr/lib/cli/atk-sharp-2.0/atk-sharp.dll* $PREFIX/opt/renode/bin/
    cp /usr/lib/cli/gdk-sharp-2.0/gdk-sharp.dll* $PREFIX/opt/renode/bin/
    cp /usr/lib/cli/pango-sharp-2.0/pango-sharp.dll* $PREFIX/opt/renode/bin/

    mkdir -p $PREFIX/lib/
    install -D /usr/lib/cli/gtk-sharp-2.0/libgtksharpglue-2.so $PREFIX/lib/libgtksharpglue-2.so
    install -D /usr/lib/cli/gdk-sharp-2.0/libgdksharpglue-2.so $PREFIX/lib/libgdksharpglue-2.so
    install -D /usr/lib/cli/glib-sharp-2.0/libglibsharpglue-2.so $PREFIX/lib/libglibsharpglue-2.so
    install -D /usr/lib/x86_64-linux-gnu/gtk-2.0/modules/libatk-bridge.so $PREFIX/lib/libatk-bridge.so

    sed -i 's/\/usr\/lib\/cli\/.*-sharp-2.0\///g' $PREFIX/opt/renode/bin/*.dll.config
else
    _os_name=macos

    cp /Library/Frameworks/Mono.framework/Libraries/libatksharpglue-2* $PREFIX/lib/
    cp /Library/Frameworks/Mono.framework/Libraries/libgtksharpglue-2* $PREFIX/lib/
    cp /Library/Frameworks/Mono.framework/Libraries/libgdksharpglue-2* $PREFIX/lib/
    cp /Library/Frameworks/Mono.framework/Libraries/libglibsharpglue-2* $PREFIX/lib/

    mkdir -p $BUILD_PREFIX/lib/mono/4.5-api/
    find /Library/Frameworks/Mono.framework/Versions/5*/lib/mono/* -name 'gtk-sharp.dll*' -exec cp '{}' $BUILD_PREFIX/lib/mono/4.5-api/ ';'
    find /Library/Frameworks/Mono.framework/Versions/5*/lib/mono/* -name 'gdk-sharp.dll*' -exec cp '{}' $BUILD_PREFIX/lib/mono/4.5-api/ ';'
    find /Library/Frameworks/Mono.framework/Versions/5*/lib/mono/* -name 'atk-sharp.dll*' -exec cp '{}' $BUILD_PREFIX/lib/mono/4.5-api/ ';'
    find /Library/Frameworks/Mono.framework/Versions/5*/lib/mono/* -name 'glib-sharp.dll*' -exec cp '{}' $BUILD_PREFIX/lib/mono/4.5-api/ ';'
    find /Library/Frameworks/Mono.framework/Versions/5*/lib/mono/* -name 'pango-sharp.dll*' -exec cp '{}' $BUILD_PREFIX/lib/mono/4.5-api/ ';'
    cp /usr/lib/libc.dylib $PREFIX/lib/
fi

./build.sh

mkdir -p $PREFIX/opt/renode/bin
mkdir -p $PREFIX/opt/renode/scripts
mkdir -p $PREFIX/opt/renode/platforms
mkdir -p $PREFIX/opt/renode/tests
mkdir -p $PREFIX/opt/renode/tools
mkdir -p $PREFIX/opt/renode/licenses


cp .renode-root $PREFIX/opt/renode/
cp -r output/bin/Release/* $PREFIX/opt/renode/bin/
cp -r scripts/* $PREFIX/opt/renode/scripts/
cp -r platforms/* $PREFIX/opt/renode/platforms/
cp -r tests/* $PREFIX/opt/renode/tests/
cp -r tools/metrics_analyzer $PREFIX/opt/renode/tools
cp -r tools/execution_tracer $PREFIX/opt/renode/tools
cp -r tools/gdb_compare $PREFIX/opt/renode/tools
cp -r tools/sel4_extensions $PREFIX/opt/renode/tools

cp lib/resources/styles/robot.css $PREFIX/opt/renode/tests


tools/packaging/common_copy_licenses.sh $PREFIX/opt/renode/licenses $_os_name


sed -i.bak "s#os\.path\.join(this_path, '\.\./lib/resources/styles/robot\.css')#os.path.join(this_path,'robot.css')#g" $PREFIX/opt/renode/tests/robot_tests_provider.py
rm $PREFIX/opt/renode/tests/robot_tests_provider.py.bak

mkdir -p $PREFIX/bin/

cat > $PREFIX/bin/renode <<"EOF"
#!/usr/bin/env bash

mono $MONO_OPTIONS $CONDA_PREFIX/opt/renode/bin/Renode.exe "$@"
EOF

cat > $PREFIX/bin/renode-test <<"EOF"
#!/usr/bin/env bash

STTY_CONFIG=`stty -g 2>/dev/null`
python3 $CONDA_PREFIX/opt/renode/tests/run_tests.py --robot-framework-remote-server-full-directory $CONDA_PREFIX/opt/renode/bin "$@"
RESULT_CODE=$?
if [ -n "${STTY_CONFIG:-}" ]
then
    trap "" SIGTTOU
    stty "$STTY_CONFIG"
    trap - SIGTTOU
fi
exit $RESULT_CODE
EOF

mkdir -p "${PREFIX}/etc/conda/activate.d"
cp "${RECIPE_DIR}/activate.sh" "${PREFIX}/etc/conda/activate.d/${PKG_NAME}_activate.sh"

