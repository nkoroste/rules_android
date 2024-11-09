# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""R8 processor steps for android_binary_internal."""

load("//rules:acls.bzl", "acls")
load("//rules:proguard.bzl", "proguard")
load(
    "//rules:utils.bzl",
    "ANDROID_TOOLCHAIN_TYPE",
    "get_android_sdk",
    "get_android_toolchain",
    "utils",
    _log = "log",
)
load(
    "//rules:processing_pipeline.bzl",
    "ProviderInfo",
)
load("//rules:common.bzl", "common")
load("//rules:java.bzl", "java")
load("//rules:resources.bzl", _resources = "resources")

def _process(ctx, deploy_jar, proguard_specs, baseline_profile = None, startup_profile = None, rewritten_baseline_profile = None, feature_split_jars = {}, compiler_dump = "off", r8_jvm_args = []):
    """Runs R8 for desugaring, optimization, and dexing.
    Args:
      ctx: Rule contxt.
      deploy_jar: The deploy jar from java compilation..
      feature_split_jars: [optional] Dictionary of feature module jars to outputs.

    Returns:
      A AndroidDexInfo provider.
    """
    dexes_zip = ctx.actions.declare_file(ctx.label.name + "_dexes.zip")

    android_jar = get_android_sdk(ctx).android_jar

    inputs = [android_jar, deploy_jar] + proguard_specs
    outputs = [dexes_zip]

    min_sdk_version = getattr(ctx.attr, "min_sdk_version")
    if not min_sdk_version:
        min_sdk_version = 21
    args = ctx.actions.args()
    args.add("--release")
    if min_sdk_version:
        args.add("--min-api", min_sdk_version)
    args.add("--output", dexes_zip)
    args.add_all(proguard_specs, before_each = "--pg-conf")
    args.add("--lib", android_jar)

    for feature_jar in feature_split_jars:
        args.add("--feature", feature_jar)
        args.add(feature_split_jars[feature_jar].path)
        inputs.append(feature_jar)
        outputs.append(feature_split_jars[feature_jar])

    args.add(deploy_jar)  # jar to optimize + desugar + dex

    proguard_output_map = ctx.actions.declare_file(ctx.label.name + "_proguard.map")
    args.add("--pg-map-output", proguard_output_map)
    outputs.append(proguard_output_map)

    if startup_profile:
        args.add("--startup-profile", startup_profile)
        inputs.append(startup_profile)

    if baseline_profile:
        args.add("--art-profile", baseline_profile)
        args.add(rewritten_baseline_profile)
        inputs.append(baseline_profile)
        outputs.append(rewritten_baseline_profile)

    if compiler_dump != "off":
        dump_zip = ctx.actions.declare_file(ctx.label.name + "_dump.zip")

        dump_outputs = [dump_zip]

        # Skip generating the Dex files for APK (build will ultimately fail, but saves ~15 minutes)
        if compiler_dump == "dump_only":
            dump_outputs.extend(outputs)

        # Note: R8 will exit immediately after dumping
        java.run(
            ctx = ctx,
            host_javabase = common.get_host_javabase(ctx),
            executable = get_android_toolchain(ctx).r8.files_to_run,
            arguments = [args],
            inputs = inputs,
            outputs = dump_outputs,
            jvm_flags = [
                "-Xms8g",
                "-Xmx8g",
                "-Dcom.android.tools.r8.dumpinputtofile=%s" % dump_zip.path,
            ] + r8_jvm_args,
            mnemonic = "AndroidR8CompilerDump",
            progress_message = "R8 Generating Compiler Dump %{label}",
        )

        inputs.append(dump_zip)

        if compiler_dump == "dump_only":
            return AndroidDexInfo(
                deploy_jar = deploy_jar,
                final_classes_dex_zip = dexes_zip,
                final_proguard_output_map = proguard_output_map,
                # R8 preserves the Java resources (i.e. non-Java-class files) in its output zip, so no need
                # to provide a Java resources zip.
                java_resource_jar = None,
            )

    java.run(
        ctx = ctx,
        host_javabase = common.get_host_javabase(ctx),
        executable = get_android_toolchain(ctx).r8.files_to_run,
        arguments = [args],
        inputs = inputs,
        outputs = outputs,
        jvm_flags = [
            "-Xms8g",
            "-Xmx8g",
        ] + r8_jvm_args,
        mnemonic = "AndroidR8",
        progress_message = "R8 Optimizing, Desugaring, and Dexing %{label}",
    )

    android_dex_info = AndroidDexInfo(
        deploy_jar = deploy_jar,
        final_classes_dex_zip = dexes_zip,
        final_proguard_output_map = proguard_output_map,
        # R8 preserves the Java resources (i.e. non-Java-class files) in its output zip, so no need
        # to provide a Java resources zip.
        java_resource_jar = None,
    )
    return android_dex_info

