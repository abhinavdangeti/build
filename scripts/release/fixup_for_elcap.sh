#!/bin/bash

set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $(basename $0) <input zip> <output zip>"
    exit 1
fi
input_zip=$1
output_zip=$2

BASE="Couchbase Server.app/Contents/Resources/couchbase-core"

# Extract
temp_dir=$(mktemp -d /tmp/elcap_fixup.XXXXXX)
echo "Extracting..."
unzip -q -o "$input_zip" -d $temp_dir
echo "Extracted to $temp_dir"

## Fix rpaths in various binaries / plugins
echo "Fixing rpaths in binaries / plugins..."

# Plugins to beam.smp ($BASE/lib/erlang/erts-5.10.4.0.0.1/bin/beam.smp) - needs
# $BASE/lib adding to rpath.
install_name_tool -add_rpath @executable_path/../../.. \
    "$temp_dir/$BASE/lib/couchdb/erlang/lib/snappy-1.0.4/priv/snappy_nif.so"
install_name_tool -add_rpath @executable_path/../../.. \
    "$temp_dir/$BASE/lib/couchdb/erlang/lib/mapreduce-1.0/priv/mapreduce_nif.so"

# indexer & gometaexecutable - needs $BASE/lib for libforestdb
install_name_tool -add_rpath @executable_path/../lib \
    "$temp_dir/$BASE/bin/indexer"
install_name_tool -add_rpath @executable_path/../lib \
    "$temp_dir/$BASE/bin/gometa"

# vbuckettool & vbucketkeygen- needs $BASE/lib for libvbucket.dylib
install_name_tool -add_rpath @executable_path/../../lib \
    "$temp_dir/$BASE/bin/tools/vbuckettool"
install_name_tool -add_rpath @executable_path/../../lib \
    "$temp_dir/$BASE/bin/tools/vbucketkeygen"

echo "Fixing rpaths complete"

# Fix python tools - make failure to import libcouchstore non-fatal. Still can't
# use tools which directly operate on couchstore files, but at least the other
# tools (cbdocloader, etc) work.
patch --quiet "$temp_dir/$BASE/lib/python/couchstore.py" <<EOF
--- lib/python/couchstore.py2015-09-18 18:49:33.000000000 +0100
+++ lib/python/couchstore.py2015-10-03 11:04:52.000000000 +0100
@@ -28,8 +28,7 @@
     except OSError, err:
         continue
 else:
-    traceback.print_exc()
-    sys.exit(1)
+    raise ImportError("Failed to locate suitable couchstore shared library")
 
 
 _lib.couchstore_strerror.restype = ctypes.c_char_p
EOF

# Update README.txt
patch --quiet "$temp_dir/README.txt" <<EOF
--- README.txt2015-09-18 18:57:02.000000000 +0100
+++ README.txt2015-10-03 11:55:37.000000000 +0100
@@ -1,4 +1,10 @@
-Couchbase Server
+Couchbase Server - Mac OS X 10.11 (El Capitan) Developer Preview 1
+
+*** This is a developer preview of Couchbase Server 4.0 
+*** for Mac OS X 10.11 “El Capitan”.
+*** “El Capitan” is not yet a Couchbase supported platform. This
+*** developer preview should only be used on OS X 10.11 and only
+*** for testing. See below for known issues.
 
 Couchbase Server is a distributed NoSQL document database for
 interactive applications.  Its scale-out architecture runs in the
@@ -18,3 +24,10 @@
 included with Couchbase Server at:
 
 http://www.couchbase.com/redirect/agreement/3rdparty-license/Couchbase-server/4.0.0
+
+
+KNOWN ISSUES ON OS X 10.11 (El Capitan)
+
+* cbbackup, cbrestore & cbtransfer do not work when the source or
+  destination type is ‘couchstore-files://' [MB-16454]
+ 
EOF

# Package back into a zip file.
echo "Packaging back into $output_zip"
rm -f $output_zip
abs_output_zip=$(pwd)/$output_zip
pushd $temp_dir >/dev/null
zip --quiet --recurse-paths --symlinks -9 $abs_output_zip *
popd >/dev/null

# TEMP copy into Applications
#echo "Copying to /Applications"
#cp -a "$temp_dir/Couchbase Server.app" /Applications/

# Cleanup
rm -fr $temp_dir
