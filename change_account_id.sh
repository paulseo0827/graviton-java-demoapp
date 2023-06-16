#!/bin/bash

account_id=$1
sed -i "s/REPLACE_ACCOUNT_ID/$account_id/g" makefile
sed -i "s/REPLACE_ACCOUNT_ID/$account_id/g" deploy/kubernetes/deployment-arm64.yaml
sed -i "s/REPLACE_ACCOUNT_ID/$account_id/g" deploy/kubernetes/deployment-x86.yaml
sed -i "s/REPLACE_ACCOUNT_ID/$account_id/g" deploy/kubernetes/deployment-arm64-multiarchmanifest.yaml
sed -i "s/REPLACE_ACCOUNT_ID/$account_id/g" deploy/kubernetes/deployment-x86-multiarchmanifest.yaml
sed -i "s/REPLACE_ACCOUNT_ID/$account_id/g" aws-lb-controller.sh
