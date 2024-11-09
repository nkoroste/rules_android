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

"""android_application rule."""

<<<<<<< Updated upstream
load("@rules_java//java/common:java_common.bzl", "java_common")
=======
load(
    "//rules:attrs.bzl",
    _attrs = "attrs",
)
load(":android_feature_module_rule.bzl", "get_feature_module_paths")
load(":attrs.bzl", "ANDROID_APPLICATION_ATTRS")
>>>>>>> Stashed changes
load(
    "//rules:aapt.bzl",
    _aapt = "aapt",
)
load(
    "//rules:baseline_profiles.bzl",
    _baseline_profiles = "baseline_profiles",
)
load(
    "//rules:bundletool.bzl",
    _bundletool = "bundletool",
)
load(
    "//rules:busybox.bzl",
    _busybox = "busybox",
)
load(
    "//rules:common.bzl",
    _common = "common",
)
load(
    "//rules:java.bzl",
    _java = "java",
)
load("//rules:r8.bzl",
     _r8 = "r8",
)
load(
    "//rules:providers.bzl",
    "AndroidBundleInfo",
    "AndroidFeatureModuleInfo",
<<<<<<< Updated upstream
    "AndroidIdeInfo",
    "AndroidPreDexJarInfo",
    "ApkInfo",
    "ProguardMappingInfo",
    "StarlarkAndroidResourcesInfo",
)
load(
    "//rules:sandboxed_sdk_toolbox.bzl",
    _sandboxed_sdk_toolbox = "sandboxed_sdk_toolbox",
=======
    "StarlarkAndroidResourcesInfo",
>>>>>>> Stashed changes
)
load(
    "//rules:utils.bzl",
    "ANDROID_TOOLCHAIN_TYPE",
    "get_android_toolchain",
    "get_android_sdk",
    "utils",
    _log = "log",
)
<<<<<<< Updated upstream
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(
    "//rules/android_sandboxed_sdk:providers.bzl",
    "AndroidArchivedSandboxedSdkInfo",
    "AndroidSandboxedSdkBundleInfo",
)
load(":android_feature_module_rule.bzl", "get_feature_module_paths")
load(":attrs.bzl", "ANDROID_APPLICATION_ATTRS")

visibility(PROJECT_VISIBILITY)
=======
load(
    "//contrib_rules/android_application:lazy_features.bzl",
    _repackage_as_lazy = "repackage_as_lazy",
)
load(
    "//contrib_rules/android_application:dynamic_build_config.bzl",
    _make_dynamic_build_config = "make_dynamic_build_config",
)
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
>>>>>>> Stashed changes

UNSUPPORTED_ATTRS = [
    "srcs",
]

_EMPTY_ZIP = "UEsFBgAAAAAAAAAAAAAAAAAAAAAAAA=="

def _verify_attrs(attrs, fqn):
    for attr in UNSUPPORTED_ATTRS:
        if hasattr(attrs, attr):
            _log.error("Unsupported attr: %s in android_application" % attr)

    for attr in ["deps"]:
        if attr not in attrs:
            _log.error("%s missing require attribute `%s`" % (fqn, attr))

