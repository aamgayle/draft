# remove previous tests
echo "Removing previous integration configs"
rm -rf ./integration/*
echo "Removing previous integration workflows"
rm ../.github/workflows/integration-linux.yml
rm ../.github/workflows/integration-windows.yml

# add build to workflow
echo "name: draft Linux Integrations

on:
  push:
    branches: [ int-tests ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Go
        uses: actions/setup-go@v2
        with:
          go-version: 1.18.2
      - name: make
        run: make
      - uses: actions/upload-artifact@v2
        with:
          name: helm-skaffold
          path: ./test/skaffold.yaml
          if-no-files-found: error
      - uses: actions/upload-artifact@v2
        with:
          name: draft-binary
          path: ./draft
          if-no-files-found: error" > ../.github/workflows/integration-linux.yml

echo "name: draft Windows Integrations

on:
  push:
    branches: [ int-tests ]
  workflow_dispatch:

jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Go
        uses: actions/setup-go@v2
        with:
          go-version: 1.18
      - name: make
        run: make
      - uses: actions/upload-artifact@v2
        with:
          name: draft-binary
          path: ./draft.exe
          if-no-files-found: error
      - uses: actions/upload-artifact@v2
        with:
          name: check_windows_helm
          path: ./test/check_windows_helm.ps1
          if-no-files-found: error
      - uses: actions/upload-artifact@v2
        with:
          name: check_windows_addon_helm
          path: ./test/check_windows_addon_helm.ps1
          if-no-files-found: error
      - uses: actions/upload-artifact@v2
        with:
          name: check_windows_kustomize
          path: ./test/check_windows_kustomize.ps1
          if-no-files-found: error
      - uses: actions/upload-artifact@v2
        with:
          name: check_windows_addon_kustomize
          path: ./test/check_windows_addon_kustomize.ps1
          if-no-files-found: error" > ../.github/workflows/integration-windows.yml
    # create helm workflow
    echo "
  $lang-helm-create:
    runs-on: windows-latest
    needs: build
    steps:
      - uses: actions/checkout@v2
      - uses: actions/download-artifact@v2
        with:
          name: draft-binary
      - run: mkdir ./langtest
      - uses: actions/checkout@v2
        with:
          repository: $repo
          path: ./langtest
      - run: Remove-Item ./langtest/manifests -Recurse -Force -ErrorAction Ignore
      - run: Remove-Item ./langtest/Dockerfile -ErrorAction Ignore
      - run: Remove-Item ./langtest/.dockerignore -ErrorAction Ignore
      - run: ./draft.exe -v create -c ./test/integration/$lang/helm.yaml -d ./langtest/
      - uses: actions/download-artifact@v2
        with:
          name: check_windows_helm
          path: ./langtest/
      - run: ./check_windows_helm.ps1
        working-directory: ./langtest/
      - uses: actions/upload-artifact@v3
        with:
          name: $lang-helm-create
          path: ./langtest
  $lang-helm-update:
    needs: $lang-helm-create
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/download-artifact@v2
        with:
          name: draft-binary
      - uses: actions/download-artifact@v3
        with:
          name: $lang-helm-create
          path: ./langtest/
      - run: Remove-Item ./langtest/charts/templates/ingress.yaml -Recurse -Force -ErrorAction Ignore
      - run: ./draft.exe -v update -d ./langtest/ $ingress_test_args
      - uses: actions/download-artifact@v2
        with:
          name: check_windows_addon_helm
          path: ./langtest/
      - run: ./check_windows_addon_helm.ps1
        working-directory: ./langtest/" >> ../.github/workflows/integration-windows.yml