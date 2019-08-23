#!/bin/bash

set -ex

BASE_BRANCH=master
# From https://docs.travis-ci.com/user/environment-variables
if [[ $AZURE_CI ]]; then
  git remote add upstream https://github.com/pytorch/pytorch
  git fetch upstream "$TARGET_BRANCH"
  BASE_BRANCH="upstream/$TARGET_BRANCH"
fi

if [[ ! -d build ]]; then
  git submodule update --init --recursive

  mkdir build
  pushd build
  # We really only need compile_commands.json, so no need to build!
  time cmake ..
  popd

  # Generate ATen files.
  time python aten/src/ATen/gen.py \
    -s aten/src/ATen \
    -d build/aten/src/ATen \
    aten/src/ATen/Declarations.cwrap \
    aten/src/THNN/generic/THNN.h \
    aten/src/THCUNN/generic/THCUNN.h \
    aten/src/ATen/nn.yaml \
    aten/src/ATen/native/native_functions.yaml

  # Generate PyTorch files.
  time python tools/setup_helpers/generate_code.py            \
    --declarations-path build/aten/src/ATen/Declarations.yaml \
    --nn-path aten/src
fi

# Run Clang-Tidy
# The negative filters below are to exclude files that include onnx_pb.h or
# caffe2_pb.h, otherwise we'd have to build protos as part of this CI job.
time python tools/clang_tidy.py             \
  --verbose                                 \
  --paths torch/csrc/jit/ir.cpp                       \
  --junit "$JUNIT_OUTPUT"
  -g"-torch/csrc/jit/export.cpp"            \
  -g"-torch/csrc/jit/import.cpp"            \
  -g"-torch/csrc/jit/netdef_converter.cpp"  \
  "$@"