def _process_feature_module(
        ctx,
        out = None,
        base_apk = None,
        feature_target = None,
        java_package = None,
        application_id = None,
        r8_feature_map = None):

    dex_archives = []
    apk_info = feature_target[AndroidFeatureModuleInfo].binary[ApkInfo]
    optimized_dex = r8_feature_map.get(apk_info.deploy_jar)
    dex_zip = ctx.actions.declare_file(ctx.label.name + "/" + feature_target.label.name + "/classes.dex.zip")
    zip_tool = get_android_toolchain(ctx).zip_tool.files_to_run
    if optimized_dex:
        ctx.actions.run_shell(
            tools = [zip_tool],
            inputs = [optimized_dex],
            outputs = [dex_zip],
            command = """#!/bin/sh
if [ ! -f "{dex_dir}/classes.dex" ]; then
    echo "{empty_zip}" | base64 -d >  "{dex_zip}"
else
    find {dex_dir} -exec touch -t 199609240000 {{}} \\;
    {zip_tool} -X -j -r -q {dex_zip} {dex_dir}
fi
            """.format(
                empty_zip = _EMPTY_ZIP,
                zip_tool = zip_tool.executable.path,
                dex_zip = dex_zip.path,
                dex_dir = optimized_dex.path,
            ),
            mnemonic = "ZipDex",
            progress_message = "Zipping optimized dex %s" % optimized_dex.path,
        )
        dex_archives = [dex_zip]
    else:
        # extract dex files from the feature module apk or create an empty zip if there are no dex files
        unzip_tool = get_android_toolchain(ctx).unzip_tool.files_to_run
        ctx.actions.run_shell(
            tools = [unzip_tool, zip_tool],
            inputs = [apk_info.unsigned_apk],
            outputs = [dex_zip],
            command = """#!/bin/sh
    {unzip_tool} -l {unsigned_apk} "classes*.dex"
    unzip=$?
    if [[ "${{unzip}}" != 0 ]]; then
        echo "{empty_zip}" | base64 -d >  "{dex_zip}"
    else
        {zip_tool} -q {unsigned_apk} "classes*.dex" --copy --out {dex_zip}
    fi
            """.format(
                empty_zip = _EMPTY_ZIP,
                zip_tool = zip_tool.executable.path,
                unzip_tool = unzip_tool.executable.path,
                dex_zip = dex_zip.path,
                unsigned_apk = apk_info.unsigned_apk.path,
            ),
            mnemonic = "ZipDex",
            progress_message = "Zipping dex %s" % dex_zip.path,
        )
        dex_archives = [dex_zip]

    manifest = _create_feature_manifest(
        ctx,
        base_apk,
        java_package,
        feature_target,
        dex_zip,
        ctx.attr._android_sdk[AndroidSdkInfo].aapt2,
        ctx.executable._feature_manifest_script,
        ctx.executable._priority_feature_manifest_script,
        get_android_toolchain(ctx).android_resources_busybox,
        _common.get_host_javabase(ctx),
    )
<<<<<<< Updated upstream
    res = feature_target[AndroidFeatureModuleInfo].library[StarlarkAndroidResourcesInfo]
    binary = feature_target[AndroidFeatureModuleInfo].binary[ApkInfo].unsigned_apk
    has_native_libs = bool(feature_target[AndroidFeatureModuleInfo].binary[AndroidIdeInfo].native_libs)
    is_asset_pack = bool(feature_target[AndroidFeatureModuleInfo].is_asset_pack)
=======

    feature_deps = feature_target[AndroidFeatureModuleInfo].deps
    direct_resources_nodes_deps = []
    transitive_resources_nodes_deps = []
    transitive_manifests = []
    transitive_assets = []
    transitive_compiled_assets = []
    transitive_resource_files = []
    transitive_compiled_resources = []
    transitive_r_txts = []
    for dep in utils.dedupe_split_attr(feature_deps):
        if StarlarkAndroidResourcesInfo not in dep:
            continue
