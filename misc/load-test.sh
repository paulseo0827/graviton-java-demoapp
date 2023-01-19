#!/bin/bash

set -v

kubectl run -i -t --rm --image=public.ecr.aws/otterley/hey \
   --restart=Never load-generator -- \
   -n 2000000 -c 20 -q 1 http://java-demoapp:8080/tools/cpu
