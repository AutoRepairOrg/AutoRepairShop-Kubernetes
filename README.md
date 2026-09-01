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
   - ✅ Provisionar EKS Cluster
   - ✅ Criar Node Group
   - ✅ Aplicar manifestos Kubernetes
   - ✅ Criar LoadBalancer (NLB)
   - ✅ Configurar HPA

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

# 5. Verificar deployment
kubectl get all -n oficina
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
    - Apply namespace
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
│   ├── namespace.yaml          # Namespace 'oficina'
│   ├── api-configmap.yaml      # Configurações da API
│   ├── api-secrets.yaml        # Secrets (JWT, etc)
│   ├── api-deployment.yaml     # Deployment da API
│   ├── api-service.yaml        # Service ClusterIP (interno)
│   ├── api-service-nlb.yaml    # Service LoadBalancer (externo)
│   └── api-hpa.yaml            # Horizontal Pod Autoscaler
└── README.md                   # Este arquivo
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

## 📈 Monitoramento

### **Comandos Úteis**

```bash
# Visualizar pods
kubectl get pods -n oficina

# Logs em tempo real
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

