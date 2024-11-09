# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""Attributes."""

load("//rules:android_neverlink_aspect.bzl", "android_neverlink_aspect")
load(
    "//rules:attrs.bzl",
    _attrs = "attrs",
)
load("//rules:dex_desugar_aspect.bzl", "dex_desugar_aspect")
load(
    "//rules:native_deps.bzl",
    "split_config_aspect",
)
load("//rules:providers.bzl", "StarlarkApkInfo")
<<<<<<< Updated upstream
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")

visibility(PROJECT_VISIBILITY)
=======
>>>>>>> Stashed changes

def make_deps(allow_rules, providers, aspects):
    return attr.label_list(
        allow_files = True,
        allow_rules = allow_rules,
        providers = providers,
        aspects = aspects,
        cfg = android_common.multi_cpu_configuration,
    )

DEPS_ALLOW_RULES = [
    "aar_import",
    "android_library",
    "cc_library",
    "java_import",
    "java_library",
    "java_lite_proto_library",
]

DEPS_PROVIDERS = [
    [CcInfo],
    [JavaInfo],
    ["AndroidResourcesInfo", "AndroidAssetsInfo"],
]

DEPS_ASPECTS = [
    dex_desugar_aspect,
    android_neverlink_aspect,
]

ATTRS = _attrs.replace(
    _attrs.add(
        dict(
            srcs = attr.label_list(
                # TODO(timpeut): Set PropertyFlag direct_compile_time_input
                allow_files = [".java", ".srcjar"],
            ),
            deps = make_deps(DEPS_ALLOW_RULES, DEPS_PROVIDERS, DEPS_ASPECTS),
            enable_data_binding = attr.bool(),
            instruments = attr.label(),
            manifest_values = attr.string_dict(),
            manifest_merger = attr.string(
                default = "auto",
                values = ["auto", "legacy", "android", "force_android"],
            ),
            native_target = attr.label(
                allow_files = False,
                allow_rules = ["android_binary", "android_test"],
            ),
            generate_art_profile = attr.bool(
                default = True,
                doc = """
                Whether to generate ART profile. If true, the ART profile will be generated
                and bundled into your APK’s asset directory. During APK installation, Android
                Runtime(ART) will perform Ahead-of-time (AOT) compilation of methods in the
                profile, speeding up app startup time or reducing jank in some circumstances.
                """,
            ),
            startup_profiles = attr.label_list(
                allow_empty = True,
                allow_files = [".txt"],
                doc = """
                List of baseline profiles that were collected at runtime (often from start-up) for
                this binary. When this is specified, all baseline profiles (including these) are
                used to inform code optimizations in the build toolchain. This may improve runtime
                performance at the cost of dex size. If the dex size cost is too large and the
                performance wins too small, the same profiles can be provided as a dep from an
                android_library with `baseline_profiles` to avoid the runtime-focused code
                optimizations that are enabled by `startup_profiles`.
                """,
            ),
            proguard_specs = attr.label_list(allow_empty = True, allow_files = True),
            # SNAP: Snap-specific mechanism for providing a startup profile that avoids
            # the profile expansion and merging performed by upstream `startup_profiles`
            startup_profile = attr.label(
                mandatory = False,
                allow_single_file = True,
                default = None,
                doc = "ART Startup profile to provide to R8 for PGO",
            ),
            baseline_profile = attr.label(
                mandatory = False,
                allow_single_file = True,
                default = None,
                doc = "ART Baseline profile to provide to R8 for PGO",
            ),
            compiler_dump = attr.string(
                default = "off",
                values = ["off", "on", "dump_only"],
                doc = """
                Whether to generate an R8 compiler dump or not.
                The file will be outputted as `target_dump.zip`.
                off: Don't generate compiler dump (default)
                on: Generate APK + Compiler Dump
                dump_only: Generate Compiler Dump Only (faster, but the build will eventually fail)
                """,
            ),
            r8_jvm_args = attr.string_list(doc = "JVM Args to pass into R8."),
            resource_apks = attr.label_list(
                allow_rules = ["apk_import"],
                providers = [
                    [StarlarkApkInfo],
                ],
                doc = (
                    "List of resource only apks to link against."
                ),
            ),
            resource_configuration_filters = attr.string_list(),
            densities = attr.string_list(),
            nocompress_extensions = attr.string_list(),
            shrink_resources = _attrs.tristate.create(
                default = _attrs.tristate.auto,
            ),
            dexopts = attr.string_list(),
            main_dex_list = attr.label(allow_single_file = True),
            main_dex_list_opts = attr.string_list(),
            main_dex_proguard_specs = attr.label_list(allow_empty = True, allow_files = True),
            min_sdk_version = attr.int(),
            incremental_dexing = _attrs.tristate.create(
                default = _attrs.tristate.auto,
            ),
            proguard_generate_mapping = attr.bool(default = False),
            proguard_optimization_passes = attr.int(),
            proguard_apply_mapping = attr.label(allow_single_file = True),
            multidex = attr.string(
                default = "native",
                values = ["native", "legacy", "manual_main_dex"],
            ),
            _java_toolchain = attr.label(
                default = Label("//tools/jdk:toolchain_android_only"),
            ),
            _defined_resource_files = attr.bool(default = False),
            _enable_manifest_merging = attr.bool(default = True),
            _cc_toolchain_split = attr.label(
                cfg = android_common.multi_cpu_configuration,
                default = "@bazel_tools//tools/cpp:current_cc_toolchain",
                aspects = [split_config_aspect],
            ),
            _optimizing_dexer = attr.label(
                cfg = "exec",
                allow_single_file = True,
                default = configuration_field(
                    fragment = "android",
                    name = "optimizing_dexer",
                ),
            ),
            _desugared_java8_legacy_apis = attr.label(
                default = Label("//tools/android:desugared_java8_legacy_apis"),
                allow_single_file = True,
            ),
            _bytecode_optimizer = attr.label(
                default = configuration_field(
                    fragment = "java",
                    name = "bytecode_optimizer",
                ),
                cfg = "exec",
                executable = True,
            ),
            _legacy_main_dex_list_generator = attr.label(
                default = configuration_field(
                    fragment = "android",
                    name = "legacy_main_dex_list_generator",
                ),
                cfg = "exec",
                executable = True,
            ),
            _enable_manifest_merging_dependency_priorities = attr.label(
                doc = """When enabled respect the manifest priorities during manifest merging.""",
                default = "//rules/flags:enable_manifest_merging_dependency_priorities",
            ),
        ),
        _attrs.COMPILATION,
        _attrs.DATA_CONTEXT,
        _attrs.ANDROID_TOOLCHAIN_ATTRS,
        _attrs.AUTOMATIC_EXEC_GROUPS_ENABLED,
    ),
    # TODO(b/167599192): don't override manifest attr to remove .xml file restriction.
    manifest = attr.label(
        allow_single_file = True,
    ),
)
