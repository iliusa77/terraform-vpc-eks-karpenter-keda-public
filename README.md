This repository contains Github Actions pipeline and Terraform modules/resources
for Amazon VPC and EKS cluster (with [`Bottlerocket OS`](https://github.com/bottlerocket-os/bottlerocket) AMI in EKS node groups) deploy with `Karpenter`,`KEDA`,`Metrics Server` and `Kubernetes Operational View` Kubernetes controllers.


## Manual Deploy (with local Terraform)

- Create S3 bucket for Terraform backend and DynamoDB table (Partition key: LockID) for locking and update `bucket`,`region` and `dynamodb_table` in `providers.tf` section:
```
  backend "s3" {
    bucket = "karpenter-eks2"
    key    = "terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "karpenter_eks_terraform_state"
  }
```

- Update (if needed) EKS version, EC2 instance types, min/max/desired size in `eks.tf`
```
cluster_version = "1.30"
  eks_managed_node_groups = {
    karpenter = {
      instance_types = ["t2.medium","t2.small"]
      capacity_type = "SPOT"

      min_size     = 1
      max_size     = 100
      desired_size = 1
```

- Configure aws-cli
```
aws configure
```

- Enable profile 

Uncomment in `providers.tf` the following:
```
provider "aws" {
  #profile    = "${var.profile}"
```

Uncomment in `vars.tf` the following:
```
#variable "profile" {
#  description = "AWS credentials profile you want to use"
#  default     = "default" 
#}
```

- Define Terraform variables in `vars.tf`
```
# AWS Region
variable "region" {}

# AWS account (this is important for connection to cluster with kubectl)
variable "aws_account" {}

# AWS IAM user  (this is important for connection to cluster with kubectl)
variable "aws_user" {}

```

- VPC & EKS creation
```
terraform init
terraform plan
terraform apply -auto-approve
```

- Switch EKS cluster Authentication mode from `ConfigMap` to `EKS API and ConfigMap` if get error during `terraform apply`


- Add EKS cluster in kube config
```
aws eks list-clusters
{
    "clusters": [
        "karpenter-eks-cluster"
    ]
}

aws eks update-kubeconfig --region us-east-1 --name karpenter-eks-cluster
```

### Karpenter
- Check Karpenter resources
```
helm ls -n karpenter
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
karpenter       karpenter       1               2024-05-29 10:52:14.690640595 +0000 UTC deployed        karpenter-v0.32.1       0.32.1     
karpenter-crd   karpenter       1               2024-05-29 09:54:47.166396414 +0000 UTC deployed        karpenter-crd-v0.32.1   0.32.1  

kubectl get all -n karpenter
NAME                             READY   STATUS    RESTARTS   AGE
pod/karpenter-7f7bb85b84-74886   1/1     Running   0          3m
pod/karpenter-7f7bb85b84-mwdp6   1/1     Running   0          3m

NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
service/karpenter   ClusterIP   172.20.38.116   <none>        8000/TCP,8001/TCP,8443/TCP   3m1s

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/karpenter   2/2     2            2           3m1s

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/karpenter-7f7bb85b84   2         2         2       3m1s
```

### KEDA
- Check KEDA resources
```
helm ls -n keda     
NAME    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART           APP VERSION
keda    keda            1               2024-05-29 12:08:41.020917509 +0000 UTC deployed        keda-2.8.2      2.8.1 

kubectl get all -n keda
NAME                                                   READY   STATUS    RESTARTS       AGE
pod/keda-operator-775755f6ff-2lkn4                     1/1     Running   5 (111s ago)   14m
pod/keda-operator-metrics-apiserver-77f4cbf988-g8rv9   1/1     Running   0              39m

NAME                                      TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
service/keda-operator-metrics-apiserver   ClusterIP   172.20.23.17   <none>        443/TCP,80/TCP   39m

NAME                                              READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/keda-operator                     1/1     1            1           39m
deployment.apps/keda-operator-metrics-apiserver   1/1     1            1           39m

NAME                                                         DESIRED   CURRENT   READY   AGE
replicaset.apps/keda-operator-775755f6ff                     1         1         1       39m
replicaset.apps/keda-operator-metrics-apiserver-77f4cbf988   1         1         1       39m
```

- Check Metrics Server, KEDA Scaled Objects, Nginx deployment, pod, replica set
```
kubectl get po -n kube-system | grep metrics-server                   
metrics-server-5676b464d-247gh   1/1     Running   0          8m45s

kubectl get so -n default
NAME               SCALETARGETKIND   SCALETARGETNAME   MIN   MAX   TRIGGERS   AUTHENTICATION   READY   ACTIVE   FALLBACK   AGE
cpu-scaledobject                     nginx             1     10    cpu                                                     8m14s

kubectl get deploy -n default | grep nginx
nginx     1/1     1            1           2m46s

kubectl get po -n default | grep nginx    
nginx-77d8468669-mzpdx   1/1     Running   0          3m20s

kubectl get rs -n default | grep nginx
nginx-77d8468669     1         1         1       6m5s

kubectl get svc -n default | grep nginx
nginx        ClusterIP   172.20.197.144   <none>        80/TCP    6m41s
```

- Validate scaling by generating traffic loads to see if KEDA autoscaling will take place
```
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never --namespace default -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://nginx.default.svc.cluster.local; done" 
```


- Cleanup: VPC & EKS destroy
```
terraform destroy -auto-approve
```


## Auto Deploy with Github Actions

- Create S3 bucket for Terraform backend and DynamoDB table (Partition key: LockID) for locking and update `bucket`,`region` and `dynamodb_table` in `providers.tf` section:
```
  backend "s3" {
    bucket = "karpenter-eks2"
    key    = "terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "karpenter_eks_terraform_state"
  }
```

- Update (if needed) EKS version, EC2 instance types, min/max/desired size in `eks.tf`
```
cluster_version = "1.30"
  eks_managed_node_groups = {
    karpenter = {
      instance_types = ["t2.medium","t2.small"]
      capacity_type = "SPOT"

      min_size     = 1
      max_size     = 100
      desired_size = 1
```

- Disable profile 

Comment in `providers.tf` the following:
```
provider "aws" {
  profile    = "${var.profile}"
}
```

Comment in `vars.tf` the following:
```
variable "profile" {
  description = "AWS credentials profile you want to use"
  default     = "default" 
}
```

Go to Github Actions tab and run "Terraform - VPC & EKS & Karpenter & KEDA" pipeline


