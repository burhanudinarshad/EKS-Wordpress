mkdir prometheus
cd ./prometheus

cat > prometheus-storageclass.yaml <<-EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: prometheus
  namespace: prometheus
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
reclaimPolicy: Retain
mountOptions:
  debug
EOF

kubectl apply -f prometheus-storageclass.yaml


wget https://raw.githubusercontent.com/jonnalagadda35153/EKS-Fargate/master/EKS_Fargate_Monitoring/Monitoring/prometheus_values.yml
helm install prometheus -f prometheus_values.yml stable/prometheus --namespace prometheus
