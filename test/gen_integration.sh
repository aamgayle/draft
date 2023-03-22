# remove previous tests
echo "Removing previous integration configs"
rm -rf ./integration/*
echo "Removing previous integration workflows"
rm ../.github/workflows/integration-linux.yml
rm ../.github/workflows/integration-windows.yml

# create temp files for keeping track off workflow jobs to build job-dependency graph
# this is used to populated the needs: field of the required final workflow jobs
helm_workflow_names_file=./temp/helm_workflow_names.txt
rm $helm_workflow_names_file
helm_win_workflow_names_file=./temp/helm_win_workflow_names.txt
rm $helm_win_workflow_names_file
kustomize_workflow_names_file=./temp/kustomize_workflow_names.txt
rm $kustomize_workflow_names_file
kustomize_win_workflow_names_file=./temp/kustomize_win_workflow_names.txt
rm $kustomize_win_workflow_names_file
manifest_workflow_names_file=./temp/manifest_workflow_names.txt
rm $manifest_workflow_names_file
mkdir -p ./temp

# add build to workflow
echo "# this file is generated using gen_integration.sh
name: draft Linux Integrations

on:
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Go
        uses: actions/setup-go@v2
        with:
          go-version: 1.18.2
      - name: make
        run: make
      - uses: actions/upload-artifact@v3
        with:
          name: helm-skaffold
          path: ./test/skaffold.yaml
          if-no-files-found: error
      - uses: actions/upload-artifact@v3
        with:
          name: draft-binary
          path: ./draft
          if-no-files-found: error" > ../.github/workflows/integration-linux.yml

echo "name: draft Windows Integrations

on:
  pull_request_review:
    types: [submitted]
  workflow_dispatch:

jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Go
        uses: actions/setup-go@v2
        with:
          go-version: 1.18
      - name: make
        run: make
      - uses: actions/upload-artifact@v3
        with:
          name: draft-binary
          path: ./draft.exe
          if-no-files-found: error
      - uses: actions/upload-artifact@v3
        with:
          name: check_windows_helm
          path: ./test/check_windows_helm.ps1
          if-no-files-found: error
      - uses: actions/upload-artifact@v3
        with:
          name: check_windows_addon_helm
          path: ./test/check_windows_addon_helm.ps1
          if-no-files-found: error
      - uses: actions/upload-artifact@v3
        with:
          name: check_windows_kustomize
          path: ./test/check_windows_kustomize.ps1
          if-no-files-found: error
      - uses: actions/upload-artifact@v3
        with:
          name: check_windows_addon_kustomize
          path: ./test/check_windows_addon_kustomize.ps1
          if-no-files-found: error" > ../.github/workflows/integration-windows.yml


# read config and add integration test for each language
cat integration_config.json | jq -c '.[]' | while read -r test; 
do 
    note="# this file is generated using gen_integration.sh"
    # extract from json
    lang=$(echo $test | jq '.language' -r)
    version=$(echo $test | jq '.version' -r)
    builderversion=$(echo $test | jq '.builderversion' -r)
    port=$(echo $test | jq '.port' -r)
    serviceport=$(echo $test | jq '.serviceport' -r)
    repo=$(echo $test | jq '.repo' -r)

    imagename="host.minikube.internal:5001/testapp"
    # addon integration testing vars
    ingress_test_args="-a webapp_routing --variable ingress-tls-cert-keyvault-uri=test.cert.keyvault.uri --variable ingress-use-osm-mtls=true --variable ingress-host=host1"
    echo "Adding $lang with port $port"

    mkdir ./integration/$lang

    # create helm.yaml
    echo "$note
deployType: \"Helm\"
languageType: \"$lang\"
deployVariables:
  - name: \"PORT\"
    value: \"$port\"
  - name: \"SERVICEPORT\"
    value: \"$serviceport\"
  - name: \"APPNAME\"
    value: \"testapp\"
  - name: \"IMAGENAME\"
    value: \"$imagename\"
languageVariables:
  - name: \"VERSION\"
    value: \"$version\"
  - name: \"BUILDERVERSION\"
    value: \"$builderversion\"
  - name: \"PORT\"
    value: \"$port\"" > ./integration/$lang/helm.yaml

    # create kustomize.yaml
    echo "$note
deployType: \"kustomize\"
languageType: \"$lang\"
deployVariables:
  - name: \"PORT\"
    value: \"$port\"
  - name: \"SERVICEPORT\"
    value: \"$serviceport\"
  - name: \"APPNAME\"
    value: \"testapp\"
  - name: \"IMAGENAME\"
    value: \"$imagename\"
languageVariables:
  - name: \"VERSION\"
    value: \"$version\"
  - name: \"BUILDERVERSION\"
    value: \"$builderversion\"
  - name: \"PORT\"
    value: \"$port\"" > ./integration/$lang/kustomize.yaml

    # create manifest.yaml
    echo "$note
deployType: \"manifests\"
languageType: \"$lang\"
deployVariables:
  - name: \"PORT\"
    value: \"$port\"
  - name: \"SERVICEPORT\"
    value: \"$serviceport\"
  - name: \"APPNAME\"
    value: \"testapp\"
  - name: \"IMAGENAME\"
    value: \"$imagename\"
languageVariables:
  - name: \"VERSION\"
    value: \"$version\"
  - name: \"BUILDERVERSION\"
    value: \"$builderversion\"
  - name: \"PORT\"
    value: \"$port\"" > ./integration/$lang/manifest.yaml

    # create helm workflow
    helm_create_update_job_name=$lang-helm-create-update
    echo $helm_create_update_job_name >> $helm_workflow_names_file
    echo "
  $lang-helm-dry-run:
      runs-on: ubuntu-latest
      needs: build
      steps:
        - uses: actions/checkout@v3
        - uses: actions/download-artifact@v3
          with:
            name: draft-binary
        - run: chmod +x ./draft
        - run: mkdir ./langtest
        - uses: actions/checkout@v3
          with:
            repository: $repo
            path: ./langtest
        - name: Execute Dry Run
          run: |
            mkdir -p test/temp
            ./draft --dry-run --dry-run-file test/temp/dry-run.json \
            create -c ./test/integration/$lang/helm.yaml \
            -d ./langtest/ --skip-file-detection
        - name: Validate JSON
          run: |
            npm install -g ajv-cli@5.0.0
            ajv validate -s test/dry_run_schema.json -d test/temp/dry-run.json
  $lang-helm-docker-para:
    runs-on: ubuntu-latest
    services:
      registry:
        image: registry:2
        ports:
          - 5001:5000
    needs: $lang-helm-dry-run
    steps:
      - uses: actions/checkout@v3
      - uses: actions/download-artifact@v3
        with:
          name: draft-binary
      - run: chmod +x ./draft
      - run: mkdir ./langtest
      - uses: actions/checkout@v3
        with:
          repository: $repo
          path: ./langtest
      - run: rm -rf ./langtest/manifests && rm -f ./langtest/Dockerfile ./langtest/.dockerignore
      - run: ./draft -v create -c ./test/integration/$lang/helm.yaml -d ./langtest/
      - run: ./draft -b main -v generate-workflow -d ./langtest/ -c someAksCluster -r someRegistry -g someResourceGroup --container-name someContainer -build-content-path .
      - run: ./draft -v update -d ./langtest/ $ingress_test_args
      - name: start minikube
        id: minikube
        uses: medyagh/setup-minikube@master
        with:
          insecure-registry: 'host.minikube.internal:5001,10.0.0.0/24'
      # Runs Helm to create manifest files
      - name: Bake deployment
        uses: azure/k8s-bake@v2.1
        with:
          renderEngine: 'helm'
          helmChart: ./langtest/charts
          overrideFiles: ./langtest/charts/values.yaml
          overrides: |
            replicas:2
          helm-version: 'latest'
          releaseName: 'test-release'
        id: bake
      - name: Build and Push image
        continue-on-error: true
        run: |
          export SHELL=/bin/bash
          eval \$(minikube -p minikube docker-env)
          docker build -f ./langtest/Dockerfile -t testapp ./langtest/
          docker tag testapp $imagename
          echo -n \"verifying images:\"
          docker images
          docker push $imagename
          echo 'Curling host.minikube.internal test app images from minikube'
          minikube ssh \"curl http://host.minikube.internal:5001/v2/testapp/tags/list\"
      # Deploys application based on manifest files from previous step
      - name: Deploy application
        uses: Azure/k8s-deploy@v3.0
        continue-on-error: true
        id: deploy
        with:
          action: deploy
          manifests: \${{ steps.bake.outputs.manifestsBundle }}
          images: |
            $imagename
      - name: Wait for rollout
        continue-on-error: true
        id: rollout
        run: |
          kubectl rollout status deployment/test-release-testapp --timeout=2m
      - name: Print K8s Objects
        run: |
          kubectl get po -o json
          kubectl get svc -o json
          kubectl get deploy -o json
      - name: Curl Endpoint
        run: |
          kubectl get svc
          echo 'Starting minikube tunnel'
          minikube tunnel  > /dev/null 2>&1 & tunnelPID=\$!
          sleep 120
          kubectl get svc
          SERVICEIP=\$(kubectl get svc -o jsonpath={'.items[1].status.loadBalancer.ingress[0].ip'})
          echo \"SERVICEIP: \$SERVICEIP\"
          echo 'Curling service IP'
          curl -m 3 \$SERVICEIP:$serviceport
          kill \$tunnelPID
      - run: ./draft -b main -v generate-workflow -d ./langtest/ -c someAksCluster -r someRegistry -g someResourceGroup --container-name someContainer
      - name: Execute dry run for update command
        run: |
          mkdir -p test/temp
          ./draft --dry-run --dry-run-file test/temp/update_dry_run.json update -d ./langtest/ $ingress_test_args  
      - name: Validate JSON
        run: |
          npm install -g ajv-cli@5.0.0
          ajv validate -s test/update_dry_run_schema.json -d test/temp/update_dry_run.json
      - run: ./draft -v update -d ./langtest/ $ingress_test_args
      - name: Check default namespace
        if: steps.deploy.outcome != 'success'
        run: kubectl get po
      - name: Fail if any error
        if: steps.deploy.outcome != 'success'
        run: exit 6" >> ../.github/workflows/integration-linux.yml
done

echo "
  helm-win-integrations-summary:
      runs-on: windows-latest
      needs: [ $( paste -sd ',' $helm_win_workflow_names_file) ]
      steps:
        - run: echo "helm integrations passed"
" >> ../.github/workflows/integration-windows.yml

echo "
  kustomize-win-integrations-summary:
      runs-on: windows-latest
      needs: [ $( paste -sd ',' $kustomize_win_workflow_names_file) ]
      steps:
        - run: echo "kustomize integrations passed"
" >> ../.github/workflows/integration-windows.yml

echo "
  helm-integrations-summary:
      runs-on: ubuntu-latest
      needs: [ $( paste -sd ',' $helm_workflow_names_file) ]
      steps:
        - run: echo "helm integrations passed"
" >> ../.github/workflows/integration-linux.yml

echo "
  kustomize-integrations-summary:
      runs-on: ubuntu-latest
      needs: [ $( paste -sd ',' $kustomize_workflow_names_file) ]
      steps:
        - run: echo "kustomize integrations passed"
" >> ../.github/workflows/integration-linux.yml

echo "
  manifest-integrations-summary:
      runs-on: ubuntu-latest
      needs: [ $( paste -sd ',' $manifest_workflow_names_file) ]
      steps:
        - run: echo "manifest integrations passed"
" >> ../.github/workflows/integration-linux.yml
