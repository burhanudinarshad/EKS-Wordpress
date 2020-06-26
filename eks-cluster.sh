STACK_NAME=wptest20

Vpc_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='Vpc'].OutputValue" --output text)
AWS_REGION=us-east-1
CLUSTER_NAME=ca-gov-wpaas


############   get WEB Subnet IDs #################################################################################
WebSubnet_eus1a=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$Vpc_ID" "Name=availability-zone,Values=us-east-1a" \
"Name=availability-zone,Values=us-east-1a" "Name=tag:Name,Values=WebSubnet*" \
--query "Subnets[0].SubnetId" --output text)

WebSubnet_eus1b=$(aws ec2 describe-subnets \
--filters "Name=vpc-id,Values=$Vpc_ID" "Name=availability-zone,Values=us-east-1b" \
 "Name=tag:Name,Values=WebSubnet*" \
--query "Subnets[0].SubnetId" --output text)

WebSubnet_eus1c=$(aws ec2 describe-subnets \
--filters "Name=vpc-id,Values=$Vpc_ID" "Name=availability-zone,Values=us-east-1c" "Name=tag:Name,Values=WebSubnet*" \
--query "Subnets[0].SubnetId" --output text)

##############get Public Subnet IDs ####################################################################################
publicsubnet_eus1a=$(aws ec2 describe-subnets \
--filters "Name=vpc-id,Values=$Vpc_ID" "Name=availability-zone,Values=us-east-1a" "Name=tag:Name,Values=PublicSubnet*" \
--query "Subnets[0].SubnetId" --output text)

publicsubnet_eus1b=$(aws ec2 describe-subnets \
--filters "Name=vpc-id,Values=$Vpc_ID" "Name=availability-zone,Values=us-east-1b" "Name=tag:Name,Values=PublicSubnet*" \
--query "Subnets[0].SubnetId" --output text)

publicsubnet_eus1c=$(aws ec2 describe-subnets \
--filters "Name=vpc-id,Values=$Vpc_ID" "Name=availability-zone,Values=us-east-1c" "Name=tag:Name,Values=PublicSubnet*" \
--query "Subnets[0].SubnetId" --output text)

echo "WebSubnet_eus1a $WebSubnet_eus1a"
echo "WebSubnet_eus1b $WebSubnet_eus1b"
echo "WebSubnet_eus1c $WebSubnet_eus1c"


echo "publicsubnet_eus1a $publicsubnet_eus1a"
echo "publicsubnet_eus1b $publicsubnet_eus1b"
echo "publicsubnet_eus1c $publicsubnet_eus1c"


#----------------------Create Cluster with managed node groups 

cat > eks-cluster.yaml <<-EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: $CLUSTER_NAME-eks
  region: $AWS_REGION
  version: "1.14"

vpc:
  subnets:
    public:
      us-east-1a: { id: $publicsubnet_eus1a }
      us-east-1b: { id: $publicsubnet_eus1b }
      us-east-1c: { id: $publicsubnet_eus1c }
    private:
      us-east-1a: { id: $WebSubnet_eus1a }
      us-east-1b: { id: $WebSubnet_eus1b }
      us-east-1c: { id: $WebSubnet_eus1c }

managedNodeGroups:
  - name: managed-external-ng-1
    instanceType: t2.micro
    minSize: 3
    maxSize: 5
    desiredCapacity: 3
    volumeSize: 20
    privateNetworking: true
    ssh:
      allow: false
    labels: {role: external}
    tags:
      nodegroup-role: worker
    iam:
      withAddonPolicies:
        externalDNS: true
        certManager: true
EOF

################ create EKS Cluster using EKSCTL
eksctl create cluster -f eks-cluster.yaml
