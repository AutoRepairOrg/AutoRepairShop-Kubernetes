# Infraestrutura Kubernetes (EKS) e manifestos da aplicação AutoRepairShop.
---

## 📖 Sobre

Este repositório contém:
- **Infraestrutura como Código (Terraform):** Provisionamento do cluster EKS na AWS
- **Manifestos Kubernetes:** Deployments, Services, ConfigMaps, Secrets, HPA
- **CI/CD:** Validação e deploy automático via GitHub Actions

---

## 🛠️ Tecnologias

- **Terraform** 1.6.6 - Infraestrutura como código
- **AWS EKS** 1.31 - Kubernetes gerenciado
- **Kubernetes** - Orquestração de containers
- **Docker** - Containerização
- **GitHub Actions** - CI/CD automático
- **kubectl** - CLI do Kubernetes
- **Horizontal Pod Autoscaler (HPA)** - Escalabilidade automática
- **Fluent Bit + Amazon CloudWatch Logs** - Coleta e centralização de logs do namespace `oficina`

---

## ✅ Pré-requisitos

- [Terraform](https://www.terraform.io/downloads) >= 1.6
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.28
- [AWS CLI](https://aws.amazon.com/cli/) configurado
- Credenciais AWS com permissões:
  - `eks:*`
  - `ec2:*`
  - `iam:*` (para IRSA)
  - `elasticloadbalancing:*`
  - `logs:*` (CloudWatch Logs — Fluent Bit usa o IAM do node / LabRole)

---

## 🚀 Instalação e Deploy

### **Método 1: Via CI/CD (Recomendado)**

1. **Configure os secrets no GitHub:**
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_SESSION_TOKEN`

2. **Faça um commit:**
   ```bash
   git add infra/ k8s/
   git commit -m "feat: atualizar configuração do cluster"
   git push origin master
   ```

3. **O workflow CD irá:**
   - ✅ Aplicar Fluent Bit (logs → CloudWatch)
   - ✅ Aplicar manifestos Kubernetes da API
   - ✅ Criar/atualizar LoadBalancer (NLB)
   - ✅ Configurar HPA
   - ✅ Reiniciar e aguardar rollout da API

---

### **Método 2: Deploy Manual**

```bash
# 1. Clone o repositório
git clone https://github.com/AutoRepairOrg/AutoRepairShop-Kubernetes.git
cd AutoRepairShop-Kubernetes

# 2. Provisionar infraestrutura com Terraform
cd infra
terraform init
terraform plan
terraform apply

# 3. Configurar kubectl
aws eks update-kubeconfig --name autorepairshop-eks --region us-east-1

# 4. Aplicar manifestos Kubernetes
cd ../k8s
kubectl apply -f namespace.yaml
kubectl apply -f api-configmap.yaml
kubectl apply -f api-secrets.yaml
kubectl apply -f api-deployment.yaml
kubectl apply -f api-service-nlb.yaml
kubectl apply -f api-hpa.yaml

# 5. Deploy Fluent Bit → CloudWatch Logs
kubectl apply -f cloudwatch-namespace.yaml
kubectl apply -f fluent-bit-cluster-info.yaml
kubectl apply -f fluent-bit-rbac.yaml
kubectl apply -f fluent-bit-configmap.yaml
kubectl apply -f fluent-bit-daemonset.yaml

# 6. Verificar deployment
kubectl get all -n oficina
kubectl get pods -n amazon-cloudwatch
kubectl get svc api-nlb -n oficina
```

---

## 🔄 CI/CD

### **Workflows**

#### **CI - Validação (Pull Requests)**
```yaml
Trigger: Pull Request → master
Jobs:
  terraform-validate:
    - Terraform Format Check
    - Terraform Init
    - Terraform Validate
  
  kubernetes-validate:
    - Kubeval (validar manifests YAML)
```

#### **CD - Deploy (Push to master)**
```yaml
Trigger: Push → master
Jobs:
  terraform-deploy:
    - Terraform Init
    - Terraform Plan
    - Terraform Apply (EKS Cluster)
  
  deploy-kubernetes:
    - Update kubeconfig
    - Deploy Fluent Bit (CloudWatch Logs)
    - Apply ConfigMaps/Secrets
    - Deploy API
    - Wait for rollout
    - Show service info
```

### **Branch Protection**

- ✅ Pull Requests obrigatórios
- ✅ CI deve passar antes do merge
- ✅ Deploy automático após merge

---

## 📁 Estrutura do Projeto

```
AutoRepairShop-Kubernetes/
├── .github/
│   └── workflows/
│       ├── ci.yml              # Validação em PRs
│       └── cd.yml              # Deploy em master
├── infra/
│   ├── main.tf                 # EKS Cluster + Node Group
│   ├── namespace.tf            # Namespace Kubernetes
│   ├── outputs.tf              # Outputs (cluster info)
│   ├── providers.tf            # Providers AWS + Kubernetes
│   ├── variables.tf            # Variáveis do Terraform
│   └── .terraform.lock.hcl     # Lock de versões
├── k8s/
│   ├── namespace.yaml                  # Namespace 'oficina'
│   ├── api-configmap.yaml              # Configurações da API
│   ├── api-secrets.yaml                # Secrets (JWT, etc)
│   ├── api-deployment.yaml             # Deployment da API
│   ├── api-service.yaml                # Service ClusterIP (interno)
│   ├── api-service-nlb.yaml            # Service LoadBalancer (externo)
│   ├── api-hpa.yaml                    # Horizontal Pod Autoscaler
│   ├── cloudwatch-namespace.yaml       # Namespace amazon-cloudwatch
│   ├── fluent-bit-cluster-info.yaml    # Cluster/região para Fluent Bit
│   ├── fluent-bit-rbac.yaml            # RBAC do Fluent Bit
│   ├── fluent-bit-configmap.yaml       # Pipeline de logs → CloudWatch
│   └── fluent-bit-daemonset.yaml       # DaemonSet Fluent Bit
└── README.md                           # Este arquivo
```

## 📊 Escalabilidade

### **Horizontal Pod Autoscaler (HPA)**

O HPA ajusta automaticamente o número de réplicas baseado em:
- **CPU:** Escala quando > 50%
- **Memória:** (configurável)
- **Custom Metrics:** (Datadog, Prometheus)

```bash
# Ver status do HPA
kubectl get hpa -n oficina

# Descrição detalhada
kubectl describe hpa api-hpa -n oficina

# Forçar scaling manual
kubectl scale deployment api --replicas=3 -n oficina
```

### **Node Group Auto Scaling**

Configurado no Terraform:
```hcl
scaling_config {
  desired_size = 1
  min_size     = 1
  max_size     = 2
}
```

---

## 📈 Monitoramento e Logs (CloudWatch)

Os pods do namespace `oficina` (API, SQL Server, etc.) enviam stdout/stderr para o **Amazon CloudWatch Logs** via **Fluent Bit** (DaemonSet).

### **Como funciona**

```
Pod (oficina) → stdout → /var/log/containers/*_oficina_*.log
                              ↓
                    Fluent Bit (DaemonSet)
                              ↓
         CloudWatch Log Group:
         /aws/containerinsights/autorepairshop-eks/application
```

- Credenciais: IAM do **node** (`LabRole`) — sem IRSA adicional
- Retenção: **7 dias** (configurada no Fluent Bit)
- Namespace do coletor: `amazon-cloudwatch`

### **Manifestos**

| Arquivo | Função |
|---------|--------|
| `k8s/cloudwatch-namespace.yaml` | Namespace `amazon-cloudwatch` |
| `k8s/fluent-bit-cluster-info.yaml` | Cluster name + região |
| `k8s/fluent-bit-rbac.yaml` | ServiceAccount + ClusterRole |
| `k8s/fluent-bit-configmap.yaml` | Pipeline Fluent Bit → CloudWatch |
| `k8s/fluent-bit-daemonset.yaml` | DaemonSet `aws-for-fluent-bit` |

### **Consultar logs**

```bash
# Status do Fluent Bit
kubectl get pods -n amazon-cloudwatch -l k8s-app=fluent-bit
kubectl logs -n amazon-cloudwatch -l k8s-app=fluent-bit --tail=50

# Tail no CloudWatch (após o DaemonSet estar Running)
aws logs tail /aws/containerinsights/autorepairshop-eks/application --follow --region us-east-1

# Filtrar por pod/stream
aws logs describe-log-streams \
  --log-group-name /aws/containerinsights/autorepairshop-eks/application \
  --region us-east-1 \
  --order-by LastEventTime \
  --descending \
  --max-items 10
```

No console AWS: **CloudWatch → Log groups →** `/aws/containerinsights/autorepairshop-eks/application`.

### **Comandos Úteis (cluster)**

```bash
# Visualizar pods
kubectl get pods -n oficina

# Logs em tempo real (kubectl)
kubectl logs -f deployment/api -n oficina

# Métricas de recursos
kubectl top pods -n oficina
kubectl top nodes

# Status do deployment
kubectl rollout status deployment/api -n oficina

# Histórico de rollouts
kubectl rollout history deployment/api -n oficina

# Eventos
kubectl get events -n oficina --sort-by='.lastTimestamp'
```

### **Health Checks**

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
```

## 🔐 Secrets Management

### **Opção 1: Kubernetes Secrets (atual)**
```bash
kubectl create secret generic api-secrets \
  --from-literal=Jwt__Key=<KEY> \
  --namespace=oficina
```

### **Opção 2: External Secrets Operator (recomendado para produção)**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: api-secrets
  namespace: oficina
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: api-secrets
  data:
  - secretKey: Jwt__Key
    remoteRef:
      key: autorepair/jwt-key
```

---
## 📊 Recursos Criados

### **AWS Resources**
- ✅ EKS Cluster (Control Plane)
- ✅ Node Group (EC2 instances)
- ✅ VPC (se não existir)
- ✅ Security Groups
- ✅ IAM Roles (cluster + nodes)
- ✅ Network Load Balancer
- ✅ Target Groups

### **Kubernetes Resources**
- ✅ Namespace: `oficina`
- ✅ Deployment: `api`
- ✅ Service (ClusterIP): `api`
- ✅ Service (LoadBalancer): `api-nlb`
- ✅ ConfigMap: `api-config`
- ✅ Secret: `api-secrets`
- ✅ HPA: `api-hpa`
- ✅ Namespace: `amazon-cloudwatch`
- ✅ DaemonSet: `fluent-bit` (logs → CloudWatch)

### **CloudWatch Resources**
- ✅ Log group: `/aws/containerinsights/autorepairshop-eks/application` (criado automaticamente)

---

## 📄 Licença

Este projeto faz parte do **Tech Challenge - Fase 3** da FIAP.

**Autores:**
- Dhiulia da Silva
- Mateus Pinheiro

---

## 🔗 Links Relacionados

- [AutoRepairShop-Api](https://github.com/AutoRepairOrg/AutoRepairShop-Api) - Aplicação principal
- [AutoRepairShop-Database](https://github.com/AutoRepairOrg/AutoRepairShop-Database) - RDS SQL Server
- [AutoRepairShop-Lambda](https://github.com/AutoRepairOrg/AutoRepairShop-Lambda) - Autenticação serverless
