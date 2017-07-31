rm -rf $DIR
mkdir -p $DIR/{bin,licenses}

#copy the main content
cp -r $BASE/src/Emul8/{scripts,platforms,.emul8root} $DIR
cp -r $BASE/output/bin/$TARGET/*.{dll,exe,dll.config} $DIR/bin
cp -r $BASE/{scripts,platforms} $DIR


#copy the licenses
#some files already include the library name
find $BASE/src/Emul8/{Emulator,External} $BASE/resources  $BASE/tools/packaging/macos -iname "*-license" -exec cp {} $DIR/licenses \;

#others will need a parent directory name.
find $BASE/{src/Emul8,resources} -iname "license" -print0 |\
    while IFS= read -r -d $'\0' file
do
    full_dirname=${file%/*}
    dirname=${full_dirname##*/}
    cp $file $DIR/licenses/$dirname-license
done