>>>>>>> Stashed changes

        res = dep[StarlarkAndroidResourcesInfo]
        direct_resources_nodes_deps.append(res.direct_resources_nodes)
        transitive_resources_nodes_deps.append(res.transitive_resources_nodes)
        transitive_manifests.append(res.transitive_manifests)
        transitive_assets.append(res.transitive_assets)
        transitive_compiled_assets.append(res.transitive_compiled_assets)
        transitive_resource_files.append(res.transitive_resource_files)
        transitive_compiled_resources.append(res.transitive_compiled_resources)
        transitive_r_txts.append(res.transitive_r_txts)

    direct_resources_nodes = depset(transitive = direct_resources_nodes_deps)
    transitive_resources_nodes = depset(transitive = transitive_resources_nodes_deps)

    # Create res .proto-apk_, output depending on whether this split has native libs.
    res_apk = ctx.actions.declare_file(ctx.label.name + "/" + feature_target.label.name + "/res.proto-ap_")
    _busybox.package(
        ctx,
        out_r_src_jar = ctx.actions.declare_file("R.srcjar", sibling = manifest),
        out_r_txt = ctx.actions.declare_file("R.txt", sibling = manifest),
        out_symbols = ctx.actions.declare_file("merged.bin", sibling = manifest),
        out_manifest = ctx.actions.declare_file("AndroidManifest_processed.xml", sibling = manifest),
        out_proguard_cfg = ctx.actions.declare_file("proguard.cfg", sibling = manifest),
        out_main_dex_proguard_cfg = ctx.actions.declare_file(
            "main_dex_proguard.cfg",
            sibling = manifest,
        ),
        out_resource_files_zip = ctx.actions.declare_file("resource_files.zip", sibling = manifest),
        out_file = res_apk,
        manifest = manifest,
        java_package = java_package,
        direct_resources_nodes = direct_resources_nodes,
        transitive_resources_nodes = transitive_resources_nodes,
        transitive_manifests = transitive_manifests,
        transitive_assets = transitive_assets,
        transitive_compiled_assets = transitive_compiled_assets,
        transitive_resource_files = transitive_resource_files,
        transitive_compiled_resources = transitive_compiled_resources,
        transitive_r_txts = transitive_r_txts,
        additional_apks_to_link_against = [base_apk],
        proto_format = True,  # required for aab.
        android_jar = ctx.attr._android_sdk[AndroidSdkInfo].android_jar,
        aapt = get_android_toolchain(ctx).aapt2.files_to_run,
        busybox = get_android_toolchain(ctx).android_resources_busybox.files_to_run,
        host_javabase = _common.get_host_javabase(ctx),
        should_throw_on_conflict = False,
        application_id = application_id,
    )

    deps = feature_target[AndroidFeatureModuleInfo].deps
    native_libs = []
    for _,arch_deps in deps.items():
        for native_lib_provider in utils.collect_providers(AndroidNativeLibsInfo, arch_deps):
            native_libs.extend(native_lib_provider.native_libs.to_list())

    # Extract AndroidManifest.xml and assets from res-ap_
    filtered_res = ctx.actions.declare_file(ctx.label.name + "/" + feature_target.label.name + "/filtered_res.zip")
    _common.filter_zip_include(ctx, res_apk, filtered_res, ["AndroidManifest.xml", "assets/*"])

    # Merge into output
    merged_jar = ctx.actions.declare_file(ctx.label.name + "/" + feature_target.label.name + "/merged.zip")
    _java.singlejar(
        ctx,
        inputs = dex_archives + native_libs + [filtered_res],
        output = merged_jar,
        java_toolchain = _common.get_java_toolchain(ctx),
    )

    # make bundle a lazy loaded module if requested
    if ctx.attr._lazy_bundles[BuildSettingInfo].value:
        name = feature_target[AndroidFeatureModuleInfo].feature_name
        merged_jar = _repackage_as_lazy(ctx, merged_jar, name)

    exclude_filters = feature_target[AndroidFeatureModuleInfo].excludes
    _common.filter_zip_exclude(
            ctx,
            out,
            merged_jar,
            filters = ["META-INF/MANIFEST.MF"] + exclude_filters,
    )

def _create_r8_output_directories(ctx):
    jar_to_dir = dict()
    for module in ctx.attr.feature_modules:
        name = module[AndroidFeatureModuleInfo].feature_name
        output_dir = ctx.actions.declare_directory(
                ctx.label.name + "/proguarded_modules/" + name
        )

        deploy_jar = module[AndroidFeatureModuleInfo].binary[ApkInfo].deploy_jar
        jar_to_dir[deploy_jar] = output_dir
    return jar_to_dir