def _process_resource_shrinking(ctx, final_classes_dex_zip, final_proguard_output_map, resources_apk, android_application_resource, feature_split_jars = {}, raw_resources = []):
    """Runs resource shrinking.
    Args:
      ctx: Rule contxt.
      final_classes_dex_zip: Zip file with the final optimized dex files generated by R8.
      resources_apk: The resource apk generated during resource processing.
      android_application_resource: The android_application resources info.
    Returns:
      An AndroidApplicationResourcesInfo.
    """
    local_proguard_specs = ctx.files.proguard_specs
    if (not acls.use_r8(str(ctx.label)) or
        not local_proguard_specs or
        not _resources.is_resource_shrinking_enabled(
            ctx.attr.shrink_resources,
            ctx.fragments.android.use_android_resource_shrinking,
        )):
        return None

    android_toolchain = get_android_toolchain(ctx)

    # 1. Convert the resource APK to proto format (resource shrinker operates on a proto apk)
    proto_resource_apk = ctx.actions.declare_file(ctx.label.name + "_proto_resource_apk.ap_")
    ctx.actions.run(
        arguments = [ctx.actions.args()
            .add("convert")
            .add(resources_apk)  # input apk
            .add("-o", proto_resource_apk)  # output apk
            .add("--output-format", "proto")],
        executable = android_toolchain.aapt2.files_to_run,
        inputs = [resources_apk],
        mnemonic = "Aapt2ConvertToProtoForResourceShrinkerR8",
        outputs = [proto_resource_apk],
        toolchain = ANDROID_TOOLCHAIN_TYPE,
    )

    # 2. Run the resource shrinker
    proto_resource_apk_shrunk = ctx.actions.declare_file(
        ctx.label.name + "_proto_resource_apk_shrunk.ap_",
    )

    resource_shrinking_usage_log = ctx.actions.declare_file(ctx.label.name + "_resource_shrinking_usage.log")
    resource_shrinking_res_config = ctx.actions.declare_file(ctx.label.name + "_resources.cfg")
    args = ctx.actions.args()
    args.add("--input", proto_resource_apk)
    args.add("--dex_input", final_classes_dex_zip)
    for feature_split in feature_split_jars:
        args.add("--dex_input", feature_split_jars[feature_split].path)

    args.add("--proguard_mapping", final_proguard_output_map)
    args.add("--output", proto_resource_apk_shrunk)
    args.add("--precise_shrinking", "true")
    args.add("--print_usage_log", resource_shrinking_usage_log)
    args.add("--print_config", resource_shrinking_res_config)
    args.add_all(raw_resources, before_each = "--raw_resources")

    java.run(
        ctx = ctx,
        host_javabase = common.get_host_javabase(ctx),
        executable = android_toolchain.resource_shrinker.files_to_run,
        arguments = [args],
        inputs = [proto_resource_apk, final_classes_dex_zip, final_proguard_output_map] + raw_resources + feature_split_jars.values(),
        outputs = [proto_resource_apk_shrunk, resource_shrinking_usage_log, resource_shrinking_res_config],
        mnemonic = "ResourceShrinkerForR8",
        progress_message = "Shrinking resources %{label}",
    )

    # 3. Convert back to a binary APK
    resource_apk_shrunk = ctx.actions.declare_file(ctx.label.name + "_resource_apk_shrunk.ap_")
    ctx.actions.run(
        arguments = [ctx.actions.args()
            .add("convert")
            .add(proto_resource_apk_shrunk)  # input apk
            .add("-o", resource_apk_shrunk)  # output apk
            .add("--output-format", "binary")],
        executable = android_toolchain.aapt2.files_to_run,
        inputs = [proto_resource_apk_shrunk],
        mnemonic = "Aapt2ConvertBackToBinaryForResourceShrinkerR8",
        outputs = [resource_apk_shrunk],
        toolchain = ANDROID_TOOLCHAIN_TYPE,
    )

    # 4. Optimize resources (shorten resource path names, remove resource names, collapse resource values)
    resource_apk_optimized = ctx.actions.declare_file(ctx.label.name + "_resource_apk_optimized.ap_")
    resource_obfuscation_map = ctx.actions.declare_file(ctx.label.name + "_resource_obfuscation.map")
    ctx.actions.run(
        arguments = [ctx.actions.args()
            .add("optimize")
            .add(resource_apk_shrunk)
            .add("-o", resource_apk_optimized)
            .add("--resources-config-path", resource_shrinking_res_config)
            .add("--collapse-resource-names")
            .add("--shorten-resource-paths")
            .add("--deduplicate-entry-values")
            .add("--save-obfuscation-map", resource_obfuscation_map)
            ],
        executable = android_toolchain.aapt2.files_to_run,
        inputs = [resource_apk_shrunk, resource_shrinking_res_config],
        mnemonic = "Aapt2OptimizeForResourceShrinkerR8",
        outputs = [resource_apk_optimized, resource_obfuscation_map],
        toolchain = ANDROID_TOOLCHAIN_TYPE,
    )

    aari = android_application_resource

    # Replace the resource apk in the AndroidApplicationResourceInfo provider from resource
    # processing.
    new_aari = AndroidApplicationResourceInfo(
        resource_apk = resource_apk_optimized,
        resource_java_src_jar = aari.resource_java_src_jar,
        resource_java_class_jar = aari.resource_java_class_jar,
        manifest = aari.manifest,
        resource_proguard_config = aari.resource_proguard_config,
        main_dex_proguard_config = aari.main_dex_proguard_config,
        r_txt = aari.r_txt,
        resources_zip = aari.resources_zip,
        databinding_info = aari.databinding_info,
        should_compile_java_srcs = aari.should_compile_java_srcs,
    )
    return new_aari

r8 = struct(
    process = _process,
    process_resource_shrinking = _process_resource_shrinking,
)
