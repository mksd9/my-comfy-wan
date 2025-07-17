# ComfyUI WAN RunPod Template - Bazel Workspace (rules_oci)

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# rules_oci for OCI container building
http_archive(
    name = "rules_oci",
    sha256 = "176e601d21d1151efd88b6b027a24e782493c5d623d8c6211c7767f306d655c8",
    strip_prefix = "rules_oci-1.7.5",
    url = "https://github.com/bazel-contrib/rules_oci/releases/download/v1.7.5/rules_oci-v1.7.5.tar.gz",
)

load("@rules_oci//oci:dependencies.bzl", "rules_oci_dependencies")
rules_oci_dependencies()

load("@rules_oci//oci:repositories.bzl", "LATEST_CRANE_VERSION", "oci_register_toolchains")
oci_register_toolchains(
    name = "oci",
    crane_version = LATEST_CRANE_VERSION,
)

# Pull base CUDA image
load("@rules_oci//oci:pull.bzl", "oci_pull")
oci_pull(
    name = "cuda_base",
    digest = "sha256:b5d0e4a9e1c9b3e5d7e3f4d7c8b2a5e6f9d2c3e4d5e6f7a8b9c0d1e2f3a4b5c6",
    image = "nvidia/cuda:12.3.2-devel-ubuntu22.04",
)

# rules_pkg for packaging files
http_archive(
    name = "rules_pkg",
    sha256 = "d250924a2ecc5176808fc4c25d5cf5e9e79e6346d79d5ab1c493e289e722d1d0",
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_pkg/releases/download/0.10.1/rules_pkg-0.10.1.tar.gz",
        "https://github.com/bazelbuild/rules_pkg/releases/download/0.10.1/rules_pkg-0.10.1.tar.gz",
    ],
)

load("@rules_pkg//:deps.bzl", "rules_pkg_dependencies")
rules_pkg_dependencies()