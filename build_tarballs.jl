# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "tensorrt"
version = v"8.2.3"

CUDA_version = VersionNumber(haskey(ENV, "CUDA_VERSION") ? ENV["CUDA_VERSION"] : "11.4.2")
CUDNN_version = v"8.3.1"
if haskey(ENV, "NV_CUDNN_VERSION")
    m = match(r"^(\d+\.\d+\.\d+).*", ENV["NV_CUDNN_VERSION"])
    if m !== nothing
        CUDNN_version = VersionNumber(m.captures[1])
    end
end

bin_pkgs = [
    "libnvinfer$(version.major)",
    "libnvonnxparsers$(version.major)",
    "libnvparsers$(version.major)",
    "libnvinfer-plugin$(version.major)"
]
dev_pkgs = [
    "libnvinfer-dev",
    "libnvonnxparsers-dev",
    "libnvparsers-dev",
    "libnvinfer-plugin-dev"
]
pkgs = vcat(bin_pkgs, dev_pkgs)
pkg_version="$version-1+cuda$(CUDA_version.major).$(CUDA_version.minor)"
pkg_specs = ["$pkg=$pkg_version" for pkg in pkgs]
unpack_deb(pkg) = "dpkg-deb -x /var/cache/apt/archives/$(pkg)_$(pkg_version)_*.deb $(joinpath(@__DIR__
, "src"))"
cmds = """
apt-get update && \
apt-get install -y --no-install-recommends ca-certificates gnupg && \
apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/7fa2af80.pub && \
echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64 /" | tee /etc/apt/sources.list.d/cuda.list && \
apt-get update && \
apt-get install --download-only -y --no-install-recommends $(join(pkg_specs, " ")) && \
$(join([unpack_deb(pkg) for pkg in pkgs], " && "))
"""
@info "Downloading TensorRT $version"
run(`sh -c $cmds`)

sources = [
    DirectorySource("src")
]

# Bash recipe for building across all platforms
scripts = [
"""
install_license \$prefix/usr/share/doc/$pkg/copyright
"""
for pkg in pkgs
]
script = "cp -av src/* \$prefix/" * join(scripts, "\n")

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [
    Platform("x86_64", "Linux"; libc="glibc", cuda = "$(CUDA_version.major).$(CUDA_version.minor)")
]

# The products that we will ensure are always built
products = Product[
    LibraryProduct(bin_pkg, Symbol(bin_pkg)) for bin_pkg in bin_pkgs
]

# Dependencies that must be installed before this package can be built
dependencies = [
    Dependency("CUDNN_jll"; compat="^$(CUDNN_version.major)")
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
    julia_compat = "1.6")
