#!/bin/bash --posix
# Copyright 2021 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

out="${1}"
manifest="${2}"
<<<<<<< Updated upstream
apk="${3}"
is_coverage="${4}"
is_java8="${5}"
lib_label="${6}"
xmllint="${7}"
unzip="${8}"
is_asset_pack="${9}"
=======
>>>>>>> Stashed changes

if [[ -n "$manifest" ]]; then
  grep 'dist:title=\"\${MODULE_TITLE}\"' "$manifest"
  if [[ "$?" != 0 ]]; then
    echo ""
    echo "$manifest dist:title should be \${MODULE_TITLE} placeholder"
    echo ""
    exit 1
  fi
fi

# Skip dex validation when running under code coverage.
# When running under code coverage an additional dep is implicitly added to all
# binary targets, causing a validation failure.
if [[ "$is_coverage" == "false" ]]; then
  dexes=$("$unzip" -l "$apk" | grep ".dex" | wc -l)
  if [[ ("$is_java8" == "true" && "$dexes" -gt 1 ) || ( "$is_java8" == "false" && "$dexes" -gt 0)]]; then
    echo ""
    echo "android_feature_module does not support Java or Kotlin sources."
    echo "Check $lib_label for any srcs or deps."
    echo ""
    exit 1
  fi
fi

touch "$out"