def _create_feature_manifest(
        ctx,
        base_apk,
        java_package,
        feature_target,
        dex_zip,
        aapt2,
        feature_manifest_script,
        priority_feature_manifest_script,
        android_resources_busybox,
        host_javabase):
    info = feature_target[AndroidFeatureModuleInfo]
    manifest = ctx.actions.declare_file(ctx.label.name + "/" + feature_target.label.name + "/AndroidManifest.xml")

    feature_deps = []
    for deps in feature_target[AndroidFeatureModuleInfo].deps.values():
        feature_deps.extend(deps)

    transitive_manifests = []
    resource_providers = utils.collect_providers(StarlarkAndroidResourcesInfo, feature_deps)
    for resource_info in resource_providers:
        transitive_manifests.extend(resource_info.transitive_manifests.to_list())

    manifest_to_merge = None
    # Rule has not specified a manifest. Populate the default manifest template.
    if not info.manifest:
        args = ctx.actions.args()
        args.add(manifest.path)
        args.add(base_apk.path)
        args.add(java_package)
        args.add(info.feature_name)
        args.add(info.title_id)
        args.add(aapt2.executable)
        args.add(dex_zip)
        if ctx.attr._lazy_bundles[BuildSettingInfo].value:
            args.add("true")
        else:
            args.add("false")

        ctx.actions.run(
            executable = feature_manifest_script,
            inputs = [base_apk],
            outputs = [manifest],
            arguments = [args],
            tools = [
                aapt2,
            ],
            mnemonic = "GenFeatureManifest",
            progress_message = "Generating AndroidManifest.xml for " + feature_target.label.name,
            toolchain = None,
        )
        manifest_to_merge = manifest
    else:
        # Rule has a manifest (already validated by android_feature_module).
        # Generate a priority manifest and then merge the user supplied manifest.
        priority_manifest = ctx.actions.declare_file(
            ctx.label.name + "/" + feature_target.label.name + "/Prioriy_AndroidManifest.xml",
        )
        args = ctx.actions.args()
        args.add(priority_manifest.path)
        args.add(base_apk.path)
        args.add(info.manifest.path)
        args.add(info.feature_name)
        args.add(aapt2.executable)
        args.add(dex_zip)
        if ctx.attr._lazy_bundles[BuildSettingInfo].value:
            args.add("true")
        else:
            args.add("false")

        ctx.actions.run(
            executable = priority_feature_manifest_script,
            inputs = [info.manifest, base_apk],
            outputs = [priority_manifest],
            arguments = [args],
            tools = [
                aapt2,
            ],
            mnemonic = "GenPriorityFeatureManifest",
            progress_message = "Generating Priority AndroidManifest.xml for " + feature_target.label.name,
            toolchain = None,
        )

        manifest_to_merge = ctx.actions.declare_file(ctx.label.name + "/" + feature_target.label.name + "/feature_AndroidManifest.xml")
        args = ctx.actions.args()
        args.add("--main_manifest", priority_manifest.path)
        args.add("--feature_manifest", info.manifest.path)
        args.add("--feature_title", "@string/" + info.title_id)
        args.add("--out", manifest_to_merge.path)
        ctx.actions.run(
            executable = ctx.attr._merge_manifests.files_to_run,
            inputs = [priority_manifest, info.manifest],
            outputs = [manifest_to_merge],
            arguments = [args],
            toolchain = None,
        )

    _busybox.merge_manifests(
        ctx,
        out_file = manifest,
        out_log_file = ctx.actions.declare_file(
         "_migrated/_merged/" + ctx.label.name + "/%s_feature_manifest_merger_log.txt" % info.feature_name,
        ),
         manifest = manifest_to_merge,
         mergee_manifests = depset(transitive_manifests),
         manifest_values = {"MODULE_TITLE": "@string/" + info.title_id},
         merge_type = "APPLICATION",
         java_package = java_package,
         busybox = get_android_toolchain(ctx).android_resources_busybox.files_to_run,
         host_javabase =  _common.get_host_javabase(ctx),
    )
    return manifest

def _validate_manifest_values(manifest_values):
    if "applicationId" not in manifest_values:
        _log.error("missing required applicationId in manifest_values")

