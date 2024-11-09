# Copyright 2020 The Bazel Authors. All rights reserved.
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

"""Starlark Android Binary for Android Rules."""

<<<<<<< Updated upstream
load("//rules:acls.bzl", "acls")
=======
load(":attrs.bzl", "ATTRS")
load(":impl.bzl", "impl")
>>>>>>> Stashed changes
load(
    "//rules:attrs.bzl",
    _attrs = "attrs",
)
<<<<<<< Updated upstream
load("//rules:utils.bzl", "ANDROID_SDK_TOOLCHAIN_TYPE")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(":attrs.bzl", "ATTRS")
load(":impl.bzl", "impl")

visibility(PROJECT_VISIBILITY)
=======
>>>>>>> Stashed changes

_DEFAULT_ALLOWED_ATTRS = ["name", "visibility", "tags", "testonly", "transitive_configs", "$enable_manifest_merging", "features", "exec_properties"]

_DEFAULT_PROVIDES = [AndroidApplicationResourceInfo, OutputGroupInfo]

def make_rule(
        attrs = ATTRS,
        implementation = impl,
        provides = _DEFAULT_PROVIDES,
<<<<<<< Updated upstream
        outputs = _outputs,
=======
>>>>>>> Stashed changes
        additional_toolchains = [],
        additional_providers = []):
    """Makes the rule.

    Args:
      attrs: A dict. The attributes for the rule.
      implementation: A function. The rule's implementation method.
      provides: A list. The providers that the rule must provide.
      additional_toolchains: A list. Additional toolchains passed to pass to rule(toolchains).
      additional_providers: A list. Additional providers passed to pass to rule(providers).

    Returns:
      A rule.
    """
    return rule(
        attrs = attrs,
        implementation = implementation,
        provides = provides + additional_providers,
        toolchains = [
            "//toolchains/android:toolchain_type",
            "//toolchains/android_sdk:toolchain_type",
            "@bazel_tools//tools/jdk:toolchain_type",
        ] + additional_toolchains,
        _skylark_testable = True,
        fragments = [
            "android",
            "bazel_android",
            "java",
            "cpp",
        ],
    )

android_binary_internal = make_rule()

<<<<<<< Updated upstream
# TODO(zhaoqxu): Consider removing this method
=======
>>>>>>> Stashed changes
def sanitize_attrs(attrs, allowed_attrs = ATTRS.keys()):
    """Sanitizes the attributes.

    The android_binary_internal has a subset of the android_binary attributes, but is
    called from the android_binary macro with the same full set of attributes. This removes
    any unnecessary attributes.

    Args:
<<<<<<< Updated upstream
      attrs: A dict. The attributes for the android_binary rule.
=======
      attrs: A dict. The attributes for the android_binary_internal rule.
>>>>>>> Stashed changes
      allowed_attrs: The list of attribute keys to keep.

    Returns:
      A dictionary containing valid attributes.
    """
    for attr_name in list(attrs.keys()):
        if attr_name not in allowed_attrs and attr_name not in _DEFAULT_ALLOWED_ATTRS:
            attrs.pop(attr_name, None)

        # Some teams set this to a boolean/None which works for the native attribute but breaks
        # the Starlark attribute.
        if attr_name == "shrink_resources":
            if attrs[attr_name] == None:
                attrs.pop(attr_name, None)
            else:
                attrs[attr_name] = _attrs.tristate.normalize(attrs[attr_name])

    return attrs

def android_binary_internal_macro(**attrs):
    """android_binary_internal rule.

    Args:
      **attrs: Rule attributes
    """
<<<<<<< Updated upstream

    # Required for ACLs check in _outputs(), since the callback can't access the native module.
    attrs["$package_name"] = native.package_name()

    if type(attrs.get("proguard_specs", None)) == "select" or attrs.get("proguard_specs", None):
        attrs["$generate_proguard_outputs"] = True

    android_binary(
        **sanitize_attrs(
            attrs,
            # _package_name and other attributes are allowed attributes but are also private.
            # We need to allow the $ form of the attribute to stop the sanitize function from
            # removing it.
            allowed_attrs = list(ATTRS.keys()) +
                            [
                                "$package_name",
                                "$rewrite_resources_through_optimizer",
                                "$generate_proguard_outputs",
                            ],
        )
    )
=======
    android_binary_internal(**sanitize_attrs(attrs))
>>>>>>> Stashed changes
