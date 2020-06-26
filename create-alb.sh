STACK_NAME=wptest20

AWS_ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
Vpc_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='Vpc'].OutputValue" --output text)
AWS_REGION=us-east-1
CLUSTER_NAME=ca-gov-wpaas-eks

# create OIDC authentication provider 
eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --approve

#create IAM policy 
wget -O alb-ingress-iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/master/docs/examples/iam-policy.json
aws iam create-policy --policy-name ALBIngressControllerIAMPolicy --policy-document file://alb-ingress-iam-policy.json


#create file for RBAC of cluster role 
cat > rbac-role.yaml <<-EOF
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/name: alb-ingress-controller
  name: alb-ingress-controller
rules:
  - apiGroups:
      - ""
      - extensions
    resources:
      - configmaps
      - endpoints
      - events
      - ingresses
      - ingresses/status
      - services
    verbs:
      - create
      - get
      - list
      - update
      - watch
      - patch
  - apiGroups:
      - ""
      - extensions
    resources:
      - nodes
      - pods
      - secrets
      - services
      - namespaces
    verbs:
      - get
      - list
      - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/name: alb-ingress-controller
  name: alb-ingress-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: alb-ingress-controller
subjects:
  - kind: ServiceAccount
    name: alb-ingress-controller
    namespace: kube-system
EOF

kubectl apply -f rbac-role.yaml

#create kubernetes service account
eksctl create iamserviceaccount \
--name alb-ingress-controller \
--namespace kube-system \
--cluster $CLUSTER_NAME \
--attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/ALBIngressControllerIAMPolicy \
--approve


# YMAL file for ALB ingress controller 
cat > alb-ingress-controller.yaml <<-EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: alb-ingress-controller
  name: alb-ingress-controller
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: alb-ingress-controller
  template:
    metadata:
      labels:
        app.kubernetes.io/name: alb-ingress-controller
    spec:
      containers:
      - name: alb-ingress-controller
        args:
        - --ingress-class=alb
        - --cluster-name=ca-gov-wpaas-eks
        image: docker.io/amazon/aws-alb-ingress-controller:v1.1.6
      serviceAccountName: alb-ingress-controller
EOF



#command to deploy alb ingress contoller 
kubectl apply -f alb-ingress-controller.yaml