def _impl(ctx):
    _validate_manifest_values(ctx.attr.manifest_values)

    # Convert base apk to .proto_ap_
    base_apk = ctx.attr.base_module[ApkInfo].unsigned_apk
    base_proto_apk = ctx.actions.declare_file(ctx.label.name + "/modules/base.proto-ap_")

    r8_feature_map = dict()
    android_dex_info = None
    baseline_profile_info = None
    if ctx.attr.proguard_specs:
        r8_feature_map = _create_r8_output_directories(ctx)
        main_deploy_jar = ctx.attr.base_module[ApkInfo].deploy_jar

        proguard_specs = []
        for specs in ctx.files.proguard_specs:
            proguard_specs.append(specs)

        spec_providers = utils.collect_providers(
                ProguardSpecProvider,
                [ctx.attr.base_module_internal] + ctx.attr.feature_modules
        )
        for sp in spec_providers:
            proguard_specs.extend(sp.specs.to_list())

        rewritten_baseline_profile = None
        if ctx.attr.baseline_profile:
            rewritten_baseline_profile = ctx.actions.declare_file(ctx.label.name + "_rewritten-baseline-prof.txt")

        android_dex_info = _r8.process(
                ctx,
                main_deploy_jar,
                proguard_specs,
                startup_profile = ctx.file.startup_profile,
                baseline_profile = ctx.file.baseline_profile,
                rewritten_baseline_profile = rewritten_baseline_profile,
                compiler_dump = ctx.attr.compiler_dump,
                r8_jvm_args = ctx.attr.r8_jvm_args,
                feature_split_jars = r8_feature_map,
        )
        resource_apk = ctx.attr.base_module_internal[AndroidApplicationResourceInfo].resource_apk

        resource_info = _r8.process_resource_shrinking(
            ctx,
            android_dex_info.final_classes_dex_zip,
            android_dex_info.final_proguard_output_map,
            resource_apk,
            ctx.attr.base_module_internal[AndroidApplicationResourceInfo],
            feature_split_jars = r8_feature_map,
            raw_resources = ctx.files.feature_modules_title_files
        )
        if resource_info:
            resource_apk = resource_info.resource_apk

        # process baseline profiles
        baseline_profile_info = None
        if ctx.attr.baseline_profile:
            baseline_profile_info = _baseline_profiles.process_art_profile(
                ctx,
                android_dex_info.final_classes_dex_zip,
                merged_profile = rewritten_baseline_profile,
                profgen = get_android_toolchain(ctx).profgen.files_to_run,
                zipper = get_android_toolchain(ctx).zipper.files_to_run,
                toolchain_type = ANDROID_TOOLCHAIN_TYPE,
            )
            
        dynamic_config_zip =  _make_dynamic_build_config(ctx) 
        base_apk = ctx.actions.declare_file(ctx.label.name + "_base_proguarded_unsigned.apk")
        native_libs = ctx.attr.base_module_internal[AndroidBinaryNativeLibsInfo].transitive_native_libs.to_list()
        _java.singlejar(
            ctx,
            inputs = [resource_apk, android_dex_info.final_classes_dex_zip, dynamic_config_zip] + native_libs,
            output = base_apk,
            include_build_data = False,
            java_toolchain = _common.get_java_toolchain(ctx),
        )

    _aapt.convert(
        ctx,
        out = base_proto_apk,
        input = base_apk,
        to_proto = True,
        aapt = get_android_toolchain(ctx).aapt2.files_to_run,
    )
    proto_apks = [base_proto_apk]

    # Convert each feature to .proto-ap_
    for feature in ctx.attr.feature_modules:
        feature_proto_apk = ctx.actions.declare_file(
            "%s.proto-ap_" % feature.label.name,
            sibling = base_proto_apk,
        )
        _process_feature_module(
            ctx,
            out = feature_proto_apk,
            base_apk = base_apk,
            feature_target = feature,
            java_package = _java.resolve_package_from_label(ctx.label, ctx.attr.custom_package),
            application_id = ctx.attr.manifest_values.get("applicationId"),
            r8_feature_map = r8_feature_map,
        )
        proto_apks.append(feature_proto_apk)

    # Convert each each .proto-ap_ to module zip
    modules = []
    for proto_apk in proto_apks:
        module = ctx.actions.declare_file(
            proto_apk.basename + ".zip",
            sibling = proto_apk,
        )
        modules.append(module)
        _bundletool.proto_apk_to_module(
            ctx,
            out = module,
            proto_apk = proto_apk,
            bundletool_module_builder =
                get_android_toolchain(ctx).bundletool_module_builder.files_to_run,
        )

    metadata = dict()
    if android_dex_info:
        metadata["com.android.tools.build.obfuscation/proguard.map"] = android_dex_info.final_proguard_output_map

