#!/bin/bash -xe

CLUSTER_NAME=${EKS_CLUSTER}
KARPENTER_VERSION=v0.18.1

export HELM_EXPERIMENTAL_OCI=1

CLUSTER_ENDPOINT="$(aws eks describe-cluster \
    --name ${CLUSTER_NAME} --query "cluster.endpoint" \
    --output text)"
OIDC_ENDPOINT="$(aws eks describe-cluster --name ${CLUSTER_NAME} \
    --query "cluster.identity.oidc.issuer" --output text)"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' \
    --output text)

echo '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}' > /tmp/node-trust-policy.json

aws iam create-role --role-name KarpenterInstanceNodeRole \
    --assume-role-policy-document file:///tmp/node-trust-policy.json

rm -f /tmp/node-trust-policy.json

aws iam attach-role-policy --role-name KarpenterInstanceNodeRole \
    --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

aws iam attach-role-policy --role-name KarpenterInstanceNodeRole \
    --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

aws iam attach-role-policy --role-name KarpenterInstanceNodeRole \
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

aws iam attach-role-policy --role-name KarpenterInstanceNodeRole \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

aws iam create-instance-profile \
    --instance-profile-name KarpenterInstanceProfile

aws iam add-role-to-instance-profile \
    --instance-profile-name KarpenterInstanceProfile \
    --role-name KarpenterInstanceNodeRole

echo "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
        {
            \"Effect\": \"Allow\",
            \"Principal\": {
                \"Federated\": \"arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_ENDPOINT#*//}\"
            },
            \"Action\": \"sts:AssumeRoleWithWebIdentity\",
            \"Condition\": {
                \"StringEquals\": {
                    \"${OIDC_ENDPOINT#*//}:aud\": \"sts.amazonaws.com\",
                    \"${OIDC_ENDPOINT#*//}:sub\": \"system:serviceaccount:karpenter:karpenter\"
                }
            }
        }
    ]
}" > /tmp/controller-trust-policy.json

aws iam create-role --role-name KarpenterControllerRole-${CLUSTER_NAME} \
    --assume-role-policy-document file:///tmp/controller-trust-policy.json

echo '{
    "Statement": [
        {
            "Action": [
                "ssm:GetParameter",
                "iam:PassRole",
                "ec2:DescribeImages",
                "ec2:RunInstances",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeLaunchTemplates",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceTypes",
                "ec2:DescribeInstanceTypeOfferings",
                "ec2:DescribeAvailabilityZones",
                "ec2:DeleteLaunchTemplate",
                "ec2:CreateTags",
                "ec2:CreateLaunchTemplate",
                "ec2:CreateFleet",
                "ec2:DescribeSpotPriceHistory",
                "pricing:GetProducts"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "Karpenter"
        },
        {
            "Action": "ec2:TerminateInstances",
            "Condition": {
                "StringLike": {
                    "ec2:ResourceTag/Name": "*karpenter*"
                }
            },
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "ConditionalEC2Termination"
        }
    ],
    "Version": "2012-10-17"
}' > /tmp/controller-policy.json

aws iam put-role-policy --role-name KarpenterControllerRole-${CLUSTER_NAME} \
    --policy-name KarpenterControllerPolicy-${CLUSTER_NAME} \
    --policy-document file:///tmp/controller-policy.json

rm -f /tmp/controller-policy.json

for NODEGROUP in $(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} \
    --query 'nodegroups' --output text); do aws ec2 create-tags \
        --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}" \
        --resources $(aws eks describe-nodegroup --cluster-name ${CLUSTER_NAME} \
        --nodegroup-name $NODEGROUP --query 'nodegroup.subnets' --output text )
done

NODEGROUP=$(aws eks list-nodegroups --cluster-name ${CLUSTER_NAME} \
    --query 'nodegroups[0]' --output text)

SECURITY_GROUPS=$(aws eks describe-cluster \
    --name ${CLUSTER_NAME} --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)

aws ec2 create-tags \
    --tags "Key=karpenter.sh/discovery,Value=${CLUSTER_NAME}" \
    --resources ${SECURITY_GROUPS}

helm template karpenter oci://public.ecr.aws/karpenter/karpenter --version ${KARPENTER_VERSION} --namespace karpenter \
    --set aws.defaultInstanceProfile=KarpenterInstanceProfile \
    --set clusterEndpoint="${CLUSTER_ENDPOINT}" \
    --set clusterName=${CLUSTER_NAME} \
    --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterControllerRole-${CLUSTER_NAME}" \
    --version ${KARPENTER_VERSION} > /tmp/karpenter.yaml

kubectl create namespace karpenter
kubectl create -f \
    https://raw.githubusercontent.com/aws/karpenter/${KARPENTER_VERSION}/charts/karpenter/crds/karpenter.sh_provisioners.yaml
kubectl apply -f /tmp/karpenter.yaml

echo 'sleeping 30 seconds while waiting for Karpenter to launch'
sleep 30

cat <<EOF | kubectl apply -f -
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: default
spec:
  provider:
    subnetSelector:
      karpenter.sh/discovery: ${CLUSTER_NAME}
    securityGroupSelector:
      karpenter.sh/discovery: ${CLUSTER_NAME}
  requirements:
  - key: karpenter.k8s.aws/instance-category
    operator: In
    values: ["c", "m", "r"]
  - key: karpenter.sh/capacity-type
    operator: In
    values:
    - on-demand
  - key: kubernetes.io/arch
    operator: In
    values:
    - amd64
    - arm64
EOF

cat <<EOF
Don't forget to run

kubectl -n kube-system edit configmap aws-auth

and add the following below the existing groups entry:

    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/KarpenterInstanceNodeRole
      username: system:node:{{EC2PrivateDNSName}}
EOF