<<<<<<< Updated upstream
=======
    if baseline_profile_info:
        metadata["assets.dexopt/baseline.prof"] = baseline_profile_info.profile
        metadata["assets.dexopt/baseline.profm"] = baseline_profile_info.profile_meta 

>>>>>>> Stashed changes
    if ctx.file.rotation_config:
        metadata["com.google.play.apps.signing/RotationConfig.textproto"] = ctx.file.rotation_config

    if ctx.file.app_integrity_config:
        metadata["com.google.play.apps.integrity/AppIntegrityConfig.pb"] = ctx.file.app_integrity_config

    # Create .aab
    base_aab = ctx.actions.declare_file(ctx.label.name + "_base_aab")
    _bundletool.build(
        ctx,
        out = base_aab,
        modules = modules,
        config = ctx.file.bundle_config_file,
        metadata = metadata,
        bundletool = get_android_toolchain(ctx).bundletool.files_to_run,
        host_javabase = _common.get_host_javabase(ctx),
    )

    _common.filter_zip_exclude(
        ctx = ctx,
        input = base_aab,
        output = ctx.outputs.unsigned_aab,
        filters = ctx.attr.excludes,
    )

    # Create `blaze run` script
    base_apk_info = ctx.attr.base_module[ApkInfo]
    deploy_script_files = [base_apk_info.signing_keys[-1]]
    subs = {
        "%bundletool_path%": get_android_toolchain(ctx).bundletool.files_to_run.executable.short_path,
        "%aab%": ctx.outputs.unsigned_aab.short_path,
        "%newest_key%": base_apk_info.signing_keys[-1].short_path,
    }
    if base_apk_info.signing_lineage:
        signer_properties = _common.create_signer_properties(ctx, base_apk_info.signing_keys[0])
        subs["%oldest_signer_properties%"] = signer_properties.short_path
        subs["%lineage%"] = base_apk_info.signing_lineage.short_path
        subs["%min_rotation_api%"] = base_apk_info.signing_min_v3_rotation_api_version
        deploy_script_files.extend(
            [signer_properties, base_apk_info.signing_lineage, base_apk_info.signing_keys[0]],
        )
    else:
        subs["%oldest_signer_properties%"] = ""
        subs["%lineage%"] = ""
        subs["%min_rotation_api%"] = ""
    ctx.actions.expand_template(
        template = ctx.file._bundle_deploy,
        output = ctx.outputs.deploy_script,
        substitutions = subs,
        is_executable = True,
    )

    return [
        ctx.attr.base_module[ApkInfo],
        ctx.attr.base_module[AndroidPreDexJarInfo],
        AndroidBundleInfo(unsigned_aab = ctx.outputs.unsigned_aab),
        DefaultInfo(
            executable = ctx.outputs.deploy_script,
            runfiles = ctx.runfiles([
                ctx.outputs.unsigned_aab,
                get_android_toolchain(ctx).bundletool.files_to_run.executable,
            ] + deploy_script_files),
        ),
    ]

android_application = rule(
    attrs = ANDROID_APPLICATION_ATTRS,
    cfg = android_common.android_platforms_transition,
    fragments = [
        "android",
        "bazel_android",
        "java",
    ],
    executable = True,
    implementation = _impl,
    outputs = {
        "deploy_script": "%{name}.sh",
        "unsigned_aab": "%{name}_unsigned.aab",
    },
    toolchains = [
        "//toolchains/android:toolchain_type",
        "@bazel_tools//tools/jdk:toolchain_type",
    ],
    _skylark_testable = True,
)

def android_application_macro(_android_binary, **attrs):
    """android_application_macro.

    Args:
      _android_binary: The android_binary rule to use.
      **attrs: android_application attributes.
    """

    fqn = "//%s:%s" % (native.package_name(), attrs["name"])

    # Must pop these because android_binary does not have these attributes.
    app_integrity_config = attrs.pop("app_integrity_config", None)
    rotation_config = attrs.pop("rotation_config", None)

    # Simply fall back to android_binary if no feature splits or bundle_config
    if not attrs.get("feature_modules", None) and not (attrs.get("bundle_config", None) or attrs.get("bundle_config_file", None)):
        _android_binary(**attrs)
        return

    _verify_attrs(attrs, fqn)

    # Create an android_binary base split, plus an android_application to produce the aab
    name = attrs.pop("name")

    # default to [] if feature_modules = None is passed
    feature_modules = attrs.pop("feature_modules", []) or []
    bundle_config = attrs.pop("bundle_config", None)
    bundle_config_file = attrs.pop("bundle_config_file", None)

    # bundle_config is deprecated in favor of bundle_config_file
    # In the future bundle_config will accept a build rule rather than a raw file.
    bundle_config_file = bundle_config_file or bundle_config

    modules_titles = []
    deps = attrs.pop("deps", [])
    for feature_module in feature_modules:
        if not feature_module.startswith("//") or ":" not in feature_module:
            _log.error("feature_modules expects fully qualified paths, i.e. //some/path:target")
        module_targets = get_feature_module_paths(feature_module)
        deps = deps + [str(module_targets.title_lib)]
        modules_titles.append(str(module_targets.title_strings_xml))

    # we dont want to proguard the base module. It needs to be proguarded with all the splits.
    proguard_specs = attrs.pop("proguard_specs", [])
    proguard_generate_mapping = attrs.pop("proguard_generate_mapping", False)
    startup_profile = attrs.pop("startup_profile", None)
    baseline_profile = attrs.pop("baseline_profile", None)
    compiler_dump = attrs.pop("compiler_dump", "off")
    r8_jvm_args = attrs.pop("r8_jvm_args", [])
    shrink_resources = attrs.pop("shrink_resources", _attrs.tristate.auto)

    # only supported in android_application rule
    excludes = attrs.pop("excludes", [])

    _android_binary(
        name = name,
        deps = deps,
        **attrs
    )

    base_module = ":%s" % base_split_name
    android_application(
<<<<<<< Updated upstream
        name = "%s_aab" % name,
        base_module = ":%s" % name,
=======
        name = name,
        base_module = base_module,
        base_module_internal  = base_module + "_RESOURCES_DO_NOT_USE",
>>>>>>> Stashed changes
        bundle_config_file = bundle_config_file,
        app_integrity_config = app_integrity_config,
        rotation_config = rotation_config,
        proguard_specs = proguard_specs,
        proguard_generate_mapping = proguard_generate_mapping,
        startup_profile = startup_profile,
        baseline_profile = baseline_profile,
        compiler_dump = compiler_dump,
        r8_jvm_args = r8_jvm_args,
        shrink_resources = shrink_resources,
        feature_modules_title_files = modules_titles,
        custom_package = attrs.get("custom_package", None),
        testonly = attrs.get("testonly"),
        transitive_configs = attrs.get("transitive_configs", []),
        feature_modules = feature_modules,
        manifest_values = attrs.get("manifest_values"),
        visibility = attrs.get("visibility", None),
        excludes = excludes,
    )
